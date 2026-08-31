#!/usr/bin/env python3
"""可視前景を論理pixel gridへ正規化し、パレットを量子化する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def alpha_mask(image: Image.Image, threshold: int) -> Image.Image:
    """縮尺決定用に、見えない半透明ノイズを除いた前景マスクを作る。"""
    return image.getchannel("A").point(lambda value: 255 if value > threshold else 0)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--size", type=int, default=64)
    parser.add_argument("--colors", type=int, default=32)
    parser.add_argument("--alpha-threshold", type=int)
    parser.add_argument("--content-height", type=int, help="可視前景の目標高さ。未指定時はspecまたは48px")
    parser.add_argument("--max-visible-width", type=int)
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text(encoding="utf-8")) if args.spec else {}
    normalization = spec.get("normalization", {})
    alpha_threshold = args.alpha_threshold if args.alpha_threshold is not None else normalization.get("alpha_bbox_threshold", 8)
    target_visible_height = args.content_height if args.content_height is not None else normalization.get("target_visible_height", 48)
    max_visible_width = args.max_visible_width if args.max_visible_width is not None else normalization.get("max_visible_width", args.size - 4)
    source = Image.open(args.input).convert("RGBA")
    # 先にalpha閾値を適用する。半透明の背景・縁ノイズをbboxへ含めると、
    # キャラクター自身を不必要に縮小してしまう。
    mask = alpha_mask(source, alpha_threshold)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("source image has no foreground alpha")
    visible_width = bbox[2] - bbox[0]
    visible_height = bbox[3] - bbox[1]
    padding = max(2, round(max(visible_width, visible_height) * 0.04))
    crop = source.crop((max(0, bbox[0] - padding), max(0, bbox[1] - padding), min(source.width, bbox[2] + padding), min(source.height, bbox[3] + padding)))
    desired_scale = min(target_visible_height / visible_height, max_visible_width / visible_width)
    # padding込みのcropがセルからあふれないよう、最終的な安全上限を設ける。
    fit_scale = min((args.size - 2) / crop.width, (args.size - 2) / crop.height)
    scale = min(desired_scale, fit_scale)
    target_size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    # 高解像度からの縮小はNEARESTではなくLANCZOS。以降に作る64px格子が論理pixel gridとなる。
    resized_crop = crop.resize(target_size, Image.Resampling.LANCZOS)
    resized = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
    resized.alpha_composite(resized_crop, ((args.size - target_size[0]) // 2, (args.size - target_size[1]) // 2))
    alpha = alpha_mask(resized, alpha_threshold)
    rgb = resized.convert("RGB").quantize(colors=args.colors, method=Image.Quantize.FASTOCTREE).convert("RGB")
    result = Image.merge("RGBA", (*rgb.split(), alpha))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)
    colors = result.get_flattened_data()
    palette_count = len({pixel[:3] for pixel in colors if pixel[3]})
    result_bbox = alpha.getbbox()
    print(json.dumps({"status": "ok", "source_size": source.size, "visible_bbox": bbox, "visible_size": [visible_width, visible_height], "target_visible_height": target_visible_height, "max_visible_width": max_visible_width, "content_size": target_size, "result_visible_size": [result_bbox[2] - result_bbox[0], result_bbox[3] - result_bbox[1]], "pixel_grid": [args.size, args.size], "resample": "LANCZOS", "palette_colors": palette_count}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
