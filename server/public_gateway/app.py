"""Narrow public adapter for the four Lobby API endpoints.

This is intentionally not a general reverse proxy. Every inbound field is
validated before the fixed loopback upstream is contacted.
"""
from __future__ import annotations

import logging
import os
import re

import httpx
from fastapi import FastAPI, Request
from fastapi.responses import JSONResponse, Response


UPSTREAM = "http://127.0.0.1:8000"
MAX_BODY_BYTES = 4096
ROOM_ID_PATTERN = re.compile(r"^[0-9a-f]{32}$")
API_ALLOWED_HEADERS = {
    "host", "connection", "accept", "accept-encoding", "user-agent",
    "content-type", "content-length", "x-skill-battle-access-token",
}
PROXY_METADATA_HEADERS = {
    "forwarded",
    "tailscale-headers-info",
    "tailscale-ingress-target",
    "tailscale-user-login",
    "tailscale-user-name",
    "tailscale-user-profile-pic",
    "x-forwarded-for",
    "x-forwarded-host",
    "x-forwarded-proto",
    "x-real-ip",
}
TIMEOUT = httpx.Timeout(connect=2.0, read=5.0, write=5.0, pool=5.0)
LOGGER = logging.getLogger(__name__)

app = FastAPI(title="Skill Battle Public Gateway", version="1.0")


def _allowed_route(method: str, path: str) -> bool:
    if method == "GET":
        return path in {"/healthz", "/v1/rooms"}
    if method == "POST" and path == "/v1/rooms":
        return True
    if method == "POST" and path.startswith("/v1/rooms/") and path.endswith("/join"):
        room_id = path.removeprefix("/v1/rooms/").removesuffix("/join")
        return bool(ROOM_ID_PATTERN.fullmatch(room_id))
    return False


async def _send_upstream(method: str, path: str, headers: dict[str, str], body: bytes) -> httpx.Response:
    """Use a literal loopback URL; neither request data nor config controls it."""
    async with httpx.AsyncClient(timeout=TIMEOUT, follow_redirects=False) as client:
        return await client.request(method, UPSTREAM + path, headers=headers, content=body)


@app.middleware("http")
async def public_allowlist(request: Request, call_next):
    path = request.url.path
    method = request.method.upper()
    if not _allowed_route(method, path):
        return JSONResponse({"detail": "not found"}, status_code=404)
    if request.url.query:
        return JSONResponse({"detail": "query parameters are not allowed"}, status_code=400)

    inbound_names = {name.lower() for name in request.headers.keys()}
    disallowed_names = inbound_names - API_ALLOWED_HEADERS - PROXY_METADATA_HEADERS
    if path != "/healthz" and disallowed_names:
        LOGGER.warning("rejected public gateway request header names: %s", ", ".join(sorted(disallowed_names)))
        return JSONResponse({"detail": "request header is not allowed"}, status_code=400)
    if method == "POST" and request.headers.get("content-type", "").lower() != "application/json":
        return JSONResponse({"detail": "application/json is required"}, status_code=415)
    if method == "GET" and int(request.headers.get("content-length", "0") or "0") > 0:
        return JSONResponse({"detail": "body is not allowed"}, status_code=400)
    body = await request.body()
    if len(body) > MAX_BODY_BYTES:
        return JSONResponse({"detail": "request body is too large"}, status_code=413)
    request.state.gateway_body = body
    return await call_next(request)


@app.api_route("/healthz", methods=["GET"])
@app.api_route("/v1/rooms", methods=["GET", "POST"])
@app.api_route("/v1/rooms/{room_id}/join", methods=["POST"])
async def forward(request: Request, room_id: str | None = None) -> Response:
    # The router's parameter matching is intentionally supplemented by the
    # middleware exact-path check above; do not widen this route.
    headers: dict[str, str] = {}
    token = request.headers.get("x-skill-battle-access-token")
    if token is not None:
        headers["X-Skill-Battle-Access-Token"] = token
    if request.method == "POST":
        headers["Content-Type"] = "application/json"
    try:
        upstream = await _send_upstream(request.method, request.url.path, headers, request.state.gateway_body)
    except httpx.HTTPError:
        return JSONResponse({"detail": "upstream service is unavailable"}, status_code=502)
    if 300 <= upstream.status_code < 400:
        return JSONResponse({"detail": "upstream service is unavailable"}, status_code=502)
    content_type = upstream.headers.get("content-type", "application/json")
    return Response(content=upstream.content, status_code=upstream.status_code, media_type=content_type.split(";", 1)[0])
