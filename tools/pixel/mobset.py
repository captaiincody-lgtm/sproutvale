"""Turns a few cleaned frames into a full monster set the game can load.

The game asks each monster for a set of poses (idle, angry, run, wind, lunge, hurt, dead, hop, hopA,
land, white…). An AI sheet usually has only a handful of frames, so a small recipe says which frame
plays each pose, with optional 1-pixel tweaks so the loops still breathe:

  {
    "frames": "path/to/cleaned/frames",     # the folder clean.py wrote
    "row": "rat",                             # which row of it
    "keys": {
      "idle":  ["0", "0^"],                   # frame 0, then frame 0 stretched up a pixel (a breath)
      "angry": ["1", "1^"],
      "run":   ["0", "1", "2", "1"],
      "wind":  ["0v"],                        # squashed down a pixel (winding up)
      "lunge": ["2"], "hurt": ["3"], "dead": ["3v"], "hop": ["2"], "hopA": ["2"], "land": ["0v"]
    }
  }

Tweaks after the frame number: ^ stretch up 1 px, v squash 1 px, < > nudge 1 px left/right,
f flip horizontally. "white" (the hit flash) is made from the first idle frame automatically.

Usage:
  python3 tools/pixel/mobset.py RECIPE.json godot/art/mobs/NAME [--variants]
      writes one strip per pose into the folder, updates the folder's entry in ../mobs.json, and with
      --variants also rebuilds NAME_shiny and NAME_elite with the game's own recolour rules.
Needs Pillow, NumPy and SciPy.
"""
import argparse
import json
import os
import sys

import numpy as np

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import pixelkit as pk  # noqa: E402


def body_mid(f):
    ys = np.nonzero((f[..., 3] > 0.5).any(1))[0]
    return (ys.min() + ys.max()) // 2 if len(ys) else f.shape[0] // 2


def tweak(f, ops):
    f = f.copy()
    for op in ops:
        if op == "^":     # duplicate the middle row: everything above it moves up a pixel
            m = body_mid(f)
            f[:m] = f[1:m + 1]
        elif op == "v":   # drop the middle row: everything above it moves down a pixel
            m = body_mid(f)
            f[1:m + 1] = f[:m].copy()
            f[0] = 0
        elif op == "<":
            f = np.concatenate([f[:, 1:], np.zeros_like(f[:, :1])], 1)
        elif op == ">":
            f = np.concatenate([np.zeros_like(f[:, :1]), f[:, :-1]], 1)
        elif op == "f":
            f = f[:, ::-1].copy()
    return f


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("recipe")
    ap.add_argument("out")
    ap.add_argument("--variants", action="store_true", help="also rebuild the _shiny and _elite recolours")
    args = ap.parse_args()
    rec = json.load(open(args.recipe))
    base = os.path.dirname(os.path.abspath(args.recipe))
    fdir = os.path.join(base, rec["frames"]) if not os.path.isabs(rec["frames"]) else rec["frames"]
    row = rec["row"]

    cache = {}

    def frame(spec):
        i = int("".join(ch for ch in spec if ch.isdigit()))
        if i not in cache:
            cache[i] = pk.load(os.path.join(fdir, "%s_%d.png" % (row, i)))
        return tweak(cache[i], [ch for ch in spec if not ch.isdigit()])

    os.makedirs(args.out, exist_ok=True)
    counts = {}
    strips = {}
    for key, specs in rec["keys"].items():
        strips[key] = pk.strip([frame(s) for s in specs])
        counts[key] = len(specs)
    first = rec["keys"].get("idle", next(iter(rec["keys"].values())))[0]
    strips.setdefault("white", pk.white(frame(first)))
    counts.setdefault("white", 1)
    for key, arr in strips.items():
        pk.save(arr, os.path.join(args.out, key + ".png"))
    fh, fw = cache[next(iter(cache))].shape[:2]

    name = os.path.basename(os.path.normpath(args.out))
    root = os.path.dirname(os.path.abspath(args.out))
    man_path = os.path.join(root, "mobs.json")
    man = json.load(open(man_path)) if os.path.exists(man_path) else {"sets": {}}
    names = [name]
    if args.variants:
        for suf, fn in (("_shiny", pk.shiny), ("_elite", pk.elite)):
            d = os.path.join(root, name + suf)
            os.makedirs(d, exist_ok=True)
            for key, arr in strips.items():
                pk.save(arr if key == "white" else fn(arr), os.path.join(d, key + ".png"))
            names.append(name + suf)
    for n in names:
        old = man["sets"].get(n, {})
        missing = set(old.get("keys", {})) - set(counts)
        if missing:
            print("  note: %s had poses this recipe doesn't make: %s (left as they were)" % (n, ", ".join(sorted(missing))))
        keys = dict(old.get("keys", {}))
        keys.update(counts)
        man["sets"][n] = {"w": fw, "h": fh, "dim": old.get("dim"), "keys": keys}
    json.dump(man, open(man_path, "w"), indent=1)
    print("wrote %s (%s)" % (", ".join(names), ", ".join("%s %d" % kv for kv in counts.items())))


if __name__ == "__main__":
    main()
