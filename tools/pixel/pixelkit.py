"""Shared helpers for the pixel-art tools in this folder (Pillow + NumPy + SciPy only).

Colours are handled as float arrays in 0..1. Perceptual work (k-means, nearest colour, ramps) is done
in OKLab, which keeps hue shifts and lightness steps even across the palette.
"""
import json
import os

import numpy as np
from PIL import Image
from scipy import ndimage

# ---------------------------------------------------------------------------- io


def load(path):
    """RGBA float array (H, W, 4) in 0..1."""
    return np.asarray(Image.open(path).convert("RGBA")).astype(np.float32) / 255.0


def save(arr, path):
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    a = np.clip(arr * 255.0 + 0.5, 0, 255).astype(np.uint8)
    Image.fromarray(a, "RGBA").save(path, optimize=True)


def hexcol(c):
    c = np.clip(np.asarray(c[:3]) * 255 + 0.5, 0, 255).astype(int)
    return "#%02x%02x%02x" % tuple(c)


def parse_hex(s):
    s = s.strip().lstrip("#")
    return np.array([int(s[i:i + 2], 16) for i in (0, 2, 4)], np.float32) / 255.0


# ---------------------------------------------------------------------------- colour spaces


def _lin(c):
    return np.where(c <= 0.04045, c / 12.92, ((c + 0.055) / 1.055) ** 2.4)


def _gam(c):
    c = np.clip(c, 0, 1)
    return np.where(c <= 0.0031308, c * 12.92, 1.055 * c ** (1 / 2.4) - 0.055)


def rgb2lab(rgb):
    """sRGB (…, 3) → OKLab (…, 3)."""
    r, g, b = np.moveaxis(_lin(np.asarray(rgb, np.float64)), -1, 0)
    l = 0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b
    m = 0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b
    s = 0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b
    l, m, s = np.cbrt(l), np.cbrt(m), np.cbrt(s)
    return np.stack([0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
                     1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
                     0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s], -1)


def lab2rgb(lab):
    L, a, b = np.moveaxis(np.asarray(lab, np.float64), -1, 0)
    l = (L + 0.3963377774 * a + 0.2158037573 * b) ** 3
    m = (L - 0.1055613458 * a - 0.0638541728 * b) ** 3
    s = (L - 0.0894841775 * a - 1.2914855480 * b) ** 3
    return _gam(np.stack([4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s,
                          -1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s,
                          -0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s], -1))


def lab2lch(lab):
    L, a, b = np.moveaxis(lab, -1, 0)
    return np.stack([L, np.hypot(a, b), np.arctan2(b, a)], -1)


def lch2lab(lch):
    L, C, h = np.moveaxis(lch, -1, 0)
    return np.stack([L, C * np.cos(h), C * np.sin(h)], -1)


# ---------------------------------------------------------------------------- palettes


def kmeans(points, k, iters=40, seed=7):
    """Plain k-means with k-means++ seeding. points (N, D) → (centres (k, D), labels (N,))."""
    rng = np.random.default_rng(seed)
    n = len(points)
    k = min(k, len(np.unique(points, axis=0)))
    cent = [points[rng.integers(n)]]
    d2 = ((points - cent[0]) ** 2).sum(1)
    for _ in range(1, k):
        p = d2 / d2.sum() if d2.sum() > 0 else None
        cent.append(points[rng.choice(n, p=p)])
        d2 = np.minimum(d2, ((points - cent[-1]) ** 2).sum(1))
    cent = np.array(cent)
    lab = np.zeros(n, int)
    for _ in range(iters):
        dist = ((points[:, None, :] - cent[None]) ** 2).sum(-1)
        new = dist.argmin(1)
        if _ and (new == lab).all():
            break
        lab = new
        for j in range(k):
            sel = points[lab == j]
            if len(sel):
                cent[j] = sel.mean(0)
    return cent, lab


def nearest(rgb, palette_rgb):
    """Index of the nearest palette colour (OKLab distance) for every colour in rgb (…, 3)."""
    flat = rgb.reshape(-1, 3)
    pl = rgb2lab(palette_rgb)
    out = np.empty(len(flat), int)
    for i in range(0, len(flat), 65536):
        q = rgb2lab(flat[i:i + 65536])
        out[i:i + 65536] = ((q[:, None, :] - pl[None]) ** 2).sum(-1).argmin(1)
    return out.reshape(rgb.shape[:-1])


def load_palette(spec):
    """A palette from a .hex/.txt list (one #rrggbb per line, the Lospec format), a .json list, or a PNG
    (every distinct opaque colour, e.g. a Lospec 1x swatch strip)."""
    if spec.endswith(".png"):
        a = load(spec)
        return np.unique(a[a[..., 3] > 0.5][:, :3].round(4), axis=0)
    if spec.endswith(".json"):
        return np.array([parse_hex(h) for h in json.load(open(spec))])
    return np.array([parse_hex(l) for l in open(spec) if l.strip() and not l.startswith(";")])


def palette_strip(palette_rgb, path, cell=8):
    n = len(palette_rgb)
    a = np.ones((cell, cell * n, 4), np.float32)
    for i, c in enumerate(palette_rgb):
        a[:, i * cell:(i + 1) * cell, :3] = c
    save(a, path)


# ---------------------------------------------------------------------------- ramps (hue-shifted shading)

# lightness step, chroma scale and hue shift (radians, towards cool for shadows, warm for lights)
# for each shade level, relative to the base colour
RAMP = {-3: (-0.30, 0.95, 0.26), -2: (-0.19, 1.05, 0.17), -1: (-0.095, 1.06, 0.08),
        0: (0.0, 1.0, 0.0), 1: (0.075, 0.9, -0.06), 2: (0.15, 0.7, -0.10)}
COOL = np.arctan2(-0.12, -0.03)   # OKLab hue of a blue-violet
WARM = np.arctan2(0.12, 0.02)     # OKLab hue of a warm yellow


def _toward(h, target, amt):
    d = (target - h + np.pi) % (2 * np.pi) - np.pi
    return h + np.clip(d, -abs(amt), abs(amt))


def ramp(rgb):
    """{level: rgb} for one base colour: darker levels cooler and a little richer, lighter levels warmer
    and paler, the way pixel artists hue-shift by hand."""
    L, C, h = lab2lch(rgb2lab(np.asarray(rgb, np.float64)))
    out = {}
    for lv, (dl, cs, dh) in RAMP.items():
        L2 = np.clip(L + dl * (1.0 if dl < 0 else (1 - L) * 2.2 if L > 0.55 else 1.0), 0.08, 0.98)
        tgt = COOL if dh > 0 else WARM
        h2 = _toward(h, tgt, abs(dh)) if C > 0.02 else h
        C2 = C * cs + (0.012 * -lv if lv < 0 and C < 0.03 else 0)   # greys pick up a little cool tint
        if lv < 0 and C < 0.03:
            h2 = COOL
        out[lv] = np.clip(lab2rgb(lch2lab(np.array([L2, C2, h2]))), 0, 1)
    return out


# ---------------------------------------------------------------------------- variants (ported from the prototype)


def _rgb2hsl(rgb):
    r, g, b = np.moveaxis(rgb, -1, 0)
    mx, mn = rgb.max(-1), rgb.min(-1)
    l = (mx + mn) / 2
    d = mx - mn
    s = np.where(d > 0.01, np.where(l > 0.5, d / np.maximum(2 - mx - mn, 1e-6), d / np.maximum(mx + mn, 1e-6)), 0)
    dd = np.maximum(d, 1e-6)
    h = np.where(mx == r, (g - b) / dd + np.where(g < b, 6, 0), np.where(mx == g, (b - r) / dd + 2, (r - g) / dd + 4)) / 6
    h = np.where(d > 0.01, h, 0)
    return h, s, l, d


def _hsl2rgb(h, s, l):
    q = np.where(l < 0.5, l * (1 + s), l + s - l * s)
    p = 2 * l - q

    def hue(t):
        t = t % 1
        return np.where(t < 1 / 6, p + (q - p) * 6 * t, np.where(t < 0.5, q, np.where(t < 2 / 3, p + (q - p) * (2 / 3 - t) * 6, p)))
    return np.stack([hue(h + 1 / 3), hue(h), hue(h - 1 / 3)], -1)


def shiny(arr, shift=0.42):
    """The prototype's shiny recolour: rotate hue, lift saturation, leave dark outlines alone."""
    out = arr.copy()
    h, s, l, d = _rgb2hsl(arr[..., :3])
    grey = d <= 0.01
    s = np.where(grey, 0.35, s)
    h = np.where(grey, 0.14, h)
    h = (h + shift) % 1
    s = np.minimum(1, s * 1.35 + 0.1)
    L = np.minimum(0.92, l * 1.07)
    rgb = _hsl2rgb(h, s, L)
    m = (arr[..., 3] > 0.04) & (l >= 0.16)
    out[..., :3] = np.where(m[..., None], rgb, arr[..., :3])
    return out


def elite(arr):
    """The prototype's elite tint: near-black, keeping a trace of the colour and any bright eyes."""
    out = arr.copy()
    r, g, b = arr[..., 0] * 255, arr[..., 1] * 255, arr[..., 2] * 255
    l = (r + g + b) / 765
    m = (arr[..., 3] > 0.04) & (l <= 0.9)
    new = np.stack([r * 0.22 + 18 + l * 30, g * 0.12 + 8, b * 0.22 + 30 + l * 40], -1) / 255
    out[..., :3] = np.where(m[..., None], np.clip(new, 0, 1), arr[..., :3])
    return out


def white(arr):
    out = arr.copy()
    out[..., :3] = 1.0
    return out


# ---------------------------------------------------------------------------- misc


def components(mask, connectivity=1):
    st = ndimage.generate_binary_structure(2, connectivity)
    return ndimage.label(mask, structure=st)


def strip(frames):
    return np.concatenate(frames, axis=1)


def unstrip(arr, w):
    return [arr[:, i * w:(i + 1) * w] for i in range(arr.shape[1] // w)]
