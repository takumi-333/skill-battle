"""Signed, short-lived room tickets shared with the Godot dedicated server."""
import base64
import hashlib
import hmac
import json
import time


def issue(secret: str, room_id: str, slot: int, lifetime_seconds: int = 60) -> str:
    payload = {"room_id": room_id, "slot": slot, "expires_at": int(time.time()) + lifetime_seconds}
    encoded = base64.b64encode(json.dumps(payload, separators=(",", ":")).encode()).decode()
    signature = hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).hexdigest()
    return f"{encoded}.{signature}"


def verify(secret: str, ticket: str, room_id: str, slot: int) -> bool:
    try:
        encoded, signature = ticket.split(".", 1)
        expected = hmac.new(secret.encode(), encoded.encode(), hashlib.sha256).hexdigest()
        payload = json.loads(base64.b64decode(encoded))
        return hmac.compare_digest(signature, expected) and payload["room_id"] == room_id and payload["slot"] == slot and int(payload["expires_at"]) >= time.time()
    except (ValueError, KeyError, TypeError, json.JSONDecodeError):
        return False
