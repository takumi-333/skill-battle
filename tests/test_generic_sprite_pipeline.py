from __future__ import annotations

import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from PIL import Image


ROOT = Path(__file__).resolve().parents[1]
BUILD = ROOT / "tools" / "build_sprite.py"
VALIDATE = ROOT / "tools" / "validate_sprite.py"
PREVIEW = ROOT / "tools" / "preview_sprite_animation.py"
CLEANUP = ROOT / "tools" / "cleanup_frame_artifacts.py"
EXTRACT = ROOT / "tools" / "extract_sheet_frames.py"
PROMOTE = ROOT / "tools" / "promote_sprite.py"
PIXELIZE = ROOT / "tools" / "pixelize_frame.py"


def effect_spec() -> dict[str, object]:
    ids = [f"c{index}" for index in range(4)]
    return {
        "schema_version": 2,
        "asset_id": "fire_impact",
        "profile": "effect",
        "canvas": {"width": 16, "height": 16},
        "layout": {"type": "grid", "cell_size": {"width": 4, "height": 4}, "columns": ids, "rows": ids},
        "anchor": {"type": "center"},
        "normalization": {"alpha_bbox_threshold": 8},
    }


def effect_animation() -> dict[str, object]:
    return {
        "schema_version": 2,
        "asset_id": "fire_impact",
        "clips": [{
            "id": "impact", "loop": False, "fps": 12,
            "frames": [
                {
                    "id": f"impact_{index:02d}",
                    "placement": {"column": f"c{index % 4}", "row": f"c{index // 4}"},
                    "events": ["hit"] if index == 5 else [],
                }
                for index in range(16)
            ],
        }],
    }


class GenericSpritePipelineTest(unittest.TestCase):
    def run_tool(self, tool: Path, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run([sys.executable, str(tool), *args], text=True, capture_output=True, check=False)

    def test_build_validate_and_preview_sixteen_frame_effect_without_character_rules(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec_path = directory / "effect.asset.json"
            animation_path = directory / "effect.animation.json"
            spec_path.write_text(json.dumps(effect_spec()), encoding="utf-8")
            animation_path.write_text(json.dumps(effect_animation()), encoding="utf-8")
            frames_dir = directory / "frames"
            frames_dir.mkdir()
            for index in range(16):
                image = Image.new("RGBA", (4, 4), (0, 0, 0, 0))
                image.putpixel((index % 4, index // 4), (255, 80, 0, 255))
                image.putpixel((3 - index % 4, 3 - index // 4), (255, 220, 80, 255))
                image.save(frames_dir / f"impact_{index:02d}.png")

            sheet = directory / "effect.png"
            build_report = directory / "build.json"
            result = self.run_tool(BUILD, "--spec", str(spec_path), "--animation", str(animation_path), "--frames-dir", str(frames_dir), "--output", str(sheet), "--report", str(build_report))
            self.assertEqual(result.returncode, 0, result.stderr)
            with Image.open(sheet) as built_sheet:
                self.assertEqual(built_sheet.size, (16, 16))
            self.assertEqual(len(json.loads(build_report.read_text(encoding="utf-8"))["frames"]), 16)

            validation = directory / "validation.json"
            result = self.run_tool(VALIDATE, "--spec", str(spec_path), "--animation", str(animation_path), "--build-report", str(build_report), "--input", str(sheet), "--report", str(validation))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(validation.read_text(encoding="utf-8"))["profile"], "effect")

            preview = directory / "review.html"
            result = self.run_tool(PREVIEW, "--spec", str(spec_path), "--animation", str(animation_path), "--input", str(sheet), "--output", str(preview))
            self.assertEqual(result.returncode, 0, result.stderr)
            html = preview.read_text(encoding="utf-8")
            self.assertIn('id="clip"', html)
            self.assertIn("impact_05", html)
            self.assertIn("hit", html)

            extracted = directory / "extracted"
            result = self.run_tool(EXTRACT, "--sheet", str(sheet), "--spec", str(spec_path), "--animation", str(animation_path), "--output-dir", str(extracted))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(len(list(extracted.glob("*.png"))), 16)

            promoted = directory / "promoted.png"
            result = self.run_tool(PROMOTE, "--spec", str(spec_path), "--animation", str(animation_path), "--build-report", str(build_report), "--input", str(sheet), "--target", str(promoted))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertTrue(promoted.is_file())

    def test_effect_profile_disables_character_artifact_cleanup_unless_opted_in(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec_path = directory / "effect.asset.json"
            spec_path.write_text(json.dumps(effect_spec()), encoding="utf-8")
            image = Image.new("RGBA", (8, 8), (0, 0, 0, 0))
            image.putpixel((1, 1), (255, 80, 0, 255))
            image.putpixel((7, 7), (255, 220, 80, 255))
            input_path = directory / "particles.png"
            report_path = directory / "cleanup.json"
            image.save(input_path)
            result = self.run_tool(CLEANUP, str(input_path), "--spec", str(spec_path), "--check-only", "--report", str(report_path))
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertEqual(json.loads(report_path.read_text(encoding="utf-8"))["status"], "disabled")

    def test_atlas_layout_accepts_explicit_rectangles(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec = {
                "schema_version": 2, "asset_id": "bolt", "profile": "projectile",
                "canvas": {"width": 12, "height": 4}, "layout": {"type": "atlas"}, "anchor": {"type": "none"},
            }
            animation = {
                "schema_version": 2, "asset_id": "bolt", "clips": [{"id": "travel", "loop": True, "fps": 10, "frames": [
                    {"id": "bolt_0", "placement": {"x": 0, "y": 0, "width": 5, "height": 4}},
                    {"id": "bolt_1", "placement": {"x": 6, "y": 0, "width": 6, "height": 4}},
                ]}],
            }
            spec_path, animation_path = directory / "atlas.asset.json", directory / "atlas.animation.json"
            spec_path.write_text(json.dumps(spec), encoding="utf-8")
            animation_path.write_text(json.dumps(animation), encoding="utf-8")
            frames = directory / "frames"
            frames.mkdir()
            Image.new("RGBA", (5, 4), (0, 160, 255, 255)).save(frames / "bolt_0.png")
            Image.new("RGBA", (6, 4), (80, 220, 255, 255)).save(frames / "bolt_1.png")
            result = self.run_tool(BUILD, "--spec", str(spec_path), "--animation", str(animation_path), "--frames-dir", str(frames), "--output", str(directory / "atlas.png"), "--report", str(directory / "build.json"))
            self.assertEqual(result.returncode, 0, result.stderr)

    def test_pixelize_supports_rectangular_frame_output(self) -> None:
        with tempfile.TemporaryDirectory() as temporary:
            directory = Path(temporary)
            spec_path = directory / "effect.asset.json"
            spec_path.write_text(json.dumps(effect_spec()), encoding="utf-8")
            source = Image.new("RGBA", (20, 20), (0, 0, 0, 0))
            for y in range(4, 16):
                for x in range(4, 16):
                    source.putpixel((x, y), (255, 100, 20, 255))
            input_path, output_path = directory / "source.png", directory / "frame.png"
            source.save(input_path)
            result = self.run_tool(PIXELIZE, str(input_path), str(output_path), "--spec", str(spec_path), "--width", "8", "--height", "4")
            self.assertEqual(result.returncode, 0, result.stderr)
            with Image.open(output_path) as frame:
                self.assertEqual(frame.size, (8, 4))


if __name__ == "__main__":
    unittest.main()
