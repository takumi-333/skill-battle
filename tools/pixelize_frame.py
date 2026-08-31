#!/usr/bin/env python3
"""semantic renderを論理pixel gridへ縮小し、パレットを量子化する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--size", type=int, default=64)
    parser.add_argument("--colors", type=int, default=32)
    parser.add_argument("--alpha-threshold", type=int, default=8)
    parser.add_argument("--content-height", type=int, default=48)
    args = parser.parse_args()
    source = Image.open(args.input).convert("RGBA")
    # 生成器ごとの余白はalpha bboxで除き、セル内の占有率を決定論的に揃える。
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("source image has no foreground alpha")
    padding = max(2, round(max(bbox[2] - bbox[0], bbox[3] - bbox[1]) * 0.04))
    crop = source.crop((max(0, bbox[0] - padding), max(0, bbox[1] - padding), min(source.width, bbox[2] + padding), min(source.height, bbox[3] + padding)))
    scale = min(args.content_height / crop.height, (args.size - 4) / crop.width)
    target_size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    # 高解像度からの縮小はNEARESTではなくLANCZOS。以降に作る64px格子が論理pixel gridとなる。
    resized_crop = crop.resize(target_size, Image.Resampling.LANCZOS)
    resized = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
    resized.alpha_composite(resized_crop, ((args.size - target_size[0]) // 2, (args.size - target_size[1]) // 2))
    alpha = resized.getchannel("A").point(lambda value: 255 if value > args.alpha_threshold else 0)
    rgb = resized.convert("RGB").quantize(colors=args.colors, method=Image.Quantize.FASTOCTREE).convert("RGB")
    result = Image.merge("RGBA", (*rgb.split(), alpha))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    colors = result.get_flattened_data()
    palette_count = len({pixel[:3] for pixel in colors if pixel[3]})
    print(json.dumps({"status": "ok", "source_size": source.size, "source_bbox": bbox, "content_size": target_size, "pixel_grid": [args.size, args.size], "resample": "LANCZOS", "palette_colors": palette_count}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
