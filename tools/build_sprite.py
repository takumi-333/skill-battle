#!/usr/bin/env python3
"""個別RGBAフレームをanimation specのgridまたはatlasへ決定論的に組版する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image

from sprite_pipeline import alpha_threshold, load_pipeline, target_anchor


def alpha_mask(image: Image.Image, threshold: int) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)


def normalize(
    frame: Image.Image,
    placement: dict[str, Any],
    anchor: tuple[float, float] | None,
    anchor_type: str,
    threshold: int,
    root: tuple[float, float] | None,
    contact_point: tuple[float, float] | None,
) -> tuple[Image.Image, dict[str, object]]:
    """フレームを配置矩形へ収め、rootまたはprofile由来のanchorで揃える。"""
    source = frame.convert("RGBA")
    original_size = source.size
    target_size = (placement["width"], placement["height"])
    if source.size != target_size:
        source = source.resize(target_size, Image.Resampling.NEAREST)
        scale_x = target_size[0] / original_size[0]
        scale_y = target_size[1] / original_size[1]
        if root is not None:
            root = root[0] * scale_x, root[1] * scale_y
        if contact_point is not None:
            contact_point = contact_point[0] * scale_x, contact_point[1] * scale_y

    bbox = alpha_mask(source, threshold).getbbox()
    if bbox is None:
        raise ValueError("empty alpha frame")
    fallback_anchor = (
        ((bbox[0] + bbox[2] - 1) / 2, (bbox[1] + bbox[3] - 1) / 2)
        if anchor_type == "center"
        else ((bbox[0] + bbox[2] - 1) / 2, bbox[3] - 1)
    )
    if anchor is None:
        source_anchor = None
        offset = (0, 0)
        anchor_source = "none"
    else:
        source_anchor = root if root is not None else fallback_anchor
        offset = (round(anchor[0] - source_anchor[0]), round(anchor[1] - source_anchor[1]))
        anchor_source = "root" if root is not None else "alpha_bbox_bottom_center"
    target = Image.new("RGBA", target_size, (0, 0, 0, 0))
    target.alpha_composite(source, offset)

    def translated(value: tuple[float, float] | None) -> list[float] | None:
        return None if value is None else [value[0] + offset[0], value[1] + offset[1]]

    return target, {
        "source_size": list(original_size),
        "source_bbox": bbox,
        "source_anchor": list(source_anchor) if source_anchor is not None else None,
        "anchor_source": anchor_source,
        "offset": list(offset),
        "result_bbox": alpha_mask(target, threshold).getbbox(),
        "result_root": translated(root),
        "result_contact_point": translated(contact_point),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--animation", "--motion", dest="animation", type=Path, required=True, help="animation spec（--motionは旧仕様互換）")
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    asset, animation = load_pipeline(args.spec, args.animation)
    canvas = asset["canvas"]
    output = Image.new("RGBA", (canvas["width"], canvas["height"]), (0, 0, 0, 0))
    threshold = alpha_threshold(asset)
    report: dict[str, Any] = {
        "asset_id": asset["asset_id"],
        "profile": asset["profile"],
        "layout": asset["layout"],
        "anchor": asset["anchor"],
        "alpha_threshold": threshold,
        "frames": {},
    }

    for frame in animation["frames"]:
        frame_id = frame["id"]
        path = args.frames_dir / f"{frame_id}.png"
        if not path.exists():
            raise FileNotFoundError(f"missing frame: {path}")
        placement = frame["placement"]
        anchor = target_anchor(asset, placement)
        normalized, frame_report = normalize(
            Image.open(path), placement, anchor, asset["anchor"]["type"], threshold, frame["root"], frame["contact_point"]
        )
        output.alpha_composite(normalized, (placement["x"], placement["y"]))
        report["frames"][frame_id] = {
            "clip": frame["clip"],
            "variant": frame["variant"],
            "placement": placement,
            "events": frame["events"],
            "ground_y": frame["ground_y"],
            "target_anchor": list(anchor) if anchor is not None else None,
            **frame_report,
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": "ok", "output": str(args.output), "frames": len(animation["frames"]), "profile": asset["profile"]}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
