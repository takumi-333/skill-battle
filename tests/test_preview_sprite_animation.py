from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "preview_sprite_animation.py"


def write_specs(directory: Path) -> tuple[Path, Path]:
    spec = {
        "asset_id": "test_character",
        "canvas": {"width": 16, "height": 10},
        "cell_size": {"width": 2, "height": 2},
        "columns": ["down", "down_left", "left", "up_left", "up", "up_right", "right", "down_right"],
        "rows": ["idle", "walk_01", "walk_02", "walk_03", "walk_04"],
    }
    motion = {"frames": [
        {"id": f"{direction}_{phase}", "direction": direction, "phase": phase}
        for direction in spec["columns"] for phase in spec["rows"]
    ]}
    spec_path = directory / "asset.json"
    motion_path = directory / "motion.json"
    spec_path.write_text(json.dumps(spec), encoding="utf-8")
    motion_path.write_text(json.dumps(motion), encoding="utf-8")
    return spec_path, motion_path


class PreviewSpriteAnimationTest(unittest.TestCase):
    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(TOOL), *args], text=True, capture_output=True, check=False)

    def test_generates_self_contained_review_html_from_sheet(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec, motion = write_specs(directory)
            sheet = Image.new("RGBA", (16, 10), (0, 0, 0, 0))
            sheet.putpixel((0, 0), (255, 0, 0, 255))
            input_path = directory / "candidate.png"
            output_path = directory / "review.html"
            sheet.save(input_path)

            result = self.run_tool("--spec", str(spec), "--motion", str(motion), "--input", str(input_path), "--output", str(output_path))

            self.assertEqual(result.returncode, 0, result.stderr)
            output = output_path.read_text(encoding="utf-8")
            self.assertIn("data:image/png;base64,", output)
            self.assertIn("0.25倍速度", output)
            self.assertIn("4倍nearest", output)
            self.assertIn("down_walk_01", output)

    def test_allows_partial_frames_directory_for_pattern_review(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec, motion = write_specs(directory)
            frames = directory / "frames"
            frames.mkdir()
            for phase in ("idle", "walk_01", "walk_02", "walk_03", "walk_04"):
                Image.new("RGBA", (2, 2), (255, 0, 0, 255)).save(frames / f"down_{phase}.png")
            output_path = directory / "review.html"

            result = self.run_tool("--spec", str(spec), "--motion", str(motion), "--frames-dir", str(frames), "--output", str(output_path))

            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("一部パターン未作成", output_path.read_text(encoding="utf-8"))

    def test_rejects_mismatched_sheet_size_and_duplicate_motion_position(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec, motion = write_specs(directory)
            Image.new("RGBA", (1, 1)).save(directory / "bad.png")
            result = self.run_tool("--spec", str(spec), "--motion", str(motion), "--input", str(directory / "bad.png"), "--output", str(directory / "review.html"))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("sprite sheet size expected", result.stderr)

            data = json.loads(motion.read_text(encoding="utf-8"))
            data["frames"].append({"id": "duplicate", "direction": "down", "phase": "idle"})
            motion.write_text(json.dumps(data), encoding="utf-8")
            result = self.run_tool("--spec", str(spec), "--motion", str(motion), "--input", str(directory / "bad.png"), "--output", str(directory / "review.html"))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("duplicate motion position", result.stderr)


if __name__ == "__main__":
    unittest.main()
