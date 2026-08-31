#!/usr/bin/env python3
"""採用済みの個別RGBAフレームをroot優先で8x5シートへ組版する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path
from typing import Any

from PIL import Image


def alpha_mask(image: Image.Image, threshold: int) -> Image.Image:
    return image.getchannel("A").point(lambda value: 255 if value >= threshold else 0)


def point(value: Any, name: str) -> tuple[float, float] | None:
    if value is None:
        return None
    if isinstance(value, list) and len(value) == 2 and all(isinstance(component, (int, float)) for component in value):
        return float(value[0]), float(value[1])
    if isinstance(value, dict) and all(isinstance(value.get(key), (int, float)) for key in ("x", "y")):
        return float(value["x"]), float(value["y"])
    raise ValueError(f"{name} must be [x, y] or {{x, y}}")


def normalize(
    frame: Image.Image,
    anchor: tuple[int, int],
    cell_size: tuple[int, int],
    alpha_threshold: int,
    root: tuple[float, float] | None,
    contact_point: tuple[float, float] | None,
) -> tuple[Image.Image, dict[str, object]]:
    source = frame.convert("RGBA")
    original_size = source.size
    if source.size != cell_size:
        source = source.resize(cell_size, Image.Resampling.NEAREST)
        scale_x = cell_size[0] / original_size[0]
        scale_y = cell_size[1] / original_size[1]
        if root is not None:
            root = root[0] * scale_x, root[1] * scale_y
        if contact_point is not None:
            contact_point = contact_point[0] * scale_x, contact_point[1] * scale_y

    bbox = alpha_mask(source, alpha_threshold).getbbox()
    if bbox is None:
        raise ValueError("empty alpha frame")
    fallback_anchor = ((bbox[0] + bbox[2] - 1) / 2, bbox[3] - 1)
    source_anchor = root if root is not None else fallback_anchor
    offset = (round(anchor[0] - source_anchor[0]), round(anchor[1] - source_anchor[1]))
    target = Image.new("RGBA", cell_size, (0, 0, 0, 0))
    target.alpha_composite(source, offset)

    def translated(value: tuple[float, float] | None) -> list[float] | None:
        return None if value is None else [value[0] + offset[0], value[1] + offset[1]]

    return target, {
        "source_bbox": bbox,
        "source_anchor": list(source_anchor),
        "anchor_source": "root" if root is not None else "alpha_bbox_bottom_center",
        "offset": offset,
        "result_bbox": alpha_mask(target, alpha_threshold).getbbox(),
        "result_root": translated(root),
        "result_contact_point": translated(contact_point),
    }


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--motion", type=Path, required=True)
    parser.add_argument("--frames-dir", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()

    spec = json.loads(args.spec.read_text(encoding="utf-8"))
    motion = json.loads(args.motion.read_text(encoding="utf-8"))
    directions = spec["columns"]
    rows = spec["rows"]
    anchor = (spec["foot_anchor"]["x"], spec["foot_anchor"]["y"])
    cell_size = (spec["cell_size"]["width"], spec["cell_size"]["height"])
    alpha_threshold = spec.get("normalization", {}).get("alpha_bbox_threshold", 8)
    output = Image.new("RGBA", (spec["canvas"]["width"], spec["canvas"]["height"]), (0, 0, 0, 0))
    report: dict[str, object] = {"asset_id": spec["asset_id"], "frames": {}, "anchor": anchor, "alpha_threshold": alpha_threshold}

    for frame in motion["frames"]:
        frame_id = frame["id"]
        path = args.frames_dir / f"{frame_id}.png"
        if not path.exists():
            raise FileNotFoundError(f"missing frame: {path}")
        root = point(frame.get("root", frame.get("root_anchor")), f"{frame_id}.root")
        contact = point(frame.get("contact_point"), f"{frame_id}.contact_point")
        normalized, frame_report = normalize(Image.open(path), anchor, cell_size, alpha_threshold, root, contact)
        column = directions.index(frame["direction"])
        row = rows.index(frame["phase"])
        output.alpha_composite(normalized, (column * cell_size[0], row * cell_size[1]))
        report["frames"][frame_id] = {
            "column": column,
            "row": row,
            "direction": frame["direction"],
            "phase": frame["phase"],
            "contact_foot": frame.get("contact_foot"),
            "ground_y": frame.get("ground_y", anchor[1]),
            **frame_report,
        }

    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": "ok", "output": str(args.output), "frames": len(motion["frames"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
