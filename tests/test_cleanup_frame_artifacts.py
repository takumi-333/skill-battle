from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "cleanup_frame_artifacts.py"


def write_spec(directory: Path, **overrides: int) -> Path:
    cleanup = {
        "enabled": True,
        "alpha_threshold": 8,
        "min_component_area": 2,
        "max_component_gap": 8,
        "max_auto_remove_area": 12,
        "remove_above_primary": True,
        "max_above_primary_area": 32,
        "max_removed_pixels": 64,
    }
    cleanup.update(overrides)
    path = directory / "asset.json"
    path.write_text(json.dumps({"artifact_cleanup": cleanup}), encoding="utf-8")
    return path


def dirty_frame() -> Image.Image:
    image = Image.new("RGBA", (64, 64), (24, 29, 49, 0))
    for y in range(10, 56):
        for x in range(25, 40):
            image.putpixel((x, y), (24, 29, 49, 255))
    # A nearby disconnected staff-like component must survive.
    for y in range(22, 42):
        image.putpixel((43, y), (216, 181, 91, 255))
    # A tiny and distant artifact must be removed.
    image.putpixel((2, 2), (255, 0, 0, 255))
    return image


class CleanupFrameArtifactsTest(unittest.TestCase):
    def run_tool(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(TOOL), *args], text=True, capture_output=True, check=False)

    def test_removes_distant_artifact_and_preserves_nearby_component(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            input_path = directory / "dirty.png"
            output_path = directory / "clean.png"
            report_path = directory / "cleanup.json"
            dirty_frame().save(input_path)
            result = self.run_tool(str(input_path), str(output_path), "--spec", str(write_spec(directory)), "--report", str(report_path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(Image.open(output_path).getpixel((2, 2))[3], 0)
            self.assertEqual(Image.open(output_path).getpixel((43, 30))[3], 255)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(report["removed_pixels"], 1)
            self.assertEqual(report["post_cleanup"]["candidates"], [])

    def test_check_only_fails_before_cleanup(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            input_path = directory / "dirty.png"
            report_path = directory / "check.json"
            dirty_frame().save(input_path)
            result = self.run_tool(str(input_path), "--spec", str(write_spec(directory)), "--check-only", "--report", str(report_path))
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("candidates", json.loads(report_path.read_text(encoding="utf-8")))

    def test_removes_small_component_above_body_even_when_gap_is_small(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            input_path = directory / "top-fragment.png"
            output_path = directory / "clean.png"
            report_path = directory / "cleanup.json"
            image = Image.new("RGBA", (64, 64), (24, 29, 49, 0))
            for y in range(10, 56):
                for x in range(25, 40):
                    image.putpixel((x, y), (24, 29, 49, 255))
            # The gap is only five pixels, but the fragment is wholly above the body.
            for x in range(30, 36):
                image.putpixel((x, 4), (8, 10, 20, 255))
            image.save(input_path)
            result = self.run_tool(str(input_path), str(output_path), "--spec", str(write_spec(directory)), "--report", str(report_path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(Image.open(output_path).getpixel((32, 4))[3], 0)
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertIn("above_primary", report["candidates"][0]["reasons"])

    def test_large_distant_component_requires_review(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            input_path = directory / "unsafe.png"
            output_path = directory / "unsafe-clean.png"
            report_path = directory / "unsafe.json"
            image = dirty_frame()
            for y in range(2, 8):
                for x in range(2, 8):
                    image.putpixel((x, y), (255, 0, 0, 255))
            image.save(input_path)
            result = self.run_tool(str(input_path), str(output_path), "--spec", str(write_spec(directory)), "--report", str(report_path))
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse(output_path.exists())
            report = json.loads(report_path.read_text(encoding="utf-8"))
            self.assertEqual(len(report["unsafe_components"]), 1)


if __name__ == "__main__":
    unittest.main()
