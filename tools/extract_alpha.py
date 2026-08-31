#!/usr/bin/env python3
"""透過を保持し、不透明な単色背景だけを明示的に抜く。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def corner_background(image: Image.Image) -> tuple[int, int, int]:
    width, height = image.size
    corners = [(0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)]
    values = [image.getpixel(point)[:3] for point in corners]
    return tuple(round(sum(value[index] for value in values) / len(values)) for index in range(3))


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--threshold", type=int, default=18)
    parser.add_argument("--force-chroma-key", action="store_true")
    args = parser.parse_args()
    image = Image.open(args.input).convert("RGBA")
    alpha = image.getchannel("A")
    native_alpha = alpha.getextrema()[0] < 255
    method = "native_alpha" if native_alpha and not args.force_chroma_key else "corner_chroma_key"
    background = None
    if method == "corner_chroma_key":
        background = corner_background(image)
        pixels = image.load()
        for y in range(image.height):
            for x in range(image.width):
                red, green, blue, old_alpha = pixels[x, y]
                distance = max(abs(red - background[0]), abs(green - background[1]), abs(blue - background[2]))
                if distance <= args.threshold:
                    pixels[x, y] = (red, green, blue, 0)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    image.save(args.output)
    print(json.dumps({"status": "ok", "alpha": {"source": "generator" if native_alpha else "postprocess", "method": method, "threshold": args.threshold if background else None, "background": background}}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
