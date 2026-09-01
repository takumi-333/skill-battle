from __future__ import annotations

import importlib.util
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
TOOL = ROOT / "tools" / "sprite_editor.py"
HTML = ROOT / "tools" / "sprite_editor.html"
SPEC = importlib.util.spec_from_file_location("sprite_editor", TOOL)
assert SPEC and SPEC.loader
sprite_editor = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(sprite_editor)


class SpriteEditorTest(unittest.TestCase):
    def test_server_is_localhost_and_uses_a_dynamic_port(self) -> None:
        server = sprite_editor.make_server()
        try:
            self.assertEqual(server.server_address[0], "127.0.0.1")
            self.assertGreater(server.server_port, 0)
            self.assertEqual(sprite_editor.editor_url(server.server_port), f"http://127.0.0.1:{server.server_port}/sprite_editor.html")
        finally:
            server.server_close()

    def test_editor_defines_pixel_editing_and_direct_overwrite(self) -> None:
        html = HTML.read_text(encoding="utf-8")
        for required in (
            'id="sheetMode"', 'id="cellMode"', 'id="cellWidth"', 'id="cellHeight"', 'id="pencil"', 'id="eraser"', 'id="fill"',
            'id="transparent"', 'id="save"', 'const CELL=64', 'showOpenFilePicker',
            'createWritable()', "requestPermission({mode:'readwrite'})", 'image-rendering:pixelated',
        ):
            self.assertIn(required, html)
