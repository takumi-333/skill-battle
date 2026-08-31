#!/usr/bin/env python3
"""既存シートを、参照用の64px個別フレームへ非破壊で展開する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--sheet", type=Path, required=True)
    parser.add_argument("--motion", type=Path, required=True)
    parser.add_argument("--output-dir", type=Path, required=True)
    args = parser.parse_args()
    spec = json.loads(args.motion.read_text(encoding="utf-8"))
    directions = [item["id"] for item in spec["directions"]]
    frames = spec["frames"]
    image = Image.open(args.sheet).convert("RGBA")
    if image.size != (512, 320):
        raise ValueError(f"expected 512x320 sheet, got {image.size}")
    args.output_dir.mkdir(parents=True, exist_ok=True)
    for frame in frames:
        direction = frame["direction"]
        column = directions.index(direction)
        row = 0 if frame["phase"] == "idle" else int(frame["id"].rsplit("_", 1)[1])
        crop = image.crop((column * 64, row * 64, column * 64 + 64, row * 64 + 64))
        crop.save(args.output_dir / f"{frame['id']}.png")
    print(json.dumps({"status": "ok", "frames": len(frames), "output_dir": str(args.output_dir)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
