import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "server" / "lobby"))
from database import LobbyDatabase

def test_room_reservations_are_limited_to_two_slots(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    room, first_slot = db.create_room("test")
    assert first_slot == 1
    assert db.reserve(room["id"]) == 2
    assert db.reserve(room["id"]) is None
    rooms = db.list_rooms()
    assert rooms[0]["players"] == 2

def test_expired_empty_room_is_removed_from_public_list(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    room, _ = db.create_room("expired")
    with db.connection:
        db.connection.execute("UPDATE rooms SET slot1_reserved_until=? WHERE id=?", (int(time.time()) - 1, room["id"]))
    assert db.list_rooms() == []

def test_server_monitoring_keeps_latest_heartbeat_and_events(tmp_path):
    db = LobbyDatabase(str(tmp_path / "lobby.db"))
    db.record_server_update("heartbeat", None, {"active_rooms": 2, "connected_peers": 3})
    db.record_server_update("join_accepted", "room-1", {"slot": 1, "peer_id": 42})
    monitoring = db.server_monitoring()
    assert monitoring["heartbeat"]["details"]["active_rooms"] == 2
    assert monitoring["events"][0]["kind"] == "join_accepted"
    assert monitoring["events"][0]["room_id"] == "room-1"
