import importlib
import sys
from pathlib import Path

import pytest
from fastapi.testclient import TestClient

LOBBY_DIR = Path(__file__).resolve().parents[2] / "server" / "lobby"
sys.path.insert(0, str(LOBBY_DIR))
import app as lobby_app
from tokens import decode_and_verify


def _load_app(monkeypatch, tmp_path):
    secrets = {
        "SKILL_BATTLE_TOKEN_SECRET": "a" * 64,
        "SKILL_BATTLE_ADMIN_TOKEN": "b" * 64,
        "SKILL_BATTLE_INTERNAL_API_TOKEN": "c" * 64,
        "SKILL_BATTLE_PUBLIC_ACCESS_TOKEN": "d" * 64,
    }
    for key, value in secrets.items():
        monkeypatch.setenv(key, value)
    monkeypatch.setenv("SKILL_BATTLE_UVICORN_WORKERS", "1")
    monkeypatch.setenv("SKILL_BATTLE_ALLOW_INVALID_CONFIG_FOR_HEALTHCHECK", "1")
    monkeypatch.setenv("SKILL_BATTLE_LOBBY_DB", str(tmp_path / "lobby.db"))
    return importlib.reload(lobby_app), secrets


def test_protected_routes_fail_closed_when_secret_configuration_is_missing(monkeypatch, tmp_path):
    module, secrets = _load_app(monkeypatch, tmp_path)
    monkeypatch.delenv("SKILL_BATTLE_PUBLIC_ACCESS_TOKEN")
    module = importlib.reload(module)
    client = TestClient(module.app)
    assert client.get("/healthz").json()["protected_api_ready"] is False
    assert client.get("/v1/rooms", headers={"X-Skill-Battle-Access-Token": secrets["SKILL_BATTLE_PUBLIC_ACCESS_TOKEN"]}).status_code == 503
    monkeypatch.delenv("SKILL_BATTLE_ALLOW_INVALID_CONFIG_FOR_HEALTHCHECK")
    module = importlib.reload(module)
    with pytest.raises(RuntimeError):
        with TestClient(module.app):
            pass


def test_public_lobby_requires_an_explicit_database_path(monkeypatch, tmp_path):
    module, _secrets = _load_app(monkeypatch, tmp_path)
    monkeypatch.setenv("SKILL_BATTLE_PUBLIC_MODE", "1")
    monkeypatch.delenv("SKILL_BATTLE_LOBBY_DB")
    with pytest.raises(RuntimeError, match="SKILL_BATTLE_LOBBY_DB"):
        module.resolve_database_path()


def test_public_lobby_uses_the_explicit_state_database_path(monkeypatch, tmp_path):
    module, _secrets = _load_app(monkeypatch, tmp_path)
    public_database = tmp_path / ".local-server" / "public-lobby.db"
    public_database.parent.mkdir()
    monkeypatch.setenv("SKILL_BATTLE_PUBLIC_MODE", "1")
    monkeypatch.setenv("SKILL_BATTLE_LOBBY_DB", str(public_database))
    module = importlib.reload(module)
    assert module.resolve_database_path() == str(public_database)
    assert public_database.exists()


def test_public_and_internal_authentication_nonce_and_rate_limit(monkeypatch, tmp_path):
    module, secrets = _load_app(monkeypatch, tmp_path)
    client = TestClient(module.app)
    public = {"X-Skill-Battle-Access-Token": secrets["SKILL_BATTLE_PUBLIC_ACCESS_TOKEN"]}
    internal = {"X-Skill-Battle-Internal-Token": secrets["SKILL_BATTLE_INTERNAL_API_TOKEN"]}

    assert client.get("/v1/rooms").status_code == 401
    assert client.post("/internal/rooms/not-a-room/status", json={"status": "closed"}).status_code == 401
    created = client.post("/v1/rooms", headers=public, json={"name": "secure room"})
    assert created.status_code == 200
    ticket = created.json()
    payload = decode_and_verify(secrets["SKILL_BATTLE_TOKEN_SECRET"], ticket["token"], ticket["room"]["id"], ticket["slot"])
    assert payload is not None
    consume_body = {"slot": ticket["slot"], "nonce": payload["nonce"]}
    assert client.post(f"/internal/rooms/{ticket['room']['id']}/consume", headers=internal, json=consume_body).status_code == 200
    assert client.post(f"/internal/rooms/{ticket['room']['id']}/consume", headers=internal, json=consume_body).status_code == 409
    assert client.post(f"/internal/rooms/{ticket['room']['id']}/status", headers=internal, json={"status": "connected", "slot": 1}).status_code == 200

    module.rate_limiter._limits["rooms"] = 1
    assert client.get("/v1/rooms", headers=public).status_code == 200
    limited = client.get("/v1/rooms", headers=public)
    assert limited.status_code == 429
    assert limited.headers["Retry-After"].isdigit()


def test_internal_reconciliation_closes_pre_restart_rooms(monkeypatch, tmp_path):
    module, secrets = _load_app(monkeypatch, tmp_path)
    client = TestClient(module.app)
    public = {"X-Skill-Battle-Access-Token": secrets["SKILL_BATTLE_PUBLIC_ACCESS_TOKEN"]}
    internal = {"X-Skill-Battle-Internal-Token": secrets["SKILL_BATTLE_INTERNAL_API_TOKEN"]}

    created = client.post("/v1/rooms", headers=public, json={"name": "restart room"})
    assert created.status_code == 200
    reconciled = client.post("/internal/server/reconcile", headers=internal)
    assert reconciled.status_code == 200
    assert reconciled.json() == {"ok": True, "closed_rooms": 1}
    assert client.get("/v1/rooms", headers=public).json() == {"rooms": []}
