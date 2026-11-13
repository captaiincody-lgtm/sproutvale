"""Cleans an AI-made (or scanned, or upscaled) sprite sheet into true pixel art.

What it fixes:
  * "mixels": the picture is drawn with fat pixels of drifting, non-integer size and blurry edges.
    The script measures the real pixel size, finds where the grid sits under each sprite, and reads one
    colour per grid cell from the cell's centre (so the blurred edges between cells are ignored).
  * colour soup: thousands of near-identical colours become one shared palette (k-means in OKLab, 32
    colours by default, or snapped to a palette you give it), the same for every frame on the sheet.
  * soft edges: alpha becomes fully on or off, and stray single pixels are dropped.
  * slicing: each sprite on the sheet is found, sorted into rows and columns, lined up with the other
    frames in its row so the animation doesn't wobble, and saved on a fixed-size frame with its feet on
    an anchor point (the game's monster frames are 88 x 72 with the feet at 44, 66).

Usage:
  python3 tools/pixel/clean.py SHEET.png OUT_DIR [--colors 32] [--palette pal.hex] [--px auto|4.2]
         [--grid COLSxROWS] [--frame 88x72] [--anchor 44,66] [--bg auto|none|#rrggbb] [--names a,b,c]

Writes OUT_DIR/<row name>_<frame>.png, OUT_DIR/<row name>.png (a strip per row), OUT_DIR/palette.png,
OUT_DIR/preview.png (everything at 4x on a checkerboard) and OUT_DIR/clean.json (what it measured).
Rows are named row0, row1, … unless --names gives names. Needs Pillow, NumPy and SciPy.
"""
import argparse
import json
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402


# ---------------------------------------------------------------------------- background


def key_background(a, spec):
    """Give a flat-background image an alpha channel by flood-filling the background from the border."""
    if spec == "none":
        return a, []
    has_alpha = (a[..., 3] < 0.99).mean() > 0.02
    if spec == "auto" and has_alpha:
        return a, []
    rgb = a[..., :3]
    if spec == "auto":
        border = np.concatenate([rgb[0], rgb[-1], rgb[:, 0], rgb[:, -1]])
        q = (border * 15).round().astype(int)
        vals, counts = np.unique(q, axis=0, return_counts=True)
        order = counts.argsort()[::-1]
        bgs = [border[(q == vals[i]).all(1)].mean(0) for i in order[:2] if counts[i] > len(border) * 0.15]
    else:
        bgs = [pk.parse_hex(s) for s in spec.split(",")]
    near = np.zeros(rgb.shape[:2], bool)
    for c in bgs:
        near |= np.abs(rgb - c).max(-1) < 0.09
    lab, _ = ndimage.label(near)
    edge = np.unique(np.concatenate([lab[0], lab[-1], lab[:, 0], lab[:, -1]]))
    bg = np.isin(lab, edge[edge > 0])
    # the blurred fringe where sprite fades into background: looser match, but only right next to it
    loose = np.zeros_like(near)
    for c in bgs:
        loose |= np.abs(rgb - c).max(-1) < 0.30
    bg |= loose & ndimage.binary_dilation(bg, iterations=3)
    out = a.copy()
    out[..., 3] = np.where(bg, 0, a[..., 3])
    return out, bgs


def defringe(f, bgs):
    """Drop edge pixels that are really a blur of sprite and removed background: an edge pixel goes if
    it is closer to the background colour than to the sprite pixels just inside it."""
    if not bgs:
        return f
    f = f.copy()
    for _ in range(2):
        m = f[..., 3] > 0.5
        inner = ndimage.binary_erosion(m, border_value=0)
        edge = m & ~inner
        ys, xs = np.nonzero(edge)
        drop = []
        for y, x in zip(ys, xs):
            y0, y1, x0, x1 = max(0, y - 2), y + 3, max(0, x - 2), x + 3
            sub = inner[y0:y1, x0:x1]
            if not sub.any():
                continue
            q = f[y0:y1, x0:x1][sub][:, :3].mean(0)
            p = f[y, x, :3]
            db = min(np.abs(p - b).max() for b in bgs)
            if db < np.abs(p - q).max() * 0.8:
                drop.append((y, x))
        for y, x in drop:
            f[y, x] = 0
        if not drop:
            break
    return f


# ---------------------------------------------------------------------------- grid measuring


def edge_profiles(a):
    """How much the colour changes between neighbouring columns / rows (premultiplied, so outlines count)."""
    p = a[..., :3] * a[..., 3:4]
    p = np.concatenate([p, a[..., 3:4]], -1)
    ex = np.abs(np.diff(p, axis=1)).sum(-1)   # change between column x and x+1
    ey = np.abs(np.diff(p, axis=0)).sum(-1)
    return ex.sum(0), ey.sum(1)


def grid_score(prof, s, o):
    """Mean edge energy on the predicted cell boundaries, relative to the average."""
    n = len(prof)
    pos = np.round(o + np.arange(int((n - o) / s) + 1) * s - 1).astype(int)
    pos = pos[(pos >= 0) & (pos < n)]
    if len(pos) < 3:
        return 0
    return prof[pos].mean() / (prof.mean() + 1e-9)


def best_phase(prof, s):
    offs = np.arange(0, s, 0.25)
    sc = [grid_score(prof, s, o) for o in offs]
    i = int(np.argmax(sc))
    return offs[i], sc[i]


def measure_px(a, lo=1.5, hi=24):
    """The size of one art pixel in image pixels (may be fractional, e.g. 2.67 for a sheet upscaled by
    an AI model). The cell edges repeat at that period, so it shows as the strongest peak in the
    spectrum of the edge profiles. Both axes are measured and averaged."""
    periods = []
    for prof in edge_profiles(a):
        p = prof - np.convolve(prof, np.ones(15) / 15, "same")
        n = 1 << int(np.ceil(np.log2(len(p) * 8)))   # zero-pad for a finer frequency grid
        F = np.abs(np.fft.rfft(p, n)) ** 2
        fr = np.fft.rfftfreq(n)
        ok = (fr > 1 / hi) & (fr < 1 / lo)
        i = np.nonzero(ok)[0][np.argmax(F[ok])]
        periods.append((1 / fr[i], F[i] / F[ok].mean()))
    return float(np.mean([p for p, _ in periods]))


# ---------------------------------------------------------------------------- finding sprites


def find_sprites(a, grid=None, gap=None):
    """Bounding boxes (y0, y1, x0, x1) of the sprites on the sheet, as rows of frames."""
    m = a[..., 3] > 0.5
    H, W = m.shape
    if grid:
        cols, rows = grid
        out = []
        for r in range(rows):
            row = []
            for c in range(cols):
                y0, y1, x0, x1 = H * r // rows, H * (r + 1) // rows, W * c // cols, W * (c + 1) // cols
                sub = m[y0:y1, x0:x1]
                ys, xs = np.nonzero(sub)
                if len(ys):
                    row.append((y0 + ys.min(), y0 + ys.max() + 1, x0 + xs.min(), x0 + xs.max() + 1))
            if row:
                out.append(row)
        return out
    gap = gap or max(4, int(min(H, W) * 0.006))
    lab, n = ndimage.label(ndimage.binary_dilation(m, iterations=gap))
    boxes = []
    sizes = ndimage.sum(m, lab, range(1, n + 1))
    for i, sl in enumerate(ndimage.find_objects(lab)):
        if sizes[i] < sizes.max() * 0.04:
            continue
        sub = m[sl] & (lab[sl] == i + 1)
        ys, xs = np.nonzero(sub)
        boxes.append((sl[0].start + ys.min(), sl[0].start + ys.max() + 1, sl[1].start + xs.min(), sl[1].start + xs.max() + 1))
    # group into rows: a box joins a row if it overlaps the row's vertical span by half its height
    boxes.sort(key=lambda b: (b[0] + b[1]) / 2)
    rows = []
    for b in boxes:
        cy = (b[0] + b[1]) / 2
        for row in rows:
            ry0 = min(r[0] for r in row)
            ry1 = max(r[1] for r in row)
            if ry0 <= cy <= ry1:
                row.append(b)
                break
        else:
            rows.append([b])
    return [sorted(r, key=lambda b: b[2]) for r in rows]


# ---------------------------------------------------------------------------- resampling


def resample_paint(a, box, f, pad=2, sharpen=0.6):
    """For painted (not pixel-grid) art: shrink a sprite's box by f with an area filter, so every art
    pixel is the average of the paint under it, then sharpen a little so edges stay crisp."""
    from PIL import Image
    y0, y1, x0, x1 = box
    H, W = a.shape[:2]
    y0, x0 = max(0, int(y0 - pad * f)), max(0, int(x0 - pad * f))
    y1, x1 = min(H, int(y1 + pad * f)), min(W, int(x1 + pad * f))
    crop = a[y0:y1, x0:x1].astype(np.float32)
    pm = np.concatenate([crop[..., :3] * crop[..., 3:4], crop[..., 3:4]], -1)
    w, h = max(1, round((x1 - x0) / f)), max(1, round((y1 - y0) / f))
    chans = [np.asarray(Image.fromarray(pm[..., c], "F").resize((w, h), Image.BOX)) for c in range(4)]
    out = np.stack(chans, -1)
    al = out[..., 3:4]
    rgb = np.where(al > 1e-3, out[..., :3] / np.maximum(al, 1e-3), 0)
    if sharpen:
        blur = np.stack([ndimage.gaussian_filter(rgb[..., c], 0.8) for c in range(3)], -1)
        rgb = np.clip(rgb + sharpen * (rgb - blur), 0, 1)
    res = np.zeros((h, w, 4), np.float32)
    solid = al[..., 0] >= 0.5
    res[solid, :3] = rgb[solid]
    res[solid, 3] = 1
    return res


def resample(a, box, s, pad=2):
    """Read one colour per art pixel out of a sprite's box. Returns RGBA float (h, w, 4)."""
    y0, y1, x0, x1 = box
    H, W = a.shape[:2]
    y0, x0 = max(0, int(y0 - pad * s)), max(0, int(x0 - pad * s))
    y1, x1 = min(H, int(y1 + pad * s)), min(W, int(x1 + pad * s))
    crop = a[y0:y1, x0:x1]
    px, py = edge_profiles(crop)
    ox = best_phase(px, s)[0]
    oy = best_phase(py, s)[0]
    nx = int((crop.shape[1] - ox) / s)
    ny = int((crop.shape[0] - oy) / s)
    out = np.zeros((ny, nx, 4), np.float32)
    inner = 0.25   # sample the middle half of each cell
    for j in range(ny):
        ya = int(round(oy + (j + inner) * s))
        yb = max(ya + 1, int(round(oy + (j + 1 - inner) * s)))
        for i in range(nx):
            xa = int(round(ox + (i + inner) * s))
            xb = max(xa + 1, int(round(ox + (i + 1 - inner) * s)))
            cell = crop[ya:yb, xa:xb].reshape(-1, 4)
            if not len(cell):
                continue
            al = cell[:, 3]
            if np.median(al) < 0.5:
                continue
            solid = cell[al >= 0.5]
            out[j, i, :3] = np.median(solid[:, :3], 0)
            out[j, i, 3] = 1
    return out


def drop_orphans(f):
    m = f[..., 3] > 0.5
    nb = ndimage.convolve(m.astype(int), np.array([[0, 1, 0], [1, 0, 1], [0, 1, 0]]), mode="constant")
    f = f.copy()
    f[m & (nb == 0), 3] = 0
    return f


def quantize(frames, k, palette=None):
    """Snap every opaque pixel of every frame to one shared palette."""
    pts = np.concatenate([f[f[..., 3] > 0.5][:, :3] for f in frames])
    if palette is None:
        # small vivid details (a red eye, a glint) are too few pixels to win a k-means cluster, so
        # anything the main palette can't come close to gets a few accent colours of its own
        lab = pk.rgb2lab(pts)
        n_acc = min(4, max(1, k // 8))
        cent, _ = pk.kmeans(lab, k - n_acc)
        d = np.sqrt(((lab[:, None] - cent[None]) ** 2).sum(-1).min(1))
        far = lab[d > 0.07]
        if len(far) >= 3:
            acc, alab = pk.kmeans(far, n_acc)
            acc = acc[np.bincount(alab, minlength=len(acc)) >= 2]
            cent = np.concatenate([cent, acc])
        palette = np.clip(pk.lab2rgb(cent), 0, 1)
        palette = (palette * 255).round() / 255
    # sort the palette dark → light so the swatch strip reads well
    palette = palette[np.argsort(pk.rgb2lab(palette)[:, 0])]
    out = []
    for f in frames:
        g = f.copy()
        m = g[..., 3] > 0.5
        if m.any():
            g[m, :3] = palette[pk.nearest(g[m][:, :3], palette)]
        g[~m] = 0
        out.append(g)
    return out, palette


# ---------------------------------------------------------------------------- framing


def align_row(frames):
    """Horizontal offsets that line each frame up with the first one (feet on the same baseline)."""
    def bottom_mask(f):
        m = f[..., 3] > 0.5
        ys = np.nonzero(m.any(1))[0]
        return m[: ys.max() + 1] if len(ys) else m
    ref = bottom_mask(frames[0])
    offs = [0]
    for f in frames[1:]:
        cur = bottom_mask(f)
        h = min(len(ref), len(cur))
        r, c = ref[-h:].astype(float), cur[-h:].astype(float)
        best, bo = -1, 0
        for d in range(-c.shape[1], r.shape[1]):
            # overlap of cur shifted right by d with ref
            a0, a1 = max(0, d), min(r.shape[1], d + c.shape[1])
            if a1 <= a0:
                continue
            ov = (r[:, a0:a1] * c[:, a0 - d:a1 - d]).sum()
            if ov > best:
                best, bo = ov, d
        offs.append(bo)
    return offs


def frame_row(frames, size, anchor):
    """Place a row's frames on fixed-size canvases, lined up, feet on the anchor."""
    fw, fh = size
    ax, ay = anchor
    offs = align_row(frames)
    # the row's combined extent decides where the anchor goes
    lefts = [o for o in offs]
    rights = [o + f.shape[1] for o, f in zip(offs, frames)]
    cx = (min(lefts) + max(rights)) / 2
    out, clipped = [], False
    for f, o in zip(frames, offs):
        m = f[..., 3] > 0.5
        ys = np.nonzero(m.any(1))[0]
        bottom = ys.max() + 1 if len(ys) else f.shape[0]
        canvas = np.zeros((fh, fw, 4), np.float32)
        dx = int(round(ax - cx + o))
        dy = ay - bottom
        for y in range(f.shape[0]):
            ty = y + dy
            if not 0 <= ty < fh:
                if m[y].any():
                    clipped = True
                continue
            for x0 in (0,):
                xa, xb = max(0, dx), min(fw, dx + f.shape[1])
                if xb > xa:
                    canvas[ty, xa:xb] = f[y, xa - dx:xb - dx]
                if (m[y, : max(0, -dx)].any()) or (m[y, max(0, fw - dx):].any()):
                    clipped = True
        out.append(canvas)
    return out, clipped


def checker(h, w, cell=8):
    yy, xx = np.mgrid[:h, :w]
    c = np.where(((yy // cell) + (xx // cell)) % 2 == 0, 0.20, 0.25)
    return np.stack([c, c, c + 0.02, np.ones_like(c)], -1).astype(np.float32)


def over(dst, src):
    a = src[..., 3:4]
    dst[..., :3] = src[..., :3] * a + dst[..., :3] * (1 - a)
    return dst


def preview(rows, path, scale=4, pad=4):
    fh, fw = rows[0][0].shape[:2]
    ncol = max(len(r) for r in rows)
    H = len(rows) * (fh + pad) + pad
    W = ncol * (fw + pad) + pad
    sheet = np.zeros((H, W, 4), np.float32)
    sheet[..., 3] = 1
    sheet[..., :3] = 0.12
    for r, row in enumerate(rows):
        for c, f in enumerate(row):
            y, x = pad + r * (fh + pad), pad + c * (fw + pad)
            sheet[y:y + fh, x:x + fw] = over(checker(fh, fw, 4), f)
    big = np.repeat(np.repeat(sheet, scale, 0), scale, 1)
    pk.save(big, path)


# ---------------------------------------------------------------------------- main


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("out")
    ap.add_argument("--colors", type=int, default=32, help="palette size when no --palette is given")
    ap.add_argument("--palette", help="snap to this palette instead (.hex/.txt list, .json list or a swatch .png)")
    ap.add_argument("--px", default="auto", help="size of one art pixel in the sheet, e.g. 4 or 4.15 (auto measures it); "
                    "'paint' for painted art with no pixel grid (it is shrunk with an area filter instead)")
    ap.add_argument("--width", type=int, help="make the first frame of the first row this many art pixels wide "
                    "(to match a monster's current size) instead of --scale")
    ap.add_argument("--rows", help="only these rows of the sheet, e.g. 0 or 1,3 (counted from 0, top to bottom)")
    ap.add_argument("--scale", default="fit", help="shrink the art: 2 reads one pixel per 2x2 art pixels; 'fit' (default) "
                    "shrinks only as much as needed to fit the frame; 1 keeps the sheet's own resolution")
    ap.add_argument("--grid", help="COLSxROWS: split the sheet evenly instead of finding sprites automatically")
    ap.add_argument("--frame", default="88x72", help="output frame size WxH, or 'tight' to crop each frame")
    ap.add_argument("--anchor", default="44,66", help="where the feet go in each frame (x,y)")
    ap.add_argument("--bg", default="auto", help="background to remove: auto, none, or #rrggbb[,#rrggbb]")
    ap.add_argument("--names", help="comma-separated names for the rows, top to bottom")
    ap.add_argument("--keep-orphans", action="store_true", help="keep isolated single pixels")
    args = ap.parse_args()

    a, bgs = key_background(pk.load(args.sheet), args.bg)
    grid = tuple(int(v) for v in args.grid.lower().split("x")) if args.grid else None
    rows = find_sprites(a, grid)
    if not rows:
        sys.exit("no sprites found (is the background removed? try --bg)")
    if args.rows:
        rows = [rows[int(i)] for i in args.rows.split(",")]
    paint = args.px == "paint"
    s = 1.0 if paint else measure_px(a) if args.px == "auto" else float(args.px)
    if args.width:
        b = rows[0][0]
        scale = max(1.0, (b[3] - b[2]) / s / args.width)
    elif args.scale == "fit":
        scale = 1.0
        if args.frame != "tight":
            fw, fh = (int(v) for v in args.frame.lower().split("x"))
            ax, ay = (int(v) for v in args.anchor.split(","))
            room_w, room_h = fw - 2, ay - 1
            for row in rows:
                for b in row:
                    scale = max(scale, (b[3] - b[2]) / s / room_w, (b[1] - b[0]) / s / room_h)
            scale *= 1.02   # the grid snap can add a pixel
    else:
        scale = float(args.scale)
    args.scale = round(scale, 3)
    s_used = s * scale
    print("art pixel = %.2f image pixels%s; %d rows: %s" % (s, " (shrunk %.2fx)" % scale if scale != 1 else "",
                                                          len(rows), ", ".join(str(len(r)) for r in rows)))

    low = [[(resample_paint(a, b, s_used) if paint else resample(a, b, s_used)) for b in row] for row in rows]
    low = [[defringe(f, bgs) for f in row] for row in low]
    if not args.keep_orphans:
        low = [[drop_orphans(f) for f in row] for row in low]
    flat, pal = quantize([f for row in low for f in row], args.colors,
                         pk.load_palette(args.palette) if args.palette else None)
    it = iter(flat)
    low = [[next(it) for _ in row] for row in low]

    names = args.names.split(",") if args.names else ["row%d" % i for i in range(len(low))]
    names += ["row%d" % i for i in range(len(names), len(low))]
    os.makedirs(args.out, exist_ok=True)
    report = {"source": os.path.basename(args.sheet), "art_pixel": round(float(s), 3), "scale": args.scale,
              "palette": [pk.hexcol(c) for c in pal], "rows": {}}
    framed_rows = []
    for name, row in zip(names, low):
        if args.frame == "tight":
            framed = row
            clipped = False
        else:
            fw, fh = (int(v) for v in args.frame.lower().split("x"))
            ax, ay = (int(v) for v in args.anchor.split(","))
            framed, clipped = frame_row(row, (fw, fh), (ax, ay))
        if clipped:
            print("  warning: %s doesn't fit in %s; try --scale 1.25 (or bigger) to shrink it" % (name, args.frame))
        for i, f in enumerate(framed):
            pk.save(f, os.path.join(args.out, "%s_%d.png" % (name, i)))
        if args.frame != "tight":
            pk.save(pk.strip(framed), os.path.join(args.out, name + ".png"))
        sizes = [list(f.shape[1::-1]) for f in row]
        report["rows"][name] = {"frames": len(row), "art_sizes": sizes, "clipped": clipped}
        framed_rows.append(framed)
        print("  %s: %d frames, art %s" % (name, len(row), " ".join("%dx%d" % tuple(z) for z in sizes)))
    pk.palette_strip(pal, os.path.join(args.out, "palette.png"))
    if args.frame != "tight":
        preview(framed_rows, os.path.join(args.out, "preview.png"))
    json.dump(report, open(os.path.join(args.out, "clean.json"), "w"), indent=1)
    print("palette: %d colours -> %s" % (len(pal), os.path.join(args.out, "palette.png")))


if __name__ == "__main__":
    main()
