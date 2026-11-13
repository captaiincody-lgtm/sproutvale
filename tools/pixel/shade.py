"""Gives flat-coloured pixel sprites real volume: shading, hue-shifted ramps and a selective outline.

The game's monsters were drawn in code as flat fills (one colour per body part). This pass reads each
frame, works out a rough 3D shape from the silhouette and from each colour patch, lights it from the
upper left, and repaints every pixel from a short colour ramp built around its flat colour: shadows go
darker, cooler and richer, lights go paler and warmer, the way pixel artists shade by hand. Every frame
of a monster uses the same ramps, so the whole set stays palette-locked.

It also works on art you draw yourself: paint a sprite in flat colours (no shading) at the right frame
size, run it through this, and touch up the result by hand.

What it adds, all on the original pixel grid (no pixel moves, nothing is resized):
  * form shading: up to 5 tones per colour (deep shadow, shadow, base, light, highlight)
  * a contact shadow where one body part tucks behind another
  * a 1-pixel rim light on edges that face the light
  * a selective outline ("sel-out"): a dark outline tinted from the colour it borders, darker on the
    shadow side, skipped if the sprite already has a dark outline
  * optional 2x2 ordered dithering in the soft shadow band (--dither)

Tiny details (eyes, glints, single-colour specks under --detail pixels) and the hit-flash frames
("white") are left alone.

Usage:
  python3 tools/pixel/shade.py IN_DIR OUT_DIR [--strength 1.0] [--dither] [--no-outline] [--palette pal.hex]
      IN_DIR is a monster folder of strips (e.g. godot/art/mobs/rat); frames are cut using the w/h in
      the nearest mobs.json, or --frame WxH. OUT_DIR may be the same folder to shade in place.
  python3 tools/pixel/shade.py --mobs godot/art/mobs rat boar green ... [--out DIR]
      shades those monsters and their _shiny / _elite recolours. Without --out, overwrites the files
      in place. Run it on freshly baked (flat) art: shading already-shaded art again muddies it.
Needs Pillow, NumPy and SciPy.
"""
import argparse
import json
import os
import shutil
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402

LIGHT = np.array([-0.55, -0.72, 0.62])   # from the upper left and in front (image y points down)
LIGHT = LIGHT / np.linalg.norm(LIGHT)
SKIP_KEYS = {"white", "whiteStand"}      # hit-flash silhouettes stay pure white


def dome(d, r):
    """Height of a rounded edge profile: 0 at the edge, rising like a quarter circle to r."""
    t = np.clip(d / r, 0, 1)
    return r * np.sqrt(1 - (1 - t) ** 2)


def shade_frame(f, ramps, opts):
    """f: RGBA float frame. ramps: {base colour key: {level: rgb}} (filled in as new colours appear)."""
    a = f[..., 3]
    m = a > 0.5
    if not m.any():
        return f
    rgb = f[..., :3]
    key = (rgb * 255).round().astype(int)
    keyi = (key[..., 0] << 16) | (key[..., 1] << 8) | key[..., 2]
    keyi = np.where(m, keyi, -1)
    H, W = m.shape

    # ---- details: small patches, pupils and glints that keep their exact colour
    detail = np.zeros((H, W), bool)
    for kv in np.unique(keyi[m]):
        lab, n = pk.components(keyi == kv)
        sizes = ndimage.sum(np.ones_like(lab), lab, range(1, n + 1))
        for i in range(n):
            sel = lab == i + 1
            c = rgb[sel][0]
            v = c.max()
            if sizes[i] <= opts.detail or v < 0.12 or (sizes[i] <= opts.detail * 3 and (c.min() > 0.85)):
                detail[sel] = True

    # ---- materials: colours of one hue family that touch (a slime's body and its painted highlight
    # band, say) are one surface, so the band boundary doesn't read as a fold
    cols = [kv for kv in np.unique(keyi[m & ~detail])]
    parent = {kv: kv for kv in cols}

    def find(k):
        while parent[k] != k:
            parent[k] = parent[parent[k]]
            k = parent[k]
        return k
    lch = {kv: pk.lab2lch(pk.rgb2lab(np.array([(kv >> 16) & 255, (kv >> 8) & 255, kv & 255]) / 255.0)) for kv in cols}
    for i, k1 in enumerate(cols):
        for k2 in cols[i + 1:]:
            L1, C1, h1 = lch[k1]
            L2, C2, h2 = lch[k2]
            dh = abs((h1 - h2 + np.pi) % (2 * np.pi) - np.pi)
            same_hue = (C1 < 0.04 and C2 < 0.04) or (min(C1, C2) >= 0.04 and dh < 0.45)
            if same_hue and abs(L1 - L2) < 0.22:
                parent[find(k1)] = find(k2)
    mat = np.zeros((H, W), int)
    for kv in cols:
        mat[(keyi == kv) & ~detail] = find(kv) + 1   # +1 keeps black (0) distinct from "nothing"
    materials = np.zeros((H, W), int)
    nmat = 0
    for mv in np.unique(mat[mat != 0]):
        lab, n = pk.components(mat == mv)
        for i in range(n):
            nmat += 1
            materials[lab == i + 1] = nmat

    # ---- height field: the whole silhouette's roundness plus each material patch's own (with the
    # eyes and other details inside it filled in, so they don't dent the surface)
    r_sil = opts.radius
    d_sil = ndimage.distance_transform_edt(np.pad(m, 1))[1:-1, 1:-1]
    d_reg = np.zeros((H, W))
    for i in range(1, nmat + 1):
        sel = ndimage.binary_fill_holes(materials == i)
        dd = ndimage.distance_transform_edt(np.pad(sel, 1))[1:-1, 1:-1]
        d_reg[sel] = np.maximum(d_reg[sel], dd[sel])
    h = 0.55 * dome(d_sil, r_sil) + 0.45 * dome(d_reg, r_sil * 0.6)
    h = ndimage.gaussian_filter(h, 0.7) * m
    gy, gx = np.gradient(h)
    n = np.stack([-gx, -gy, np.full_like(h, 1.0 / opts.strength)], -1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    lam = n @ LIGHT
    # a little extra shadow low on the body (ambient occlusion from the ground)
    ys = np.nonzero(m.any(1))[0]
    top, bot = ys.min(), ys.max()
    yrel = (np.arange(H)[:, None] - top) / max(1, bot - top)
    lam = lam - 0.10 * np.clip(yrel - 0.6, 0, 1) * 2.5

    flat = LIGHT[2]
    t = lam - flat     # 0 = facing the viewer
    level = np.select([t < -0.42, t < -0.17, t < 0.12, t < 0.26], [-2, -1, 0, 1], 2)
    if opts.dither:
        bayer = np.array([[0, 2], [3, 1]]) / 4 - 0.375
        b = np.tile(bayer, (H // 2 + 1, W // 2 + 1))[:H, :W]
        soft = (t > -0.24) & (t < -0.10)
        level = np.where(soft, np.where(t + b * 0.14 < -0.17, -1, 0), level)

    # ---- contact shadow: where a body part meets a higher one, its border pixel drops a tone
    for dy, dx in ((0, 1), (0, -1), (1, 0), (-1, 0)):
        nb = np.roll(materials, (dy, dx), (0, 1))
        nh = np.roll(h, (dy, dx), (0, 1))
        edge = m & (materials > 0) & (nb != materials) & (nb > 0) & (nh > h + 0.25)
        level = np.where(edge & ~detail, np.minimum(level, 0) - 1, level)

    # ---- rim light: pixels on the silhouette edge facing the light
    outside = ~m
    up = np.roll(outside, 1, 0)
    up[0] = True
    left = np.roll(outside, 1, 1)
    left[:, 0] = True
    rim = m & (up | left) & (t > -0.05)
    level = np.where(rim & ~detail, np.maximum(level, 1), level)
    level = np.clip(level, -2, 2)

    # ---- repaint from the ramps
    out = f.copy()
    for kv in np.unique(keyi[m & ~detail]):
        if kv not in ramps:
            base = np.array([(kv >> 16) & 255, (kv >> 8) & 255, kv & 255]) / 255.0
            ramps[kv] = pk.ramp(base)
        rp = ramps[kv]
        sel = (keyi == kv) & ~detail
        for lv in (-2, -1, 0, 1, 2):
            s2 = sel & (level == lv)
            out[s2, :3] = rp[lv]

    # ---- selective outline
    if opts.outline:
        edge_in = m & ~ndimage.binary_erosion(m, border_value=0)
        already = (rgb[edge_in].max(-1) < 0.22).mean() > 0.6 if edge_in.any() else False
        if not already:
            ring = ndimage.binary_dilation(m, structure=ndimage.generate_binary_structure(2, 1)) & ~m
            ys2, xs2 = np.nonzero(ring)
            for y, x in zip(ys2, xs2):
                # tint from the neighbour it hugs (prefer the one below/right: the outline reads as shadow)
                best = None
                for dy, dx, side in ((1, 0, 0), (0, 1, 0), (0, -1, 1), (-1, 0, 1)):
                    yy, xx = y + dy, x + dx
                    if 0 <= yy < H and 0 <= xx < W and m[yy, xx]:
                        best = (yy, xx, side)
                        break
                if best is None:
                    continue
                yy, xx, side = best
                kv = keyi[yy, xx]
                if kv not in ramps:
                    base = rgb[yy, xx]
                    ramps[kv] = pk.ramp(base)
                # outline pixels above/left of the body face the light: one step lighter
                lit = side == 0 and (dy == 1 or dx == 1)
                out[y, x, :3] = ramps[kv][-2 if lit and opts.selout else -3]
                out[y, x, 3] = 1.0
    if opts.palette is not None:
        mm = out[..., 3] > 0.5
        out[mm, :3] = opts.palette[pk.nearest(out[mm][:, :3], opts.palette)]
    return out


def find_manifest(folder):
    d = os.path.abspath(folder)
    for _ in range(3):
        d = os.path.dirname(d)
        p = os.path.join(d, "mobs.json")
        if os.path.exists(p):
            return p
    return None


def shade_folder(src, dst, opts, frame=None):
    name = os.path.basename(os.path.normpath(src))
    if frame is None:
        man = find_manifest(src + "/x")
        sets = json.load(open(man))["sets"] if man else {}
        st = sets.get(name)
        if not st:
            sys.exit("%s isn't in mobs.json; pass --frame WxH" % name)
        frame = (st["w"], st["h"])
    fw, fh = frame
    ramps = {}
    os.makedirs(dst, exist_ok=True)
    for fn in sorted(os.listdir(src)):
        if not fn.endswith(".png"):
            continue
        key = fn[:-4]
        arr = pk.load(os.path.join(src, fn))
        if key in SKIP_KEYS:
            if os.path.abspath(src) != os.path.abspath(dst):
                shutil.copy(os.path.join(src, fn), os.path.join(dst, fn))
            continue
        frames = pk.unstrip(arr, fw) if arr.shape[1] >= fw else [arr]
        frames = [shade_frame(f, ramps, opts) for f in frames]
        pk.save(pk.strip(frames), os.path.join(dst, fn))
    return ramps


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("paths", nargs="+")
    ap.add_argument("--mobs", action="store_true", help="first path is a mobs folder, the rest are monster names")
    ap.add_argument("--out", help="with --mobs: write here instead of in place")
    ap.add_argument("--frame", help="frame size WxH (default: from mobs.json)")
    ap.add_argument("--strength", type=float, default=1.5, help="how strongly the shape bends the light (0.5-2)")
    ap.add_argument("--radius", type=float, default=9.0, help="how many pixels in from the edge a body is fully round")
    ap.add_argument("--detail", type=int, default=6, help="colour patches this small or smaller are left as drawn")
    ap.add_argument("--dither", action="store_true", help="2x2 ordered dithering in the soft shadow band")
    ap.add_argument("--no-outline", dest="outline", action="store_false")
    ap.add_argument("--no-selout", dest="selout", action="store_false", help="one outline colour all the way round")
    ap.add_argument("--palette", help="finally snap every colour to this palette (.hex/.txt, .json or swatch .png)")
    opts = ap.parse_args()
    opts.palette = pk.load_palette(opts.palette) if opts.palette else None
    frame = tuple(int(v) for v in opts.frame.lower().split("x")) if opts.frame else None

    if opts.mobs:
        root, names = opts.paths[0], opts.paths[1:]
        out_root = opts.out or root
        for name in names:
            # the _shiny and _elite folders are flat recolours of the same drawing, so they are shaded
            # the same way (recolouring the shaded base instead would rotate the cool shadows to odd hues)
            for nm in (name, name + "_shiny", name + "_elite"):
                src = os.path.join(root, nm)
                if not os.path.isdir(src):
                    continue
                ramps = shade_folder(src, os.path.join(out_root, nm), opts, frame or _frame_from(root, nm))
                print("shaded %-16s %2d flat colours -> %3d shades" % (nm, len(ramps), len(ramps) * 6))
    else:
        src, dst = opts.paths[0], opts.paths[1] if len(opts.paths) > 1 else opts.paths[0]
        shade_folder(src, dst, opts, frame)
        print("shaded", src, "->", dst)


def _frame_from(root, name):
    st = json.load(open(os.path.join(root, "mobs.json")))["sets"][name]
    return st["w"], st["h"]


if __name__ == "__main__":
    main()
