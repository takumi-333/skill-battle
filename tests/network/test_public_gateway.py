import asyncio
import importlib.util
from pathlib import Path

import httpx
from fastapi.testclient import TestClient


GATEWAY_PATH = Path(__file__).resolve().parents[2] / "server" / "public_gateway" / "app.py"


def _load_gateway():
    spec = importlib.util.spec_from_file_location("public_gateway_test_app", GATEWAY_PATH)
    module = importlib.util.module_from_spec(spec)
    assert spec.loader is not None
    spec.loader.exec_module(module)
    return module


def test_gateway_forwards_only_allowlisted_request_data(monkeypatch):
    gateway = _load_gateway()
    seen = {}

    async def fake_send(method, path, headers, body):
        seen.update(method=method, path=path, headers=headers, body=body)
        return httpx.Response(200, json={"ok": True})

    monkeypatch.setattr(gateway, "_send_upstream", fake_send)
    client = TestClient(gateway.app)
    response = client.post(
        "/v1/rooms",
        headers={
            "X-Skill-Battle-Access-Token": "invite",
            "Content-Type": "application/json",
            "Tailscale-Headers-Info": "ignored-proxy-metadata",
            "Tailscale-Ingress-Target": "takumipc.tail1f4370.ts.net:443",
            "Tailscale-User-Login": "player@example.test",
            "Tailscale-User-Name": "Player",
            "Tailscale-User-Profile-Pic": "https://example.test/player.png",
            "X-Forwarded-For": "203.0.113.1",
            "X-Forwarded-Proto": "https",
        },
        json={"name": "room"},
    )
    assert response.status_code == 200
    assert seen == {
        "method": "POST",
        "path": "/v1/rooms",
        "headers": {"X-Skill-Battle-Access-Token": "invite", "Content-Type": "application/json"},
        "body": b'{"name":"room"}',
    }


def test_gateway_rejects_nonpublic_paths_and_unallowlisted_input(monkeypatch):
    gateway = _load_gateway()

    async def fake_send(*_args):
        raise AssertionError("rejected requests must not reach upstream")

    monkeypatch.setattr(gateway, "_send_upstream", fake_send)
    client = TestClient(gateway.app)
    assert client.get("/admin").status_code == 404
    assert client.get("/internal/rooms/x").status_code == 404
    assert client.get("/v1/rooms?ignored=1").status_code == 400
    assert client.get("/v1/rooms", headers={"X-Not-Allowed": "value"}).status_code == 400
    assert client.post("/v1/rooms", headers={"Content-Type": "text/plain"}, content=b"x").status_code == 415
    assert client.post("/v1/rooms/not-a-room/join", headers={"Content-Type": "application/json"}, content=b"{}").status_code == 404
    assert client.post("/v1/rooms", headers={"Content-Type": "application/json"}, content=b"x" * 4097).status_code == 413


def test_gateway_logs_only_rejected_header_names(monkeypatch, caplog):
    gateway = _load_gateway()

    async def fake_send(*_args):
        raise AssertionError("rejected requests must not reach upstream")

    monkeypatch.setattr(gateway, "_send_upstream", fake_send)
    with caplog.at_level("WARNING", logger=gateway.__name__):
        response = TestClient(gateway.app).get(
            "/v1/rooms",
            headers={"X-Diagnostic-Only": "must-not-appear-in-logs"},
        )
    assert response.status_code == 400
    assert "x-diagnostic-only" in caplog.text
    assert "must-not-appear-in-logs" not in caplog.text


def test_gateway_healthz_ignores_browser_and_forwarded_headers(monkeypatch):
    gateway = _load_gateway()
    seen = {}

    async def fake_send(method, path, headers, body):
        seen.update(method=method, path=path, headers=headers, body=body)
        return httpx.Response(200, json={"ok": True})

    monkeypatch.setattr(gateway, "_send_upstream", fake_send)
    response = TestClient(gateway.app).get(
        "/healthz",
        headers={
            "Sec-Fetch-Mode": "navigate",
            "Sec-Fetch-Site": "none",
            "Accept-Language": "ja",
            "X-Forwarded-For": "203.0.113.1",
            "X-Forwarded-Proto": "https",
        },
    )
    assert response.status_code == 200
    assert seen == {"method": "GET", "path": "/healthz", "headers": {}, "body": b""}


def test_gateway_hides_upstream_failure(monkeypatch):
    gateway = _load_gateway()

    async def failed_send(*_args):
        raise httpx.ConnectError("do not leak this detail")

    monkeypatch.setattr(gateway, "_send_upstream", failed_send)
    response = TestClient(gateway.app).get("/healthz")
    assert response.status_code == 502
    assert "leak" not in response.text
