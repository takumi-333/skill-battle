"""Public lobby API and authenticated server-operations dashboard."""
import os
import json
import subprocess
from pathlib import Path
from fastapi import Depends, FastAPI, Header, HTTPException
from fastapi.responses import FileResponse
from pydantic import BaseModel, Field
from database import LobbyDatabase
from tokens import issue

SECRET = os.environ.get("SKILL_BATTLE_TOKEN_SECRET", "")
if not SECRET:
    raise RuntimeError("SKILL_BATTLE_TOKEN_SECRET must be set")
db = LobbyDatabase(os.environ.get("SKILL_BATTLE_LOBBY_DB", "lobby.db"))
SERVER_ADDRESS = os.environ.get("SKILL_BATTLE_SERVER_ADDRESS", "127.0.0.1")
SERVER_PORT = int(os.environ.get("SKILL_BATTLE_SERVER_PORT", "7000"))
ADMIN_TOKEN = os.environ.get("SKILL_BATTLE_ADMIN_TOKEN", "")
INTERNAL_API_TOKEN = os.environ.get("SKILL_BATTLE_INTERNAL_API_TOKEN", "")
CONTROL_SCRIPT = os.environ.get("SKILL_BATTLE_CONTROL_SCRIPT", "/usr/local/sbin/skill-battle-control")
ADMIN_PAGE = Path(__file__).parent / "static" / "admin.html"
PROJECT_ROOT = Path(__file__).resolve().parents[2]
WINDOWS_LAUNCHER_DIR = PROJECT_ROOT / "deploy" / "windows"
WINDOWS_STATE_DIR = PROJECT_ROOT / ".local-server"
app = FastAPI(title="Skill Battle Lobby", version="1.0")

class CreateRoom(BaseModel):
    name: str = Field(min_length=1, max_length=48)

class ServerEvent(BaseModel):
    status: str

class ServerMonitoringUpdate(BaseModel):
    kind: str = Field(pattern="^(heartbeat|join_accepted|join_rejected|match_event_accepted|match_event_rejected|ready_changed|match_started|peer_disconnected|room_closed)$")
    room_id: str | None = Field(default=None, max_length=64)
    details: dict = Field(default_factory=dict)

class ServiceAction(BaseModel):
    action: str = Field(pattern="^(start|stop|restart)$")

def require_admin(x_skill_battle_admin_token: str = Header(default="")) -> None:
    if not ADMIN_TOKEN:
        raise HTTPException(503, "管理トークンが設定されていません")
    if x_skill_battle_admin_token != ADMIN_TOKEN:
        raise HTTPException(401, "管理トークンが無効です")

def require_internal(x_skill_battle_internal_token: str = Header(default="")) -> None:
    if not INTERNAL_API_TOKEN or x_skill_battle_internal_token != INTERNAL_API_TOKEN:
        raise HTTPException(401, "内部APIトークンが無効です")

def run_control(action: str) -> dict:
    if os.name == "nt":
        return run_windows_launcher_control(action)
    if not Path(CONTROL_SCRIPT).is_file():
        raise HTTPException(503, "サービス制御スクリプトが未配置です")
    completed = subprocess.run(
        ["sudo", "-n", CONTROL_SCRIPT, action],
        check=False, capture_output=True, text=True, timeout=15,
    )
    if completed.returncode != 0:
        raise HTTPException(502, completed.stderr.strip() or "サービス操作に失敗しました")
    return {"ok": True, "output": completed.stdout.strip()}

def windows_powershell() -> str:
    return str(Path(os.environ.get("SystemRoot", r"C:\Windows")) / "System32" / "WindowsPowerShell" / "v1.0" / "powershell.exe")

def run_windows_launcher_control(action: str) -> dict:
    scripts = {
        "status": "status-local.ps1",
        "start": "start-local.ps1",
        "stop": "stop-local.ps1",
        "restart": "restart-local.ps1",
    }
    script = WINDOWS_LAUNCHER_DIR / scripts[action]
    if not script.is_file():
        raise HTTPException(503, "Windowsローカルランチャーが未配置です")
    command = [windows_powershell(), "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", str(script)]
    if action == "start":
        command.append("-NoBrowser")
    if action == "stop":
        command.append("-Quiet")
    if action in {"stop", "restart"}:
        # The action intentionally stops this Lobby process. Run it detached so
        # it can finish restarting even after this HTTP request is disconnected.
        subprocess.Popen(command, stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        return {"ok": True, "output": "Windowsローカルランチャーへ%sを依頼しました。" % ("停止" if action == "stop" else "再起動")}
    completed = subprocess.run(command, check=False, capture_output=True, text=True, timeout=30)
    if completed.returncode != 0:
        raise HTTPException(502, completed.stderr.strip() or "Windowsローカルランチャーの操作に失敗しました")
    if action == "status":
        try:
            status = json.loads(completed.stdout)
            return {"ok": True, "output": json.dumps(status, ensure_ascii=False, indent=2)}
        except json.JSONDecodeError:
            raise HTTPException(502, "Windowsローカルランチャーの状態を読み取れません")
    return {"ok": True, "output": completed.stdout.strip() or "Windowsローカルランチャーを開始しました。"}

def local_launcher_logs() -> dict:
    names = ("lobby.stdout.log", "lobby.stderr.log", "dedicated.stdout.log", "dedicated.stderr.log")
    chunks = []
    for name in names:
        path = WINDOWS_STATE_DIR / name
        if path.is_file():
            lines = path.read_text(encoding="utf-8", errors="replace").splitlines()[-60:]
            chunks.append("--- %s ---\n%s" % (name, "\n".join(lines) if lines else "(empty)"))
    return {"ok": True, "output": "\n\n".join(chunks) if chunks else "ローカルランチャーのログはまだありません。"}

def ticket(room: dict, slot: int) -> dict:
    return {"room": room, "slot": slot, "token": issue(SECRET, room["id"], slot), "server_address": SERVER_ADDRESS, "server_port": SERVER_PORT}

@app.get("/healthz")
def healthz() -> dict:
    return {"ok": True}

@app.get("/v1/rooms")
def list_rooms() -> dict:
    return {"rooms": db.list_rooms()}

@app.post("/v1/rooms")
def create_room(body: CreateRoom) -> dict:
    room, slot = db.create_room(body.name.strip())
    return ticket(room, slot)

@app.post("/v1/rooms/{room_id}/join")
def join_room(room_id: str) -> dict:
    slot = db.reserve(room_id)
    if slot is None:
        raise HTTPException(409, "room is full, closed, or unavailable")
    room = next((room for room in db.list_rooms() if room["id"] == room_id), None)
    if room is None:
        raise HTTPException(404, "room not found")
    return ticket(room, slot)

@app.post("/internal/rooms/{room_id}/status")
def room_status(room_id: str, event: ServerEvent) -> dict:
    if not db.update_status(room_id, event.status):
        raise HTTPException(404, "room not found")
    return {"ok": True}

@app.post("/internal/server/updates")
def server_monitoring_update(update: ServerMonitoringUpdate, _: None = Depends(require_internal)) -> dict:
    db.record_server_update(update.kind, update.room_id, update.details)
    return {"ok": True}

@app.get("/admin")
def admin_page() -> FileResponse:
    return FileResponse(ADMIN_PAGE)

@app.get("/admin/api/monitoring")
def admin_monitoring(_: None = Depends(require_admin)) -> dict:
    return db.server_monitoring()

@app.get("/admin/api/services")
def admin_services(_: None = Depends(require_admin)) -> dict:
    return run_control("status")

@app.get("/admin/api/logs")
def admin_logs(_: None = Depends(require_admin)) -> dict:
    if os.name == "nt":
        return local_launcher_logs()
    return run_control("logs")

@app.post("/admin/api/services")
def admin_service_action(body: ServiceAction, _: None = Depends(require_admin)) -> dict:
    return run_control(body.action)
