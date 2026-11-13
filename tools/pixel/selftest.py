"""Checks clean.py on a known answer: takes real game frames, ruins them the way an AI upscaler does
(a fractional 2.67x blow-up, a slight blur, colour noise and a white background), cleans them
back and reports how close the result is to the original pixels.

Usage:  python3 tools/pixel/selftest.py [godot/art/mobs/boar/run.png] [--out DIR]
"""
import argparse
import os
import subprocess
import sys
import tempfile

import numpy as np
from PIL import Image, ImageFilter

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

HERE = os.path.dirname(os.path.abspath(__file__))


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("strip", nargs="?", default=os.path.join(HERE, "../../godot/art/mobs/boar/run.png"))
    ap.add_argument("--frame", default="88x72")
    ap.add_argument("--out")
    args = ap.parse_args()
    fw, fh = (int(v) for v in args.frame.split("x"))
    src = pk.load(args.strip)
    frames = pk.unstrip(src, fw)
    out = args.out or tempfile.mkdtemp()
    os.makedirs(out, exist_ok=True)

    # 1) ruin: lay the frames out with gaps, blow up 2.67x smoothly, blur, add noise, flatten on white
    gap = 24
    sheet = np.zeros((fh + 2 * gap, len(frames) * (fw + gap) + gap, 4), np.float32)
    for i, f in enumerate(frames):
        sheet[gap:gap + fh, gap + i * (fw + gap):gap + i * (fw + gap) + fw] = f
    s = 2.67
    im = Image.fromarray((sheet * 255).astype(np.uint8), "RGBA")
    big = im.resize((round(im.width * s), round(im.height * s)), Image.NEAREST).filter(ImageFilter.GaussianBlur(0.7))
    flat = Image.new("RGBA", big.size, (255, 255, 255, 255))
    flat.alpha_composite(big)
    noisy = np.asarray(flat).astype(np.float32) + np.random.default_rng(1).normal(0, 4, (big.height, big.width, 4))
    noisy[..., 3] = 255
    ruined = os.path.join(out, "ruined.png")
    Image.fromarray(np.clip(noisy, 0, 255).astype(np.uint8), "RGBA").save(ruined)

    # 2) clean
    n_colours = len(np.unique(src[src[..., 3] > 0.5][:, :3].round(3), axis=0))
    subprocess.run([sys.executable, os.path.join(HERE, "clean.py"), ruined, os.path.join(out, "clean"),
                    "--names", "f", "--scale", "1", "--frame", "tight", "--colors", str(max(n_colours, 8))], check=True)

    # 3) compare each cleaned frame with its original (best overlap, since cropping shifts them)
    ok_alpha, colour_err = [], []
    for i, f in enumerate(frames):
        c = pk.load(os.path.join(out, "clean", "f_%d.png" % i))
        m0 = f[..., 3] > 0.5
        best = None
        for dy in range(-4, fh - c.shape[0] + 5):
            for dx in range(-4, fw - c.shape[1] + 5):
                canvas = np.zeros_like(f)
                ys, xs = max(0, dy), max(0, dx)
                ye, xe = min(fh, dy + c.shape[0]), min(fw, dx + c.shape[1])
                if ye <= ys or xe <= xs:
                    continue
                canvas[ys:ye, xs:xe] = c[ys - dy:ye - dy, xs - dx:xe - dx]
                m1 = canvas[..., 3] > 0.5
                score = (m0 == m1).mean()
                if best is None or score > best[0]:
                    both = m0 & m1
                    err = np.abs(canvas[both, :3] - f[both, :3]).max(-1).mean() * 255 if both.any() else 255
                    best = (score, err)
        ok_alpha.append(best[0])
        colour_err.append(best[1])
    print("silhouette match %.1f%%, average colour error %.1f/255 over %d frames (ruined sheet: %s)"
          % (100 * np.mean(ok_alpha), np.mean(colour_err), len(frames), ruined))
    if np.mean(ok_alpha) < 0.97:
        sys.exit("FAIL: the cleaned silhouettes drifted from the originals")


if __name__ == "__main__":
    main()
