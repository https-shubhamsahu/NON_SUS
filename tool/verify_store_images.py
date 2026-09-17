#!/usr/bin/env python3
"""Copy the Play icon, flatten listing PNGs, and print a dimension table.

Phone screenshots are optional. Missing `phoneScreenshots/` is not a failure;
if PNGs are present they are still checked against Play's phone rules.
"""

from __future__ import annotations

import shutil
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
IMAGES = ROOT / "fastlane" / "metadata" / "android" / "en-IN" / "images"
ICON_SRC = ROOT / "homepage" / "public" / "app_icon.png"
PHONE = IMAGES / "phoneScreenshots"


def _flatten_rgb(path: Path) -> Image.Image:
    im = Image.open(path)
    if im.mode != "RGB":
        im = im.convert("RGB")
        im.save(path, "PNG")
        im = Image.open(path)
    return im


def _check_icon(path: Path) -> list[str]:
    issues = []
    im = Image.open(path)
    w, h = im.size
    kb = path.stat().st_size / 1024
    if (w, h) != (512, 512):
        issues.append(f"icon must be 512x512, got {w}x{h}")
    if path.stat().st_size >= 1024 * 1024:
        issues.append(f"icon must be <1 MB, got {kb:.1f} KB")
    return issues


def _check_feature(path: Path) -> list[str]:
    issues = []
    im = Image.open(path)
    w, h = im.size
    if (w, h) != (1024, 500):
        issues.append(f"feature graphic must be 1024x500, got {w}x{h}")
    if im.mode in ("RGBA", "LA", "P") and "transparency" in im.info:
        issues.append("feature graphic has transparency; Play wants 24-bit PNG")
    if im.mode == "RGBA":
        issues.append("feature graphic is RGBA; flatten to RGB")
    return issues


def _check_phone(path: Path) -> list[str]:
    issues = []
    im = Image.open(path)
    w, h = im.size
    ratio = max(w, h) / min(w, h)
    if min(w, h) < 1080:
        issues.append(f"{path.name}: each side must be ≥1080px, got {w}x{h}")
    if ratio - 2.0 > 0.001:
        issues.append(f"{path.name}: aspect {ratio:.3f} exceeds 2:1")
    if im.mode == "RGBA":
        issues.append(f"{path.name}: RGBA; flatten to RGB")
    return issues


def main() -> int:
    IMAGES.mkdir(parents=True, exist_ok=True)

    icon_dest = IMAGES / "icon.png"
    if not ICON_SRC.is_file():
        print(f"missing icon source {ICON_SRC}", file=sys.stderr)
        return 1
    shutil.copyfile(ICON_SRC, icon_dest)
    _flatten_rgb(icon_dest)

    feature = IMAGES / "featureGraphic.png"
    if feature.is_file():
        _flatten_rgb(feature)

    phone_shots = sorted(PHONE.glob("*.png")) if PHONE.is_dir() else []
    for shot in phone_shots:
        _flatten_rgb(shot)

    rows = []
    issues: list[str] = []
    required = [icon_dest, feature]
    for path in [*required, *phone_shots]:
        if not path.is_file():
            issues.append(f"missing {path.relative_to(ROOT)}")
            continue
        im = Image.open(path)
        w, h = im.size
        kb = path.stat().st_size / 1024
        ratio = max(w, h) / max(min(w, h), 1)
        rel = path.relative_to(ROOT)
        rows.append((str(rel), w, h, im.mode, kb, ratio))
        if path == icon_dest:
            issues.extend(_check_icon(path))
        elif path.name == "featureGraphic.png":
            issues.extend(_check_feature(path))
        else:
            issues.extend(_check_phone(path))

    print(f"{'file':<72} {'w':>5} {'h':>5} {'mode':>5} {'kb':>8} {'ratio':>6}")
    print("-" * 110)
    for name, w, h, mode, kb, ratio in rows:
        print(f"{name:<72} {w:5} {h:5} {mode:>5} {kb:8.1f} {ratio:6.3f}")

    if not phone_shots:
        print("\nNo phoneScreenshots yet (optional; capture from a real device).")

    if issues:
        print("\nFAILED:")
        for item in issues:
            print(f"  - {item}")
        return 1
    print("\nChecked listing images meet the specs above.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
