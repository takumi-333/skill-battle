#!/usr/bin/env python3
"""検査済みシートのみを採用先へ明示的にコピーする。"""

from __future__ import annotations

import argparse
import json
import shutil
import subprocess
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--spec", type=Path, required=True)
    parser.add_argument("--animation", "--motion", dest="animation", type=Path, help="animation spec（--motionは旧仕様互換）")
    parser.add_argument("--build-report", type=Path)
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--target", type=Path, required=True)
    args = parser.parse_args()
    report = args.input.with_suffix(".promotion-validation.json")
    validator = Path(__file__).with_name("validate_sprite.py")
    command = [sys.executable, str(validator), "--spec", str(args.spec), "--input", str(args.input), "--report", str(report)]
    if args.animation:
        command.extend(["--animation", str(args.animation)])
    if args.build_report:
        command.extend(["--build-report", str(args.build_report)])
    result = subprocess.run(command, check=False)
    if result.returncode:
        print(json.dumps({"status": "refused", "reason": "validation_failed"}, ensure_ascii=False))
        return result.returncode
    args.target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(args.input, args.target)
    print(json.dumps({"status": "promoted", "target": str(args.target)}, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
