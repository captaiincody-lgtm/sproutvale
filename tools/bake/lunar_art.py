"""Paints the art for the Lunar quest line and the neighborhood the heroes build after the ending.

    art/maps/home_village.png     the home map after the ending: all five houses side by side (cut out of
                                  each hero's own home map and Tank's house sprite), on the old meadow ground
    art/maps/moon1.png            the Moon's landing site: grey dust, craters, boulders to jump on
    art/sky/moon_far.png          distant crater rims (parallax, tiles every 1536 px)
    art/sky/moon_mid.png          nearer ridges (parallax)
    art/maps/house_<hero>_night.png  each house inside, with the windows showing the blood-red night
    art/items/luna_coin.png       a Luna Coin (9x9), the Abyssal Coin in cyan

Everything is drawn at 2x like the rest of the maps (one world unit = 2 px). Re-run it only if the home
maps change; it overwrites the files above (so a hand-painted replacement would be lost).

Usage:  python3 tools/bake/lunar_art.py
Needs:  Pillow and numpy.
"""
import os

import numpy as np
from PIL import Image, ImageDraw

ART = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..", "godot", "art")

# must match scripts/lunar.gd: VILLAGE (house centres, world units) and VILLAGE_W
VILLAGE = {"rock": 300, "archer": 650, "mage": 1030, "summoner": 1410, "tank": 1750}
VILLAGE_W = 2340
# where each house sits in its own 2200x600 home map: [left, right] (it's centred on x=940 px)
SRC = {"rock": (760, 1120), "archer": (740, 1150), "mage": (640, 1250), "summoner": (740, 1130)}
FLOOR = 520   # the ground line in the home maps, in px


def p(*a):
    return os.path.join(ART, *a)


def village():
    base = Image.open(p("maps", "home_tank.png")).convert("RGBA")
    W = VILLAGE_W * 2
    out = Image.new("RGBA", (W, 600), (0, 0, 0, 0))
    x = 0
    while x < W:
        out.alpha_composite(base, (x, 0))
        x += base.width
    # clear the trees where the houses will stand, so no trunk pokes through a wall
    a = np.asarray(out).copy()
    for h, cx in VILLAGE.items():
        x0, x1 = SRC.get(h, (780, 1100))
        L = cx * 2 + (x0 - 940) + 10
        R = cx * 2 + (x1 - 940) - 10
        a[: FLOOR - 4, max(0, L):R] = 0
    out = Image.fromarray(a, "RGBA")
    for h, cx in VILLAGE.items():
        if h == "tank":
            house = Image.open(p("tank", "house.png")).convert("RGBA")
            out.alpha_composite(house, (cx * 2 - house.width // 2, FLOOR + 4 - house.height))
            continue
        x0, x1 = SRC[h]
        src = Image.open(p("maps", "home_%s.png" % h)).convert("RGBA").crop((x0, 0, x1, FLOOR + 6))
        out.alpha_composite(src, (cx * 2 + (x0 - 940), 0))
    out.save(p("maps", "home_village.png"))


# ---------------------------------------------------------------- the Moon
rng = np.random.default_rng(7)


def moon_ground():
    W, H = 2800, 880
    fl = 800
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    # the rim of a great dark crater at the far end, behind everything
    d.ellipse((2300, fl - 150, 3300, fl + 150), fill=(70, 68, 84, 255))
    d.ellipse((2340, fl - 126, 3260, fl + 130), fill=(12, 10, 18, 255))
    # the ground: dusty grey, darker as it goes down
    for y in range(fl, H):
        k = (y - fl) / (H - fl)
        c = tuple(int(v) for v in np.array([150, 148, 156]) * (1 - k) + np.array([74, 72, 84]) * k)
        d.line((0, y, W, y), fill=c + (255,))
    d.line((0, fl, W, fl), fill=(206, 204, 214, 255), width=2)
    d.line((0, fl + 2, W, fl + 2), fill=(176, 174, 184, 255), width=2)
    # craters in the ground's face
    for i in range(26):
        cx = int(rng.uniform(20, 2780))
        cy = int(rng.uniform(fl + 14, H - 10))
        r = int(rng.uniform(8, 26) * (0.6 + (cy - fl) / (H - fl)))
        d.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), fill=(96, 94, 106, 255))
        d.ellipse((cx - r + 3, cy - r // 2 + 2, cx + r - 3, cy + r // 2), fill=(118, 116, 128, 255))
        d.arc((cx - r, cy - r // 2, cx + r, cy + r // 2), 200, 340, fill=(60, 58, 70, 255), width=2)
    # pebbles and dust on top of the surface
    for i in range(260):
        x = int(rng.uniform(0, W))
        y = int(rng.uniform(fl + 4, H))
        s = int(rng.choice([2, 2, 2, 4]))
        c = int(rng.uniform(90, 190))
        d.rectangle((x, y, x + s - 1, y + s - 1), fill=(c, c - 2, c + 8, 255))
    for i in range(70):   # rocks resting on the surface
        x = int(rng.uniform(10, W - 10))
        w = int(rng.choice([4, 6, 8, 10]))
        d.rectangle((x, fl - w // 2, x + w, fl), fill=(120, 118, 130, 255))
        d.rectangle((x, fl - w // 2, x + w, fl - w // 2 + 1), fill=(190, 188, 200, 255))
    # boulders to jump on (must match the platforms of moon1 in scripts/lunar.gd)
    for (bx, by, bw) in [(520, 330, 70), (700, 290, 90), (900, 320, 60), (1060, 266, 80), (1240, 320, 70)]:
        X0, X1, Y0 = bx * 2, (bx + bw) * 2, by * 2
        hgt = fl - Y0
        spread = 30 + hgt * 0.35
        # a lumpy rock mound: a flat top you can stand on, sides that bulge and widen to the ground
        pts = [(X0, Y0)]
        pts += [(X1 - k * 6, Y0 + int(rng.uniform(-2, 2))) for k in range(0)]
        pts.append((X1, Y0))
        for k in range(1, 7):
            u = k / 6
            pts.append((X1 + spread * u ** 1.6 + rng.uniform(-6, 6), Y0 + hgt * u))
        for k in range(6, 0, -1):
            u = k / 6
            pts.append((X0 - spread * u ** 1.6 + rng.uniform(-6, 6), Y0 + hgt * u))
        d.polygon(pts, fill=(112, 110, 124, 255))
        d.polygon([(X0 + 16, Y0 + 18), (X1 - 6, Y0 + 18), (X1 + spread * 0.7, fl), (X0 - spread * 0.2, fl)], fill=(96, 94, 108, 255))
        d.line([(X0 - 2, Y0 + 3), (X0 + 6, Y0), (X1 - 6, Y0), (X1 + 2, Y0 + 3)], fill=(204, 202, 214, 255), width=4)
        for k in range(7):
            cx = int(rng.uniform(X0, X1 + spread * 0.5))
            cy = int(rng.uniform(Y0 + 24, fl - 14))
            r = int(rng.uniform(4, 9))
            d.ellipse((cx - r, cy - r // 2, cx + r, cy + r // 2), fill=(78, 76, 90, 255))
            d.arc((cx - r, cy - r // 2, cx + r, cy + r // 2), 20, 160, fill=(150, 148, 162, 255), width=1)
    img.save(p("maps", "moon1.png"))


def ridge(W, H, seed, amps, base, col, rim):
    """a horizontal band of hills that wraps around every W px"""
    r = np.random.default_rng(seed)
    xs = np.arange(W)
    y = np.full(W, float(base))
    for (n, a) in amps:
        ph = r.uniform(0, 2 * np.pi)
        y -= a * (0.5 + 0.5 * np.sin(xs / W * 2 * np.pi * n + ph))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    a = np.zeros((H, W, 4), np.uint8)
    for x in range(W):
        t = int(max(0, y[x]))
        a[t:, x] = col + (255,)
        a[t:t + 2, x] = rim + (255,)
    img = Image.fromarray(a, "RGBA")
    return img, y


def moon_sky():
    far, _ = ridge(1536, 240, 3, [(3, 50), (7, 22), (13, 8)], 200, (74, 72, 92), (120, 118, 140))
    d = ImageDraw.Draw(far)
    for i in range(10):   # crater rims on the far hills
        x = int(rng.uniform(40, 1490))
        d.arc((x - 40, 150, x + 40, 190), 180, 360, fill=(100, 98, 120, 255), width=3)
    far.save(p("sky", "moon_far.png"))
    mid, _ = ridge(1536, 180, 5, [(2, 40), (5, 26), (11, 10)], 150, (52, 50, 64), (96, 94, 112))
    mid.save(p("sky", "moon_mid.png"))


# ---------------------------------------------------------------- the night outside the windows
WINDOWS = {
    "rock": [(540, 268, 630, 338)],
    "archer": [(114, 194, 168, 248), (572, 112, 628, 168)],
    "mage": [(164, 112, 222, 152), (516, 112, 572, 152)],
    "summoner": [(120, 50, 260, 156)],
}


def night_windows():
    for h, rects in WINDOWS.items():
        im = Image.open(p("maps", "house_%s.png" % h)).convert("RGBA")
        a = np.asarray(im).astype(int).copy()
        for (x0, y0, x1, y1) in rects:
            sub = a[y0:y1, x0:x1]
            r, g, b = sub[..., 0], sub[..., 1], sub[..., 2]
            view = ((b > 190) & (b - r > 30)) | ((g > 120) & (g - r > 30) & (g - b > 10))
            ground = (g > 120) & (g - r > 30) & (g - b > 10) & (h == "summoner")
            yy = np.linspace(0, 1, y1 - y0)[:, None] * np.ones((1, x1 - x0))
            sky = np.stack([18 + 50 * yy, 4 + 10 * yy, 14 + 20 * yy], -1)
            new = np.where(ground[..., None], np.array([14, 8, 14]), sky)
            for c in range(3):
                sub[..., c] = np.where(view, new[..., c], sub[..., c])
            # a few stars, and the red moon in the biggest window
            for k in range(6):
                sx, sy = int(rng.uniform(2, x1 - x0 - 2)), int(rng.uniform(2, (y1 - y0) * 0.5))
                if view[sy, sx]:
                    sub[sy, sx, :3] = (230, 200, 210)
            if h in ("summoner", "rock"):
                mx, my, mr = (x1 - x0) * 3 // 4, (y1 - y0) // 3, 9 if h == "summoner" else 6
                yy2, xx2 = np.mgrid[0:y1 - y0, 0:x1 - x0]
                disc = ((xx2 - mx) ** 2 + (yy2 - my) ** 2 < mr * mr) & view
                sub[disc, 0], sub[disc, 1], sub[disc, 2] = 200, 40, 50
            a[y0:y1, x0:x1] = sub
        Image.fromarray(a.astype(np.uint8), "RGBA").save(p("maps", "house_%s_night.png" % h))
    # Tank's workshop has no windows: the night shows in the light instead (lunar_draw.gd)
    Image.open(p("maps", "house_tank.png")).save(p("maps", "house_tank_night.png"))


def luna_coin():
    im = Image.open(p("items", "abyss_coin.png")).convert("RGBA")
    remap = {(26, 8, 40): (6, 30, 52), (122, 58, 160): (40, 140, 190), (255, 58, 216): (100, 236, 255), (255, 208, 244): (226, 255, 255)}
    a = np.asarray(im).copy()
    for k, v in remap.items():
        m = (a[..., 0] == k[0]) & (a[..., 1] == k[1]) & (a[..., 2] == k[2])
        a[m, :3] = v
    Image.fromarray(a, "RGBA").save(p("items", "luna_coin.png"))


if __name__ == "__main__":
    village()
    moon_ground()
    moon_sky()
    night_windows()
    luna_coin()
    print("lunar art written")
