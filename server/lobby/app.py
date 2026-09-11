"""Loopback-only Lobby API. Public traffic is accepted only via Gateway."""
from __future__ import annotations

from collections import defaultdict, deque
from contextlib import asynccontextmanager
import hmac
import json
import os
import subprocess
import threading
import time
from pathlib import Path

from fastapi import Depends, FastAPI, Header, HTTPException, Request
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field

from database import DatabaseBusy, LobbyDatabase
from tokens import issue


MIN_SECRET_LENGTH = 32
SECRET_ENVIRONMENTS = (
    "SKILL_BATTLE_TOKEN_SECRET",
    "SKILL_BATTLE_ADMIN_TOKEN",
    "SKILL_BATTLE_INTERNAL_API_TOKEN",
    "SKILL_BATTLE_PUBLIC_ACCESS_TOKEN",
)
TICKET_LIFETIME_SECONDS = 60
RESERVATION_LIFETIME_SECONDS = 60
CONNECTING_LEASE_SECONDS = 15


def _read_secret_configuration() -> tuple[dict[str, str], str | None]:
    values = {name: os.environ.get(name, "") for name in SECRET_ENVIRONMENTS}
    missing_or_short = [name for name, value in values.items() if len(value) < MIN_SECRET_LENGTH]
    duplicates = len(set(values.values())) != len(values) or any(not value for value in values.values())
    workers = os.environ.get("SKILL_BATTLE_UVICORN_WORKERS", "1")
    if missing_or_short:
        return values, "公開用secretが未設定または短すぎます"
    if duplicates:
        return values, "公開用secretを用途間で共有できません"
    if workers != "1":
        return values, "Lobbyはuvicorn worker 1でのみ起動できます"
    return values, None


SECRETS, CONFIGURATION_ERROR = _read_secret_configuration()
SECRET = SECRETS["SKILL_BATTLE_TOKEN_SECRET"]
ADMIN_TOKEN = SECRETS["SKILL_BATTLE_ADMIN_TOKEN"]
INTERNAL_API_TOKEN = SECRETS["SKILL_BATTLE_INTERNAL_API_TOKEN"]
PUBLIC_ACCESS_TOKEN = SECRETS["SKILL_BATTLE_PUBLIC_ACCESS_TOKEN"]
DEFAULT_DB_PATH = Path(__file__).with_name("lobby.db")


def resolve_database_path() -> str:
    configured_path = os.environ.get("SKILL_BATTLE_LOBBY_DB", "").strip()
    if configured_path:
        return configured_path
    if os.environ.get("SKILL_BATTLE_PUBLIC_MODE") == "1":
        raise RuntimeError("公開LobbyにはSKILL_BATTLE_LOBBY_DBを設定してください")
    return str(DEFAULT_DB_PATH)


db = LobbyDatabase(resolve_database_path())
SERVER_ADDRESS = os.environ.get("SKILL_BATTLE_SERVER_ADDRESS", "127.0.0.1")
SERVER_PORT = int(os.environ.get("SKILL_BATTLE_SERVER_PORT", "7000"))
CONTROL_SCRIPT = os.environ.get("SKILL_BATTLE_CONTROL_SCRIPT", "/usr/local/sbin/skill-battle-control")
ADMIN_PAGE = Path(__file__).parent / "static" / "admin.html"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
WINDOWS_LAUNCHER_DIR = PROJECT_ROOT / "deploy" / "windows"
WINDOWS_STATE_DIR = PROJECT_ROOT / ".local-server"
@asynccontextmanager
async def public_lifespan(_app: FastAPI):
    """Public launchers fail at startup; test/diagnostic mode remains 503-safe."""
    if CONFIGURATION_ERROR is not None and os.environ.get("SKILL_BATTLE_ALLOW_INVALID_CONFIG_FOR_HEALTHCHECK") != "1":
        raise RuntimeError(CONFIGURATION_ERROR)
    yield


app = FastAPI(title="Skill Battle Lobby", version="2.0", lifespan=public_lifespan)


class CreateRoom(BaseModel):
    name: str = Field(min_length=1, max_length=48)


class JoinRoom(BaseModel):
    """An explicit empty JSON body keeps the public Gateway contract strict."""


class ConsumeNonce(BaseModel):
    nonce: str = Field(min_length=32, max_length=256)
    slot: int = Field(ge=1, le=2)


class RoomStatus(BaseModel):
    status: str = Field(pattern="^(connected|disconnected|running|closed)$")
    slot: int | None = Field(default=None, ge=1, le=2)


class ServerMonitoringUpdate(BaseModel):
    kind: str = Field(pattern="^(heartbeat|join_accepted|join_rejected|match_event_accepted|match_event_rejected|ready_changed|match_started|peer_disconnected|room_closed)$")
    room_id: str | None = Field(default=None, max_length=64)
    details: dict = Field(default_factory=dict)


class ServiceAction(BaseModel):
    action: str = Field(pattern="^(start|stop|restart)$")


class PublicRateLimiter:
    def __init__(self) -> None:
        self._entries: dict[tuple[str, str], deque[float]] = defaultdict(deque)
        self._lock = threading.Lock()
        self._limits = {"rooms": 60, "create": 10, "join": 20}

    def check(self, token: str, bucket: str) -> None:
        now = time.monotonic()
        with self._lock:
            entries = self._entries[(token, bucket)]
            while entries and entries[0] <= now - 60.0:
                entries.popleft()
            limit = self._limits[bucket]
            if len(entries) >= limit:
                retry_after = max(1, int(entries[0] + 60.0 - now) + 1)
                raise HTTPException(429, "リクエストが多すぎます", headers={"Retry-After": str(retry_after)})
            entries.append(now)


rate_limiter = PublicRateLimiter()


def _require_configuration() -> None:
    if CONFIGURATION_ERROR is not None:
        raise HTTPException(503, "公開APIの秘密設定が利用できません")


def require_admin(x_skill_battle_admin_token: str = Header(default="")) -> None:
    _require_configuration()
    if not hmac.compare_digest(x_skill_battle_admin_token, ADMIN_TOKEN):
        raise HTTPException(401, "管理トークンが無効です")


def require_internal(x_skill_battle_internal_token: str = Header(default="")) -> None:
    _require_configuration()
    if not hmac.compare_digest(x_skill_battle_internal_token, INTERNAL_API_TOKEN):
        raise HTTPException(401, "内部APIトークンが無効です")


def require_public(request: Request, x_skill_battle_access_token: str = Header(default="")) -> str:
    _require_configuration()
    if not hmac.compare_digest(x_skill_battle_access_token, PUBLIC_ACCESS_TOKEN):
        raise HTTPException(401, "招待アクセストークンが無効です")
    if request.url.path == "/v1/rooms" and request.method == "GET":
        bucket = "rooms"
    elif request.url.path == "/v1/rooms":
        bucket = "create"
    else:
        bucket = "join"
    rate_limiter.check(x_skill_battle_access_token, bucket)
    return x_skill_battle_access_token


def _database_call(call):
    try:
        return call()
    except DatabaseBusy as error:
        raise HTTPException(503, "ロビーが一時的に混雑しています", headers={"Retry-After": "1"}) from error


def run_control(action: str) -> dict:
    if os.name == "nt":
        return run_windows_launcher_control(action)
    if not Path(CONTROL_SCRIPT).is_file():
        raise HTTPException(503, "サービス制御スクリプトが未配置です")
    completed = subprocess.run(["sudo", "-n", CONTROL_SCRIPT, action], check=False, capture_output=True, text=True, timeout=15)
    if completed.returncode != 0:
        raise HTTPException(502, completed.stderr.strip() or "サービス操作に失敗しました")
    return {"ok": True, "output": completed.stdout.strip()}


def windows_powershell() -> str:
    return str(Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe")


def run_windows_launcher_control(action: str) -> dict:
    scripts = {"status": "status-local.ps1", "start": "start-local.ps1", "stop": "stop-local.ps1", "restart": "restart-local.ps1"}
    script = WINDOWS_LAUNCHER_DIR / scripts[action]
    if not script.is_file():
        raise HTTPException(503, "Windowsローカルランチャーが未配置です")
    command = [windows_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script)]
    if action == "start":
        command.append("-NoBrowser")
    if action == "stop":
        command.append("-Quiet")
    if action in {"stop", "restart"}:
        subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"ok": True, "output": "Windowsローカルランチャーへ操作を依頼しました。"}
    completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=30)
    if completed.returncode != 0:
        raise HTTPException(502, completed.stderr.strip() or "Windowsローカルランチャーの操作に失敗しました")
    if action == "status":
        try:
            return {"ok": True, "output": json.dumps(json.loads(completed.stdout), ensure_ascii=False, indent=2)}
        except json.JSONDecodeError as error:
            raise HTTPException(502, "Windowsローカルランチャーの状態を読み取れません") from error
    return {"ok": True, "output": completed.stdout.strip() or "Windowsローカランチャーを開始しました。"}


def local_launcher_logs() -> dict:
    names = ("lobby.stdout.log", "lobby.stderr.log", "dedicated.stdout.log", "dedicated.stderr.log")
    chunks = []
    for name in names:
        path = WINDOWS_STATE_DIR / name
        if path.is_file():
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()[-60:]
            chunks.append("--- %s ---\n%s" % (name, "\n".join(lines) if lines else "(empty)"))
    return {"ok": True, "output": "\n\n".join(chunks) if chunks else "ローカルランチャーのログはまだありません。"}


def ticket(reservation: dict) -> dict:
    room = reservation["room"]
    return {
        "room": room,
        "slot": reservation["slot"],
        "token": issue(SECRET, room["id"], reservation["slot"], reservation["nonce"], TICKET_LIFETIME_SECONDS),
        "server_address": SERVER_ADDRESS,
        "server_port": SERVER_PORT,
    }


@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True, "protected_api_ready": CONFIGURATION_ERROR is None}


@app.get("/v1/rooms")
def list_rooms(_: str = Depends(require_public)) -> dict:
    return {"rooms": _database_call(db.list_rooms)}


@app.post("/v1/rooms")
def create_room(body: CreateRoom, _: str = Depends(require_public)) -> dict:
    reservation = _database_call(lambda: db.create_room(body.name.strip(), RESERVATION_LIFETIME_SECONDS, TICKET_LIFETIME_SECONDS))
    return ticket(reservation)


@app.post("/v1/rooms/{room_id}/join")
def join_room(room_id: str, _body: JoinRoom, _: str = Depends(require_public)) -> dict:
    reservation = _database_call(lambda: db.reserve(room_id, RESERVATION_LIFETIME_SECONDS, TICKET_LIFETIME_SECONDS))
    if reservation is None:
        raise HTTPException(409, "room is full, closed, or unavailable")
    return ticket(reservation)


@app.post("/internal/rooms/{room_id}/consume")
def consume_nonce(room_id: str, body: ConsumeNonce, _: None = Depends(require_internal)) -> dict:
    if not _database_call(lambda: db.consume_nonce(room_id, body.slot, body.nonce, CONNECTING_LEASE_SECONDS)):
        raise HTTPException(409, "参加予約は利用できません")
    return {"ok": True}


@app.post("/internal/rooms/{room_id}/status")
def room_status(room_id: str, event: RoomStatus, _: None = Depends(require_internal)) -> dict:
    if not _database_call(lambda: db.notify_status(room_id, event.slot, event.status)):
        raise HTTPException(409, "状態遷移を適用できません")
    return {"ok": True}


@app.post("/internal/server/reconcile")
def reconcile_server_restart(_: None = Depends(require_internal)) -> dict:
    """Discard room state that cannot survive a Dedicated Server restart."""
    return {"ok": True, "closed_rooms": _database_call(db.reconcile_server_restart)}


@app.post("/internal/server/updates")
def server_monitoring_update(update: ServerMonitoringUpdate, _: None = Depends(require_internal)) -> dict:
    _database_call(lambda: db.record_server_update(update.kind, update.room_id, update.details))
    return {"ok": True}


@app.get("/admin")
def admin_page() -> FileResponse:
    return FileResponse(ADMIN_PAGE)


@app.get("/admin/api/monitoring")
def admin_monitoring(_: None = Depends(require_admin)) -> dict:
    return _database_call(db.server_monitoring)


@app.get("/admin/api/services")
def admin_services(_: None = Depends(require_admin)) -> dict:
    return run_control("status")


@app.get("/admin/api/logs")
def admin_logs(_: None = Depends(require_admin)) -> dict:
    return local_launcher_logs() if os.name == "nt" else run_control("logs")


@app.post("/admin/api/services")
def admin_service_action(body: ServiceAction, _: None = Depends(require_admin)) -> dict:
    return run_control(body.action)
