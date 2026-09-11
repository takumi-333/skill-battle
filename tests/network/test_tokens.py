import sys
import time
from pathlib import Path
sys.path.insert(0, str(Path(__file__).resolve().parents[2] / "server" / "lobby"))
from tokens import issue, verify

def test_ticket_is_bound_to_room_slot_and_expiry():
    token = issue("test-secret", "room-a", 1, 1)
    assert verify("test-secret", token, "room-a", 1)
    assert not verify("test-secret", token, "room-a", 2)
    assert not verify("wrong-secret", token, "room-a", 1)
    time.sleep(1.05)
    assert not verify("test-secret", token, "room-a", 1)


def test_ticket_contains_a_nonce_and_rejects_tampering():
    token = issue("test-secret", "room-a", 1, "n" * 32, 60)
    assert verify("test-secret", token, "room-a", 1)
    encoded, signature = token.split(".")
    assert not verify("test-secret", encoded + "." + ("0" * len(signature)), "room-a", 1)
