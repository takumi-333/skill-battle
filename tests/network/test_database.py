import sys
import threading
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "server" / "lobby"))
from database import LobbyDatabase


def _connect_both(db: LobbyDatabase, room_id: str, first: dict, second: dict) -> None:
    assert db.consume_nonce(room_id, 1, first["nonce"])
    assert db.notify_status(room_id, 1, "connected")
    assert db.consume_nonce(room_id, 2, second["nonce"])
    assert db.notify_status(room_id, 2, "connected")


def test_room_reservations_are_limited_to_two_slots_and_atomic(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    created = db.create_room("test")
    room_id = created["room"]["id"]
    results = []

    def reserve() -> None:
        results.append(db.reserve(room_id))

    workers = [threading.Thread(target=reserve) for _ in range(8)]
    for worker in workers:
        worker.start()
    for worker in workers:
        worker.join()

    successful = [result for result in results if result is not None]
    assert len(successful) == 1
    assert successful[0]["slot"] == 2
    assert db.list_rooms()[0]["players"] == 2


def test_nonce_is_consumed_once_and_connecting_lease_never_rewinds_it(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    created = db.create_room("nonce", reservation_seconds=120, token_seconds=120)
    room_id = created["room"]["id"]
    assert db.consume_nonce(room_id, 1, created["nonce"], connecting_lease_seconds=1)
    assert not db.consume_nonce(room_id, 1, created["nonce"])

    with db.connection:
        db.connection.execute("UPDATE reservations SET connecting_lease_until=? WHERE room_id=? AND slot=1", (int(time.time()) - 1, room_id))
    db.list_rooms()  # crash recovery collects only the expired CONNECTING lease
    assert not db.consume_nonce(room_id, 1, created["nonce"])


def test_running_room_is_terminal_and_is_not_republished_by_expiry(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    first = db.create_room("running", reservation_seconds=120, token_seconds=120)
    room_id = first["room"]["id"]
    second = db.reserve(room_id, reservation_seconds=120, token_seconds=120)
    assert second is not None
    _connect_both(db, room_id, first, second)
    assert db.notify_status(room_id, None, "running")

    with db.connection:
        db.connection.execute("UPDATE reservations SET reserved_until=?, connecting_lease_until=? WHERE room_id=?", (0, 0, room_id))
    assert db.list_rooms() == []
    assert db.get_room(room_id)["status"] == "RUNNING"
    assert db.reserve(room_id) is None
    assert db.notify_status(room_id, 1, "disconnected")
    assert db.get_room(room_id)["status"] == "CLOSED"
    assert not db.notify_status(room_id, None, "running")


def test_server_restart_closes_connected_and_running_rooms(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    first = db.create_room("restart", reservation_seconds=120, token_seconds=120)
    room_id = first["room"]["id"]
    second = db.reserve(room_id, reservation_seconds=120, token_seconds=120)
    assert second is not None
    _connect_both(db, room_id, first, second)
    assert db.notify_status(room_id, None, "running")

    assert db.reconcile_server_restart() == 1
    assert db.get_room(room_id)["status"] == "CLOSED"
    assert db.list_rooms() == []
    assert db.reserve(room_id) is None
    assert db.reconcile_server_restart() == 0


def test_pre_match_disconnect_releases_only_its_slot(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    first = db.create_room("disconnect")
    room_id = first["room"]["id"]
    second = db.reserve(room_id)
    assert second is not None
    assert db.consume_nonce(room_id, 2, second["nonce"])
    assert db.notify_status(room_id, 2, "connected")
    assert db.notify_status(room_id, 2, "disconnected")
    replacement = db.reserve(room_id)
    assert replacement is not None
    assert replacement["slot"] == 2
    # A duplicate delivery after a replacement has reserved the same slot is a
    # successful no-op; it must not erase the replacement reservation.
    assert db.notify_status(room_id, 2, "disconnected")
    assert db.list_rooms()[0]["players"] == 2


def test_server_monitoring_keeps_latest_heartbeat_and_events(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    db.record_server_update("heartbeat", None, {"active_rooms": 2, "connected_peers": 3})
    db.record_server_update("join_accepted", "room-1", {"slot": 1, "peer_id": 42})
    monitoring = db.server_monitoring()
    assert monitoring["heartbeat"]["details"]["active_rooms"] == 2
    assert monitoring["events"][0]["kind"] == "join_accepted"
