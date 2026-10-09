"""Recolours the Abyssal Volcano's summit art purple, like the volcano in the opening cutscene.

The climb art was baked once from climb_art.js; this shifts the finished PNGs instead of re-baking:
fiery reds, oranges and yellows become abyssal magenta and pink, and the dark rock and the smoke take
on a violet cast. Run it again only on fresh, un-recoloured PNGs (it isn't idempotent).

Usage:  python3 tools/recolor/purple_volcano.py godot/art/climb/maps/peak.png godot/art/climb/sky/peak_far.png ...
Needs:  Pillow and numpy.
"""
import sys
import numpy as np
from PIL import Image


def recolor(path):
    im = Image.open(path).convert("RGBA")
    a = np.asarray(im).astype(np.float32) / 255.0
    rgb, alpha = a[..., :3], a[..., 3:]
    hsv = np.asarray(Image.fromarray((rgb * 255).astype(np.uint8), "RGB").convert("HSV")).astype(np.float32) / 255.0
    h, s, v = hsv[..., 0], hsv[..., 1], hsv[..., 2]
    hot = ((h < 0.17) | (h > 0.92)) & (s > 0.22)
    # fire → abyssal magenta (hue ~0.86), a touch more saturated; the brightest cores go pale pink
    h2 = np.where(hot, 0.86 - np.clip(np.where(h > 0.5, h - 1.0, h), -0.08, 0.17) * 0.35, h)
    s2 = np.where(hot, np.clip(s * 1.05, 0, 1), s)
    # rock, ash and smoke: a violet cast, stronger the darker it is
    cool = ~hot
    s2 = np.where(cool, np.clip(np.maximum(s, 0.18 + 0.3 * (1 - v)), 0, 0.6), s2)
    h2 = np.where(cool, 0.77, h2)
    out = np.stack([h2, s2, v], -1)
    rgb2 = np.asarray(Image.fromarray((np.clip(out, 0, 1) * 255).astype(np.uint8), "HSV").convert("RGB")).astype(np.float32) / 255.0
    res = np.concatenate([rgb2, alpha], -1)
    Image.fromarray((res * 255 + 0.5).astype(np.uint8), "RGBA").save(path)
    print("recoloured", path)


for p in sys.argv[1:]:
    recolor(p)
