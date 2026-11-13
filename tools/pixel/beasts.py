"""Paints Sproutvale's meadow beasts (boar, rat, ferret, tortoise) in detail with painter.py and writes
them as game monster sets (every pose, shiny and elite recolours, mobs.json entry).

Usage:  python3 tools/pixel/beasts.py [boar rat ferret tortoise] [--out godot/art/mobs] [--preview DIR]
Needs Pillow, NumPy and SciPy.
"""
import argparse
import json
import math
import os
import sys

import numpy as np
from scipy import ndimage

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402
from painter import Painter, ramp_fn, outline, lock_palette  # noqa: E402

GROUND = 69.6   # bottom of the feet, in frame pixels (the game puts the monster's feet at y 69 of 72)


# ---------------------------------------------------------------------------- geometry helpers


def rot(p, pivot, deg):
    t = math.radians(deg)
    x, y = p[0] - pivot[0], p[1] - pivot[1]
    return (pivot[0] + x * math.cos(t) - y * math.sin(t), pivot[1] + x * math.sin(t) + y * math.cos(t))


def ik(hip, foot, l1, l2, bend):
    """Knee position for a two-bone leg from hip to foot. bend +1 = knee forward (right), -1 = back."""
    hx, hy = hip
    fx, fy = foot
    d = math.hypot(fx - hx, fy - hy)
    d = min(d, l1 + l2 - 1e-3)
    a = math.atan2(fy - hy, fx - hx)
    c = (l1 * l1 + d * d - l2 * l2) / (2 * l1 * max(d, 1e-3))
    c = max(-1, min(1, c))
    off = math.acos(c)
    ang = a - off * bend
    return (hx + l1 * math.cos(ang), hy + l1 * math.sin(ang))


def lerp(a, b, t):
    return (a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t)


def ygrad(P, y0, y1):
    """Weights 0 above y0 rising to 1 at y1 (frame pixels)."""
    K = P.K
    return np.clip((P.yy - y0 * K) / ((y1 - y0) * K), 0, 1)


# ---------------------------------------------------------------------------- the boar

BOAR = dict(
    body="#9a4e26", back="#3e2214", belly="#cf9a64", cheek="#e2b27e", leg="#6a3c22", hoof="#2b211d",
    snout="#b06644", nose="#d28274", ear_in="#a85848", tusk="#f1e6c8", outline="#20140e",
    eye_white="#efe4cf", pupil="#140c0a", brow="#24140c",
)


def boar_pose(name, i=0):
    """Pose parameters: body offset (dx, dy), body tilt, head pitch, foot offsets, face."""
    p = dict(dx=0.0, dy=0.0, tilt=0.0, pitch=0.0, feet={"fn": (0, 0), "ff": (0, 0), "hn": (0, 0), "hf": (0, 0)},
             eye="open", mouth=0, tail=0.0, snort=False)
    if name == "idle":
        p["dy"] = 0.0 if i == 0 else 0.6
        p["tail"] = 0 if i == 0 else 1
    elif name == "angry":
        p.update(pitch=8, dy=0.8 + 0.4 * i, eye="angry", tail=2 - i)
        p["feet"]["fn"] = (2, 0)
        p["snort"] = i == 1
    elif name == "run":
        # gallop: reach, gather, reach, gather
        reach = i % 2 == 0
        if reach:
            p.update(dy=-2.0, tilt=-3, pitch=-2, eye="angry")
            p["feet"] = {"fn": (9, -2), "ff": (13, -4), "hn": (-9, -2), "hf": (-5, -3)} if i == 0 else \
                        {"fn": (12, -3), "ff": (8, -1), "hn": (-6, -3), "hf": (-10, -1)}
        else:
            p.update(dy=0.5, tilt=2, pitch=4, eye="angry")
            p["feet"] = {"fn": (-6, -4), "ff": (-9, -2), "hn": (8, -3), "hf": (5, -1)} if i == 1 else \
                        {"fn": (-8, -2), "ff": (-5, -3), "hn": (5, -1), "hf": (9, -4)}
        p["tail"] = i
    elif name == "wind":
        p.update(dx=-3, dy=2.5, pitch=12, tilt=4, eye="angry")
        p["feet"] = {"fn": (3, 0), "ff": (4, 0), "hn": (-1, 0), "hf": (0, 0)}
    elif name == "lunge":
        p.update(dx=4, dy=-2.5, tilt=-5, pitch=-6, eye="angry", mouth=1)
        p["feet"] = {"fn": (13, -4), "ff": (10, -2), "hn": (-12, -1), "hf": (-9, -3)}
    elif name == "hurt":
        p.update(dx=-2, dy=0.5, tilt=7, pitch=-16, eye="closed", mouth=1)
        p["feet"] = {"fn": (4, -3), "ff": (2, 0), "hn": (-2, 0), "hf": (0, 0)}
    elif name == "hop":
        p.update(dy=-1.5, tilt=-2, pitch=-2)
        p["feet"] = {"fn": (6, -5), "ff": (8, -6), "hn": (-6, -5), "hf": (-3, -6)}
    elif name == "hopA":
        p.update(dy=-1.5, tilt=-2, pitch=2, eye="angry")
        p["feet"] = {"fn": (6, -5), "ff": (8, -6), "hn": (-6, -5), "hf": (-3, -6)}
    elif name == "land":
        p.update(dy=3, pitch=6, eye="open")
        p["feet"] = {"fn": (2, 0), "ff": (1, 0), "hn": (-2, 0), "hf": (-1, 0)}
    elif name == "dead":
        p.update(dy=6, tilt=0, pitch=14, eye="dead")
        p["feet"] = {"fn": (6, 0), "ff": (8, 0), "hn": (-6, 0), "hf": (-8, 0)}
    return p


def paint_boar(pose, seed=1):
    C = BOAR
    P = Painter(seed=seed)
    dx, dy, tilt = pose["dx"], pose["dy"], pose["tilt"]
    piv = (42, 52)

    def B(x, y):   # body space → frame (the body sits LIFT px higher than the first sketch: longer legs)
        q = rot((x, y - 3.0), piv, tilt)
        return (q[0] + dx, q[1] + dy)
    neck = B(60, 46)

    def Hd(x, y):  # head space → frame (pitch about the neck)
        return rot(B(x, y), neck, pose["pitch"])

    body_r = ramp_fn(C["body"])
    back_r = ramp_fn(C["back"])
    belly_r = ramp_fn(C["belly"])
    cheek_r = ramp_fn(C["cheek"])
    leg_r = ramp_fn(C["leg"])
    hoof_r = ramp_fn(C["hoof"])
    FUR = (215, 1.6)   # fur lies back and down

    hips = {"fn": B(57, 55), "ff": B(52, 54), "hn": B(25, 54), "hf": B(30, 53)}
    rest = {"fn": (59, GROUND), "ff": (53.5, GROUND), "hn": (24.5, GROUND), "hf": (31.5, GROUND)}
    feet = {k: (rest[k][0] + pose["feet"][k][0] + dx * 0.4, min(GROUND, rest[k][1] + pose["feet"][k][1])) for k in rest}
    if pose["eye"] == "dead":
        feet = {k: (hips[k][0] + pose["feet"][k][0], hips[k][1] + 6) for k in hips}

    def leg(k, near):
        front = k[0] == "f"
        hip, foot = hips[k], feet[k]
        shade = 0.0 if near else 0.22
        if front:
            wrist = (foot[0] - 0.3, foot[1] - 5.0)
            elbow = ik(hip, wrist, 6.5, 5.5, -1)
            pts, rad = [hip, elbow, wrist, (foot[0], foot[1] - 1.6)], [4.0, 2.7, 1.8, 1.7]
        else:
            hock = (foot[0] - 1.8, foot[1] - 6.0)
            knee = ik(hip, hock, 7.5, 6.0, 1)
            pts, rad = [hip, knee, hock, (foot[0], foot[1] - 1.6)], [4.8, 3.3, 1.8, 1.7]
        m = P.limb(pts, rad)
        upper = 1 - ygrad(P, hip[1] + 2, hip[1] + 7)
        P.part(m, leg_r, R=2.2, fur=(95, 0.7), fuzz=0.3, shade=shade, zone=(upper, body_r))
        hm = P.poly([(foot[0] - 1.9, foot[1] - 2.4), (foot[0] + 1.6, foot[1] - 2.4), (foot[0] + 2.7, foot[1]),
                     (foot[0] - 2.0, foot[1])])
        P.part(hm, hoof_r, R=1.0, shade=shade, gloss=0.8)

    leg("hf", False)
    leg("ff", False)

    # tail with a tuft
    sw = pose["tail"]
    t0, t1, t2 = B(16, 45), B(12 - sw * 0.6, 44 + sw * 0.5), B(9.5 - sw * 0.3, 49 + sw * 0.6)
    P.part(P.limb([t0, t1, t2], [1.5, 1.0, 0.8]), body_r, R=1, contour=False)
    P.part(P.ellipse(t2[0], t2[1] + 1.6, 2.2, 3.0, ang=15), back_r, R=1.5, fur=(80, 1.2), fuzz=1.0)

    # torso: rump, barrel and the big shoulder hump in one shape
    torso = P.ellipse(*B(26, 49), 11.5, 11) | P.ellipse(*B(40, 50), 16, 11.5, ang=-4) | \
        P.ellipse(*B(52, 45.5), 12.5, 12.5, ang=-12) | P.ellipse(*B(59, 51), 7, 8.5)
    belly = ygrad(P, B(0, 54)[1], B(0, 60)[1])
    P.part(torso, body_r, R=8, fur=FUR, fuzz=1.0, zone=(belly * 0.9, belly_r), ao=(B(0, 44)[1], B(0, 62)[1]),
           lum_bias=-0.1)

    # the mane: a dark crest from the brow to the rump, then long swept-back bristles
    spine = [B(14, 45), B(20, 40), B(30, 36), B(42, 33.5), B(51, 31.5), B(58, 33.5), B(64, 38.5)]
    crest = P.limb(spine, [1.6, 2.8, 3.4, 3.8, 4.0, 3.6, 2.6])
    P.part(crest, back_r, R=3, fur=(200, 1.3), fuzz=1.3, contour=False)
    tall = lambda s: 3.0 + 8.0 * max(0.0, math.sin(math.pi * min(1.0, s * 1.08))) ** 0.6
    back_row = P.spikes(spine, 22, length=tall, width=2.8, lean=-0.5, jitter=0.35)
    P.part(back_row, back_r, R=1.2, fur=(250, 1.0), contour=True, lum_bias=-0.12)
    front_row = P.spikes([lerp(spine[i], spine[i + 1], 0.5) for i in range(len(spine) - 1)], 16,
                         length=lambda s: tall(s) * 0.75, width=2.6, lean=-0.42, jitter=0.4)
    P.part(front_row, back_r, R=1.2, fur=(250, 1.0), contour=True, lum_bias=0.18)

    leg("hn", True)
    leg("fn", True)

    # head: a wedge from the brow down to the snout, a cream cheek, the nose disc
    head = P.poly([Hd(55.5, 41), Hd(61, 36.5), Hd(66, 40), Hd(73, 47.5), Hd(78.5, 51), Hd(80, 54),
                   Hd(79.5, 58.5), Hd(74, 60), Hd(67, 62), Hd(60, 61.5), Hd(55.5, 56)])
    cheek = P.poly([Hd(57, 54), Hd(64, 50.5), Hd(70, 54), Hd(72, 60.5), Hd(64, 62.5), Hd(57, 59.5)])
    P.part(head, body_r, R=4.5, fur=(200, 1.2), fuzz=0.7, zone=(cheek, cheek_r), lum_bias=-0.04)
    if pose["mouth"]:
        P.part(P.poly([Hd(68, 58.5), Hd(77, 58.5), Hd(76, 63), Hd(69.5, 61.5)]), ramp_fn("#8a3530"), R=1,
               flat=True, lum_bias=-0.2)
        P.part(P.limb([Hd(67.5, 61.2), Hd(75, 63.2)], [1.9, 1.2]), cheek_r, R=1.2)
    snout = P.limb([Hd(71, 53.8), Hd(79.5, 55.6)], [3.6, 3.0])
    P.part(snout, ramp_fn(C["snout"]), R=2.2, fur=(0, 0.4), contour=False)
    P.part(P.ellipse(*Hd(80.6, 55.6), 1.5, 3.0, ang=pose["pitch"] - 8), ramp_fn(C["nose"]), R=1.2, gloss=0.5)

    # ear: a pointed leaf, tip up and back
    e0, e1, tip = Hd(59.5, 42), Hd(66.5, 42.5), Hd(60, 31.5)
    P.part(P.poly([e0, tip, e1, Hd(63.5, 45)]), body_r, R=1.8, fur=(260, 0.5))
    P.part(P.poly([lerp(e0, e1, 0.3), lerp(tip, lerp(e0, e1, 0.5), 0.3), lerp(e0, e1, 0.8)]), ramp_fn(C["ear_in"]),
           R=1, contour=False, lum_bias=-0.05)

    # crisp details at game resolution
    ex, ey = Hd(70.0, 47.6)
    if pose["eye"] in ("open", "angry"):
        P.px(ex, ey, C["pupil"])
        P.px(ex - 1, ey, C["eye_white"])
        P.px(ex, ey + 1, C["pupil"])
        P.px(ex - 1, ey + 1, "#5a3a2a")
        if pose["eye"] == "angry":
            P.pxs([(ex - 2, ey - 2), (ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 1)], C["brow"])
        else:
            P.pxs([(ex - 1, ey - 1), (ex, ey - 1)], C["brow"])
    elif pose["eye"] == "closed":
        P.pxs([(ex - 2, ey - 1), (ex - 1, ey), (ex, ey), (ex + 1, ey)], C["brow"])
    else:
        P.pxs([(ex - 1, ey - 1), (ex + 1, ey - 1), (ex, ey), (ex - 1, ey + 1), (ex + 1, ey + 1)], C["brow"])
    nx, ny = Hd(81.2, 55.2)
    P.pxs([(nx, ny), (nx, ny + 2)], "#5a2422")
    tx, ty = Hd(74.6, 60.2)
    P.pxs([(tx, ty), (tx + 1, ty), (tx + 1, ty - 1), (tx + 2, ty - 2), (tx + 2, ty - 3)], C["tusk"])
    P.pxs([(tx, ty + 1), (tx + 1, ty + 1), (tx + 2, ty)], "#3a2418")
    if pose["snort"]:   # a puff of breath
        puff = P.ellipse(nx + 3, ny + 1, 2.0, 1.7) | P.ellipse(nx + 4.8, ny, 1.6, 1.5) | P.ellipse(nx + 4.6, ny + 2, 1.4, 1.2)
        P.part(puff, ramp_fn("#e9dcc2"), R=1.2, contour=False, fuzz=0.3, fur=(0, 0.3))
    return P


# ---------------------------------------------------------------------------- the rat

RAT = dict(
    body="#8c7b6b", back="#5e4f44", belly="#e2d3ba", pink="#e2928e", ear_in="#d97c80", tail="#d98a88",
    outline="#1e1614", pupil="#0e0a0a", eye_hi="#fbf6f0", whisker="#cfc6bc", tooth="#f6efe0", nose="#c95c66",
    brow="#2a201c",
)


def paint_rat(pose, seed=2):
    C = RAT
    P = Painter(seed=seed)
    k = 0.7   # the rat's strides are shorter than the boar's
    dx, dy, tilt = pose["dx"] * k, pose["dy"] * k, pose["tilt"]
    piv = (42, 58)

    def B(x, y):
        q = rot((x, y), piv, tilt)
        return (q[0] + dx, q[1] + dy)
    neck = B(53, 56)

    def Hd(x, y):
        return rot(B(x, y), neck, pose["pitch"] * 0.8)

    body_r = ramp_fn(C["body"])
    back_r = ramp_fn(C["back"])
    belly_r = ramp_fn(C["belly"])
    pink_r = ramp_fn(C["pink"])
    FUR = (200, 1.3)

    hips = {"fn": B(51, 61), "ff": B(48, 60.5), "hn": B(31, 61), "hf": B(35, 60)}
    rest = {"fn": (53, GROUND), "ff": (49, GROUND), "hn": (28, GROUND), "hf": (33.5, GROUND)}
    off = {kk: (v[0] * k, v[1] * k) for kk, v in pose["feet"].items()}
    feet = {kk: (rest[kk][0] + off[kk][0] + dx * 0.4, min(GROUND, rest[kk][1] + off[kk][1])) for kk in rest}
    if pose["eye"] == "dead":
        feet = {kk: (hips[kk][0] + off[kk][0], hips[kk][1] + 3) for kk in hips}

    def leg(kk, near):
        front = kk[0] == "f"
        hip, foot = hips[kk], feet[kk]
        shade = 0.0 if near else 0.22
        if front:
            mid = ik(hip, (foot[0], foot[1] - 1.5), 3.6, 3.6, -1)
            m = P.limb([hip, mid, (foot[0], foot[1] - 1.2)], [2.6, 1.3, 1.0])
        else:
            hock = (foot[0] - 2.5, foot[1] - 2.0)
            knee = ik(hip, hock, 4.6, 3.6, 1)
            m = P.limb([hip, knee, hock], [3.6, 1.6, 1.1])
            paw = P.limb([hock, (foot[0] + 1.5, foot[1] - 0.8)], [1.1, 0.9])
            P.part(paw, pink_r, R=0.8, shade=shade)
        P.part(m, body_r, R=1.6, fur=(100, 0.6), shade=shade, zone=(ygrad(P, hip[1] + 2.5, hip[1] + 4.5), pink_r))
        if front:
            P.part(P.ellipse(foot[0] + 0.8, foot[1] - 0.8, 1.6, 0.9), pink_r, R=0.8, shade=shade)

    leg("hf", False)
    leg("ff", False)

    # the long bare tail, curling up behind
    sw = pose["tail"]
    tail = [B(22, 60), B(15, 59 - sw * 0.3), B(9.5, 54 - sw * 0.5), B(8.5 + sw * 0.6, 47), B(11 + sw * 0.8, 42.5),
            B(14.5 + sw, 41.5)]
    P.part(P.limb(tail, [1.9, 1.5, 1.2, 1.0, 0.8, 0.5]), ramp_fn(C["tail"]), R=1.0, contour=False)

    body = P.ellipse(*B(30, 57.5), 10.5, 9.5) | P.ellipse(*B(40, 56.5), 11.5, 9.5, ang=-6) | P.ellipse(*B(49.5, 58), 7.5, 7.2)
    top = 1 - ygrad(P, B(0, 50)[1], B(0, 53.5)[1])
    P.part(body, body_r, R=6, fur=FUR, fuzz=1.0,
           zone=[(top, back_r), (ygrad(P, B(0, 59.5)[1], B(0, 63.5)[1]), belly_r)], ao=(B(0, 48)[1], B(0, 67)[1]))

    leg("hn", True)
    leg("fn", True)

    # head: round skull tapering to a pointed, whiskered snout
    head = P.poly([Hd(51, 54), Hd(56, 50), Hd(61, 50.5), Hd(66, 54), Hd(70, 57.2), Hd(69.5, 59.3), Hd(63, 61.5),
                   Hd(56, 62), Hd(51, 60)])
    P.part(head, body_r, R=4, fur=(190, 1.1), fuzz=0.5, zone=(P.poly([Hd(55, 59), Hd(62, 58), Hd(69, 58.8),
                                                                    Hd(64, 62), Hd(55, 62.5)]), belly_r))
    if pose["mouth"]:
        P.part(P.poly([Hd(63, 59.5), Hd(68.5, 59.2), Hd(67, 62), Hd(63.5, 61.5)]), ramp_fn("#8a3a3a"), R=1, flat=True)
    P.part(P.ellipse(*Hd(70, 58), 1.1, 1.0), ramp_fn(C["nose"]), R=0.8, contour=False, gloss=0.6)

    # the big round ear
    ear_back = pose["eye"] == "angry"
    ec = Hd(55.0 - (1.2 if ear_back else 0), 49.0 + (0.8 if ear_back else 0))
    ear = P.ellipse(ec[0], ec[1] - 0.5, 4.3, 4.8, ang=-25 if ear_back else -10)
    P.part(ear, pink_r, R=2, lum_bias=-0.05)
    P.part(P.ellipse(ec[0] + 0.4, ec[1] + 0.5, 2.3, 2.8, ang=-15), ramp_fn(C["ear_in"]), R=1.5, contour=False,
           lum_bias=-0.12)

    ex, ey = Hd(62.4, 54.2)
    if pose["eye"] in ("open", "angry"):
        P.pxs([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], C["pupil"])
        P.px(ex, ey, C["eye_hi"])
        if pose["eye"] == "angry":
            P.pxs([(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 1.0)], C["brow"])
    elif pose["eye"] == "closed":
        P.pxs([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], C["brow"])
    else:
        P.pxs([(ex, ey), (ex + 2, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex + 2, ey + 2)], C["brow"])
    nx, ny = Hd(70.5, 58)
    for (wx, wy) in [(2, -2), (3, -2), (4, -3), (2, 0), (3, 0), (4, 0), (2, 1), (3, 2)]:
        P.px(nx + wx - 1, ny + wy, C["whisker"])
    if pose["mouth"] or pose["eye"] == "angry":
        P.pxs([Hd(67.5, 60.5), Hd(66.5, 60.5)], C["tooth"])
    return P


# ---------------------------------------------------------------------------- the ferret

FERRET = dict(
    body="#6e4a2e", back="#4a3020", belly="#e6d2ac", cream="#efe0c0", mask="#3a2618", leg="#3e2a1c",
    nose="#d98c86", outline="#1a110b", pupil="#0c0807", eye_hi="#fbf6ee", brow="#24170e", tooth="#f6efe0",
)


def paint_ferret(pose, seed=3):
    C = FERRET
    P = Painter(seed=seed)
    k = 0.75
    dx, dy, tilt = pose["dx"] * k, pose["dy"] * k, pose["tilt"]
    piv = (42, 58)

    def B(x, y):
        q = rot((x, y), piv, tilt)
        return (q[0] + dx, q[1] + dy)
    neck = B(57, 56)

    def Hd(x, y):
        return rot(B(x, y), neck, pose["pitch"] * 0.8)

    body_r = ramp_fn(C["body"])
    back_r = ramp_fn(C["back"])
    belly_r = ramp_fn(C["belly"])
    cream_r = ramp_fn(C["cream"])
    leg_r = ramp_fn(C["leg"])
    FUR = (190, 1.2)

    hips = {"fn": B(54, 61), "ff": B(51, 60.5), "hn": B(27, 61), "hf": B(31, 60.5)}
    rest = {"fn": (56, GROUND), "ff": (52, GROUND), "hn": (25, GROUND), "hf": (30, GROUND)}
    off = {kk: (v[0] * k, v[1] * k) for kk, v in pose["feet"].items()}
    feet = {kk: (rest[kk][0] + off[kk][0] + dx * 0.4, min(GROUND, rest[kk][1] + off[kk][1])) for kk in rest}
    if pose["eye"] == "dead":
        feet = {kk: (hips[kk][0] + off[kk][0], hips[kk][1] + 3) for kk in hips}

    def leg(kk, near):
        front = kk[0] == "f"
        hip, foot = hips[kk], feet[kk]
        shade = 0.0 if near else 0.22
        if front:
            mid = ik(hip, (foot[0], foot[1] - 1.3), 3.8, 3.6, -1)
            pts, rad = [hip, mid, (foot[0], foot[1] - 1.1)], [2.8, 1.5, 1.2]
        else:
            hock = (foot[0] - 2.0, foot[1] - 2.2)
            knee = ik(hip, hock, 4.4, 3.4, 1)
            pts, rad = [hip, knee, hock, (foot[0] + 0.8, foot[1] - 1.0)], [3.6, 1.8, 1.3, 1.1]
        P.part(P.limb(pts, rad), leg_r, R=1.5, fur=(100, 0.7), fuzz=0.3, shade=shade)
        P.part(P.ellipse(foot[0] + 1.0, foot[1] - 0.9, 1.9, 1.0), leg_r, R=0.8, shade=shade + 0.05)

    leg("hf", False)
    leg("ff", False)

    # bushy tail
    sw = pose["tail"]
    tail = [B(20, 57.5), B(13, 57 - sw * 0.4), B(7, 55.5 - sw * 0.8), B(2.5, 53 - sw)]
    P.part(P.limb(tail, [3.2, 3.4, 2.8, 1.4]), back_r, R=2.0, fur=(185, 1.6), fuzz=1.3)

    body = P.ellipse(*B(27, 58.5), 9, 7.2) | P.ellipse(*B(39, 57.5), 12, 7.0, ang=-3) | P.ellipse(*B(51, 58), 7.5, 6.6)
    top = 1 - ygrad(P, B(0, 51.5)[1], B(0, 55)[1])
    P.part(body, body_r, R=5, fur=FUR, fuzz=0.9, zone=[(top, back_r), (ygrad(P, B(0, 60.5)[1], B(0, 64)[1]), belly_r)],
           ao=(B(0, 50)[1], B(0, 66)[1]))

    leg("hn", True)
    leg("fn", True)

    # head: cream face, dark mask across the eyes, dark crown
    head = P.poly([Hd(55, 53.5), Hd(59, 50.5), Hd(64, 51), Hd(68, 54.5), Hd(71, 57.5), Hd(70, 59.6), Hd(64, 61.5),
                   Hd(57, 61.5), Hd(54, 59)])
    mask = P.poly([Hd(58.5, 53.5), Hd(63, 52.5), Hd(67.5, 55), Hd(66.5, 57.5), Hd(62, 57), Hd(58.5, 56.5)])
    crown = 1 - ygrad(P, Hd(0, 51.5)[1], Hd(0, 53.5)[1])
    P.part(head, cream_r, R=3.5, fur=(190, 0.8), fuzz=0.4, zone=[(crown, body_r), (mask, ramp_fn(C["mask"]))])
    P.part(P.ellipse(*Hd(70.8, 58.2), 1.1, 1.0), ramp_fn(C["nose"]), R=0.8, contour=False, gloss=0.6)
    if pose["mouth"]:
        P.part(P.poly([Hd(64, 59.8), Hd(69.5, 59.5), Hd(68, 62), Hd(64.5, 61.6)]), ramp_fn("#8a3a3a"), R=1, flat=True)

    # small round ear with a cream rim
    ec = Hd(58.0, 51.0)
    P.part(P.ellipse(ec[0], ec[1], 2.6, 2.4), cream_r, R=1.2)
    P.part(P.ellipse(ec[0] + 0.3, ec[1] + 0.4, 1.5, 1.4), ramp_fn("#7a4a3a"), R=1, contour=False, lum_bias=-0.1)

    ex, ey = Hd(64.0, 54.8)
    if pose["eye"] in ("open", "angry"):
        P.pxs([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], C["pupil"])
        P.px(ex, ey, C["eye_hi"])
        if pose["eye"] == "angry":
            P.pxs([(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 1)], C["brow"])
    elif pose["eye"] == "closed":
        P.pxs([(ex - 1, ey + 1), (ex, ey), (ex + 1, ey), (ex + 2, ey + 1)], C["brow"])
    else:
        P.pxs([(ex, ey), (ex + 2, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex + 2, ey + 2)], C["brow"])
    if pose["mouth"] or pose["eye"] == "angry":
        P.pxs([Hd(68.5, 60.5), Hd(67.5, 60.5)], C["tooth"])
    return P


# ---------------------------------------------------------------------------- the tortoise

TORTOISE = dict(
    shell="#58602a", moss="#6f9230", rim="#4a4422", leaf="#9ad84a", skin="#c48a4a", skin_dk="#8a5a2e",
    outline="#1a160c", pupil="#0c0a08", eye_hi="#fbf6ee", brow="#2a1c10", claw="#2a2218", line="#262412",
)


def tortoise_pose(name, i=0):
    p = boar_pose(name if name not in ("shell", "spin") else "idle", i)
    p["withdrawn"] = name in ("shell", "spin")
    p["spin"] = i if name == "spin" else 0
    p["neck"] = {"idle": 0.0, "angry": 1.5, "run": 0.8, "wind": -2.0, "lunge": 4.0, "hurt": -4.0, "dead": 1.0,
                 "hop": 0.5, "hopA": 1.5, "land": -1.0}.get(name, 0.0)
    return p


def _shell(P, C, cx, cy, rx, ry, cut, offset=0.0, rot_deg=0.0):
    """Domed, plated, mossy shell. cut: y below which the dome is cut off (None = whole oval)."""
    K = P.K
    dome = P.ellipse(cx, cy, rx, ry, ang=rot_deg)
    if cut is not None:
        dome &= P.yy <= cut * K
    # moss: soft blobs over the top of the shell
    rng = np.random.default_rng(11)
    blob = ndimage.zoom(rng.standard_normal((10, 12)), (P.H / 10, P.W / 12), order=3)
    blob = np.roll(blob, int(offset * K * 3), axis=1)
    moss = (blob > -0.1) & (P.yy < (cy + ry * 0.25) * K)
    P.part(dome, ramp_fn(C["shell"]), R=9, fur=(0, 0.6), zone=(moss, ramp_fn(C["moss"])), contour=False)
    # plates: nearest of a set of plate centres; their borders become dark grooves, their middles bulge
    seeds = []
    for j, (fy, n) in enumerate(((-0.62, 3), (-0.12, 4), (0.42, 5))):
        for t in range(n):
            fx = (t + 0.5) / n * 2 - 1 + (0.08 * j)
            seeds.append((cx + (fx * 0.85) * rx + offset * rx * 0.5, cy + fy * ry))
    seeds = np.array(seeds)
    ux = P.xx / K
    uy = P.yy / K
    best = np.full(ux.shape, 1e9)
    lab = np.zeros(ux.shape, int)
    for k, (sx, sy) in enumerate(seeds):
        ddx = (ux - sx + rx) % (2 * rx) - rx if offset else ux - sx   # plates wrap around while spinning
        d = ddx ** 2 + ((uy - sy) * 1.5) ** 2
        upd = d < best
        best[upd] = d[upd]
        lab[upd] = k
    edge = np.zeros_like(dome)
    for sh in ((0, 1), (1, 0)):
        edge |= lab != np.roll(lab, sh, (0, 1))
    edge = ndimage.binary_dilation(edge, iterations=max(1, int(K * 0.35))) & dome
    edge &= ~ndimage.binary_erosion(dome, iterations=K) | True
    bump = ndimage.distance_transform_edt(~edge)
    bump = np.clip(bump / (K * 3.0), 0, 1)
    P.rgb[dome] *= (0.85 + 0.25 * bump[dome])[:, None]
    P.rgb[edge] = pk.parse_hex(C["line"]) * 0.9 + P.rgb[edge] * 0.1
    P.rgb = np.clip(P.rgb, 0, 1)
    return dome


def paint_tortoise(pose, seed=4):
    C = TORTOISE
    P = Painter(seed=seed)
    skin_r = ramp_fn(C["skin"])
    if pose["withdrawn"]:
        sp = pose["spin"]
        _shell(P, C, 44, 60.5, 20.5, 11.0, 66.0, offset=sp * 0.25)
        P.part(P.ellipse(44, 66.2, 20.2, 3.0), ramp_fn(C["rim"]), R=1.5, fur=(0, 0.4))
        P.px(37 + sp * 3 % 12, 52, "#e8f2c8")
        return P
    k = 0.5
    dx, dy = pose["dx"] * k, pose["dy"] * 0.6

    def B(x, y):
        return (x + dx, y + dy)
    nk = pose["neck"]
    neck_base = B(53, 58)

    def Hd(x, y):
        q = (x + nk, y - nk * 0.3)
        return rot(B(*q), neck_base, pose["pitch"] * 0.6)

    hips = {"fn": B(53.5, 60), "ff": B(49, 60), "hn": B(28, 60), "hf": B(32.5, 60)}
    rest = {"fn": (56, GROUND), "ff": (50.5, GROUND), "hn": (26, GROUND), "hf": (33, GROUND)}
    off = {kk: (v[0] * k, v[1] * k) for kk, v in pose["feet"].items()}
    feet = {kk: (rest[kk][0] + off[kk][0] + dx * 0.4, min(GROUND, rest[kk][1] + off[kk][1])) for kk in rest}
    if pose["eye"] == "dead":
        feet = {kk: (hips[kk][0] + off[kk][0] * 1.5, GROUND) for kk in hips}

    def leg(kk, near):
        hip, foot = hips[kk], feet[kk]
        shade = 0.0 if near else 0.25
        m = P.limb([hip, ((hip[0] + foot[0]) / 2, (hip[1] + foot[1]) / 2), (foot[0], foot[1] - 2.0)], [3.8, 3.2, 3.2])
        P.part(m, skin_r, R=2.2, fur=(45, 0.9), shade=shade)
        P.part(P.ellipse(foot[0] + 0.3, foot[1] - 1.3, 3.4, 1.4), skin_r, R=1.2, shade=shade + 0.08)
        P.pxs([(foot[0] + 2.2, foot[1] - 0.8), (foot[0] + 0.6, foot[1] - 0.6)], C["claw"])

    leg("hf", False)
    leg("ff", False)
    # tail and the neck behind the shell's front edge
    P.part(P.poly([B(23, 58), B(18, 61), B(24, 61)]), skin_r, R=1, shade=0.1)
    neck = P.limb([B(50, 58.5), Hd(58, 56), Hd(62.5, 53.5)], [3.4, 2.9, 2.6])
    P.part(neck, skin_r, R=2.4, fur=(200, 0.8), zone=(ygrad(P, B(0, 57)[1], B(0, 60)[1]), ramp_fn("#e0b07a")))
    head = P.ellipse(*Hd(65, 52.3), 5.2, 4.1, ang=12 + pose["pitch"] * 0.6) | P.ellipse(*Hd(68.8, 53.7), 2.5, 2.2)
    P.part(head, skin_r, R=2.6, fur=(30, 0.5))
    if pose["mouth"]:
        P.part(P.poly([Hd(65, 54.5), Hd(70, 54.4), Hd(68.5, 57), Hd(65.5, 56)]), ramp_fn("#a03838"), R=1, flat=True)

    sy = 51.5 + dy
    _shell(P, C, 40 + dx, sy, 19.5, 13.5, 60.0 + dy)
    rim = P.ellipse(40 + dx, 59.4 + dy, 20.0, 2.6)
    P.part(rim, ramp_fn(C["rim"]), R=1.5, fur=(0, 0.4))
    # leaves sprouting from the moss
    for (lx, ly, ang) in ((31, 39.5, -40), (34, 37.6, -15), (39, 37.0, 20), (37, 36.5, -70), (45, 37.6, 35), (50, 40.0, 60)):
        lx, ly = B(lx, ly)
        P.part(P.ellipse(lx, ly, 2.8, 1.3, ang=ang), ramp_fn(C["leaf"]), R=1, lum_bias=0.1)

    leg("hn", True)
    leg("fn", True)

    ex, ey = Hd(66.0, 51.2)
    if pose["eye"] in ("open", "angry"):
        P.pxs([(ex, ey), (ex + 1, ey), (ex, ey + 1), (ex + 1, ey + 1)], C["pupil"])
        P.px(ex, ey, C["eye_hi"])
        if pose["eye"] == "angry":
            P.pxs([(ex - 1, ey - 1), (ex, ey - 1), (ex + 1, ey - 1)], C["brow"])
    elif pose["eye"] == "closed":
        P.pxs([(ex - 1, ey + 1), (ex, ey + 1), (ex + 1, ey + 1)], C["brow"])
    else:
        P.pxs([(ex, ey), (ex + 2, ey), (ex + 1, ey + 1), (ex, ey + 2), (ex + 2, ey + 2)], C["brow"])
    mx, my = Hd(67, 54.4)
    P.pxs([(mx, my), (mx + 1, my), (mx + 2, my - 0.4)], C["brow"])
    return P


# ---------------------------------------------------------------------------- set building

KEYS_BEAST = [("idle", 2), ("angry", 2), ("run", 4), ("wind", 1), ("lunge", 1), ("hurt", 1), ("dead", 1),
              ("hop", 1), ("hopA", 1), ("land", 1)]

CREATURES = {
    "boar": dict(pose=boar_pose, paint=paint_boar, colours=BOAR, keys=KEYS_BEAST, k=30),
    "rat": dict(pose=boar_pose, paint=paint_rat, colours=RAT, keys=KEYS_BEAST, k=28),
    "ferret": dict(pose=boar_pose, paint=paint_ferret, colours=FERRET, keys=KEYS_BEAST, k=28),
    "tortoise": dict(pose=tortoise_pose, paint=paint_tortoise, colours=TORTOISE,
                     keys=KEYS_BEAST + [("shell", 1), ("spin", 4)], k=30),
}


def build(name):
    spec = CREATURES[name]
    painters = []
    order = []
    for key, n in spec["keys"]:
        for i in range(n):
            painters.append(spec["paint"](spec["pose"](key, i), seed=1))
            order.append((key, i))
    frames = [p.render() for p in painters]
    protect = sorted({c for p in painters for _, _, c in p.decals})
    frames, pal = lock_palette(frames, spec["k"], protect)
    frames = [outline(p.apply_decals(f), spec["colours"]["outline"]) for p, f in zip(painters, frames)]
    sets = {}
    for (key, i), f in zip(order, frames):
        sets.setdefault(key, []).append(f)
    white = pk.white(sets["idle"][0])
    sets["white"] = [white]
    return sets, pal


def write_set(name, sets, root):
    man_path = os.path.join(root, "mobs.json")
    man = json.load(open(man_path))
    for suf, fn in (("", None), ("_shiny", pk.shiny), ("_elite", pk.elite)):
        d = os.path.join(root, name + suf)
        os.makedirs(d, exist_ok=True)
        keys = {}
        for key, frames in sets.items():
            arr = pk.strip(frames)
            if fn is not None and key != "white":
                arr = fn(arr)
            pk.save(arr, os.path.join(d, key + ".png"))
            keys[key] = len(frames)
        old = man["sets"].get(name + suf, {})
        allk = dict(old.get("keys", {}))
        allk.update(keys)
        man["sets"][name + suf] = {"w": 88, "h": 72, "dim": old.get("dim"), "keys": allk}
    with open(man_path, "w") as f:
        json.dump(man, f, indent=1)


def preview(sets, path, scale=4):
    frames = [f for k in sets for f in sets[k]]
    cols = 6
    rows = (len(frames) + cols - 1) // cols
    sheet = np.zeros((rows * 74, cols * 90, 4), np.float32)
    sheet[..., :3] = (0.47, 0.62, 0.45)
    sheet[..., 3] = 1
    for i, f in enumerate(frames):
        y, x = (i // cols) * 74 + 1, (i % cols) * 90 + 1
        a = f[..., 3:4]
        sheet[y:y + 72, x:x + 88, :3] = f[..., :3] * a + sheet[y:y + 72, x:x + 88, :3] * (1 - a)
    pk.save(np.repeat(np.repeat(sheet, scale, 0), scale, 1), path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", default=list(CREATURES))
    ap.add_argument("--out", help="mobs folder to write into (e.g. godot/art/mobs)")
    ap.add_argument("--preview", help="folder for preview sheets")
    a = ap.parse_args()
    for name in a.names:
        sets, pal = build(name)
        if a.preview:
            os.makedirs(a.preview, exist_ok=True)
            preview(sets, os.path.join(a.preview, name + ".png"))
        if a.out:
            write_set(name, sets, a.out)
        print("%s: %d frames, %d colours" % (name, sum(len(v) for v in sets.values()), len(pal)))


if __name__ == "__main__":
    main()
