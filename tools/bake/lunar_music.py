"""Composes the music for the Lunar quest line and saves it as looping OGG files.

    lunar.ogg   home under the blood-red moon: a slow, uneasy lullaby (minor pads, a music box, a low heartbeat)
    moon.ogg    the Moon's landing site: wide, weightless and lonely (airy choir, glassy arpeggios, no drums)

Built from the instruments in abyss_music.py (numpy synthesis, no samples), with seamless loops.

Usage:  python3 tools/bake/lunar_music.py [godot]
Needs:  Python 3 with numpy, and ffmpeg (for OGG encoding).
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import abyss_music as A  # noqa: E402

rng = A.rng


# ---------------------------------------------------------------- lunar (B minor, 52 bpm, 16 bars)
def lunar():
    beat = 60 / 52
    T = A.Track(16 * 4 * beat)
    chords = [[47, 54, 59, 62], [43, 55, 59, 62], [45, 52, 57, 60], [42, 54, 58, 61]]
    for i in range(8):
        ch = chords[i % 4]
        T.add(i * 8 * beat, A.pad(ch, 8 * beat + 2, 700, 0.008), -0.2, 0.15)
        T.add(i * 8 * beat, A.choir([c + 12 for c in ch[1:]], 8 * beat + 2, 900), 0.3, 0.07)
        T.add(i * 8 * beat, A.sub(ch[0] - 12, 6 * beat, 1.4), 0, 0.12)
    # a music box, out of tune with the night: the lullaby walks down and never resolves
    tune = [74, 73, 71, 69, 71, 66, None, None, 74, 76, 74, 73, 71, 70, None, None]
    for rep in range(4):
        for k, m in enumerate(tune):
            if m is not None:
                b = rep * 16 + k
                T.add(b * beat + rng.uniform(0, 0.03), A.bell(m + 12, 3.0, 0.7) * 0.6 + A.glass(m + 12, 3.0) * 0.4, 0.4 * ((-1) ** k), 0.09)
    # a slow heartbeat underneath
    for b in range(0, 64, 2):
        T.add(b * beat, A.kick(0.5, 70, 34), 0, 0.22)
        T.add(b * beat + 0.28, A.kick(0.5, 64, 32), 0, 0.14)
    return T.finish(5.0, 0.5, 2600, 0.42)


# ---------------------------------------------------------------- moon (E lydian, 58 bpm, 12 bars)
def moon():
    beat = 60 / 58
    bars = 12
    T = A.Track(bars * 4 * beat)
    chords = [[52, 59, 63, 66], [54, 61, 64, 69], [52, 59, 63, 68], [49, 56, 61, 64], [50, 57, 62, 66], [52, 58, 63, 66]]
    for i, ch in enumerate(chords):
        T.add(i * 8 * beat, A.choir(ch, 8 * beat + 2, 1700), -0.4, 0.13)
        T.add(i * 8 * beat, A.pad([c + 12 for c in ch], 8 * beat + 2, 3000, 0.003), 0.4, 0.05)
    for i, ch in enumerate(chords):
        notes = [c + 12 for c in ch] + [ch[2] + 24]
        for k in range(16):
            if rng.random() < 0.55:
                T.add((i * 8 + k * 0.5) * beat, A.glass(notes[(k * 2 + i) % len(notes)], 3.0), A.np.sin(k * 0.9 + i) * 0.8, 0.075)
    for k in range(12):
        T.add(rng.random() * bars * 4 * beat, A.bell(86 + int(rng.choice([0, 2, 4, 6, 7, 11])), 6, 0.3), rng.uniform(-1, 1), 0.03)
    return T.finish(7.0, 0.65, 5000, 0.36)


if __name__ == "__main__":
    for name in os.environ.get("ONLY", "lunar,moon").split(","):
        A.save(name, globals()[name]())
