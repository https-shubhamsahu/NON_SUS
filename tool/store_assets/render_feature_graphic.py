#!/usr/bin/env python3
"""Render the 1024x500 Play feature graphic with headless Chrome."""

from __future__ import annotations

import http.server
import shutil
import socketserver
import subprocess
import sys
import tempfile
import threading
import time
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
HTML = ROOT / "tool" / "store_assets" / "feature_graphic.html"
OUT = ROOT / "fastlane" / "metadata" / "android" / "en-IN" / "images" / "featureGraphic.png"
CHROME_CANDIDATES = [
    Path(r"C:\Program Files\Google\Chrome\Application\chrome.exe"),
    Path(r"C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"),
    Path.home() / r"AppData\Local\Google\Chrome\Application\chrome.exe",
    Path("/usr/bin/google-chrome"),
    Path("/usr/bin/chromium"),
    Path("/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"),
]


def _chrome() -> Path:
    for path in CHROME_CANDIDATES:
        if path.is_file():
            return path
    found = shutil.which("google-chrome") or shutil.which("chromium") or shutil.which("chrome")
    if found:
        return Path(found)
    raise SystemExit("Chrome/Chromium not found; cannot render featureGraphic.png")


def _serve(root: Path) -> tuple[socketserver.TCPServer, str]:
    class Handler(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(root), **kwargs)

        def log_message(self, format, *args):
            return

    server = socketserver.TCPServer(("127.0.0.1", 0), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    host, port = server.server_address[:2]
    return server, f"http://{host}:{port}/tool/store_assets/feature_graphic.html"


def render() -> Path:
    if not HTML.is_file():
        raise SystemExit(f"missing {HTML}")
    chrome = _chrome()
    OUT.parent.mkdir(parents=True, exist_ok=True)
    server, url = _serve(ROOT)
    user_data = Path(tempfile.mkdtemp(prefix="nosus-chrome-"))
    screenshot_tmp = Path(tempfile.mkdtemp(prefix="nosus-fg-")) / "shot.png"
    try:
        cmd = [
            str(chrome),
            "--headless=new",
            "--disable-gpu",
            "--hide-scrollbars",
            "--force-device-scale-factor=1",
            "--window-size=1024,500",
            f"--user-data-dir={user_data}",
            f"--screenshot={screenshot_tmp}",
            url,
        ]
        subprocess.run(cmd, check=True, cwd=str(ROOT))
        # Give webfonts a beat if Chrome wrote before Geist swapped in.
        time.sleep(0.4)
        if not screenshot_tmp.is_file():
            raise SystemExit("Chrome did not write a screenshot")
        im = Image.open(screenshot_tmp).convert("RGB")
        if im.size != (1024, 500):
            im = im.resize((1024, 500), Image.Resampling.LANCZOS)
        im.save(OUT, "PNG")
    finally:
        server.shutdown()
        shutil.rmtree(user_data, ignore_errors=True)
        shutil.rmtree(screenshot_tmp.parent, ignore_errors=True)
    return OUT


if __name__ == "__main__":
    path = render()
    im = Image.open(path)
    print(f"wrote {path} {im.size[0]}x{im.size[1]} {im.mode}")
    sys.exit(0)
