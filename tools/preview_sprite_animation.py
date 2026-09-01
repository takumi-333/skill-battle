#!/usr/bin/env python3
"""animation specの任意clip・variantをゲーム起動なしで確認するHTMLを生成する。"""

from __future__ import annotations

import argparse
import base64
import io
import json
from pathlib import Path
from typing import Any

from PIL import Image

from sprite_pipeline import expected_grid_positions, load_pipeline


def encode_png(image: Image.Image) -> str:
    data = io.BytesIO()
    image.save(data, format="PNG")
    return base64.b64encode(data.getvalue()).decode("ascii")


def sheet_from_frames(frames_dir: Path, asset: dict[str, Any], animation: dict[str, Any]) -> tuple[Image.Image, set[str]]:
    canvas = asset["canvas"]
    sheet = Image.new("RGBA", (canvas["width"], canvas["height"]), (0, 0, 0, 0))
    available: set[str] = set()
    for frame in animation["frames"]:
        path = frames_dir / f"{frame['id']}.png"
        if not path.exists():
            continue
        with Image.open(path) as opened:
            image = opened.convert("RGBA")
        placement = frame["placement"]
        expected_size = (placement["width"], placement["height"])
        if image.size != expected_size:
            raise ValueError(f"frame {frame['id']} size expected {expected_size}, got {image.size}")
        sheet.alpha_composite(image, (placement["x"], placement["y"]))
        available.add(frame["id"])
    if not available:
        raise ValueError(f"no animation frames found in {frames_dir}")
    return sheet, available


def review_clips(animation: dict[str, Any], available: set[str]) -> list[dict[str, Any]]:
    clips: list[dict[str, Any]] = []
    for clip in animation["clips"]:
        variants = []
        for variant in clip["variants"]:
            frames = []
            for frame in variant["frames"]:
                if frame["id"] not in available:
                    continue
                placement = frame["placement"]
                frames.append({
                    "id": frame["id"],
                    "x": placement["x"], "y": placement["y"],
                    "width": placement["width"], "height": placement["height"],
                    "duration": frame["duration"], "events": frame["events"],
                })
            variants.append({"id": variant["id"], "labels": variant["labels"], "frames": frames})
        clips.append({"id": clip["id"], "loop": clip["loop"], "fps": clip["fps"], "variants": variants})
    return clips


def render_html(config: dict[str, Any]) -> str:
    serialized = json.dumps(config, ensure_ascii=False).replace("</", "<\\/")
    return f"""<!doctype html>
<html lang=\"ja\"><head><meta charset=\"utf-8\"><meta name=\"viewport\" content=\"width=device-width, initial-scale=1\">
<title>スプライト・アニメーションレビュー</title><style>
body {{ margin:0; background:#202124; color:#f1f3f4; font-family:system-ui,sans-serif }} main {{ max-width:960px;margin:auto;padding:24px }}
h1 {{ font-size:1.4rem }} .panel {{ background:#303134;padding:16px;border-radius:8px;margin:12px 0 }}
button,select {{ margin:4px;padding:7px 10px;border-radius:4px;border:1px solid #777;background:#3c4043;color:inherit }} button.active {{ background:#8ab4f8;color:#202124 }} button:disabled {{ opacity:.4 }}
label {{ margin:4px 8px 4px 0;display:inline-block }} canvas {{ background:repeating-conic-gradient(#666 0 25%,#555 0 50%) 50% / 16px 16px;image-rendering:pixelated;border:1px solid #888;display:block;margin:16px 0 }} code {{ word-break:break-all }} .unavailable {{ color:#f28b82 }}
</style></head><body><main><h1>スプライト・アニメーションレビュー</h1>
<section class=\"panel\"><strong>対象</strong><br><code id=\"source\"></code><br><strong>asset spec</strong>: <code id=\"spec\"></code><br><strong>animation spec</strong>: <code id=\"animation\"></code></section>
<section class=\"panel\"><label>clip <select id=\"clip\"></select></label><label id=\"variantField\">variant <select id=\"variant\"></select></label><br>
<button id=\"play\">再生</button><button id=\"speed\">通常速度</button><label><input id=\"loop\" type=\"checkbox\"> ループ</label><button id=\"scale\">等倍</button><label><input id=\"silhouette\" type=\"checkbox\"> シルエット</label></section>
<canvas id=\"preview\"></canvas><section class=\"panel\"><strong>表示中</strong>: <span id=\"current\"></span></section><section class=\"panel\"><strong>再生不可のclip / variant</strong>（一部パターン未作成）<div id=\"unavailable\"></div></section>
</main><script>
const review={serialized}; const image=new Image(); const clipSelect=document.querySelector('#clip'),variantSelect=document.querySelector('#variant'); const canvas=document.querySelector('#preview'),ctx=canvas.getContext('2d');
const state={{clip:review.clips[0]?.id,variant:review.clips[0]?.variants[0]?.id,playing:true,speed:1,scale:1,index:0,changed:performance.now()}};
canvas.width=review.previewWidth;canvas.height=review.previewHeight;document.querySelector('#source').textContent=review.source;document.querySelector('#spec').textContent=review.specPath;document.querySelector('#animation').textContent=review.animationPath;
for(const clip of review.clips)clipSelect.add(new Option(clip.id,clip.id));
function selectedClip(){{return review.clips.find(clip=>clip.id===state.clip)||review.clips[0]}} function selectedVariant(){{const clip=selectedClip();return clip?.variants.find(variant=>variant.id===state.variant)||clip?.variants[0]}} function frames(){{return selectedVariant()?.frames||[]}} function reset(){{state.index=0;state.changed=performance.now()}}
function rebuildVariants(){{const clip=selectedClip();variantSelect.replaceChildren();for(const variant of clip?.variants||[]){{const suffix=Object.keys(variant.labels).length?' ('+Object.entries(variant.labels).map(([key,value])=>key+'='+value).join(', ')+')':'';variantSelect.add(new Option(variant.id+suffix,variant.id))}}state.variant=clip?.variants[0]?.id;variantSelect.value=state.variant;document.querySelector('#variantField').hidden=(clip?.variants.length||0)<=1;reset()}}
function updateControls(){{const clip=selectedClip();document.querySelector('#play').textContent=state.playing?'停止':'再生';document.querySelector('#speed').textContent=state.speed===1?'通常速度':'0.25倍速度';document.querySelector('#scale').textContent=state.scale===1?'等倍':'4倍nearest';document.querySelector('#loop').checked=Boolean(clip?.loop)}}
function draw(now){{const clip=selectedClip(),sequence=frames(),frame=sequence[state.index];const duration=(frame?.duration||1/(clip?.fps||8))*1000/state.speed;if(state.playing&&sequence.length>1&&now-state.changed>=duration){{const steps=Math.floor((now-state.changed)/duration);state.changed+=steps*duration;state.index+=steps;if(state.index>=sequence.length){{if(document.querySelector('#loop').checked)state.index%=sequence.length;else{{state.index=sequence.length-1;state.playing=false}}}}}}ctx.clearRect(0,0,canvas.width,canvas.height);const current=frames()[state.index];if(current&&image.complete){{const dx=Math.floor((canvas.width-current.width)/2),dy=Math.floor((canvas.height-current.height)/2);ctx.drawImage(image,current.x,current.y,current.width,current.height,dx,dy,current.width,current.height);if(document.querySelector('#silhouette').checked){{ctx.globalCompositeOperation='source-in';ctx.fillStyle='#000';ctx.fillRect(0,0,canvas.width,canvas.height);ctx.globalCompositeOperation='source-over'}}document.querySelector('#current').textContent=`${{clip.id}} / ${{selectedVariant().id}} / ${{current.id}}${{current.events.length?' / '+current.events.join(', '):''}}`}}else document.querySelector('#current').textContent='再生可能なフレームがありません';canvas.style.width=`${{canvas.width*state.scale}}px`;canvas.style.height=`${{canvas.height*state.scale}}px`;updateControls();requestAnimationFrame(draw)}}
clipSelect.onchange=event=>{{state.clip=event.target.value;rebuildVariants()}};variantSelect.onchange=event=>{{state.variant=event.target.value;reset()}};document.querySelector('#play').onclick=()=>{{state.playing=!state.playing;state.changed=performance.now()}};document.querySelector('#speed').onclick=()=>{{state.speed=state.speed===1?.25:1;state.changed=performance.now()}};document.querySelector('#scale').onclick=()=>state.scale=state.scale===1?4:1;document.querySelector('#loop').onchange=()=>reset();
const unavailable=[];for(const clip of review.clips)for(const variant of clip.variants)if(!variant.frames.length)unavailable.push(clip.id+' / '+variant.id);document.querySelector('#unavailable').textContent=unavailable.length?unavailable.join(', '):'なし';document.querySelector('#unavailable').className=unavailable.length?'unavailable':'';
rebuildVariants();image.onload=()=>requestAnimationFrame(draw);image.onerror=()=>document.querySelector('#current').textContent='埋め込み画像を読み込めません';image.src='data:image/png;base64,'+review.png;
</script></main></body></html>"""


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--animation", "--motion", dest="animation", type=Path, required=True, help="animation spec（--motionは旧仕様互換）")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--input", type=Path, help="完成済みまたは候補のスプライトsheet PNG")
    source.add_argument("--frames-dir", type=Path, help="途中レビュー用の個別フレームPNGディレクトリ")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()

    asset, animation = load_pipeline(args.spec, args.animation)
    canvas = asset["canvas"]
    if args.input:
        with Image.open(args.input) as opened:
            sheet = opened.convert("RGBA")
        if sheet.size != (canvas["width"], canvas["height"]):
            raise ValueError(f"sprite sheet size expected {(canvas['width'], canvas['height'])}, got {sheet.size}")
        if animation["legacy"]:
            positions = {(frame["placement"].get("column"), frame["placement"].get("row")) for frame in animation["frames"]}
            missing = expected_grid_positions(asset) - positions
            if missing:
                missing_text = ", ".join(f"{column}/{row}" for column, row in sorted(missing))
                raise ValueError(f"motion spec is missing positions for sprite sheet: {missing_text}")
        available = {frame["id"] for frame in animation["frames"]}
        source_name = str(args.input)
    else:
        if not args.frames_dir.is_dir():
            raise ValueError(f"frames directory does not exist: {args.frames_dir}")
        sheet, available = sheet_from_frames(args.frames_dir, asset, animation)
        source_name = str(args.frames_dir)

    clips = review_clips(animation, available)
    preview_width = max(frame["placement"]["width"] for frame in animation["frames"])
    preview_height = max(frame["placement"]["height"] for frame in animation["frames"])
    config = {
        "source": source_name, "specPath": str(args.spec), "animationPath": str(args.animation),
        "clips": clips, "previewWidth": preview_width, "previewHeight": preview_height, "png": encode_png(sheet),
    }
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(render_html(config), encoding="utf-8")
    print(json.dumps({"status": "ok", "output": str(args.output), "source": source_name, "clips": len(clips)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except (OSError, ValueError) as error:
        raise SystemExit(f"error: {error}")
