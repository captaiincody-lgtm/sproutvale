"""A small procedural painter for detailed creature sprites.

Creatures are built from body parts (ellipses, polygons, tapered limbs, rows of bristles). Each part
is painted at K times the final resolution with:
  * form shading: the part's own roundness, lit from the upper left, through a hue-shifted colour ramp
  * fur: streaky noise running along the part's fur direction, plus tufted, uneven edges
  * a dark contour wherever it overlaps something already painted (the inked look)
  * optional colour zones (a cream belly, a darker back) blended by a second shape or a gradient
The finished picture is shrunk with an area filter to the real pixel grid; then small crisp details
(eyes, glints, tusks, whiskers) are placed pixel by pixel, the set is locked to one palette, and a
1-pixel outline goes round the silhouette.

All coordinates are given in final (game) pixels; the painter multiplies by K itself.
"""
import numpy as np
from PIL import Image, ImageDraw
from scipy import ndimage

import pixelkit as pk

LIGHT = np.array([-0.5, -0.75, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)

# lum 0..1 → ramp level
_LV = [(-3, 0.0), (-2, 0.2), (-1, 0.42), (0, 0.62), (1, 0.8), (2, 1.0)]


def hexrgb(h):
    return pk.parse_hex(h)


def ramp_fn(base, dark=None):
    """Colour as a function of light (0..1) for one material, hue-shifted like pk.ramp. `dark`
    optionally overrides the deepest shade."""
    r = pk.ramp(hexrgb(base) if isinstance(base, str) else np.asarray(base))
    if dark is not None:
        r[-3] = hexrgb(dark)
    lv = np.array([p for _, p in _LV])
    cols = np.array([r[k] for k, _ in _LV])

    def f(lum):
        lum = np.clip(lum, 0, 1)
        out = np.empty(lum.shape + (3,))
        for c in range(3):
            out[..., c] = np.interp(lum, lv, cols[:, c])
        return out
    return f


class Painter:
    def __init__(self, w=88, h=72, K=4, seed=1):
        self.w, self.h, self.K = w, h, K
        self.W, self.H = w * K, h * K
        self.rgb = np.zeros((self.H, self.W, 3))
        self.a = np.zeros((self.H, self.W), bool)
        self.rng = np.random.default_rng(seed)
        self._noise = np.random.default_rng(seed + 99).standard_normal((96, 96))
        self._noise2 = np.random.default_rng(seed + 7).standard_normal((48, 48))
        self.decals = []
        yy, xx = np.mgrid[:self.H, :self.W]
        self.yy, self.xx = yy.astype(np.float32), xx.astype(np.float32)

    # ---------------------------------------------------------------- masks

    def _img(self):
        im = Image.new("L", (self.W, self.H), 0)
        return im, ImageDraw.Draw(im)

    def _s(self, pts):
        K = self.K
        return [(x * K, y * K) for x, y in pts]

    def ellipse(self, cx, cy, rx, ry, ang=0.0):
        K = self.K
        t = np.radians(ang)
        u = ((self.xx - cx * K) * np.cos(t) + (self.yy - cy * K) * np.sin(t)) / (rx * K)
        v = (-(self.xx - cx * K) * np.sin(t) + (self.yy - cy * K) * np.cos(t)) / (ry * K)
        return u * u + v * v <= 1.0

    def poly(self, pts):
        im, d = self._img()
        d.polygon(self._s(pts), fill=255)
        return np.asarray(im) > 127

    def limb(self, pts, radii):
        """A tapered tube through pts, radius changing linearly between the given radii."""
        im, d = self._img()
        K = self.K
        pts = np.asarray(pts, float)
        radii = np.asarray(radii, float)
        for i in range(len(pts) - 1):
            p0, p1 = pts[i], pts[i + 1]
            n = max(2, int(np.hypot(*(p1 - p0)) * K / 1.5))
            for t in np.linspace(0, 1, n):
                p = p0 + (p1 - p0) * t
                r = (radii[i] + (radii[i + 1] - radii[i]) * t) * K
                d.ellipse([p[0] * K - r, p[1] * K - r, p[0] * K + r, p[1] * K + r], fill=255)
        return np.asarray(im) > 127

    def spikes(self, path, count, length, width, lean=0.0, jitter=0.3, side=-1):
        """Bristles growing out of a curve (path: list of points), on the given side (-1 = left of the
        direction of travel, which is 'up' for a path drawn tail to head)."""
        path = np.asarray(path, float)
        seg = np.diff(path, axis=0)
        cum = np.concatenate([[0], np.cumsum(np.hypot(seg[:, 0], seg[:, 1]))])
        im, d = self._img()
        rng = self.rng
        for i in range(count):
            s = (i + 0.5) / count * cum[-1]
            j = min(np.searchsorted(cum, s) - 1, len(seg) - 1)
            j = max(j, 0)
            t = (s - cum[j]) / max(cum[j + 1] - cum[j], 1e-6)
            p = path[j] + seg[j] * t
            dvec = seg[j] / max(np.hypot(*seg[j]), 1e-6)
            nrm = np.array([dvec[1], -dvec[0]]) * -side
            L = (length(s / cum[-1]) if callable(length) else length) * (1 + rng.uniform(-jitter, jitter))
            wd = (width(s / cum[-1]) if callable(width) else width)
            tip = p + nrm * L + dvec * (L * lean + rng.uniform(-jitter, jitter) * L * 0.5)
            a = p - dvec * wd / 2
            b = p + dvec * wd / 2
            d.polygon(self._s([a, tip, b]), fill=255)
        return np.asarray(im) > 127

    # ---------------------------------------------------------------- noise

    def streaks(self, ang, along=7.0, across=1.2, which=0):
        """Fur noise: smooth along `ang` (degrees), busy across it. Values roughly -1..1."""
        K = self.K
        t = np.radians(ang)
        u = self.xx * np.cos(t) + self.yy * np.sin(t)
        v = -self.xx * np.sin(t) + self.yy * np.cos(t)
        src = self._noise if which == 0 else self._noise2
        n = ndimage.map_coordinates(src, [(v / (across * K)) % src.shape[0], (u / (along * K)) % src.shape[1]],
                                    order=1, mode="wrap")
        return np.clip(n / 1.4, -1, 1)

    # ---------------------------------------------------------------- painting

    def part(self, mask, ramp, R=4.0, fur=None, fuzz=0.0, shade=0.0, zone=None, contour=True,
             contour_dark=0.45, flat=False, lum_bias=0.0, gloss=0.0, ao=None, contrast=1.8):
        """Paint one part.
        ramp: ramp_fn(...) for its colour. R: how many pixels in from the edge it is fully round.
        fur: (angle, strength) for fur streaks. fuzz: tufted edge depth in pixels (uses the fur angle).
        shade: darken this much (0..1), for far-side limbs. zone: (mask_or_weights, ramp) to blend a
        second colour in (weights 0..1). contour: ink a dark line where it overlaps earlier paint."""
        K = self.K
        if not mask.any():
            return mask
        if fuzz and fur:
            sd = ndimage.distance_transform_edt(~mask) - ndimage.distance_transform_edt(mask)
            nz = self.streaks(fur[0], along=2.2, across=0.9, which=1)
            mask = (sd + fuzz * K * (nz * 0.8 + 0.2)) < 0
        inside = ndimage.distance_transform_edt(np.pad(mask, 1))[1:-1, 1:-1]
        r = R * K
        tt = np.clip(inside / r, 0, 1)
        h = r * np.sqrt(1 - (1 - tt) ** 2)
        h = ndimage.gaussian_filter(h, K * 0.5)
        gy, gx = np.gradient(h)
        nz_ = np.full_like(h, 1.0)
        n = np.stack([-gx, -gy, nz_], -1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        dot = n @ LIGHT
        lum = 0.62 + (dot - LIGHT[2]) * contrast + lum_bias
        if ao is not None:   # (y_top, y_bottom): darken towards the bottom of this span
            y0, y1 = ao
            lum = lum - 0.28 * np.clip((self.yy - y0 * K) / ((y1 - y0) * K), 0, 1) ** 1.5
        if flat:
            lum = np.full_like(lum, 0.62 + lum_bias)
        if fur:
            lum = lum + fur[1] * (0.13 * self.streaks(fur[0], along=3.0, across=0.75)
                                  + 0.07 * self.streaks(fur[0] + 25, along=1.5, across=0.6, which=1))
        if gloss:
            lum = lum + gloss * np.clip((dot - 0.9) * 8, 0, 1)
        lum = lum - shade
        col = ramp(lum)
        zones = [] if zone is None else zone if isinstance(zone, list) else [zone]
        for zw, zramp in zones:
            zw = zw.astype(float)
            zw = ndimage.gaussian_filter(zw, K * 1.2)
            if fur:   # zones meet along a ragged, furry line
                zw = np.clip(zw + 0.6 * self.streaks(fur[0], along=1.6, across=0.6, which=1) * (zw * (1 - zw) * 4), 0, 1)
            zw = (zw > 0.5).astype(float) * 0.85 + zw * 0.15
            col = col * (1 - zw[..., None]) + zramp(lum) * zw[..., None]
        if contour:
            ring = mask & ~ndimage.binary_erosion(mask, iterations=max(1, int(K * 0.9)))
            over = ring & self.a
            col = np.where(over[..., None], ramp(np.full(lum.shape, contour_dark * 0.3)) * 0.7, col)
        self.rgb[mask] = col[mask]
        self.a |= mask
        return mask

    # ---------------------------------------------------------------- crisp details at final resolution

    def px(self, x, y, colour):
        self.decals.append((int(round(x)), int(round(y)), colour))

    def pxs(self, pts, colour):
        for x, y in pts:
            self.px(x, y, colour)

    # ---------------------------------------------------------------- output

    def render(self):
        """Shrink to the final grid. Returns RGBA float (h, w, 4) without the decals."""
        K = self.K
        a = self.a.astype(np.float32)
        pm = self.rgb * a[..., None]
        sm = pm.reshape(self.h, K, self.w, K, 3).mean((1, 3))
        al = a.reshape(self.h, K, self.w, K).mean((1, 3))
        rgb = np.where(al[..., None] > 1e-3, sm / np.maximum(al[..., None], 1e-3), 0)
        blur = np.stack([ndimage.gaussian_filter(rgb[..., c], 0.7) for c in range(3)], -1)
        rgb = np.clip(rgb + 0.45 * (rgb - blur), 0, 1)
        out = np.zeros((self.h, self.w, 4), np.float32)
        solid = al >= 0.45
        out[solid, :3] = rgb[solid]
        out[solid, 3] = 1
        return out

    def apply_decals(self, arr):
        for x, y, c in self.decals:
            if 0 <= x < self.w and 0 <= y < self.h:
                arr[y, x, :3] = hexrgb(c) if isinstance(c, str) else c
                arr[y, x, 3] = 1
        return arr


def outline(arr, colour, inner_dark=None):
    """1-pixel outline round the silhouette (4-neighbour), in the given colour."""
    m = arr[..., 3] > 0.5
    ring = ndimage.binary_dilation(m, structure=ndimage.generate_binary_structure(2, 1)) & ~m
    out = arr.copy()
    out[ring, :3] = hexrgb(colour)
    out[ring, 3] = 1
    return out


def lock_palette(frames, k=32, protect=()):
    """One shared palette for a whole set of frames (k-means in OKLab); colours listed in `protect`
    (decal colours) are kept exactly."""
    pts = np.concatenate([f[f[..., 3] > 0.5][:, :3] for f in frames])
    prot = np.array([hexrgb(c) for c in protect]) if protect else np.zeros((0, 3))
    if len(prot):
        d = np.abs(pts[:, None] - prot[None]).max(-1).min(1)
        pts = pts[d > 0.01]
    sub = pts[np.random.default_rng(3).choice(len(pts), min(len(pts), 20000), replace=False)]
    cent, _ = pk.kmeans(pk.rgb2lab(sub), k - len(prot))
    pal = np.clip(pk.lab2rgb(cent), 0, 1)
    pal = np.concatenate([pal, prot]) if len(prot) else pal
    pal = (pal * 255).round() / 255
    out = []
    for f in frames:
        g = f.copy()
        m = g[..., 3] > 0.5
        g[m, :3] = pal[pk.nearest(g[m][:, :3], pal)]
        g[~m] = 0
        out.append(g)
    return out, pal
