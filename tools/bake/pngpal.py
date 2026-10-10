"""Re-packs baked PNGs as palette PNGs (lossless when a file has at most 256 distinct RGBA colours).

The hero art is flat pixel art with a few dozen colours, so this cuts the files to about a third of the
size Chromium writes, without changing a single pixel. The few files with more colours (soft glows) are
quantized to 256 colours.

Usage:  python3 tools/bake/pngpal.py godot/art/hero [more folders…]
Needs:  Pillow
"""
import os
import sys

from PIL import Image


def pack(path):
    im = Image.open(path)
    if im.mode == "P":
        return 0
    im = im.convert("RGBA")
    cols = im.getcolors(256)
    if cols is None:
        # soft glows push some frames past 256 colours: quantize those (the flat colours survive exactly,
        # only the faint glow gradients round off)
        before = os.path.getsize(path)
        im.quantize(256, method=Image.Quantize.FASTOCTREE).save(path, optimize=True)
        return before - os.path.getsize(path)
    pal = [c for _, c in cols]
    idx = {c: i for i, c in enumerate(pal)}
    p = Image.new("P", im.size)
    p.putdata([idx[px] for px in im.get_flattened_data()] if hasattr(im, "get_flattened_data") else [idx[px] for px in im.getdata()])
    flat = []
    for c in pal:
        flat += c[:3]
    p.putpalette(flat)
    before = os.path.getsize(path)
    p.save(path, transparency=bytes(c[3] for c in pal), optimize=True)
    return before - os.path.getsize(path)


saved = 0
for root in sys.argv[1:]:
    for d, _, files in os.walk(root):
        for f in files:
            if f.endswith(".png"):
                saved += pack(os.path.join(d, f))
print("saved %.1f MB" % (saved / 1e6))
