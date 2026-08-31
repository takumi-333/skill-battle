#!/usr/bin/env python3
"""採用済みの個別RGBAフレームをアンカー整列して8x5シートへ組版する。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


def normalize(frame: Image.Image, anchor: tuple[int, int]) -> tuple[Image.Image, dict]:
    source = frame.convert("RGBA")
    if source.size != (64, 64):
        source = source.resize((64, 64), Image.Resampling.NEAREST)
    bbox = source.getchannel("A").getbbox()
    if bbox is None:
        raise ValueError("empty alpha frame")
    center_x = (bbox[0] + bbox[2] - 1) / 2
    bottom_y = bbox[3] - 1
    offset = (round(anchor[0] - center_x), anchor[1] - bottom_y)
    target = Image.new("RGBA", (64, 64), (0, 0, 0, 0))
    target.alpha_composite(source, offset)
    return target, {"source_bbox": bbox, "offset": offset, "result_bbox": target.getchannel("A").getbbox()}


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
    anchor = (spec["foot_anchor"]["x"], spec["foot_anchor"]["y"])
    output = Image.new("RGBA", (spec["canvas"]["width"], spec["canvas"]["height"]), (0, 0, 0, 0))
    report: dict[str, object] = {"asset_id": spec["asset_id"], "frames": {}}
    for frame in motion["frames"]:
        frame_id = frame["id"]
        path = args.frames_dir / f"{frame_id}.png"
        if not path.exists():
            raise FileNotFoundError(f"missing frame: {path}")
        normalized, frame_report = normalize(Image.open(path), anchor)
        column = directions.index(frame["direction"])
        row = 0 if frame["phase"] == "idle" else int(frame_id.rsplit("_", 1)[1])
        output.alpha_composite(normalized, (column * 64, row * 64))
        report["frames"][frame_id] = {"column": column, "row": row, **frame_report}
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.report.parent.mkdir(parents=True, exist_ok=True)
    output.save(args.output)
    args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
    print(json.dumps({"status": "ok", "output": str(args.output), "frames": len(motion["frames"])}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
