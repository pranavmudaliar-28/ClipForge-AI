"""Generate the ClipForge AI launcher icon art (run with Python 3.12 + Pillow):

    py -3.12 scripts/gen_icon.py

Produces, under assets/icon/:
  icon.png            1024² full-bleed rounded gradient tile + white clapperboard (legacy/iOS)
  icon_background.png  1024² diagonal gradient (Android adaptive background)
  icon_foreground.png  1024² transparent + white clapperboard in the adaptive safe zone
"""
from __future__ import annotations

import math
import os

from PIL import Image, ImageDraw

SIZE = 1024
C1 = (124, 92, 255)   # #7C5CFF electric purple
C2 = (0, 212, 255)    # #00D4FF neon blue
WHITE = (255, 255, 255, 255)
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets", "icon")


def gradient(size: int) -> Image.Image:
    """Smooth diagonal (top-left → bottom-right) gradient."""
    small = 64
    g = Image.new("RGB", (small, small))
    px = g.load()
    for y in range(small):
        for x in range(small):
            t = (x + y) / (2 * (small - 1))
            px[x, y] = tuple(round(C1[i] + (C2[i] - C1[i]) * t) for i in range(3))
    return g.resize((size, size), Image.BICUBIC).convert("RGBA")


def clapper_layer(box: float) -> Image.Image:
    """White clapperboard (with a purple play triangle) centered in a box² layer."""
    S = int(box)
    layer = Image.new("RGBA", (S, S), (0, 0, 0, 0))
    d = ImageDraw.Draw(layer)

    # Board (slate) — white rounded rectangle in the lower portion.
    bx0, by0, bx1, by1 = S * 0.10, S * 0.34, S * 0.90, S * 0.90
    d.rounded_rectangle([bx0, by0, bx1, by1], radius=S * 0.07, fill=WHITE)

    # Purple play triangle centred on the board.
    cx, cy = S * 0.5, (by0 + by1) / 2 + S * 0.01
    r = S * 0.15
    tri = [(cx - r * 0.55, cy - r), (cx - r * 0.55, cy + r), (cx + r, cy)]
    d.polygon(tri, fill=(124, 92, 255, 255))

    # Clapper stick — a tilted row of white stripes on its own layer, then rotated.
    bar_w, bar_h = int(S * 0.86), int(S * 0.24)
    bar = Image.new("RGBA", (bar_w, bar_h), (0, 0, 0, 0))
    bd = ImageDraw.Draw(bar)
    rail = int(bar_h * 0.34)
    bd.rounded_rectangle([0, bar_h - rail, bar_w, bar_h], radius=rail * 0.4, fill=WHITE)  # bottom rail
    n = 5
    slot = bar_w / n
    skew = slot * 0.42
    for i in range(n):
        x = i * slot
        # parallelogram tooth (slanted), leaving a gap to the next
        pts = [
            (x + skew, 0),
            (x + slot * 0.72 + skew, 0),
            (x + slot * 0.72, bar_h - rail),
            (x, bar_h - rail),
        ]
        bd.polygon(pts, fill=WHITE)
    bar = bar.rotate(-9, expand=True, resample=Image.BICUBIC)

    # Place the clapper stick so it sits just above the board's top edge.
    px = int(bx0 - S * 0.02)
    py = int(by0 - bar.height * 0.72)
    layer.alpha_composite(bar, (px, py))
    return layer


def rounded_mask(size: int, radius: float) -> Image.Image:
    m = Image.new("L", (size, size), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size - 1, size - 1], radius=radius, fill=255)
    return m


def main() -> None:
    os.makedirs(OUT, exist_ok=True)
    grad = gradient(SIZE)

    # Adaptive background: plain gradient.
    grad.convert("RGB").save(os.path.join(OUT, "icon_background.png"))

    # Legacy / iOS: rounded gradient tile + clapperboard (mark ~62% of canvas).
    icon = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    icon.paste(grad, (0, 0), rounded_mask(SIZE, SIZE * 0.22))
    mark = clapper_layer(SIZE * 0.62)
    off = int((SIZE - mark.width) / 2)
    icon.alpha_composite(mark, (off, off))
    icon.save(os.path.join(OUT, "icon.png"))

    # Adaptive foreground: transparent + clapperboard in the safe zone (~54%).
    fg = Image.new("RGBA", (SIZE, SIZE), (0, 0, 0, 0))
    fmark = clapper_layer(SIZE * 0.54)
    foff = int((SIZE - fmark.width) / 2)
    fg.alpha_composite(fmark, (foff, foff))
    fg.save(os.path.join(OUT, "icon_foreground.png"))

    print("wrote:", ", ".join(sorted(os.listdir(OUT))))


if __name__ == "__main__":
    main()
