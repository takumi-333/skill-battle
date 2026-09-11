"""Signed, short-lived room tickets shared with the dedicated server.

The nonce is deliberately signed into the ticket but persisted only as a
SHA-256 digest by :mod:`database`. A leaked database therefore cannot be used
to redeem a ticket.
"""
import base64
import hashlib
import hmac
import json
import secrets
import time
from typing import Any


def issue(secret: str, room_id: str, slot: int, nonce: str | int | None = None, lifetime_seconds: int = 60) -> str:
    """Create a ticket bound to exactly one room, slot, nonce and expiry."""
    # The old four-argument API used its fourth positional value as lifetime.
    # Keep it for local tooling while the public path supplies a string nonce.
    if isinstance(nonce, int):
        lifetime_seconds = nonce
        nonce = None
    payload = {
        "room_id": room_id,
        "slot": slot,
        "nonce": nonce or secrets.token_urlsafe(32),
        "expires_at": int(time.time()) + lifetime_seconds,
    }
    encoded = base64.b64encode(json.dumps(payload, separators=(",", ":")).encode("utf-8")).decode("ascii")
    signature = hmac.new(secret.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256).hexdigest()
    return f"{encoded}.{signature}"


def decode_and_verify(secret: str, ticket: str, room_id: str, slot: int) -> dict[str, Any] | None:
    """Return a verified payload, never accepting malformed or expired data."""
    try:
        encoded, signature = ticket.split(".", 1)
        expected = hmac.new(secret.encode("utf-8"), encoded.encode("ascii"), hashlib.sha256).hexdigest()
        if not hmac.compare_digest(signature, expected):
            return None
        payload = json.loads(base64.b64decode(encoded.encode("ascii"), validate=True))
        nonce = payload.get("nonce")
        if (
            not isinstance(nonce, str)
            or len(nonce) < 32
            or payload.get("room_id") != room_id
            or payload.get("slot") != slot
            or int(payload.get("expires_at", 0)) < time.time()
        ):
            return None
        return payload
    except (ValueError, KeyError, TypeError, UnicodeError, json.JSONDecodeError):
        return None


def verify(secret: str, ticket: str, room_id: str, slot: int) -> bool:
    """Compatibility helper for callers that only need a boolean result."""
    return decode_and_verify(secret, ticket, room_id, slot) is not None
