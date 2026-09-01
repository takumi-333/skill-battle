#!/usr/bin/env python3
"""Godot用8x5スプライトシートの規格、色、透明度、配置を検査する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image

from cleanup_frame_artifacts import analyze_artifacts, cleanup_config


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


def position_index(motion: dict[str, Any] | None) -> dict[tuple[str, str], dict[str, Any]]:
    if motion is None:
        return {}
    indexed: dict[tuple[str, str], dict[str, Any]] = {}
    for frame in motion.get("frames", []):
        key = (frame.get("direction"), frame.get("phase"))
        if not all(isinstance(value, str) for value in key):
            raise ValueError(f"motion frame needs direction and phase: {frame!r}")
        if key in indexed:
            raise ValueError(f"duplicate motion position: {key}")
        indexed[key] = frame
    return indexed


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--motion", type=Path)
    parser.add_argument("--build-report", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--anchor-tolerance", type=float, default=0)
    parser.add_argument("--root-tolerance", type=float, default=0)
    parser.add_argument("--contact-tolerance", type=float, default=1)
    args = parser.parse_args()

    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    motion = json.loads(args.motion.read_text(encoding="utf-8")) if args.motion else None
    motion_by_position = position_index(motion)
    build_frames: dict[str, Any] = {}
    if args.build_report:
        build_frames = json.loads(args.build_report.read_text(encoding="utf-8")).get("frames", {})

    image = Image.open(args.input)
    errors: list[str] = []
    warnings: list[str] = []
    if image.mode != "RGBA":
        errors.append(f"mode expected RGBA, got {image.mode}")
    if image.size != (spec["canvas"]["width"], spec["canvas"]["height"]):
        errors.append(f"size expected {(spec['canvas']['width'], spec['canvas']['height'])}, got {image.size}")
    image = image.convert("RGBA")

    alpha_values = set(image.getchannel("A").get_flattened_data())
    binary_alpha = alpha_values.issubset({0, 255})
    if not binary_alpha:
        errors.append("alpha must contain only 0 or 255")

    palette: set[tuple[int, int, int]] | None = None
    if isinstance(spec.get("palette"), dict) and "colors" in spec["palette"]:
        palette = parse_palette(spec["palette"])
        invalid_palette_pixels = sum(1 for red, green, blue, alpha in image.get_flattened_data() if alpha and (red, green, blue) not in palette)
        if invalid_palette_pixels:
            errors.append(f"palette has {invalid_palette_pixels} opaque pixels outside the fixed palette")
    else:
        invalid_palette_pixels = None
        warnings.append("fixed palette is not defined; palette validation skipped")

    anchor = spec["foot_anchor"]
    normalization = spec.get("normalization", {})
    artifact_settings = cleanup_config(spec)
    alpha_threshold = normalization.get("alpha_bbox_threshold", 8)
    target_visible_height = normalization.get("target_visible_height")
    height_tolerance = normalization.get("height_tolerance", 0)
    max_visible_width = normalization.get("max_visible_width")
    min_occupancy = normalization.get("min_occupancy", 0.015)
    max_occupancy = normalization.get("max_occupancy", 1.0)
    cell_width = spec["cell_size"]["width"]
    cell_height = spec["cell_size"]["height"]
    cells: dict[str, object] = {}
    idle_heights: list[int] = []
    walk_heights: list[int] = []

    for row, row_id in enumerate(spec["rows"]):
        for column, direction in enumerate(spec["columns"]):
            cell = image.crop((column * cell_width, row * cell_height, (column + 1) * cell_width, (row + 1) * cell_height))
            bbox = alpha_mask(cell, alpha_threshold).getbbox()
            motion_frame = motion_by_position.get((direction, row_id))
            frame_id = motion_frame["id"] if motion_frame else f"{direction}_{row_id}"
            if bbox is None:
                errors.append(f"{frame_id}: empty cell after alpha threshold {alpha_threshold}")
                continue

            center_x = (bbox[0] + bbox[2] - 1) / 2
            bottom_y = bbox[3] - 1
            visible_width = bbox[2] - bbox[0]
            visible_height = bbox[3] - bbox[1]
            occupancy = sum(1 for value in cell.getchannel("A").get_flattened_data() if value) / (cell_width * cell_height)
            if target_visible_height is not None and abs(visible_height - target_visible_height) > height_tolerance:
                errors.append(f"{frame_id}: visible_height {visible_height}, expected {target_visible_height}±{height_tolerance}")
            if max_visible_width is not None and visible_width > max_visible_width:
                errors.append(f"{frame_id}: visible_width {visible_width}, maximum {max_visible_width}")
            if occupancy < min_occupancy or occupancy > max_occupancy:
                errors.append(f"{frame_id}: occupancy {occupancy:.3f}, expected {min_occupancy:.3f}..{max_occupancy:.3f}")

            root_result = None
            contact_result = None
            if motion_frame and ("root" in motion_frame or "root_anchor" in motion_frame):
                build_frame = build_frames.get(frame_id)
                if not build_frame:
                    errors.append(f"{frame_id}: root metadata requires --build-report")
                else:
                    root_result = build_frame.get("result_root")
                    if root_result is None:
                        errors.append(f"{frame_id}: build report has no result_root")
                    elif abs(root_result[0] - anchor["x"]) > args.root_tolerance or abs(root_result[1] - anchor["y"]) > args.root_tolerance:
                        errors.append(f"{frame_id}: root {root_result}, expected {[anchor['x'], anchor['y']]}±{args.root_tolerance}")
                    contact_result = build_frame.get("result_contact_point")
                    if "contact_point" in motion_frame:
                        if contact_result is None:
                            errors.append(f"{frame_id}: build report has no result_contact_point")
                        else:
                            ground_y = motion_frame.get("ground_y", anchor["y"])
                            if abs(contact_result[1] - ground_y) > args.contact_tolerance:
                                errors.append(f"{frame_id}: contact y {contact_result[1]}, expected {ground_y}±{args.contact_tolerance}")
            elif abs(center_x - anchor["x"]) > args.anchor_tolerance or abs(bottom_y - anchor["y"]) > args.anchor_tolerance:
                errors.append(f"{frame_id}: bbox anchor {[center_x, bottom_y]}, expected {[anchor['x'], anchor['y']]}±{args.anchor_tolerance}")

            if row_id == "idle":
                idle_heights.append(visible_height)
            else:
                walk_heights.append(visible_height)
            artifact_report = analyze_artifacts(cell, artifact_settings)
            if artifact_report.get("status") != "disabled" and (artifact_report.get("status") != "pass" or artifact_report.get("candidates")):
                errors.append(f"{frame_id}: artifact cleanup required before promotion")
            cells[frame_id] = {
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

    idle_walk_ratio = None
    if idle_heights and walk_heights:
        idle_average = sum(idle_heights) / len(idle_heights)
        walk_average = sum(walk_heights) / len(walk_heights)
        idle_walk_ratio = idle_average / walk_average if walk_average else None
        ratio_range = normalization.get("idle_walk_height_ratio")
        if ratio_range and not ratio_range[0] <= idle_walk_ratio <= ratio_range[1]:
            errors.append(f"idle/walk height ratio {idle_walk_ratio:.3f}, expected {ratio_range[0]}..{ratio_range[1]}")

    report = {
        "status": "pass" if not errors else "fail",
        "errors": errors,
        "warnings": warnings,
        "normalization": normalization,
        "alpha": {"binary": binary_alpha, "values": sorted(alpha_values), "bbox_threshold": alpha_threshold},
        "palette": {"defined": palette is not None, "invalid_opaque_pixels": invalid_palette_pixels},
        "idle_walk_height_ratio": idle_walk_ratio,
        "cells": cells,
    }
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "errors": len(errors), "warnings": len(warnings)}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
