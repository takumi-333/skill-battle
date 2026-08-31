#!/usr/bin/env python3
"""8方向スプライトをゲームを起動せずに確認する自己完結型HTMLを生成する。"""

from __future__ import annotations

import argparse
import base64
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image


def load_json(path: Path, label: str) -> dict[str, Any]:
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except OSError as error:
        raise ValueError(f"cannot read {label}: {path}") from error
    except json.JSONDecodeError as error:
        raise ValueError(f"invalid JSON in {label}: {path}: {error.msg}") from error
    if not isinstance(value, dict):
        raise ValueError(f"{label} must be a JSON object")
    return value


def string_list(value: Any, name: str) -> list[str]:
    if not isinstance(value, list) or not value or any(not isinstance(item, str) or not item for item in value):
        raise ValueError(f"{name} must be a non-empty array of strings")
    if len(set(value)) != len(value):
        raise ValueError(f"{name} must not contain duplicates")
    return value


def positive_int(value: Any, name: str) -> int:
    if not isinstance(value, int) or isinstance(value, bool) or value <= 0:
        raise ValueError(f"{name} must be a positive integer")
    return value


def parse_spec(spec: dict[str, Any]) -> tuple[list[str], list[str], int, int, int, int]:
    columns = string_list(spec.get("columns"), "spec.columns")
    rows = string_list(spec.get("rows"), "spec.rows")
    if "idle" not in rows:
        raise ValueError("spec.rows must contain idle")
    canvas = spec.get("canvas")
    cell_size = spec.get("cell_size")
    if not isinstance(canvas, dict) or not isinstance(cell_size, dict):
        raise ValueError("spec.canvas and spec.cell_size must be objects")
    canvas_width = positive_int(canvas.get("width"), "spec.canvas.width")
    canvas_height = positive_int(canvas.get("height"), "spec.canvas.height")
    cell_width = positive_int(cell_size.get("width"), "spec.cell_size.width")
    cell_height = positive_int(cell_size.get("height"), "spec.cell_size.height")
    if (canvas_width, canvas_height) != (cell_width * len(columns), cell_height * len(rows)):
        raise ValueError("spec canvas size must equal cell_size multiplied by columns and rows")
    return columns, rows, canvas_width, canvas_height, cell_width, cell_height


def parse_motion(motion: dict[str, Any], columns: list[str], rows: list[str]) -> dict[tuple[str, str], str]:
    frames = motion.get("frames")
    if not isinstance(frames, list) or not frames:
        raise ValueError("motion.frames must be a non-empty array")
    indexed: dict[tuple[str, str], str] = {}
    frame_ids: set[str] = set()
    for frame in frames:
        if not isinstance(frame, dict):
            raise ValueError("each motion frame must be an object")
        frame_id = frame.get("id")
        direction = frame.get("direction")
        phase = frame.get("phase")
        if not all(isinstance(value, str) and value for value in (frame_id, direction, phase)):
            raise ValueError(f"motion frame requires non-empty id, direction, and phase: {frame!r}")
        if frame_id in frame_ids:
            raise ValueError(f"duplicate motion frame id: {frame_id}")
        frame_ids.add(frame_id)
        if direction not in columns:
            raise ValueError(f"motion frame {frame_id} has unknown direction: {direction}")
        if phase not in rows:
            raise ValueError(f"motion frame {frame_id} has unknown phase: {phase}")
        key = (direction, phase)
        if key in indexed:
            raise ValueError(f"duplicate motion position: {direction}/{phase}")
        indexed[key] = frame_id
    return indexed


def sheet_from_frames(
    frames_dir: Path,
    indexed: dict[tuple[str, str], str],
    columns: list[str],
    rows: list[str],
    canvas_size: tuple[int, int],
    cell_size: tuple[int, int],
) -> tuple[Image.Image, set[tuple[str, str]]]:
    sheet = Image.new("RGBA", canvas_size, (0, 0, 0, 0))
    available: set[tuple[str, str]] = set()
    for (direction, phase), frame_id in indexed.items():
        path = frames_dir / f"{frame_id}.png"
        if not path.exists():
            continue
        with Image.open(path) as opened:
            frame = opened.convert("RGBA")
        if frame.size != cell_size:
            raise ValueError(f"frame {frame_id} size expected {cell_size}, got {frame.size}")
        sheet.alpha_composite(frame, (columns.index(direction) * cell_size[0], rows.index(phase) * cell_size[1]))
        available.add((direction, phase))
    if not available:
        raise ValueError(f"no motion frames found in {frames_dir}")
    return sheet, available


def encode_png(image: Image.Image) -> str:
    data = io.BytesIO()
    image.save(data, format="PNG")
    return base64.b64encode(data.getvalue()).decode("ascii")


def render_html(config: dict[str, Any]) -> str:
    serialized = json.dumps(config, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang=\"ja\">
<head>
<meta charset=\"utf-8\">
<meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>スプライト・アニメーションレビュー</title>
<style>
body {{ margin: 0; background: #202124; color: #f1f3f4; font-family: system-ui, sans-serif; }}
main {{ max-width: 960px; margin: auto; padding: 24px; }}
h1 {{ font-size: 1.4rem; }} .panel {{ background: #303134; padding: 16px; border-radius: 8px; margin: 12px 0; }}
button, select {{ margin: 4px; padding: 7px 10px; border-radius: 4px; border: 1px solid #777; background: #3c4043; color: inherit; }}
button.active {{ background: #8ab4f8; color: #202124; }} button:disabled {{ opacity: .4; }}
label {{ margin: 4px 8px 4px 0; display: inline-block; }} canvas {{ background: repeating-conic-gradient(#666 0 25%, #555 0 50%) 50% / 16px 16px; image-rendering: pixelated; border: 1px solid #888; display: block; margin: 16px 0; }}
code {{ word-break: break-all; }} .unavailable {{ color: #f28b82; }}
</style>
</head>
<body><main>
<h1>スプライト・アニメーションレビュー</h1>
<section class=\"panel\"><strong>対象</strong><br><code id=\"source\"></code><br><strong>asset spec</strong>: <code id=\"spec\"></code><br><strong>motion spec</strong>: <code id=\"motion\"></code></section>
<section class=\"panel\"><label>方向 <select id=\"direction\"></select></label><span id=\"directionStatus\"></span><br>
<button id=\"idle\">停止</button><button id=\"walk\">歩行</button><button id=\"play\">再生</button>
<button id=\"speed\">通常速度</button><label><input id=\"loop\" type=\"checkbox\" checked> ループ</label>
<button id=\"scale\">等倍</button><label><input id=\"silhouette\" type=\"checkbox\"> シルエット</label></section>
<canvas id=\"preview\"></canvas><section class=\"panel\"><strong>表示中</strong>: <span id=\"current\"></span></section>
<section class=\"panel\"><strong>再生不可のパターン</strong><div id=\"unavailable\"></div></section>
</main><script>
const review = {serialized};
const image = new Image();
const directionSelect = document.querySelector('#direction');
const canvas = document.querySelector('#preview'); const ctx = canvas.getContext('2d');
const state = {{ direction: review.columns[0], mode: 'walk', playing: true, speed: 1, scale: 1, index: 0, changed: performance.now() }};
canvas.width = review.cellWidth; canvas.height = review.cellHeight;
for (const direction of review.columns) {{ const option = new Option(direction, direction); directionSelect.add(option); }}
document.querySelector('#source').textContent = review.source; document.querySelector('#spec').textContent = review.specPath; document.querySelector('#motion').textContent = review.motionPath;
function frames() {{ return review.frames[state.direction]?.[state.mode] || []; }}
function setActive(id) {{ document.querySelectorAll('button').forEach(button => button.classList.toggle('active', button.id === id)); }}
function reset() {{ state.index = 0; state.changed = performance.now(); }}
function availableDirections() {{ return review.columns.filter(direction => (review.frames[direction]?.[state.mode] || []).length); }}
function ensureDirection() {{ if (!frames().length) {{ state.direction = availableDirections()[0] || review.columns[0]; directionSelect.value = state.direction; reset(); }} }}
function updateControls() {{
  ensureDirection(); const hasIdle = (review.frames[state.direction]?.idle || []).length > 0; const hasWalk = (review.frames[state.direction]?.walk || []).length > 0;
  document.querySelector('#idle').disabled = !hasIdle; document.querySelector('#walk').disabled = !hasWalk;
  setActive(state.mode); document.querySelector('#play').textContent = state.playing ? '停止' : '再生';
  document.querySelector('#speed').textContent = state.speed === 1 ? '通常速度' : '0.25倍速度'; document.querySelector('#scale').textContent = state.scale === 1 ? '等倍' : '4倍nearest';
  document.querySelector('#directionStatus').textContent = hasIdle && hasWalk ? '' : '（一部パターン未作成）';
}}
function draw(now) {{
  const sequence = frames(); const fps = review.fps * state.speed;
  if (state.playing && sequence.length > 1 && now - state.changed >= 1000 / fps) {{
    const steps = Math.floor((now - state.changed) / (1000 / fps)); state.changed += steps * 1000 / fps; state.index += steps;
    if (state.index >= sequence.length) {{ state.index = document.querySelector('#loop').checked ? state.index % sequence.length : sequence.length - 1; if (!document.querySelector('#loop').checked) state.playing = false; }}
  }}
  ctx.clearRect(0, 0, canvas.width, canvas.height); const frame = sequence[state.index];
  if (frame && image.complete) {{ ctx.drawImage(image, frame.column * canvas.width, frame.row * canvas.height, canvas.width, canvas.height, 0, 0, canvas.width, canvas.height); if (document.querySelector('#silhouette').checked) {{ ctx.globalCompositeOperation = 'source-in'; ctx.fillStyle = '#000'; ctx.fillRect(0, 0, canvas.width, canvas.height); ctx.globalCompositeOperation = 'source-over'; }} document.querySelector('#current').textContent = `${{state.direction}} / ${{state.mode}} / ${{frame.phase}} / ${{frame.id}}`; }} else {{ document.querySelector('#current').textContent = '再生可能なフレームがありません'; }}
  canvas.style.width = `${{canvas.width * state.scale}}px`; canvas.style.height = `${{canvas.height * state.scale}}px`; updateControls(); requestAnimationFrame(draw);
}}
directionSelect.addEventListener('change', event => {{ state.direction = event.target.value; reset(); }});
document.querySelector('#idle').onclick = () => {{ state.mode = 'idle'; reset(); }}; document.querySelector('#walk').onclick = () => {{ state.mode = 'walk'; reset(); }};
document.querySelector('#play').onclick = () => {{ state.playing = !state.playing; state.changed = performance.now(); }};
document.querySelector('#speed').onclick = () => {{ state.speed = state.speed === 1 ? .25 : 1; state.changed = performance.now(); }};
document.querySelector('#scale').onclick = () => {{ state.scale = state.scale === 1 ? 4 : 1; }};
const unavailable = []; for (const direction of review.columns) for (const mode of ['idle', 'walk']) if (!(review.frames[direction]?.[mode] || []).length) unavailable.push(`${{direction}} / ${{mode}}`);
document.querySelector('#unavailable').textContent = unavailable.length ? unavailable.join(', ') : 'なし'; document.querySelector('#unavailable').className = unavailable.length ? 'unavailable' : '';
image.onload = () => requestAnimationFrame(draw); image.onerror = () => {{ document.querySelector('#current').textContent = '埋め込み画像を読み込めません'; }};
image.src = 'data:image/png;base64,' + review.png;
</script></body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--motion", type=Path, required=True)
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--input", type=Path, help="完成済みまたは候補のスプライトシートPNG")
    source.add_argument("--frames-dir", type=Path, help="途中レビュー用の個別フレームPNGディレクトリ")
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--fps", type=float, default=8.0)
    args = parser.parse_args()
    if args.fps <= 0:
        raise ValueError("--fps must be greater than zero")

    spec = load_json(args.spec, "asset spec")
    motion = load_json(args.motion, "motion spec")
    columns, rows, canvas_width, canvas_height, cell_width, cell_height = parse_spec(spec)
    indexed = parse_motion(motion, columns, rows)
    expected_positions = {(direction, phase) for direction in columns for phase in rows}

    if args.input:
        with Image.open(args.input) as opened:
            sheet = opened.convert("RGBA")
        if sheet.size != (canvas_width, canvas_height):
            raise ValueError(f"sprite sheet size expected {(canvas_width, canvas_height)}, got {sheet.size}")
        missing = expected_positions - set(indexed)
        if missing:
            missing_text = ", ".join(f"{direction}/{phase}" for direction, phase in sorted(missing))
            raise ValueError(f"motion spec is missing positions for sprite sheet: {missing_text}")
        available = expected_positions
        source_name = str(args.input)
    else:
        if not args.frames_dir.is_dir():
            raise ValueError(f"frames directory does not exist: {args.frames_dir}")
        sheet, available = sheet_from_frames(args.frames_dir, indexed, columns, rows, (canvas_width, canvas_height), (cell_width, cell_height))
        source_name = str(args.frames_dir)

    frame_data: dict[str, dict[str, list[dict[str, Any]]]] = {}
    for direction in columns:
        frame_data[direction] = {"idle": [], "walk": []}
        for row, phase in enumerate(rows):
            frame_id = indexed.get((direction, phase))
            if frame_id is None or (direction, phase) not in available:
                continue
            target = "idle" if phase == "idle" else "walk"
            frame_data[direction][target].append({"id": frame_id, "phase": phase, "column": columns.index(direction), "row": row})

    config = {
        "source": source_name,
        "specPath": str(args.spec),
        "motionPath": str(args.motion),
        "columns": columns,
        "rows": rows,
        "cellWidth": cell_width,
        "cellHeight": cell_height,
        "fps": args.fps,
        "frames": frame_data,
        "png": encode_png(sheet),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_html(config), encoding="utf-8")
    print(json.dumps({"status": "ok", "output": str(args.output), "source": source_name}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        raise SystemExit(f"error: {error}")
