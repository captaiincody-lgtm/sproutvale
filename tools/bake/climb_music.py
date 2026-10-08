"""Composes the music for the climb up the Abyssal Volcano and saves it as looping OGG files.

    climb.ogg  maps 1 and 2 (rock, then the blizzard): adventurous but cold and lonely, a horn over a pizzicato ostinato
    cave.ogg   the ice cave: sparse and tense, deep drones, distant chimes, drips and something big breathing
    yeti.ogg   the King Yeti boss fight: pounding war drums, a driving low ostinato, brass stabs and a fierce choir
    peak.ogg   the summit before Glamrax's lair: big choir, slow heavy drums and a soaring, ominous melody

Everything is synthesised with numpy (no samples), sharing the instruments and the seamless-loop Track of
abyss_music.py. Each track is rendered one loop long plus its echo tail, and the tail is folded back onto the
start so the loop is seamless. Every track reseeds the random generator, so the output is deterministic.

Usage:  python3 tools/bake/climb_music.py [godot]
Needs:  Python 3 with numpy, and ffmpeg (for OGG encoding).
"""
import os
import sys

import numpy as np

sys.dont_write_bytecode = True  # importing abyss_music should not leave a __pycache__ in the repo
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import abyss_music as am  # noqa: E402
from abyss_music import (SR, Track, bell, choir, drip, env, glass, hz, kick, lp_fast,  # noqa: E402
                         noise_hit, pad, save, sub, tom)


def seed(n):
    """reseed both this script's and abyss_music's generators, so each track renders the same on its own"""
    global rng
    rng = np.random.default_rng(n)
    am.rng = np.random.default_rng(n + 1000)


rng = np.random.default_rng(0)


# ---------------------------------------------------------------- new instruments
def vsaw(f, n, detune=0.0, vib=0.0, rate=5.0, voices=3):
    """detuned saws with a gentle vibrato (phase accumulated, so the vibrato is clean)"""
    t = np.arange(n) / SR
    out = np.zeros(n)
    for k in range(voices):
        d = 0.0 if voices == 1 else detune * (2 * k / (voices - 1) - 1)
        v = 1 + vib * np.sin(2 * np.pi * (rate + 0.3 * k) * t + rng.random() * 6.28)
        p = (np.cumsum(f * (1 + d) * v) / SR + rng.random()) % 1.0
        out += 2 * p - 1
    return out / voices


def bp(x, lo, hi):
    return lp_fast(x, hi) - lp_fast(x, lo)


def strings(notes, dur, bright=1100, attack=0.6):
    """a low string section: many detuned saws with vibrato, slow bow-in and bow-out"""
    n = int(dur * SR)
    s = sum(vsaw(hz(m), n, 0.005, 0.003, 5.0, 5) for m in notes) / len(notes)
    s = lp_fast(s, bright)
    t = np.arange(n) / SR
    rel = min(1.2, dur * 0.3)
    return s * np.minimum(1, t / attack) * np.clip((dur - t) / rel, 0, 1)


def horn(m, dur, bright=1300, vib=0.004):
    """a french-horn-like voice: soft saw blend whose filter opens with the swell of the note"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + vib * np.sin(2 * np.pi * 4.8 * t) * np.minimum(1, t / 0.8))  # vibrato eases in
    ph = np.cumsum(f) / SR
    raw = sum((2 * ((ph * (1 + d) + rng.random()) % 1.0) - 1) for d in (-0.003, 0.0, 0.003)) / 3 * 0.7
    raw += np.sin(2 * np.pi * ph) * 0.5
    dark, lit = lp_fast(raw, bright * 0.45), lp_fast(raw, bright)
    swell = np.minimum(1, t / 0.18) * np.clip((dur - t) / min(0.4, dur * 0.4), 0, 1)
    return (dark * (1 - swell) + lit * swell) * swell


def brass(notes, dur, bright=2400, punch=0.09):
    """a brass stab: detuned saws, a filter that blares open then closes, a hard attack"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    raw = sum(vsaw(hz(m), n, 0.008, 0.0, 5.0, 3) for m in notes) / len(notes)
    dark, lit = lp_fast(raw, 500), lp_fast(raw, bright)
    fe = np.exp(-t / punch)
    s = lit * fe + dark * (1 - fe)
    s = np.tanh(s * 2.2) / 1.6
    return s * np.minimum(1, t / 0.006) * np.clip((dur - t) / min(0.12, dur * 0.4), 0, 1)


def pizz(m, dur=0.45):
    """a pizzicato pluck: a bright saw snap that dies fast"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    raw = vsaw(hz(m), n, 0.002, 0.0, 5.0, 2)
    dark, lit = lp_fast(raw, 450), lp_fast(raw, 2200)
    fe = np.exp(-t * 30)
    return (lit * fe + dark * (1 - fe)) * np.exp(-t * 8) * np.minimum(1, t / 0.002)


def taiko(dur=1.2, f0=95, f1=48, body=1.0):
    """a war drum: a deep pitched thud with a skin slap and a long boom"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 14)
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 3.2) * body
    s += 0.5 * np.sin(2 * np.pi * np.cumsum(f * 1.58) / SR) * np.exp(-t * 7)
    s += lp_fast(rng.standard_normal(n), 1400) * np.exp(-t * 32) * 0.7
    return np.tanh(s * 1.4)


def snare(dur=0.35):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = bp(rng.standard_normal(n), 900, 6000) * np.exp(-t * 16) * 0.8
    s += np.sin(2 * np.pi * 190 * t) * np.exp(-t * 25) * 0.6
    return s


def wind(dur, lo=250, hi=1800, whistle=True):
    """a gust: band-limited noise that swells and fades, with a faint hollow whistle riding on top"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = bp(rng.standard_normal(n), lo, hi)
    s *= 0.7 + 0.3 * np.sin(2 * np.pi * (0.4 + rng.random() * 0.3) * t + rng.random() * 6)  # gusting
    if whistle:
        fw = 700 + 250 * np.sin(2 * np.pi * 0.13 * t + rng.random() * 6)
        s += 0.08 * np.sin(2 * np.pi * np.cumsum(fw) / SR) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.31 * t))
    shape = np.sin(np.pi * t / dur) ** 2
    return s * shape


def growl(m, dur):
    """something big breathing in the dark: a low, rough saw that sags in pitch, buried in noise"""
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 - 0.06 * t / dur)
    rough = 1 + 0.25 * lp_fast(rng.standard_normal(n), 30)
    s = (2 * ((np.cumsum(f * rough) / SR) % 1.0) - 1)
    s = lp_fast(s, 220) + lp_fast(rng.standard_normal(n), 160) * 0.5
    return s * np.sin(np.pi * t / dur) ** 1.5


def timpani_roll(m, dur, crescendo=True):
    out = np.zeros(int((dur + 1.5) * SR))
    k, step = 0, 0.07
    while k * step < dur:
        g = (0.25 + 0.75 * k * step / dur) if crescendo else 1.0
        s = tom(m, 1.0) * g * (0.8 + 0.2 * rng.random())
        i = int(k * step * SR)
        out[i:i + len(s)] += s[: len(out) - i]
        k += 1
    return out * 0.3


# ---------------------------------------------------------------- the climb (A minor, 88 bpm, 24 bars)
def climb():
    seed(11)
    bpm = 88
    beat = 60 / bpm
    bars = 24
    T = Track(bars * 4 * beat)
    # two bars per chord: Am F C G | Am F Dm E | F G Em Am
    prog = [[45, 52, 57, 60], [41, 48, 57, 60], [48, 52, 55, 60], [43, 50, 55, 59],
            [45, 52, 57, 60], [41, 48, 53, 57], [38, 45, 53, 57], [40, 47, 52, 56],
            [41, 48, 53, 57], [43, 50, 55, 59], [40, 47, 52, 55], [45, 52, 57, 60]]
    for i, ch in enumerate(prog):
        t0 = i * 8 * beat
        T.add(t0, strings(ch, 8 * beat + 0.8, 1000), -0.35, 0.26)
        T.add(t0, pad([c + 12 for c in ch[1:]], 8 * beat + 1.2, 1600, 0.008), 0.4, 0.07)
        T.add(t0, sub(ch[0] - 12, 8 * beat, 1.2), 0, 0.26)
        # the ostinato: a restless pizzicato in eighths (root, fifth, octave, fifth, minor third ...)
        r = ch[0] + 12 if ch[0] < 45 else ch[0]
        third = 3 if i not in (2, 3, 7, 9) else 4  # C, G, E chords are major
        pat = [0, 7, 12, 7, third + 12, 7, 12, 7]
        for b in range(2):
            for k, o in enumerate(pat):
                acc = 1.0 if k in (0, 4) else 0.7
                T.add(t0 + b * 4 * beat + k * beat / 2, pizz(r + o), 0.25 - 0.1 * (k % 2), 0.17 * acc)
        # a soft, distant march: low tom on 1, a muffled thud on the "and" of 3
        for b in range(2):
            tb = t0 + b * 4 * beat
            T.add(tb, lp_fast(taiko(1.0, 80, 44, 0.8), 600), 0, 0.22)
            T.add(tb + 2.5 * beat, lp_fast(tom(40, 0.6), 500), 0.2, 0.18)
            T.add(tb + 3 * beat, lp_fast(tom(43, 0.6), 500), -0.2, 0.14)
    # the horn: a long-breathed adventuring tune (beats, note, length), enters at bar 2
    mel = [(8, 69, 3), (11, 72, 1), (12, 71, 2), (14, 69, 2), (16, 65, 4), (20, 64, 2), (22, 65, 2),
           (24, 67, 3), (27, 64, 1), (28, 67, 2), (30, 71, 2), (32, 69, 6),
           (40, 72, 3), (43, 74, 1), (44, 76, 4), (48, 77, 2), (50, 76, 2), (52, 74, 3), (55, 72, 1),
           (56, 71, 3), (59, 72, 1), (60, 68, 4),
           (64, 69, 2), (66, 72, 2), (68, 76, 4), (72, 74, 2), (74, 72, 2), (76, 71, 4),
           (80, 72, 2), (82, 71, 2), (84, 67, 4), (88, 69, 8)]
    for b, m, d in mel:
        T.add(b * beat, horn(m - 12, d * beat * 0.97 + 0.15, 1200), 0.1, 0.22)
        T.add(b * beat, horn(m - 24, d * beat * 0.97 + 0.15, 700), -0.1, 0.07)  # low doubling for weight
    # icy accents: bells at phrase starts and glass sparkles that drift like snow
    for b in (0, 32, 64):
        T.add(b * beat, bell(81, 5, 0.5), -0.6, 0.06)
        T.add(b * beat + 0.5 * beat, bell(88, 4, 0.4), 0.6, 0.035)
    notes = [69, 72, 76, 79, 81, 84, 88]
    for k in range(26):
        T.add(rng.random() * bars * 4 * beat, glass(notes[int(rng.integers(0, len(notes)))] + 12, 2.5),
              rng.uniform(-0.9, 0.9), 0.035)
    # wind swells now and then
    for t, d, p in ((5, 9, -0.5), (26, 8, 0.6), (44, 10, -0.3), (58, 7, 0.4)):
        T.add(t, wind(d), p, 0.18)
    return T.finish(3.0, 0.38, 3200, 0.52)


# ---------------------------------------------------------------- the ice cave (D minor drones, 50 bpm, 14 bars)
def cave():
    seed(23)
    bpm = 50
    beat = 60 / bpm
    bars = 14
    L = bars * 4 * beat
    T = Track(L)
    # drones that barely move: D, then Eb pulls against it, then back
    drones = [[38, 45, 50], [38, 45, 51], [37, 44, 50], [38, 45, 50], [38, 46, 51], [36, 43, 50], [38, 45, 49]]
    for i, ch in enumerate(drones):
        t0 = i * 8 * beat
        T.add(t0, pad(ch, 8 * beat + 3, 420, 0.004), -0.4, 0.32)
        T.add(t0, strings([c + 12 for c in ch], 8 * beat + 3, 650, 3.0), 0.4, 0.14)
        T.add(t0, sub(26, 8 * beat + 1, 1.0), 0, 0.20)
    # a cold, wordless breath of choir every other chord
    for i, ch in ((1, [62, 63]), (3, [62, 69]), (5, [61, 62])):
        T.add(i * 8 * beat + beat, choir(ch, 7 * beat, 900), rng.uniform(-0.6, 0.6), 0.09)
    # the pulse: a slow muffled double beat, like a heart under ice
    for b in range(bars * 4):
        if b % 2 == 0:
            T.add(b * beat, lp_fast(kick(0.6, 62, 30), 220), 0, 0.45)
            T.add(b * beat + 0.3, lp_fast(kick(0.5, 58, 30), 220), 0, 0.26)
    # distant ice chimes, a few at a time, far off to the sides
    chime = [74, 76, 77, 81, 82, 86, 89]
    for k in range(18):
        t = rng.random() * L
        for j in range(int(rng.integers(1, 4))):
            T.add(t + j * rng.uniform(0.15, 0.45), glass(chime[int(rng.integers(0, len(chime)))] + 12, 3.5),
                  rng.uniform(-1, 1), 0.05)
    for k in range(5):
        T.add(rng.random() * L, bell(86 + int(rng.choice([0, 1, 5])), 6, 0.5), rng.uniform(-0.9, 0.9), 0.03)
    # drips everywhere, at random times and places, sometimes in pairs
    for k in range(70):
        t = rng.random() * L
        p = rng.uniform(-1, 1)
        g = rng.uniform(0.04, 0.1)
        m = 80 + int(rng.integers(0, 14))
        T.add(t, drip(m), p, g)
        if rng.random() < 0.3:
            T.add(t + rng.uniform(0.08, 0.2), drip(m + int(rng.integers(-2, 3))), p, g * 0.6)
    # something big: a low growl and the scrape of weight shifting on ice
    for t, m in ((12, 26), (36, 25), (57, 27)):
        T.add(t, growl(m, 4.5), rng.uniform(-0.4, 0.4), 0.42)
    for k in range(4):
        T.add(rng.random() * L, lp_fast(noise_hit(2.5, 260, 1.4), 200), rng.uniform(-0.6, 0.6), 0.25)
    # thin icy wind leaking in
    T.add(20, wind(12, 900, 3500, False), -0.7, 0.05)
    T.add(46, wind(10, 900, 3500, False), 0.7, 0.05)
    return T.finish(5.5, 0.5, 2600, 0.48)


# ---------------------------------------------------------------- King Yeti (E minor/phrygian, 128 bpm, 32 bars)
def yeti():
    seed(37)
    bpm = 128
    beat = 60 / bpm
    bars = 32
    T = Track(bars * 4 * beat)
    roots = [40, 40, 41, 40, 38, 38, 36, 35]  # E E F E D D C B, two bars each, played twice
    ost = [0, 0, 12, 0, 3, 0, 7, 1]
    for bar in range(bars):
        r = roots[(bar // 2) % len(roots)]
        t0 = bar * 4 * beat
        lvl = 0.75 + 0.25 * min(1, bar / 16)  # intensity builds over the first half
        # the driving low ostinato: sub and a gritty saw an octave up, in eighths
        for k, o in enumerate(ost):
            n8 = int(beat * 0.46 * SR)
            T.add(t0 + k * beat / 2, sub(r + o - 12, beat * 0.46, 3.0), 0, 0.28 * lvl)
            grit = lp_fast(np.tanh(2.5 * am.saw(hz(r + o), n8, 0.012)) * env(n8, 0.004, 0.1), 1500)
            T.add(t0 + k * beat / 2, grit, 0.25, 0.14 * lvl)
        # war drums: boom on 1 and the "and" of 2, a big pair on 3, toms answering
        T.add(t0, taiko(1.3, 100, 46), 0, 0.5 * lvl)
        T.add(t0 + 1.5 * beat, taiko(1.0, 95, 50), -0.2, 0.36 * lvl)
        T.add(t0 + 2 * beat, taiko(1.2, 100, 46), 0.15, 0.46 * lvl)
        T.add(t0 + 2.5 * beat, taiko(1.0, 90, 52), -0.15, 0.3 * lvl)
        T.add(t0 + 3 * beat, tom(43), 0.4, 0.3 * lvl)
        T.add(t0 + 3.5 * beat, tom(40), -0.4, 0.3 * lvl)
        if bar >= 8:  # clattering snare backbeat once the fight is on
            for b in (1, 3):
                T.add(t0 + b * beat, snare(), 0.1, 0.16)
        if bar >= 16:  # double-time kick under the choir half
            for b in range(4):
                T.add(t0 + b * beat, kick(0.4, 130, 42), 0, 0.3)
        if bar % 4 == 3:  # a tom fill rolling down into the next phrase
            for k in range(6):
                T.add(t0 + (2.5 + k * 0.25) * beat, tom(50 - k * 2, 0.5), -0.6 + k * 0.24, 0.32)
    # brass stabs: from bar 4 on, on the 1 and the "and" of 2; longer blasts at phrase ends
    for bar in range(4, bars):
        r = roots[(bar // 2) % len(roots)]
        ch = [r + 12, r + 19, r + 24] if r != 41 else [r + 12, r + 19, r + 23]
        t0 = bar * 4 * beat
        g = 0.24 if bar < 16 else 0.28
        T.add(t0, brass(ch, beat * 0.6), -0.3, g)
        T.add(t0 + 1.5 * beat, brass(ch, beat * 0.4), 0.3, g * 0.8)
        if bar % 4 == 3:
            T.add(t0 + 2 * beat, brass([c + 1 for c in ch], beat * 1.4, 3000, 0.2), 0, g)
    # the fierce choir in the second half, two bars per chord, with a shout on each downbeat
    chords = [[64, 67, 71], [64, 67, 71], [65, 69, 72], [64, 67, 71], [62, 65, 69], [62, 66, 69], [60, 64, 67], [59, 63, 66]]
    for i, ch in enumerate(chords):
        t0 = (16 + 2 * i) * 4 * beat
        T.add(t0, choir(ch, 8 * beat + 0.4, 1700), -0.25, 0.26)
        T.add(t0, choir([c - 12 for c in ch], 8 * beat + 0.4, 900), 0.25, 0.2)
        T.add(t0, choir([ch[0] + 12], 1.0 * beat, 2600), 0, 0.12)
    # a pad under everything so the low end never empties
    for i in range(bars // 4):
        r = roots[(i * 2) % len(roots)]
        T.add(i * 16 * beat, pad([r, r + 7, r + 12], 16 * beat + 0.5, 600), 0, 0.12)
    return T.finish(1.8, 0.22, 3000, 0.62)


# ---------------------------------------------------------------- the summit (C minor, 72 bpm, 20 bars)
def peak():
    seed(53)
    bpm = 72
    beat = 60 / bpm
    bars = 20
    T = Track(bars * 4 * beat)
    # Cm Ab Eb Bb | Cm Ab Fm G | Ab Bb Cm Cm(Db) ... two bars per chord
    prog = [[48, 55, 60, 63], [44, 51, 56, 60], [51, 55, 58, 63], [46, 53, 58, 62], [48, 55, 60, 63],
            [44, 51, 56, 60], [41, 48, 53, 56], [43, 50, 55, 59], [44, 51, 56, 60], [43, 50, 55, 59]]
    for i, ch in enumerate(prog):
        t0 = i * 8 * beat
        # wide pads, hard left and right with different brightness
        T.add(t0, pad(ch, 8 * beat + 1.5, 900, 0.008), -0.8, 0.2)
        T.add(t0, pad([c + 12 for c in ch], 8 * beat + 1.5, 1500, 0.012), 0.8, 0.12)
        T.add(t0, strings([ch[0] - 12, ch[0]], 8 * beat + 1, 700, 0.3), 0, 0.22)
        T.add(t0, sub(ch[0] - 12, 8 * beat, 1.4), 0, 0.3)
        # the big choir
        T.add(t0, choir([c + 12 for c in ch[1:]], 8 * beat + 0.6, 1300), -0.3, 0.24)
        T.add(t0, choir(ch[:3], 8 * beat + 0.6, 800), 0.3, 0.16)
        # slow, powerful drums: a great boom on 1, a second on 3, a pickup before the next bar
        for b in range(2):
            tb = t0 + b * 4 * beat
            T.add(tb, taiko(2.0, 85, 40, 1.2), 0, 0.5)
            T.add(tb, kick(0.8, 90, 32), 0, 0.3)
            T.add(tb + 2 * beat, taiko(1.6, 90, 44), 0.1, 0.36)
            T.add(tb + 3.5 * beat, tom(38, 0.7), -0.3, 0.22)
            T.add(tb + 3.75 * beat, tom(36, 0.7), 0.3, 0.22)
        if i % 2 == 1:  # a timpani roll swelling into each new phrase
            T.add(t0 + 6 * beat, timpani_roll(36, 2 * beat), 0, 0.6)
    # the soaring melody: a horn line doubled by a high choir voice, heroic but in minor
    mel = [(8, 67, 2), (10, 72, 2), (12, 75, 3), (15, 74, 1), (16, 72, 4), (20, 68, 2), (22, 70, 2),
           (24, 75, 3), (27, 77, 1), (28, 79, 4), (32, 77, 2), (34, 75, 2), (36, 74, 4),
           (40, 72, 2), (42, 75, 2), (44, 79, 4), (48, 80, 3), (51, 79, 1), (52, 77, 2), (54, 75, 2),
           (56, 72, 2), (58, 77, 2), (60, 75, 3), (63, 74, 1), (64, 74, 4), (68, 71, 4),
           (72, 72, 4), (76, 74, 2), (78, 71, 2)]
    for b, m, d in mel:
        T.add(b * beat, horn(m - 12, d * beat * 0.97 + 0.2, 1500, 0.006), 0.1, 0.24)
        T.add(b * beat, horn(m - 24, d * beat * 0.97 + 0.2, 800), -0.1, 0.08)
        T.add(b * beat, choir([m], d * beat + 0.3, 2200), -0.15, 0.08)
    # ominous bells tolling at the start of each half, and wind across the summit
    for b in (0, 40):
        T.add(b * beat, bell(60, 7, 0.7), -0.4, 0.12)
        T.add(b * beat, bell(48, 7, 0.5), 0.4, 0.1)
    T.add(14, wind(10, 200, 1400), -0.5, 0.12)
    T.add(45, wind(10, 200, 1400), 0.5, 0.12)
    return T.finish(3.5, 0.36, 2800, 0.58)


if __name__ == "__main__":
    which = os.environ.get("ONLY", "climb,cave,yeti,peak").split(",")
    for name in which:
        save(name, globals()[name]())
