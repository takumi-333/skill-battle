"""SQLite persistence. Every reservation update runs in one immediate transaction."""
import sqlite3
import time
import uuid
import json


class LobbyDatabase:
    def __init__(self, path: str) -> None:
        self.connection = sqlite3.connect(path, check_same_thread=False)
        self.connection.row_factory = sqlite3.Row
        self.connection.execute("""CREATE TABLE IF NOT EXISTS rooms (
            id TEXT PRIMARY KEY, name TEXT NOT NULL, status TEXT NOT NULL,
            created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL,
            slot1_reserved_until INTEGER, slot2_reserved_until INTEGER
        )""")
        self.connection.execute("""CREATE TABLE IF NOT EXISTS server_heartbeats (
            singleton INTEGER PRIMARY KEY CHECK(singleton = 1),
            received_at INTEGER NOT NULL,
            payload TEXT NOT NULL
        )""")
        self.connection.execute("""CREATE TABLE IF NOT EXISTS server_events (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            created_at INTEGER NOT NULL,
            kind TEXT NOT NULL,
            room_id TEXT,
            payload TEXT NOT NULL
        )""")
        self.connection.commit()

    def create_room(self, name: str) -> tuple[dict, int]:
        now = int(time.time())
        room = {"id": uuid.uuid4().hex, "name": name[:48], "status": "open", "created_at": now, "updated_at": now}
        with self.connection:
            self.connection.execute("INSERT INTO rooms(id,name,status,created_at,updated_at) VALUES(:id,:name,:status,:created_at,:updated_at)", room)
            self.connection.execute("UPDATE rooms SET slot1_reserved_until=? WHERE id=?", (now + 60, room["id"]))
        return room, 1

    def list_rooms(self) -> list[dict]:
        with self.connection:
            self._expire()
        rows = self.connection.execute("SELECT id,name,status,slot1_reserved_until,slot2_reserved_until FROM rooms WHERE status != 'closed' ORDER BY created_at DESC").fetchall()
        now = int(time.time())
        return [{"id": row["id"], "name": row["name"], "status": row["status"], "players": int((row["slot1_reserved_until"] or 0) > now) + int((row["slot2_reserved_until"] or 0) > now)} for row in rows]

    def reserve(self, room_id: str) -> int | None:
        now = int(time.time())
        with self.connection:
            self._expire()
            room = self.connection.execute("SELECT * FROM rooms WHERE id=? AND status='open'", (room_id,)).fetchone()
            if room is None:
                return None
            for slot in (1, 2):
                column = f"slot{slot}_reserved_until"
                if not room[column] or room[column] < now:
                    self.connection.execute(f"UPDATE rooms SET {column}=?,updated_at=? WHERE id=?", (now + 60, now, room_id))
                    return slot
        return None

    def update_status(self, room_id: str, status: str) -> bool:
        if status not in {"open", "running", "closed"}:
            return False
        with self.connection:
            return self.connection.execute("UPDATE rooms SET status=?,updated_at=? WHERE id=?", (status, int(time.time()), room_id)).rowcount == 1

    def record_server_update(self, kind: str, room_id: str | None, payload: dict) -> None:
        now = int(time.time())
        encoded = json.dumps(payload, ensure_ascii=False, separators=(",", ":"))
        with self.connection:
            if kind == "heartbeat":
                self.connection.execute(
                    "INSERT INTO server_heartbeats(singleton,received_at,payload) VALUES(1,?,?) "
                    "ON CONFLICT(singleton) DO UPDATE SET received_at=excluded.received_at,payload=excluded.payload",
                    (now, encoded),
                )
            else:
                self.connection.execute(
                    "INSERT INTO server_events(created_at,kind,room_id,payload) VALUES(?,?,?,?)",
                    (now, kind[:64], room_id, encoded),
                )
                self.connection.execute(
                    "DELETE FROM server_events WHERE id NOT IN "
                    "(SELECT id FROM server_events ORDER BY id DESC LIMIT 500)"
                )

    def server_monitoring(self, event_limit: int = 50) -> dict:
        heartbeat = self.connection.execute(
            "SELECT received_at,payload FROM server_heartbeats WHERE singleton=1"
        ).fetchone()
        events = self.connection.execute(
            "SELECT created_at,kind,room_id,payload FROM server_events ORDER BY id DESC LIMIT ?",
            (max(1, min(event_limit, 100)),),
        ).fetchall()
        return {
            "heartbeat": None if heartbeat is None else {
                "received_at": heartbeat["received_at"],
                "details": json.loads(heartbeat["payload"]),
            },
            "events": [{
                "created_at": row["created_at"],
                "kind": row["kind"],
                "room_id": row["room_id"],
                "details": json.loads(row["payload"]),
            } for row in events],
        }

    def _expire(self) -> None:
        now = int(time.time())
        self.connection.execute("UPDATE rooms SET slot1_reserved_until=NULL WHERE slot1_reserved_until < ?", (now,))
        self.connection.execute("UPDATE rooms SET slot2_reserved_until=NULL WHERE slot2_reserved_until < ?", (now,))
        # A room whose creator never completed the ENet connection must not
        # remain in the public list indefinitely after its reservation expires.
        self.connection.execute("DELETE FROM rooms WHERE status='open' AND slot1_reserved_until IS NULL AND slot2_reserved_until IS NULL")
