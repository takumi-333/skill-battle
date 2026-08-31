#!/usr/bin/env python3
"""Godot用8x5スプライトシートのハード制約を検査する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    parser.add_argument("--anchor-tolerance", type=int, default=0)
    args = parser.parse_args()
    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    image = Image.open(args.input)
    errors: list[str] = []
    warnings: list[str] = []
    if image.mode != "RGBA":
        errors.append(f"mode expected RGBA, got {image.mode}")
    if image.size != (spec["canvas"]["width"], spec["canvas"]["height"]):
        errors.append(f"size expected 512x320, got {image.size}")
    image = image.convert("RGBA")
    anchor = spec["foot_anchor"]
    normalization = spec.get("normalization", {})
    target_visible_height = normalization.get("target_visible_height")
    height_tolerance = normalization.get("height_tolerance", 0)
    min_occupancy = normalization.get("min_occupancy", 0.015)
    max_occupancy = normalization.get("max_occupancy", 1.0)
    cell_width = spec["cell_size"]["width"]
    cell_height = spec["cell_size"]["height"]
    cells: dict[str, object] = {}
    for row, row_id in enumerate(spec["rows"]):
        for column, direction in enumerate(spec["columns"]):
            cell = image.crop((column * cell_width, row * cell_height, (column + 1) * cell_width, (row + 1) * cell_height))
            bbox = cell.getchannel("A").getbbox()
            frame_id = f"{direction}_{row_id}"
            if bbox is None:
                errors.append(f"{frame_id}: empty cell")
                continue
            center_x = (bbox[0] + bbox[2] - 1) / 2
            bottom_y = bbox[3] - 1
            visible_width = bbox[2] - bbox[0]
            visible_height = bbox[3] - bbox[1]
            occupancy = sum(1 for value in cell.getchannel("A").get_flattened_data() if value) / (cell_width * cell_height)
            if abs(bottom_y - anchor["y"]) > args.anchor_tolerance:
                errors.append(f"{frame_id}: bottom_y {bottom_y}, expected {anchor['y']}")
            if target_visible_height is not None and abs(visible_height - target_visible_height) > height_tolerance:
                errors.append(f"{frame_id}: visible_height {visible_height}, expected {target_visible_height}±{height_tolerance}")
            if occupancy < min_occupancy or occupancy > max_occupancy:
                errors.append(f"{frame_id}: occupancy {occupancy:.3f}, expected {min_occupancy:.3f}..{max_occupancy:.3f}")
            cells[frame_id] = {"bbox": bbox, "center_x": center_x, "bottom_y": bottom_y, "visible_width": visible_width, "visible_height": visible_height, "occupancy": occupancy}
    report = {"status": "pass" if not errors else "fail", "errors": errors, "warnings": warnings, "normalization": normalization, "cells": cells}
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": report["status"], "errors": len(errors), "warnings": len(warnings)}, ensure_ascii=False))
    return 0 if not errors else 1


if __name__ == "__main__":
    raise SystemExit(main())
