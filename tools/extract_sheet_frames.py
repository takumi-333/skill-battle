#!/usr/bin/env python3
"""既存sheetをanimation specの配置矩形ごとの参照フレームへ非破壊で展開する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image

from sprite_pipeline import load_pipeline


def extract_legacy_motion(sheet: Path, motion: Path, output_dir: Path) -> int:
    """asset specを持たない旧来の参照展開CLIを維持する。"""
    spec = json.loads(motion.read_text(encoding="utf-8"))
    directions = [item["id"] for item in spec["directions"]]
    frames = spec["frames"]
    image = Image.open(sheet).convert("RGBA")
    if image.size != (512, 320):
        raise ValueError(f"expected 512x320 sheet, got {image.size}")
    output_dir.mkdir(parents=True, exist_ok=True)
    for frame in frames:
        column = directions.index(frame["direction"])
        row = 0 if frame["phase"] == "idle" else int(frame["id"].rsplit("_", 1)[1])
        image.crop((column * 64, row * 64, column * 64 + 64, row * 64 + 64)).save(output_dir / f"{frame['id']}.png")
    print(json.dumps({"status": "ok", "frames": len(frames), "output_dir": str(output_dir), "format": "legacy"}, ensure_ascii=False))
    return 0


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--spec", type=Path, help="asset spec。省略時は旧motion specの参照展開を行う")
    parser.add_argument("--animation", "--motion", dest="animation", type=Path, required=True, help="animation spec（--motionは旧仕様互換）")
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    if args.spec is None:
        return extract_legacy_motion(args.sheet, args.animation, args.output_dir)

    asset, animation = load_pipeline(args.spec, args.animation)
    image = Image.open(args.sheet).convert("RGBA")
    canvas = asset["canvas"]
    if image.size != (canvas["width"], canvas["height"]):
        raise ValueError(f"sprite sheet size expected {(canvas['width'], canvas['height'])}, got {image.size}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for frame in animation["frames"]:
        rect = frame["placement"]
        image.crop((rect["x"], rect["y"], rect["x"] + rect["width"], rect["y"] + rect["height"])).save(args.output_dir / f"{frame['id']}.png")
    print(json.dumps({"status": "ok", "frames": len(animation["frames"]), "output_dir": str(args.output_dir), "format": asset["layout"]["type"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
