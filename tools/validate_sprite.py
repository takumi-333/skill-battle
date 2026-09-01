#!/usr/bin/env python3
"""汎用スプライトsheetの形式・配置を検査し、profile固有の規則を適用する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image

from cleanup_frame_artifacts import analyze_artifacts, cleanup_config
from sprite_pipeline import alpha_threshold, load_json, parse_animation_spec, parse_asset_spec, target_anchor


def alpha_mask(image: Image.Image, threshold: int) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)


def parse_palette(value: Any) -> set[tuple[int, int, int]]:
    colors = value.get("colors") if isinstance(value, dict) else value
    if not isinstance(colors, list) or not colors:
        raise ValueError("palette must contain a non-empty colors array")
    parsed: set[tuple[int, int, int]] = set()
    for color in colors:
        if not isinstance(color, list) or len(color) != 3 or any(not isinstance(channel, int) or not 0 <= channel <= 255 for channel in color):
            raise ValueError(f"invalid palette color: {color!r}")
        parsed.add((color[0], color[1], color[2]))
    return parsed


def fallback_frames(asset: dict[str, Any]) -> list[dict[str, Any]]:
    """旧CLIの--motion省略時だけ、grid全セルを検査対象にする。"""
    layout = asset["layout"]
    if layout["type"] != "grid":
        raise ValueError("--animation is required for an atlas layout")
    cell = layout["cell_size"]
    return [
        {
            "id": f"{column}_{row}",
            "clip": "unclassified",
            "variant": column,
            "placement": {
                "x": column_index * cell["width"],
                "y": row_index * cell["height"],
                "width": cell["width"],
                "height": cell["height"],
                "column": column,
                "row": row,
            },
            "root": None,
            "contact_point": None,
            "ground_y": None,
        }
        for row_index, row in enumerate(layout["rows"])
        for column_index, column in enumerate(layout["columns"])
    ]


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--animation", "--motion", dest="animation", type=Path, help="animation spec（--motionは旧仕様互換）")
    parser.add_argument("--build-report", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--anchor-tolerance", type=float, default=0)
    parser.add_argument("--root-tolerance", type=float, default=0)
    parser.add_argument("--contact-tolerance", type=float, default=1)
    args = parser.parse_args()

    asset = parse_asset_spec(load_json(args.spec, "asset spec"))
    animation = parse_animation_spec(load_json(args.animation, "animation spec"), asset) if args.animation else None
    frames = animation["frames"] if animation else fallback_frames(asset)
    build_frames: dict[str, Any] = {}
    if args.build_report:
        build_frames = load_json(args.build_report, "build report").get("frames", {})
        if not isinstance(build_frames, dict):
            raise ValueError("build report frames must be an object")

    image = Image.open(args.input)
    errors: list[str] = []
    warnings: list[str] = []
    canvas = asset["canvas"]
    if image.mode != "RGBA":
        errors.append(f"mode expected RGBA, got {image.mode}")
    if image.size != (canvas["width"], canvas["height"]):
        errors.append(f"size expected {(canvas['width'], canvas['height'])}, got {image.size}")
    image = image.convert("RGBA")

    alpha_values = set(image.getchannel("A").get_flattened_data())
    binary_alpha = alpha_values.issubset({0, 255})
    if not binary_alpha:
        errors.append("alpha must contain only 0 or 255")

    palette: set[tuple[int, int, int]] | None = None
    if isinstance(asset["palette"], dict) and "colors" in asset["palette"]:
        palette = parse_palette(asset["palette"])
        invalid_palette_pixels = sum(1 for red, green, blue, alpha in image.get_flattened_data() if alpha and (red, green, blue) not in palette)
        if invalid_palette_pixels:
            errors.append(f"palette has {invalid_palette_pixels} opaque pixels outside the fixed palette")
    else:
        invalid_palette_pixels = None
        warnings.append("fixed palette is not defined; palette validation skipped")

    normalization = asset["normalization"]
    threshold = alpha_threshold(asset)
    target_visible_height = normalization.get("target_visible_height")
    height_tolerance = normalization.get("height_tolerance", 0)
    max_visible_width = normalization.get("max_visible_width")
    min_occupancy = normalization.get("min_occupancy", 0.015)
    max_occupancy = normalization.get("max_occupancy", 1.0)
    profile = asset["profile"]
    character_rules = profile == "character"
    anchor_rules = profile in ("character", "weapon_attack")
    artifact_settings = cleanup_config(asset["raw"]) if character_rules else {"enabled": False}
    reports: dict[str, Any] = {}
    clip_heights: dict[str, list[int]] = {}

    for frame in frames:
        frame_id = frame["id"]
        rect = frame["placement"]
        cell = image.crop((rect["x"], rect["y"], rect["x"] + rect["width"], rect["y"] + rect["height"]))
        bbox = alpha_mask(cell, threshold).getbbox()
        if bbox is None:
            errors.append(f"{frame_id}: empty frame after alpha threshold {threshold}")
            continue
        center_x = (bbox[0] + bbox[2] - 1) / 2
        bottom_y = bbox[3] - 1
        visible_width = bbox[2] - bbox[0]
        visible_height = bbox[3] - bbox[1]
        occupancy = sum(1 for value in cell.getchannel("A").get_flattened_data() if value) / (rect["width"] * rect["height"])
        if character_rules:
            if target_visible_height is not None and abs(visible_height - target_visible_height) > height_tolerance:
                errors.append(f"{frame_id}: visible_height {visible_height}, expected {target_visible_height}±{height_tolerance}")
            if max_visible_width is not None and visible_width > max_visible_width:
                errors.append(f"{frame_id}: visible_width {visible_width}, maximum {max_visible_width}")
            if occupancy < min_occupancy or occupancy > max_occupancy:
                errors.append(f"{frame_id}: occupancy {occupancy:.3f}, expected {min_occupancy:.3f}..{max_occupancy:.3f}")
            clip_heights.setdefault(frame["clip"], []).append(visible_height)

        root_result = None
        contact_result = None
        expected_anchor = target_anchor(asset, rect)
        if anchor_rules and expected_anchor is not None:
            build_frame = build_frames.get(frame_id)
            if frame.get("root") is not None:
                if not build_frame:
                    errors.append(f"{frame_id}: root metadata requires --build-report")
                else:
                    root_result = build_frame.get("result_root")
                    if root_result is None:
                        errors.append(f"{frame_id}: build report has no result_root")
                    elif abs(root_result[0] - expected_anchor[0]) > args.root_tolerance or abs(root_result[1] - expected_anchor[1]) > args.root_tolerance:
                        errors.append(f"{frame_id}: root {root_result}, expected {list(expected_anchor)}±{args.root_tolerance}")
                    contact_result = build_frame.get("result_contact_point")
                    if frame.get("contact_point") is not None:
                        if contact_result is None:
                            errors.append(f"{frame_id}: build report has no result_contact_point")
                        else:
                            ground_y = frame.get("ground_y") if frame.get("ground_y") is not None else expected_anchor[1]
                            if abs(contact_result[1] - ground_y) > args.contact_tolerance:
                                errors.append(f"{frame_id}: contact y {contact_result[1]}, expected {ground_y}±{args.contact_tolerance}")
            elif character_rules and (abs(center_x - expected_anchor[0]) > args.anchor_tolerance or abs(bottom_y - expected_anchor[1]) > args.anchor_tolerance):
                errors.append(f"{frame_id}: bbox anchor {[center_x, bottom_y]}, expected {list(expected_anchor)}±{args.anchor_tolerance}")

        artifact_report = analyze_artifacts(cell, artifact_settings)
        if character_rules and artifact_report.get("status") != "disabled" and (artifact_report.get("status") != "pass" or artifact_report.get("candidates")):
            errors.append(f"{frame_id}: artifact cleanup required before promotion")
        reports[frame_id] = {
            "clip": frame["clip"],
            "variant": frame["variant"],
            "placement": rect,
            "bbox": bbox,
            "center_x": center_x,
            "bottom_y": bottom_y,
            "visible_width": visible_width,
            "visible_height": visible_height,
            "occupancy": occupancy,
            "root": root_result,
            "contact_point": contact_result,
            "artifact_cleanup": artifact_report,
        }

    clip_height_ratios: dict[str, float] = {}
    ratio_range = normalization.get("idle_walk_height_ratio")
    if character_rules and ratio_range and clip_heights.get("idle") and clip_heights.get("walk"):
        idle_average = sum(clip_heights["idle"]) / len(clip_heights["idle"])
        walk_average = sum(clip_heights["walk"]) / len(clip_heights["walk"])
        ratio = idle_average / walk_average if walk_average else 0
        clip_height_ratios["idle/walk"] = ratio
        if not ratio_range[0] <= ratio <= ratio_range[1]:
            errors.append(f"idle/walk height ratio {ratio:.3f}, expected {ratio_range[0]}..{ratio_range[1]}")

    report = {
        "status": "pass" if not errors else "fail",
        "asset_id": asset["asset_id"],
        "profile": profile,
        "errors": errors,
        "warnings": warnings,
        "normalization": normalization,
        "alpha": {"binary": binary_alpha, "values": sorted(alpha_values), "bbox_threshold": threshold},
        "palette": {"defined": palette is not None, "invalid_opaque_pixels": invalid_palette_pixels},
        "clip_height_ratios": clip_height_ratios,
        "frames": reports,
        "cells": reports,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "errors": len(errors), "warnings": len(warnings), "profile": profile}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
