#!/usr/bin/env python3
"""64pxの攻撃エフェクトフレームを横一列のスプライトシートへ組む。"""

from __future__ import annotations

import argparse
import json
from pathlib import Path

from PIL import Image


CELL_SIZE = 64
DEFAULT_FRAME_COUNT = 4


def main() -> int:
	parser = argparse.ArgumentParser()
	parser.add_argument("--frames-dir", type=Path, required=True)
	parser.add_argument("--output", type=Path, required=True)
	parser.add_argument("--report", type=Path, required=True)
	parser.add_argument("--frame-count", type=int, default=DEFAULT_FRAME_COUNT)
	args = parser.parse_args()
	if args.frame_count < 1:
		raise ValueError("frame-count must be at least 1")

	sheet = Image.new("RGBA", (CELL_SIZE * args.frame_count, CELL_SIZE), (0, 0, 0, 0))
	report: dict[str, object] = {"canvas": [CELL_SIZE * args.frame_count, CELL_SIZE], "frames": []}
	for index in range(args.frame_count):
		path = args.frames_dir / f"frame_{index}.png"
		if not path.exists():
			raise FileNotFoundError(f"missing frame: {path}")
		frame = Image.open(path).convert("RGBA")
		if frame.size != (CELL_SIZE, CELL_SIZE):
			raise ValueError(f"frame must be 64x64: {path} is {frame.size}")
		bbox = frame.getchannel("A").getbbox()
		if bbox is None:
			raise ValueError(f"empty alpha frame: {path}")
		sheet.alpha_composite(frame, (index * CELL_SIZE, 0))
		report["frames"].append({"index": index, "source": str(path), "visible_bbox": bbox})

	args.output.parent.mkdir(parents=True, exist_ok=True)
	args.report.parent.mkdir(parents=True, exist_ok=True)
	sheet.save(args.output)
	args.report.write_text(json.dumps(report, ensure_ascii=False, indent=2), encoding="utf-8")
	print(json.dumps({"status": "ok", "output": str(args.output), "size": list(sheet.size), "frames": args.frame_count}, ensure_ascii=False))
	return 0


if __name__ == "__main__":
	raise SystemExit(main())
