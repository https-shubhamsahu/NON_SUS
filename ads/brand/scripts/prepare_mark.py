#!/usr/bin/env python3
"""Knock the white square out of the Lux/Nox mark so it sits on #080808."""

from collections import deque
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / "src" / "lux-nox-source.png"
OUT = ROOT / "public" / "mark.png"


def lum(pixel):
    r, g, b, _a = pixel
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def main():
    src = Image.open(SRC).convert("RGBA")
    width, height = src.size
    pixels = src.load()
    seen = [[False] * width for _ in range(height)]
    queue = deque()
    for x, y in ((0, 0), (width - 1, 0), (0, height - 1), (width - 1, height - 1)):
        queue.append((x, y))
        seen[y][x] = True

    while queue:
        x, y = queue.popleft()
        if lum(pixels[x, y]) < 232:
            continue
        pixels[x, y] = (0, 0, 0, 0)
        for nx, ny in ((x - 1, y), (x + 1, y), (x, y - 1), (x, y + 1)):
            if 0 <= nx < width and 0 <= ny < height and not seen[ny][nx]:
                seen[ny][nx] = True
                queue.append((nx, ny))

    OUT.parent.mkdir(parents=True, exist_ok=True)
    src.save(OUT, "PNG")
    print(f"wrote {OUT} ({width}x{height})")


if __name__ == "__main__":
    main()
