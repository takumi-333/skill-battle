#!/usr/bin/env python3
"""Launch the local browser-based sprite editor with direct PNG overwrite support."""

from __future__ import annotations

import argparse
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
import os
from pathlib import Path
from threading import Timer
import webbrowser

TOOLS_DIR = Path(__file__).resolve().parent
SUPPORTED_BROWSERS = (
    Path(os.environ.get("PROGRAMFILES(X86)", r"C:\Program Files (x86)")) / "Microsoft" / "Edge" / "Application" / "msedge.exe",
    Path(os.environ.get("PROGRAMFILES", r"C:\Program Files")) / "Google" / "Chrome" / "Application" / "chrome.exe",
)


def editor_url(port: int) -> str:
    return f"http://127.0.0.1:{port}/sprite_editor.html"


def make_server(port: int = 0) -> ThreadingHTTPServer:
    """Serve only the tools directory on an automatically assigned local port."""
    handler = partial(SimpleHTTPRequestHandler, directory=str(TOOLS_DIR))
    return ThreadingHTTPServer(("127.0.0.1", port), handler)


def open_supported_browser(url: str) -> None:
    """Prefer a browser that implements the File System Access API."""
    for executable in SUPPORTED_BROWSERS:
        if executable.is_file():
            webbrowser.get(f'"{executable}" %s').open(url)
            return
    webbrowser.open(url)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--no-browser", action="store_true", help="open the local URL manually")
    parser.add_argument("--port", type=int, default=0, help="local port (default: choose an available port)")
    args = parser.parse_args()
    if not 0 <= args.port <= 65535:
        parser.error("--port must be between 0 and 65535")
    with make_server(args.port) as server:
        url = editor_url(server.server_port)
        print(f"スプライトエディタを起動しました: {url}")
        print("終了するには、このウィンドウで Ctrl+C を押してください。")
        if not args.no_browser:
            # Start serving before Edge/Chrome makes its first request.
            Timer(0.1, open_supported_browser, args=(url,)).start()
        try:
            server.serve_forever()
        except KeyboardInterrupt:
            print("\nスプライトエディタを終了しました。")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
