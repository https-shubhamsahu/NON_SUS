#!/usr/bin/env python3
"""Pad existing real app screenshots onto a Play-valid canvas.

Only used when emulator capture did not produce phoneScreenshots.
Does not invent UI — it letterboxes files from assets/screenshots/.
Skips shots that contain real personal filenames (resume) or the
retired profile metrics screen, which would misrepresent the current app.
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "assets" / "screenshots"
DEST = ROOT / "fastlane" / "metadata" / "android" / "en-IN" / "images" / "phoneScreenshots"

# Real in-app captures. Mapping is best-effort for a no-emulator fallback.
# Watermarked viewer (11, 19) uses demo identity, not a real student resume.
FALLBACK = {
    "1_welcome": "1.png",  # onboarding handshake — last-resort only
    "5_watermarked_viewer": "19.png",
}


def fit_play_phone(im: Image.Image, min_side: int = 1080, max_ratio: float = 2.0) -> Image.Image:
    im = im.convert("RGB")
    w, h = im.size
    scale = max(min_side / w, min_side / h, 1.0)
    if scale != 1:
        im = im.resize((int(round(w * scale)), int(round(h * scale))), Image.Resampling.LANCZOS)
    w, h = im.size
    ratio = max(w, h) / min(w, h)
    if ratio > max_ratio + 0.001:
        if h >= w:
            new_w = int(round(h / max_ratio))
            canvas = Image.new("RGB", (new_w, h), (0, 0, 0))
            canvas.paste(im, ((new_w - w) // 2, 0))
            im = canvas
        else:
            new_h = int(round(w / max_ratio))
            canvas = Image.new("RGB", (w, new_h), (0, 0, 0))
            canvas.paste(im, (0, (new_h - h) // 2))
            im = canvas
    return im


def main() -> int:
    DEST.mkdir(parents=True, exist_ok=True)
    existing = list(DEST.glob("*.png"))
    if len(existing) >= 4:
        print(f"phoneScreenshots already has {len(existing)} PNGs; not padding fallbacks")
        return 0

    wrote = 0
    for dest_name, src_name in FALLBACK.items():
        dest = DEST / f"{dest_name}.png"
        if dest.is_file():
            continue
        src = SRC / src_name
        if not src.is_file():
            print(f"skip {dest_name}: missing {src}")
            continue
        im = fit_play_phone(Image.open(src))
        im.save(dest, "PNG")
        print(f"padded {src.name} -> {dest.relative_to(ROOT)} {im.size[0]}x{im.size[1]}")
        wrote += 1
    if wrote == 0 and len(existing) < 2:
        print("no fallback screenshots written", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
