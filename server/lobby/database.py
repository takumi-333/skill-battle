"""SQLite-backed public-room state machine.

All state changes share one process lock and an explicit ``BEGIN IMMEDIATE``
transaction. The public deployment intentionally uses one uvicorn worker;
this class does not claim cross-process locking semantics.
"""
from __future__ import annotations

from contextlib import contextmanager
import hashlib
import json
import secrets
import sqlite3
import threading
import time
import uuid
from typing import Iterator


ROOM_STATES = ("AVAILABLE", "RESERVED", "CONNECTING", "CONNECTED", "RUNNING", "CLOSED")
RESERVATION_STATES = ("RESERVED", "CONNECTING", "CONNECTED", "RUNNING", "CLOSED")
MATCH_MODES = {"duel": 2, "free_for_all": 3}


class DatabaseBusy(RuntimeError):
    """The SQLite writer lock could not be acquired safely."""


class LobbyDatabase:
    def __init__(self, path: str) -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False, isolation_level=None, timeout=1.0)
        self.connection.row_factory = sqlite3.Row
        self._lock = threading.RLock()
        # journal_mode is a connection-wide operation and SQLite forbids it
        # inside BEGIN; perform it before the first state transaction.
        self.connection.execute("PRAGMA foreign_keys=ON")
        self.connection.execute("PRAGMA journal_mode=WAL")
        with self._transaction():
            self.connection.execute("""CREATE TABLE IF NOT EXISTS rooms (
                id TEXT PRIMARY KEY, name TEXT NOT NULL, status TEXT NOT NULL,
                created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
                slot1_reserved_until INTEGER, slot2_reserved_until INTEGER,
                match_mode TEXT NOT NULL DEFAULT 'duel'
            )""")
            self.connection.execute("""CREATE TABLE IF NOT EXISTS reservations (
                room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
                slot INTEGER NOT NULL CHECK(slot IN (1,2,3)),
                state TEXT NOT NULL CHECK(state IN ('RESERVED','CONNECTING','CONNECTED','RUNNING','CLOSED')),
                reserved_until INTEGER,
                connecting_lease_until INTEGER,
                connected_at INTEGER,
                created_at INTEGER NOT NULL,
                updated_at INTEGER NOT NULL,
                PRIMARY KEY(room_id, slot)
            )""")
            self.connection.execute("""CREATE TABLE IF NOT EXISTS nonces (
                nonce_hash TEXT PRIMARY KEY,
                room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
                slot INTEGER NOT NULL CHECK(slot IN (1,2,3)),
                expires_at INTEGER NOT NULL,
                issued_at INTEGER NOT NULL,
                used_at INTEGER
            )""")
            self.connection.execute("CREATE INDEX IF NOT EXISTS nonces_lookup ON nonces(room_id,slot,used_at,expires_at)")
            self.connection.execute("""CREATE TABLE IF NOT EXISTS server_heartbeats (
                singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
                received_at INTEGER NOT NULL, payload TEXT NOT NULL
            )""")
            self.connection.execute("""CREATE TABLE IF NOT EXISTS server_events (
                id INTEGER PRIMARY KEY AUTOINCREMENT, created_at INTEGER NOT NULL,
                kind TEXT NOT NULL, room_id TEXT, payload TEXT NOT NULL
            )""")
            # Upgrade databases created by the pre-state-machine implementation.
            self.connection.execute("UPDATE rooms SET status='AVAILABLE' WHERE status='open'")
            self.connection.execute("UPDATE rooms SET status='RUNNING' WHERE status='running'")
            self.connection.execute("UPDATE rooms SET status='CLOSED' WHERE status='closed'")
            self._migrate_match_mode_schema()

    @contextmanager
    def _transaction(self) -> Iterator[None]:
        with self._lock:
            try:
                self.connection.execute("BEGIN IMMEDIATE")
                yield
            except sqlite3.OperationalError as error:
                self.connection.rollback()
                if "locked" in str(error).lower() or "busy" in str(error).lower():
                    raise DatabaseBusy("SQLite is busy") from error
                raise
            except Exception:
                self.connection.rollback()
                raise
            else:
                self.connection.commit()

    @staticmethod
    def _nonce_hash(nonce: str) -> str:
        return hashlib.sha256(nonce.encode("utf-8")).hexdigest()

    def create_room(self, name: str, match_mode: str = "duel", reservation_seconds: int = 60, token_seconds: int = 60) -> dict:
        """Create a room and slot-one reservation with one redeemable nonce."""
        now = int(time.time())
        match_mode = match_mode if match_mode in MATCH_MODES else "duel"
        room = {"id": uuid.uuid4().hex, "name": name[:48], "status": "RESERVED", "match_mode": match_mode, "created_at": now, "updated_at": now}
        nonce = secrets.token_urlsafe(32)
        with self._transaction():
            self._recover_expired(now)
            self.connection.execute(
                "INSERT INTO rooms(id,name,status,match_mode,created_at,updated_at) VALUES(:id,:name,:status,:match_mode,:created_at,:updated_at)", room
            )
            self._insert_reservation(room["id"], 1, nonce, now, reservation_seconds, token_seconds)
        return {"room": room, "slot": 1, "nonce": nonce}

    def reserve(self, room_id: str, reservation_seconds: int = 60, token_seconds: int = 60) -> dict | None:
        """Atomically reserve exactly one currently-unassigned slot."""
        now = int(time.time())
        with self._transaction():
            self._recover_expired(now)
            room = self.connection.execute("SELECT * FROM rooms WHERE id=?", (room_id,)).fetchone()
            if room is None or room["status"] in {"RUNNING", "CLOSED"}:
                return None
            occupied = {
                int(row["slot"])
                for row in self.connection.execute(
                    "SELECT slot FROM reservations WHERE room_id=? AND state != 'CLOSED'", (room_id,)
                ).fetchall()
            }
            capacity = MATCH_MODES.get(str(room["match_mode"]), 2)
            slot = next((candidate for candidate in range(1, capacity + 1) if candidate not in occupied), 0)
            if slot == 0:
                return None
            nonce = secrets.token_urlsafe(32)
            self._insert_reservation(room_id, slot, nonce, now, reservation_seconds, token_seconds)
            self._refresh_room_state(room_id, now)
            return {"room": self._room_dict(room_id), "slot": slot, "nonce": nonce}

    def list_rooms(self) -> list[dict]:
        now = int(time.time())
        with self._transaction():
            self._recover_expired(now)
            rows = self.connection.execute(
                """SELECT r.id,r.name,r.status,r.match_mode,COUNT(s.slot) AS players
                   FROM rooms r JOIN reservations s ON s.room_id=r.id
                   WHERE r.status IN ('AVAILABLE','RESERVED','CONNECTING','CONNECTED')
                     AND s.state IN ('RESERVED','CONNECTING','CONNECTED')
                   GROUP BY r.id ORDER BY r.created_at DESC"""
            ).fetchall()
            return [{"id": row["id"], "name": row["name"], "status": row["status"], "match_mode": row["match_mode"], "capacity": MATCH_MODES.get(row["match_mode"], 2), "players": int(row["players"])} for row in rows]

    def consume_nonce(self, room_id: str, slot: int, nonce: str, connecting_lease_seconds: int = 15) -> bool:
        """One-way nonce consumption and RESERVED -> CONNECTING transition."""
        if slot not in (1, 2, 3) or not nonce:
            return False
        now = int(time.time())
        with self._transaction():
            self._recover_expired(now)
            nonce_hash = self._nonce_hash(nonce)
            nonce_row = self.connection.execute(
                "SELECT room_id,slot FROM nonces WHERE nonce_hash=? AND used_at IS NULL AND expires_at>=?",
                (nonce_hash, now),
            ).fetchone()
            if nonce_row is None or nonce_row["room_id"] != room_id or int(nonce_row["slot"]) != slot:
                return False
            updated = self.connection.execute(
                """UPDATE reservations SET state='CONNECTING', connecting_lease_until=?, updated_at=?
                   WHERE room_id=? AND slot=? AND state='RESERVED' AND reserved_until>=?""",
                (now + connecting_lease_seconds, now, room_id, slot, now),
            ).rowcount
            if updated != 1:
                return False
            consumed = self.connection.execute(
                "UPDATE nonces SET used_at=? WHERE nonce_hash=? AND used_at IS NULL", (now, nonce_hash)
            ).rowcount
            if consumed != 1:
                raise RuntimeError("nonce state changed during serialized consume")
            self._refresh_room_state(room_id, now)
            return True

    def notify_status(self, room_id: str, slot: int | None, status: str) -> bool:
        """Apply only legal Dedicated Server notifications to the state machine."""
        now = int(time.time())
        with self._transaction():
            self._recover_expired(now)
            room = self.connection.execute("SELECT status FROM rooms WHERE id=?", (room_id,)).fetchone()
            if room is None:
                # A late disconnect after lease recovery is already safe and
                # must not make the Dedicated Server retry forever.
                return status in {"disconnected", "closed"}
            if room["status"] == "CLOSED":
                return status in {"disconnected", "closed"}
            if status == "connected" and slot in (1, 2, 3):
                changed = self.connection.execute(
                    """UPDATE reservations SET state='CONNECTED', connected_at=?, connecting_lease_until=NULL, updated_at=?
                       WHERE room_id=? AND slot=? AND state='CONNECTING'""",
                    (now, now, room_id, slot),
                ).rowcount
                if changed:
                    self._refresh_room_state(room_id, now)
                    return True
                current = self.connection.execute(
                    "SELECT state FROM reservations WHERE room_id=? AND slot=?", (room_id, slot)
                ).fetchone()
                return current is not None and current["state"] == "CONNECTED"
            if status == "disconnected" and slot in (1, 2, 3):
                if room["status"] == "RUNNING":
                    return self._close_room(room_id, now)
                changed = self.connection.execute(
                    "DELETE FROM reservations WHERE room_id=? AND slot=? AND state IN ('CONNECTING','CONNECTED')",
                    (room_id, slot),
                ).rowcount
                if changed:
                    self._refresh_room_state(room_id, now)
                    self._remove_empty_nonterminal_rooms()
                    return True
                # A delayed duplicate disconnect must not retry forever.  It is
                # also important not to delete a new RESERVED row that reused
                # this slot after the original peer was already released.
                return True
            if status == "running":
                if room["status"] == "RUNNING":
                    return True
                connected = self.connection.execute(
                    "SELECT COUNT(*) FROM reservations WHERE room_id=? AND state='CONNECTED'", (room_id,)
                ).fetchone()[0]
                mode_row = self.connection.execute("SELECT match_mode FROM rooms WHERE id=?", (room_id,)).fetchone()
                if connected != MATCH_MODES.get(str(mode_row["match_mode"]) if mode_row else "duel", 2):
                    return False
                self.connection.execute("UPDATE reservations SET state='RUNNING',updated_at=? WHERE room_id=? AND state='CONNECTED'", (now, room_id))
                self.connection.execute("UPDATE rooms SET status='RUNNING',updated_at=? WHERE id=?", (now, room_id))
                return True
            if status == "closed":
                return self._close_room(room_id, now)
            return False

    def release_reservation(self, room_id: str, slot: int) -> bool:
        """Compatibility wrapper for an authoritative pre-match disconnect."""
        return self.notify_status(room_id, slot, "disconnected")

    def reconcile_server_restart(self) -> int:
        """Close state owned by a previous Dedicated Server process.

        A restarted server has no in-memory sessions or authenticated peers, so
        retaining CONNECTED/RUNNING reservations would publish unusable rooms.
        They are closed rather than returned to AVAILABLE: their already-issued
        tickets remain unusable and no slot can be assigned twice.
        """
        now = int(time.time())
        with self._transaction():
            room_ids = [row["id"] for row in self.connection.execute("SELECT id FROM rooms WHERE status != 'CLOSED'").fetchall()]
            if room_ids:
                self.connection.execute("UPDATE rooms SET status='CLOSED',updated_at=? WHERE status != 'CLOSED'", (now,))
                self.connection.execute("UPDATE reservations SET state='CLOSED',updated_at=? WHERE state != 'CLOSED'", (now,))
            return len(room_ids)

    def get_room(self, room_id: str) -> dict | None:
        with self._lock:
            row = self.connection.execute("SELECT id,name,status,match_mode,created_at,updated_at FROM rooms WHERE id=?", (room_id,)).fetchone()
            return None if row is None else dict(row)

    def record_server_update(self, kind: str, room_id: str | None, payload: dict) -> None:
        now = int(time.time())
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        with self._transaction():
            if kind == "heartbeat":
                self.connection.execute(
                    "INSERT INTO server_heartbeats(singleton,received_at,payload) VALUES(1,?,?) "
                    "ON CONFLICT(singleton) DO UPDATE SET received_at=excluded.received_at,payload=excluded.payload",
                    (now, encoded),
                )
            else:
                self.connection.execute("INSERT INTO server_events(created_at,kind,room_id,payload) VALUES(?,?,?,?)", (now, kind[:64], room_id, encoded))
                self.connection.execute("DELETE FROM server_events WHERE id NOT IN (SELECT id FROM server_events ORDER BY id DESC LIMIT 500)")

    def server_monitoring(self, event_limit: int = 50) -> dict:
        with self._lock:
            heartbeat = self.connection.execute("SELECT received_at,payload FROM server_heartbeats WHERE singleton=1").fetchone()
            events = self.connection.execute(
                "SELECT created_at,kind,room_id,payload FROM server_events ORDER BY id DESC LIMIT ?", (max(1, min(event_limit, 100)),)
            ).fetchall()
        return {
            "heartbeat": None if heartbeat is None else {"received_at": heartbeat["received_at"], "details": json.loads(heartbeat["payload"])},
            "events": [{"created_at": row["created_at"], "kind": row["kind"], "room_id": row["room_id"], "details": json.loads(row["payload"])} for row in events],
        }

    def _insert_reservation(self, room_id: str, slot: int, nonce: str, now: int, reservation_seconds: int, token_seconds: int) -> None:
        self.connection.execute(
            """INSERT INTO reservations(room_id,slot,state,reserved_until,connecting_lease_until,connected_at,created_at,updated_at)
               VALUES(?,?,'RESERVED',?,NULL,NULL,?,?)""",
            (room_id, slot, now + reservation_seconds, now, now),
        )
        self.connection.execute(
            "INSERT INTO nonces(nonce_hash,room_id,slot,expires_at,issued_at,used_at) VALUES(?,?,?,?,?,NULL)",
            (self._nonce_hash(nonce), room_id, slot, now + token_seconds, now),
        )

    def _room_dict(self, room_id: str) -> dict:
        row = self.connection.execute("SELECT id,name,status,match_mode,created_at,updated_at FROM rooms WHERE id=?", (room_id,)).fetchone()
        return dict(row) if row is not None else {}

    def _refresh_room_state(self, room_id: str, now: int) -> None:
        room = self.connection.execute("SELECT status FROM rooms WHERE id=?", (room_id,)).fetchone()
        if room is None or room["status"] == "CLOSED":
            return
        states = {row["state"] for row in self.connection.execute("SELECT state FROM reservations WHERE room_id=?", (room_id,)).fetchall()}
        if "RUNNING" in states:
            status = "RUNNING"
        elif "CONNECTED" in states:
            status = "CONNECTED"
        elif "CONNECTING" in states:
            status = "CONNECTING"
        elif "RESERVED" in states:
            status = "RESERVED"
        else:
            status = "AVAILABLE"
        self.connection.execute("UPDATE rooms SET status=?,updated_at=? WHERE id=?", (status, now, room_id))

    def _close_room(self, room_id: str, now: int) -> bool:
        changed = self.connection.execute("UPDATE rooms SET status='CLOSED',updated_at=? WHERE id=? AND status!='CLOSED'", (now, room_id)).rowcount
        if changed:
            self.connection.execute("UPDATE reservations SET state='CLOSED',updated_at=? WHERE room_id=? AND state!='CLOSED'", (now, room_id))
        return changed == 1

    def _recover_expired(self, now: int) -> None:
        affected = self.connection.execute(
            "SELECT DISTINCT room_id FROM reservations WHERE (state='RESERVED' AND reserved_until<?) OR (state='CONNECTING' AND connecting_lease_until<?)",
            (now, now),
        ).fetchall()
        self.connection.execute("DELETE FROM reservations WHERE state='RESERVED' AND reserved_until<?", (now,))
        self.connection.execute("DELETE FROM reservations WHERE state='CONNECTING' AND connecting_lease_until<?", (now,))
        for row in affected:
            self._refresh_room_state(row["room_id"], now)
        self._remove_empty_nonterminal_rooms()

    def _remove_empty_nonterminal_rooms(self) -> None:
        self.connection.execute(
            """DELETE FROM rooms WHERE status='AVAILABLE'
               AND NOT EXISTS (SELECT 1 FROM reservations WHERE reservations.room_id=rooms.id)"""
        )

    def _migrate_match_mode_schema(self) -> None:
        columns = {row["name"] for row in self.connection.execute("PRAGMA table_info(rooms)").fetchall()}
        if "match_mode" not in columns:
            self.connection.execute("ALTER TABLE rooms ADD COLUMN match_mode TEXT NOT NULL DEFAULT 'duel'")
        # SQLite cannot alter CHECK constraints. Rebuild only legacy two-slot tables.
        for table in ("reservations", "nonces"):
            sql_row = self.connection.execute("SELECT sql FROM sqlite_master WHERE type='table' AND name=?", (table,)).fetchone()
            if sql_row is None or "IN(1,2)" not in str(sql_row["sql"]).replace(" ", ""):
                continue
            self.connection.execute(f"ALTER TABLE {table} RENAME TO {table}_legacy")
            if table == "reservations":
                self.connection.execute("""CREATE TABLE reservations (
                    room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
                    slot INTEGER NOT NULL CHECK(slot IN (1,2,3)),
                    state TEXT NOT NULL CHECK(state IN ('RESERVED','CONNECTING','CONNECTED','RUNNING','CLOSED')),
                    reserved_until INTEGER, connecting_lease_until INTEGER, connected_at INTEGER,
                    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, PRIMARY KEY(room_id, slot))""")
            else:
                self.connection.execute("""CREATE TABLE nonces (
                    nonce_hash TEXT PRIMARY KEY, room_id TEXT NOT NULL REFERENCES rooms(id) ON DELETE CASCADE,
                    slot INTEGER NOT NULL CHECK(slot IN (1,2,3)), expires_at INTEGER NOT NULL,
                    issued_at INTEGER NOT NULL, used_at INTEGER)""")
            self.connection.execute(f"INSERT INTO {table} SELECT * FROM {table}_legacy")
            self.connection.execute(f"DROP TABLE {table}_legacy")
        self.connection.execute("CREATE INDEX IF NOT EXISTS nonces_lookup ON nonces(room_id,slot,used_at,expires_at)")
