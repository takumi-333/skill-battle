#!/usr/bin/env python3
"""可視前景を論理pixel gridへ正規化し、色とalphaを決定論的に確定する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


def alpha_mask(image: Image.Image, threshold: int) -> Image.Image:
    """縮尺決定用に、閾値以上のalphaだけを残した前景マスクを作る。"""
    return image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)


def parse_palette(value: Any) -> list[tuple[int, int, int]]:
    """specまたはJSONファイルのpalette定義をRGBタプルへ正規化する。"""
    colors = value.get("colors") if isinstance(value, dict) else value
    if not isinstance(colors, list) or not colors:
        raise ValueError("palette must contain a non-empty colors array")
    parsed: list[tuple[int, int, int]] = []
    for color in colors:
        if not isinstance(color, list) or len(color) != 3 or any(not isinstance(channel, int) or not 0 <= channel <= 255 for channel in color):
            raise ValueError(f"invalid palette color: {color!r}")
        parsed.append((color[0], color[1], color[2]))
    if len(parsed) > 256:
        raise ValueError("palette cannot contain more than 256 colors")
    return parsed


def load_palette(spec: dict[str, Any], palette_path: Path | None) -> list[tuple[int, int, int]] | None:
    if palette_path is not None:
        return parse_palette(json.loads(palette_path.read_text(encoding="utf-8")))
    palette = spec.get("palette")
    if isinstance(palette, dict) and "colors" in palette:
        return parse_palette(palette)
    return None


def remap_exact_palette(image: Image.Image, palette: list[tuple[int, int, int]]) -> Image.Image:
    """各RGB画素を固定パレット中の最短RGB色へ決定論的に写像する。"""
    remapped: list[tuple[int, int, int]] = []
    for red, green, blue in image.convert("RGB").get_flattened_data():
        remapped.append(min(palette, key=lambda color: (red - color[0]) ** 2 + (green - color[1]) ** 2 + (blue - color[2]) ** 2))
    result = Image.new("RGB", image.size)
    result.putdata(remapped)
    return result


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--spec", type=Path)
    parser.add_argument("--palette", type=Path, help="RGB配列または {colors: [...]} を含むJSON")
    parser.add_argument("--size", type=int, default=64)
    parser.add_argument("--colors", type=int, default=32, help="固定パレット未指定時の互換fallback用")
    parser.add_argument("--alpha-threshold", type=int)
    parser.add_argument("--binary-alpha-threshold", type=int)
    parser.add_argument("--content-height", type=int, help="可視前景の目標高さ。未指定時はspecまたは48px")
    parser.add_argument("--max-visible-width", type=int)
    args = parser.parse_args()

    spec = json.loads(args.spec.read_text(encoding="utf-8")) if args.spec else {}
    normalization = spec.get("normalization", {})
    alpha_threshold = args.alpha_threshold if args.alpha_threshold is not None else normalization.get("alpha_bbox_threshold", 8)
    binary_alpha_threshold = args.binary_alpha_threshold if args.binary_alpha_threshold is not None else normalization.get("binary_alpha_threshold", alpha_threshold)
    target_visible_height = args.content_height if args.content_height is not None else normalization.get("target_visible_height", 48)
    max_visible_width = args.max_visible_width if args.max_visible_width is not None else normalization.get("max_visible_width", args.size - 4)
    palette = load_palette(spec, args.palette)

    source = Image.open(args.input).convert("RGBA")
    mask = alpha_mask(source, alpha_threshold)
    bbox = mask.getbbox()
    if bbox is None:
        raise ValueError("source image has no foreground alpha")
    visible_width = bbox[2] - bbox[0]
    visible_height = bbox[3] - bbox[1]
    # 縮尺は閾値後の前景そのものから決める。余白を足すと小さな前景で
    # 安全上限に引っかかり、目標身体高さへ届かなくなる。
    crop = source.crop(bbox)
    desired_scale = min(target_visible_height / visible_height, max_visible_width / visible_width)
    fit_scale = min((args.size - 2) / crop.width, (args.size - 2) / crop.height)
    scale = min(desired_scale, fit_scale)
    target_size = (max(1, round(crop.width * scale)), max(1, round(crop.height * scale)))
    resized_crop = crop.resize(target_size, Image.Resampling.LANCZOS)
    resized = Image.new("RGBA", (args.size, args.size), (0, 0, 0, 0))
    resized.alpha_composite(resized_crop, ((args.size - target_size[0]) // 2, (args.size - target_size[1]) // 2))

    alpha = alpha_mask(resized, binary_alpha_threshold)
    if palette is not None:
        rgb = remap_exact_palette(resized, palette)
    else:
        rgb = resized.convert("RGB").quantize(colors=args.colors, method=Image.Quantize.FASTOCTREE).convert("RGB")
    result = Image.merge("RGBA", (*rgb.split(), alpha))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    result.save(args.output)

    result_bbox = alpha.getbbox()
    result_colors = {pixel[:3] for pixel in result.get_flattened_data() if pixel[3]}
    print(json.dumps({
        "status": "ok",
        "source_size": source.size,
        "visible_bbox": bbox,
        "visible_size": [visible_width, visible_height],
        "target_visible_height": target_visible_height,
        "max_visible_width": max_visible_width,
        "content_size": target_size,
        "result_visible_size": [result_bbox[2] - result_bbox[0], result_bbox[3] - result_bbox[1]],
        "pixel_grid": [args.size, args.size],
        "resample": "LANCZOS",
        "alpha": "binary",
        "alpha_threshold": binary_alpha_threshold,
        "palette_mode": "exact" if palette is not None else "adaptive_fallback",
        "palette_colors": len(result_colors),
    }, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
