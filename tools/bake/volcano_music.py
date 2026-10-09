"""Composes the music inside Glamrax's volcano and saves it as looping OGG files.

    lab.ogg      the Laboratory: cold, clinical high tech; a sequenced synth arpeggio over a pulsing bass and pads
    mecha.ogg    the Anti-Personnel Mecha Mk II: industrial and relentless; distorted bass, alarms, metal and brass
    cells.ogg    the Cell Block: tense and sparse; a ticking clock, a slow siren sweep, electric crackle, low drones
    piano.ogg    Glamrax at his piano: a dramatic minor-key piece (the game cuts it off mid-phrase when he stops)
    glamrax.ogg  the Glamrax fight: an organ and choir over pounding drums and a racing harpsichord
    finale.ogg   the ending: warm and hopeful, strings and a gentle piano in D major

Everything is synthesised with numpy (no samples), sharing the instruments and the seamless-loop Track of
abyss_music.py and climb_music.py. Every track reseeds the random generator, so the output is deterministic.

Usage:  python3 tools/bake/volcano_music.py [godot]          (ONLY=lab,piano ... to render some of them)
Needs:  Python 3 with numpy, and ffmpeg (for OGG encoding).
"""
import os
import sys

import numpy as np

sys.dont_write_bytecode = True
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import abyss_music as am  # noqa: E402
import climb_music as cm  # noqa: E402
from abyss_music import SR, Track, bell, choir, env, glass, hz, kick, lp_fast, pad, save, sub, tom  # noqa: E402
from climb_music import bp, brass, horn, snare, strings, taiko, timpani_roll  # noqa: E402


def seed(n):
    global rng
    rng = np.random.default_rng(n)
    cm.seed(n + 500)
    am.rng = np.random.default_rng(n + 1000)


rng = np.random.default_rng(0)


# ---------------------------------------------------------------- new instruments
def piano(m, dur=2.5, vel=1.0):
    """a piano: slightly stretched partials, a hammer knock, upper partials dying fast"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    B = 0.0004
    s = np.zeros(n)
    for k in range(1, 9):
        fk = f * k * np.sqrt(1 + B * k * k)
        if fk > 9000:
            break
        decay = 1.1 + 0.9 * k + f / 600
        s += np.sin(2 * np.pi * fk * t + rng.random() * 0.3) * np.exp(-t * decay) / k ** (1.4 - 0.4 * vel)
    s += lp_fast(rng.standard_normal(n), 2500) * np.exp(-t * 60) * 0.15 * vel   # the hammer
    rel = np.clip((dur - t) / 0.08, 0, 1)
    return s * np.minimum(1, t / 0.002) * rel * (0.5 + 0.5 * vel)


def harpsi(m, dur=0.5):
    """a plucked harpsichord-ish string: bright, thin, quick to die"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    raw = am.saw(hz(m), n, 0.002) * 0.6 + np.sign(np.sin(2 * np.pi * hz(m) * 2 * t)) * 0.2
    raw = bp(raw, 300, 5000)
    return raw * np.exp(-t * 7) * np.minimum(1, t / 0.001)


def organ(notes, dur, bright=1.0):
    """a pipe organ: drawbar sines at 16', 8', 4', 2 2/3', 2' with a slow swell and a breathy chiff"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in notes:
        f = hz(m)
        for mul, g in ((0.5, 0.6), (1, 1.0), (2, 0.6 * bright), (3, 0.35 * bright), (4, 0.3 * bright), (6, 0.12 * bright)):
            s += np.sin(2 * np.pi * f * mul * t + rng.random() * 6) * g
    s /= len(notes) * 2.4
    s += lp_fast(rng.standard_normal(n), 3000) * np.exp(-t * 18) * 0.05
    return s * np.minimum(1, t / 0.06) * np.clip((dur - t) / 0.25, 0, 1)


def pluck(m, dur=0.3, cut=2400, pw=0.3):
    """a sequencer synth blip: a pulse wave through a snappy filter"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    ph = (hz(m) * t + rng.random()) % 1.0
    raw = np.where(ph < pw, 1.0, -1.0)
    dark, lit = lp_fast(raw, 400), lp_fast(raw, cut)
    fe = np.exp(-t * 24)
    return (lit * fe + dark * (1 - fe)) * np.exp(-t * 6) * np.minimum(1, t / 0.002)


def hat(dur=0.08, bright=7000):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = rng.standard_normal(n) - lp_fast(rng.standard_normal(n), bright)
    return s * np.exp(-t * 60)


def tick(dur=0.05):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return np.sin(2 * np.pi * 2400 * t) * np.exp(-t * 140) + bp(rng.standard_normal(n), 2000, 6000) * np.exp(-t * 200) * 0.5


def siren(dur, lo=440, hi=660, rate=0.5):
    """a slow alarm sweep, softened so it sits under the music"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = lo + (hi - lo) * (0.5 - 0.5 * np.cos(2 * np.pi * rate * t))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) + 0.3 * np.sin(4 * np.pi * np.cumsum(f) / SR)
    return lp_fast(s, 1800) * np.sin(np.pi * t / dur) ** 0.5


def zap(dur=0.25):
    """an electric crackle"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = bp(rng.standard_normal(n), 1500, 7000) * (rng.random(n) < 0.25)
    s += np.sign(np.sin(2 * np.pi * (120 + 40 * rng.random()) * t)) * 0.2
    return s * np.exp(-t * 14)


def clang(m, dur=1.6):
    """struck metal: inharmonic partials"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    s = sum(np.sin(2 * np.pi * f * r * t) * np.exp(-t * d) * g for r, d, g in ((1, 3, 1), (2.41, 5, 0.6), (3.77, 7, 0.4), (5.93, 10, 0.3)))
    return s * np.minimum(1, t / 0.001) + bp(rng.standard_normal(n), 2000, 8000) * np.exp(-t * 40) * 0.3


def dist_bass(m, dur, drive=4.0, cut=900):
    n = int(dur * SR)
    s = np.tanh(drive * (am.saw(hz(m), n, 0.01) + 0.6 * np.sin(2 * np.pi * hz(m - 12) * np.arange(n) / SR)))
    return lp_fast(s, cut) * env(n, 0.003, min(0.08, dur * 0.3), hold=dur * 0.7)


# ---------------------------------------------------------------- the Laboratory (F# minor, 100 bpm, 16 bars)
def lab():
    seed(61)
    bpm = 100
    beat = 60 / bpm
    bars = 16
    T = Track(bars * 4 * beat)
    prog = [[42, 49, 54, 57], [38, 45, 50, 54], [45, 52, 57, 61], [40, 47, 52, 56]]   # F#m D A E
    for bar in range(bars):
        ch = prog[(bar // 2) % 4]
        t0 = bar * 4 * beat
        if bar % 2 == 0:
            T.add(t0, pad([c + 12 for c in ch], 8 * beat + 1, 1100, 0.004), -0.5, 0.12)
            T.add(t0, pad(ch, 8 * beat + 1, 600, 0.004), 0.5, 0.14)
        # the arpeggio: sixteenths, up and over, panned in a slow sweep
        arp = [ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[2] + 24, ch[3] + 12, ch[2] + 12]
        for k in range(16):
            m = arp[k % len(arp)]
            T.add(t0 + k * beat / 4, pluck(m, 0.25, 1800 + 1400 * (k % 4 == 0)), np.sin(k * 0.4 + bar) * 0.6, 0.07)
        # pulsing bass in eighths
        for k in range(8):
            T.add(t0 + k * beat / 2, sub(ch[0] - 12, beat * 0.4, 2.0), 0, 0.2 if k % 2 == 0 else 0.13)
        # a soft machine beat: kick on 1 and 3, hats on the offbeats, a rim on 4 from bar 4
        T.add(t0, kick(0.5, 100, 40), 0, 0.32)
        T.add(t0 + 2 * beat, kick(0.5, 100, 40), 0, 0.26)
        for k in range(4):
            T.add(t0 + (k + 0.5) * beat, hat(), 0.3, 0.05)
        if bar >= 4:
            T.add(t0 + 3 * beat, lp_fast(snare(0.2), 3000), -0.2, 0.08)
    # computer chirps: high glassy blips scattered like data
    for k in range(40):
        T.add(rng.random() * bars * 4 * beat, pluck(84 + int(rng.integers(0, 12)), 0.08, 5000, 0.5), rng.uniform(-1, 1), 0.025)
    # a cold lead on top in the second half
    mel = [(32, 73, 2), (34, 76, 2), (36, 78, 3), (39, 76, 1), (40, 74, 4), (44, 73, 4),
           (48, 69, 2), (50, 73, 2), (52, 76, 4), (56, 75, 2), (58, 71, 2), (60, 73, 4)]
    for b, m, d in mel:
        T.add(b * beat, glass(m, d * beat + 1.0), 0.2, 0.08)
    return T.finish(2.2, 0.28, 3600, 0.55)


# ---------------------------------------------------------------- the Mk II (C# phrygian, 140 bpm, 24 bars)
def mecha():
    seed(67)
    bpm = 140
    beat = 60 / bpm
    bars = 24
    T = Track(bars * 4 * beat)
    roots = [37, 37, 38, 37, 35, 35, 38, 36]
    riff = [0, 0, 12, 0, 1, 0, 7, 6]
    for bar in range(bars):
        r = roots[(bar // 2) % len(roots)]
        t0 = bar * 4 * beat
        lvl = 0.8 + 0.2 * min(1, bar / 8)
        for k, o in enumerate(riff):
            T.add(t0 + k * beat / 2, dist_bass(r + o, beat * 0.45), 0, 0.2 * lvl)
        # pounding industrial drums: kick on every beat, snare on 2 and 4, metal on the offbeats
        for b in range(4):
            T.add(t0 + b * beat, kick(0.4, 140, 42), 0, 0.42)
            T.add(t0 + (b + 0.5) * beat, hat(0.05, 8000), 0.4, 0.07)
        for b in (1, 3):
            T.add(t0 + b * beat, snare(0.3), 0.1, 0.22)
            T.add(t0 + b * beat, clang(73, 0.4), -0.3, 0.05)
        if bar % 4 == 3:
            for k in range(8):
                T.add(t0 + (2 + k * 0.25) * beat, tom(52 - k * 2, 0.4), -0.6 + k * 0.17, 0.26)
        # brass hits from bar 8
        if bar >= 8:
            ch = [r + 12, r + 19, r + 24]
            T.add(t0, brass(ch, beat * 0.5), -0.3, 0.2)
            T.add(t0 + 2.5 * beat, brass([c + 1 for c in ch], beat * 0.4), 0.3, 0.16)
    # the alarm: a siren sweep every four bars
    for bar in range(0, bars, 4):
        T.add(bar * 4 * beat, siren(4 * beat, 520, 780, 0.5), 0.6, 0.05)
    # big metal clangs on the phrase starts
    for bar in range(0, bars, 8):
        T.add(bar * 4 * beat, clang(37, 2.4), 0, 0.2)
    return T.finish(1.4, 0.18, 3200, 0.62)


# ---------------------------------------------------------------- the Cell Block (B minor, 80 bpm, 16 bars)
def cells():
    seed(71)
    bpm = 80
    beat = 60 / bpm
    bars = 16
    L = bars * 4 * beat
    T = Track(L)
    drones = [[35, 42, 47], [35, 42, 48], [34, 41, 47], [35, 42, 47]]
    for i, ch in enumerate(drones):
        t0 = i * 16 * beat
        T.add(t0, pad(ch, 16 * beat + 2, 500, 0.003), -0.4, 0.26)
        T.add(t0, strings([c + 12 for c in ch], 16 * beat + 2, 700, 2.0), 0.4, 0.12)
        T.add(t0, sub(23, 16 * beat, 1.0), 0, 0.2)
    # the clock: a tick on every eighth, a heavier one each beat
    for k in range(bars * 8):
        T.add(k * beat / 2, tick(), 0.5 if k % 2 else -0.5, 0.06 if k % 2 else 0.1)
    # a heartbeat kick every other bar, then every bar in the second half
    for bar in range(bars):
        if bar % 2 == 0 or bar >= 8:
            T.add(bar * 4 * beat, lp_fast(kick(0.6, 70, 34), 300), 0, 0.42)
            T.add(bar * 4 * beat + 0.28, lp_fast(kick(0.5, 64, 34), 300), 0, 0.26)
    # a low siren that sweeps through every so often, and the cells crackling
    for t in (2, 18, 34):
        T.add(t, siren(8, 220, 330, 0.25), rng.uniform(-0.6, 0.6), 0.07)
    for k in range(30):
        T.add(rng.random() * L, zap(rng.uniform(0.1, 0.3)), rng.uniform(-1, 1), 0.04)
    # a dissonant pizzicato figure creeping in the second half
    fig = [59, 60, 59, 55, 54, 55, 59, 62]
    for bar in range(8, bars):
        for k, m in enumerate(fig):
            if k % 2 == 0 or bar >= 12:
                T.add(bar * 4 * beat + k * beat / 2, cm.pizz(m, 0.35), 0.3, 0.12)
    # a growl from a cell, far off
    for t in (11, 31, 41):
        T.add(t, cm.growl(30, 3.0), rng.uniform(-0.8, 0.8), 0.3)
    return T.finish(3.0, 0.38, 2600, 0.5)


# ---------------------------------------------------------------- Glamrax's piano (D minor, 72 bpm, 16 bars)
def piano_piece():
    seed(73)
    bpm = 72
    beat = 60 / bpm
    bars = 16
    T = Track(bars * 4 * beat)
    # Dm  Bb  Gm  A | Dm  F  Gm  A7 | Bb  Gm  Edim  A | Dm  Gm  A  Dm
    prog = [[38, 50, 53, 57], [34, 50, 53, 58], [31, 50, 55, 58], [33, 49, 52, 57],
            [38, 50, 53, 57], [41, 48, 53, 57], [31, 50, 55, 58], [33, 49, 55, 57],
            [34, 50, 53, 58], [31, 50, 55, 58], [40, 49, 55, 58], [33, 49, 52, 57],
            [38, 50, 53, 57], [31, 50, 55, 58], [33, 49, 52, 57], [38, 50, 53, 57]]
    for bar, ch in enumerate(prog):
        t0 = bar * 4 * beat
        # the left hand: a deep octave on 1, then rolling triplet arpeggios
        T.add(t0, piano(ch[0] - 12, 4 * beat + 0.5, 1.0), -0.3, 0.3)
        T.add(t0, piano(ch[0], 4 * beat + 0.5, 0.9), -0.3, 0.22)
        arp = [ch[1], ch[2], ch[3], ch[2] + 12, ch[3], ch[2]]
        for k in range(12):
            T.add(t0 + k * beat / 3, piano(arp[k % 6], 1.4, 0.55 + 0.15 * (k % 3 == 0)), -0.1 + 0.05 * (k % 3), 0.12)
    # the right hand: a grand, brooding melody in octaves
    mel = [(0, 69, 2), (2, 74, 1.5), (3.5, 72, 0.5), (4, 70, 2), (6, 69, 2), (8, 67, 1.5), (9.5, 70, 0.5), (10, 74, 2), (12, 73, 4),
           (16, 69, 2), (18, 77, 1.5), (19.5, 76, 0.5), (20, 72, 2), (22, 74, 2), (24, 70, 2), (26, 74, 1), (27, 79, 1), (28, 76, 4),
           (32, 77, 1.5), (33.5, 76, 0.5), (34, 74, 2), (36, 79, 1.5), (37.5, 77, 0.5), (38, 74, 2), (40, 76, 1), (41, 77, 1), (42, 79, 2), (44, 81, 4),
           (48, 86, 2), (50, 84, 1), (51, 82, 1), (52, 79, 2), (54, 82, 2), (56, 81, 1.5), (57.5, 79, 0.5), (58, 76, 2), (60, 74, 4)]
    for b, m, d in mel:
        T.add(b * beat, piano(m, d * beat + 1.2, 1.0), 0.2, 0.26)
        T.add(b * beat, piano(m - 12, d * beat + 1.2, 0.8), 0.15, 0.14)
    # a low cello doubling the bass, very quietly, so the room feels vast
    for bar, ch in enumerate(prog):
        T.add(bar * 4 * beat, strings([ch[0]], 4 * beat + 0.6, 500, 0.4), -0.5, 0.08)
    return T.finish(3.4, 0.42, 3000, 0.55)


# ---------------------------------------------------------------- the Glamrax fight (D minor, 152 bpm, 32 bars)
def glamrax():
    seed(79)
    bpm = 152
    beat = 60 / bpm
    bars = 32
    T = Track(bars * 4 * beat)
    prog = [[38, 45, 50, 53], [39, 46, 51, 55], [36, 43, 48, 51], [37, 44, 49, 52]]   # Dm Eb Cm Db: dark and unstable
    for bar in range(bars):
        ch = prog[(bar // 2) % 4] if bar < 16 else [[38, 45, 50, 53], [34, 41, 46, 50], [36, 43, 48, 52], [37, 45, 49, 52]][(bar // 2) % 4]
        t0 = bar * 4 * beat
        lvl = 0.8 + 0.2 * min(1, bar / 8)
        if bar % 2 == 0:
            T.add(t0, organ([c + 12 for c in ch], 8 * beat + 0.3, 1.0), -0.35, 0.2 * lvl)
            T.add(t0, organ([ch[0] - 12, ch[0]], 8 * beat + 0.3, 0.5), 0.35, 0.18)
            T.add(t0, choir([c + 24 for c in ch[1:]], 8 * beat + 0.4, 1600), 0.2, 0.14 * lvl)
        # the racing harpsichord: sixteenth-note runs climbing through the chord
        run = [ch[1], ch[2], ch[3], ch[1] + 12, ch[2] + 12, ch[3] + 12, ch[1] + 24, ch[3] + 12]
        for k in range(16):
            m = run[k % 8] if (bar + k // 8) % 2 == 0 else run[7 - k % 8]
            T.add(t0 + k * beat / 4, harpsi(m + 12, 0.3), np.sin(k * 0.6) * 0.5, 0.08)
        # drums: driving kick, snare on 2 and 4, toms rolling at phrase ends, timpani on the downbeat
        for b in range(4):
            T.add(t0 + b * beat, kick(0.35, 150, 44), 0, 0.36 * lvl)
            T.add(t0 + (b + 0.5) * beat, kick(0.3, 140, 44), 0, 0.18 * lvl)
        for b in (1, 3):
            T.add(t0 + b * beat, snare(0.3), 0.1, 0.2)
        T.add(t0, taiko(1.2, 95, 44), 0, 0.3)
        if bar % 4 == 3:
            T.add(t0 + 2 * beat, timpani_roll(38, 2 * beat), 0, 0.5)
        T.add(t0, sub(ch[0] - 12, 4 * beat * 0.95, 2.0), 0, 0.22)
        # brass stabs in the second half
        if bar >= 16:
            T.add(t0, brass([ch[0] + 12, ch[1] + 12, ch[2] + 12], beat * 0.6), -0.3, 0.2)
            T.add(t0 + 1.5 * beat, brass([ch[0] + 12, ch[1] + 12, ch[2] + 12], beat * 0.4), 0.3, 0.15)
    # his theme on the horns: the piano melody again, now in full cry
    mel = [(0, 69, 2), (2, 74, 1.5), (3.5, 72, 0.5), (4, 70, 2), (6, 69, 2), (8, 67, 1.5), (9.5, 70, 0.5), (10, 74, 2), (12, 73, 4)]
    for rep in (32, 64, 96):
        for b, m, d in mel:
            T.add((rep + b * 2) * beat, horn(m - 12, d * 2 * beat * 0.97 + 0.15, 1600, 0.006), 0.1, 0.22)
            T.add((rep + b * 2) * beat, choir([m], d * 2 * beat + 0.2, 2200), -0.15, 0.08)
    for b in (0, 64):
        T.add(b * beat, bell(50, 6, 0.8), 0, 0.16)
    return T.finish(2.0, 0.24, 3000, 0.62)


# ---------------------------------------------------------------- the ending (D major, 76 bpm, 16 bars)
def finale():
    seed(83)
    bpm = 76
    beat = 60 / bpm
    bars = 16
    T = Track(bars * 4 * beat)
    prog = [[38, 50, 54, 57], [43, 50, 55, 59], [35, 50, 54, 59], [45, 49, 52, 57],
            [38, 50, 54, 57], [43, 50, 55, 59], [45, 49, 52, 57], [38, 50, 54, 57]]   # D G Bm A, D G A D
    for i, ch in enumerate(prog):
        t0 = i * 8 * beat
        T.add(t0, strings(ch, 8 * beat + 1.0, 1400, 1.2), -0.3, 0.24)
        T.add(t0, pad([c + 12 for c in ch[1:]], 8 * beat + 1.5, 1800, 0.006), 0.4, 0.08)
        T.add(t0, sub(ch[0] - 12, 8 * beat, 1.0), 0, 0.18)
        for k in range(16):
            arp = [ch[1], ch[2], ch[3], ch[2] + 12]
            T.add(t0 + k * beat / 2, piano(arp[k % 4] + 12, 1.6, 0.5), 0.2, 0.08)
    mel = [(0, 66, 2), (2, 69, 2), (4, 74, 4), (8, 71, 2), (10, 74, 2), (12, 79, 4), (16, 78, 3), (19, 76, 1), (20, 74, 2), (22, 71, 2),
           (24, 73, 4), (28, 76, 4), (32, 78, 2), (34, 81, 2), (36, 86, 4), (40, 83, 2), (42, 79, 2), (44, 83, 4),
           (48, 81, 2), (50, 78, 2), (52, 76, 2), (54, 73, 2), (56, 74, 8)]
    for b, m, d in mel:
        T.add(b * beat, horn(m - 12, d * beat * 0.97 + 0.2, 1500, 0.006), 0.1, 0.18)
        T.add(b * beat, glass(m + 12, d * beat + 1.5), -0.3, 0.04)
    for b in (0, 32):
        T.add(b * beat, bell(74, 5, 0.5), -0.5, 0.06)
        T.add(b * beat, bell(81, 5, 0.4), 0.5, 0.05)
    return T.finish(3.2, 0.36, 3600, 0.52)


if __name__ == "__main__":
    which = os.environ.get("ONLY", "lab,mecha,cells,piano,glamrax,finale").split(",")
    for name in which:
        save(name, globals()["piano_piece" if name == "piano" else name]())
