"""Composes the music for the areas beyond the Warlord's Keep and saves it as looping OGG files.

    abyss.ogg    the Abyss maps: slow, cold and heavy, a crimson pulse sinking into black water
    dreamer.ogg  The Dreamer's boss fight: a pounding, dread-filled ostinato under a wailing choir
    bubble.ogg   Inside the Bubble: quiet, glassy and mysterious

Everything is synthesised with numpy (no samples), like the prototype's own music. Each track is rendered
one loop long plus its echo tail, and the tail is folded back onto the start so the loop is seamless.

Usage:  python3 tools/bake/abyss_music.py [godot]
Needs:  Python 3 with numpy, and ffmpeg (for OGG encoding).
"""
import os
import subprocess
import sys
import tempfile
import wave

import numpy as np

SR = 44100
OUT = os.path.join(sys.argv[1] if len(sys.argv) > 1 else "godot", "audio", "music")
rng = np.random.default_rng(7)


def hz(n):  # MIDI note -> frequency
    return 440.0 * 2 ** ((n - 69) / 12)


def env(n, a, r, hold=None):
    """attack / release envelope over n samples (exponential release)"""
    t = np.arange(n) / SR
    e = np.minimum(1.0, t / max(a, 1e-4))
    if hold is None:
        return e * np.exp(-t / max(r, 1e-4))
    rel = np.clip((t - hold) / max(r, 1e-4), 0, None)
    return e * np.exp(-rel * 4) * (t < hold + r * 2.5)


def lp_fast(x, cutoff):
    """FFT brick-ish low pass with a soft knee (for long buffers)"""
    X = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1 / SR)
    X *= 1 / (1 + (f / cutoff) ** 4)
    return np.fft.irfft(X, len(x))


def saw(f, n, detune=0.0, phase=0.0):
    t = np.arange(n) / SR
    out = np.zeros(n)
    for d in (-detune, 0.0, detune):
        p = (t * f * (1 + d) + phase + rng.random()) % 1.0
        out += 2 * p - 1
    return out / 3


def sine(f, n, phase=0.0):
    return np.sin(2 * np.pi * f * np.arange(n) / SR + phase)


def reverb(x, seconds=3.0, mix=0.35, damp=3000, pre=0.02):
    """convolution with decaying, darkened noise; returns len(x) + tail samples (stereo in, stereo out)"""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    out = []
    for ch in range(2):
        ir = rng.standard_normal(n) * np.exp(-t * 6.9 / seconds)
        ir = lp_fast(ir, damp)
        ir[: int(pre * SR)] = 0
        ir /= np.sqrt(np.sum(ir ** 2)) + 1e-9
        L = len(x) + n
        size = 1 << (L - 1).bit_length()
        wet = np.fft.irfft(np.fft.rfft(x[:, ch], size) * np.fft.rfft(ir, size), size)[:L]
        dry = np.concatenate([x[:, ch], np.zeros(n)])
        out.append(dry * (1 - mix) + wet * mix * 1.6)
    return np.stack(out, 1)


class Track:
    def __init__(self, seconds):
        self.n = int(seconds * SR)
        self.buf = np.zeros((self.n + SR * 8, 2))  # room for notes that ring past the loop point

    def add(self, start, sig, pan=0.0, gain=1.0):
        i = int(start * SR)
        sig = sig * gain
        L, R = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
        end = min(len(self.buf), i + len(sig))
        self.buf[i:end, 0] += sig[: end - i] * L
        self.buf[i:end, 1] += sig[: end - i] * R

    def finish(self, rev_seconds, mix, damp, peak=0.56):
        x = reverb(self.buf, rev_seconds, mix, damp)
        loop = x[: self.n].copy()
        rest = x[self.n:]
        k = 0
        while k < len(rest):  # fold everything past the loop point back onto the start
            m = min(self.n, len(rest) - k)
            loop[:m] += rest[k: k + m]
            k += m
        loop -= loop.mean(0)
        loop *= peak / (np.abs(loop).max() + 1e-9)
        return loop


def save(name, x):
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as d:
        wav = os.path.join(d, name + ".wav")
        with wave.open(wav, "wb") as w:
            w.setnchannels(2)
            w.setsampwidth(2)
            w.setframerate(SR)
            w.writeframes((np.clip(x, -1, 1) * 32767).astype("<i2").tobytes())
        subprocess.run(["ffmpeg", "-y", "-loglevel", "error", "-i", wav, "-c:a", "libvorbis", "-q:a", "4",
                        os.path.join(OUT, name + ".ogg")], check=True)
    print("music", name, round(len(x) / SR, 2), "s")


# ---------------------------------------------------------------- instruments
def pad(notes, dur, bright=900, detune=0.006):
    n = int(dur * SR)
    s = sum(saw(hz(m), n, detune) for m in notes) / len(notes)
    s = lp_fast(s, bright)
    t = np.arange(n) / SR
    e = np.minimum(1, t / (dur * 0.35)) * np.minimum(1, (dur - t) / (dur * 0.35))
    return s * e


def choir(notes, dur, vowel=700):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.zeros(n)
    for m in notes:
        vib = 1 + 0.004 * np.sin(2 * np.pi * 5.2 * t + rng.random() * 6)
        ph = np.cumsum(hz(m) * vib) / SR
        s += sum(np.sin(2 * np.pi * ph * k) / k ** 1.3 for k in range(1, 9))
    s = lp_fast(s / len(notes), vowel)
    e = np.minimum(1, t / (dur * 0.3)) * np.minimum(1, (dur - t) / (dur * 0.3))
    return s * e


def bell(m, dur=4.0, bright=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    s = (np.sin(2 * np.pi * f * t) * np.exp(-t * 1.2)
         + 0.5 * np.sin(2 * np.pi * f * 2.76 * t) * np.exp(-t * 2.6) * bright
         + 0.25 * np.sin(2 * np.pi * f * 5.4 * t) * np.exp(-t * 5) * bright)
    return s * np.minimum(1, t / 0.004)


def glass(m, dur=3.0):  # celesta / glass harmonica
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m)
    s = np.sin(2 * np.pi * f * t + 0.6 * np.sin(2 * np.pi * f * 3 * t) * np.exp(-t * 3)) * np.exp(-t * 1.4)
    return s * np.minimum(1, t / 0.01)


def sub(m, dur, drive=1.0):
    n = int(dur * SR)
    t = np.arange(n) / SR
    s = np.tanh(drive * (np.sin(2 * np.pi * hz(m) * t) + 0.3 * np.sin(4 * np.pi * hz(m) * t)))
    return s * env(n, 0.01, dur * 0.25, hold=dur * 0.7)


def kick(dur=0.6, f0=110, f1=38):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = f1 + (f0 - f1) * np.exp(-t * 18)
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 6)


def tom(m, dur=0.7):
    n = int(dur * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 0.6 * np.exp(-t * 20))
    s = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 5)
    s += lp_fast(rng.standard_normal(n), 900) * np.exp(-t * 25) * 0.4
    return s


def noise_hit(dur, cutoff, decay):
    n = int(dur * SR)
    t = np.arange(n) / SR
    return lp_fast(rng.standard_normal(n), cutoff) * np.exp(-t * decay)


def drip(m):  # a water drop "plink"
    n = int(0.5 * SR)
    t = np.arange(n) / SR
    f = hz(m) * (1 + 1.5 * np.exp(-t * 30))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t * 9)


# ---------------------------------------------------------------- abyss (D minor, 56 bpm, 16 bars)
def abyss():
    bpm = 56
    beat = 60 / bpm
    bars = 16
    T = Track(bars * 4 * beat)
    # chords: crimson (minor with the flat second) sinking into black
    prog = [[50, 53, 57, 62], [46, 50, 53, 58], [43, 46, 50, 55], [45, 49, 52, 58],
            [50, 53, 57, 63], [46, 50, 53, 58], [44, 48, 51, 55], [45, 48, 51, 57]]
    for i in range(bars // 2):
        ch = prog[i % len(prog)]
        t0 = i * 8 * beat
        T.add(t0, pad(ch, 8 * beat + 1.5, 700 + 200 * (i % 2)), -0.3, 0.32)
        T.add(t0, pad([c + 12 for c in ch[1:]], 8 * beat + 1.5, 1400, 0.01), 0.35, 0.10)
        T.add(t0, sub(ch[0] - 24, 8 * beat, 1.6), 0, 0.42)
        # the heartbeat: a muffled double pulse each bar
        for b in range(2):
            for k, g in ((0, 0.5), (0.32, 0.32)):
                T.add(t0 + b * 4 * beat + k, lp_fast(kick(0.5, 70, 34), 300), 0, g)
    # a slow, lonely bell melody high above
    mel = [(0, 69, 4), (4, 70, 4), (8, 67, 6), (14, 65, 2), (16, 69, 3), (19, 74, 5), (24, 72, 4), (28, 70, 4),
           (32, 69, 4), (36, 70, 2), (38, 72, 2), (40, 67, 8), (48, 65, 4), (52, 63, 4), (56, 62, 8)]
    for b, m, d in mel:
        T.add(b * beat, bell(m, d * beat + 1.5, 0.6), 0.25, 0.16)
        T.add(b * beat + 0.75 * beat, bell(m + 12, 2.0, 0.3), -0.45, 0.04)  # a faint echo an octave up
    # drips and the creak of deep water
    for k in range(22):
        T.add(rng.random() * bars * 4 * beat, drip(84 + int(rng.integers(0, 10))), rng.uniform(-0.8, 0.8), 0.05)
    for k in range(6):
        T.add(rng.random() * bars * 4 * beat, lp_fast(noise_hit(3.0, 200, 1.2), 160), rng.uniform(-0.5, 0.5), 0.22)
    x = T.finish(4.5, 0.45, 1800, 0.5)
    return x


# ---------------------------------------------------------------- the Dreamer (D phrygian, 104 bpm, 16 bars)
def dreamer():
    bpm = 104
    beat = 60 / bpm
    bars = 16
    T = Track(bars * 4 * beat)
    roots = [38, 38, 39, 38, 36, 37, 38, 34]  # D, D, Eb, D, C, Db, D, Bb
    ost = [0, 0, 12, 0, 1, 0, 7, 6]           # eighth-note ostinato above each root
    for bar in range(bars):
        r = roots[(bar // 2) % len(roots)]
        t0 = bar * 4 * beat
        for k, o in enumerate(ost):
            s = sub(r + o - 12, beat * 0.48, 2.5)
            T.add(t0 + k * beat / 2, s, 0, 0.30)
            T.add(t0 + k * beat / 2, lp_fast(saw(hz(r + o), int(beat * 0.45 * SR), 0.01) * env(int(beat * 0.45 * SR), 0.005, 0.12), 1200), 0.2, 0.18)
        # drums: kick on 1 and the "and" of 2, huge toms on 4
        for b in (0, 1.5, 2.5):
            T.add(t0 + b * beat, kick(0.6, 120, 40), 0, 0.62)
        T.add(t0 + 3 * beat, tom(41), -0.3, 0.45)
        T.add(t0 + 3.5 * beat, tom(38), 0.3, 0.45)
        for b in (1, 3):
            T.add(t0 + b * beat, noise_hit(0.4, 3000, 14), 0, 0.22)  # a muffled snap
        if bar % 4 == 3:
            for k in range(4):
                T.add(t0 + (2 + k * 0.5) * beat, tom(45 - k * 3, 0.5), -0.5 + k * 0.33, 0.4)
    # the choir: rising dread, two bars per chord
    chords = [[50, 53, 57], [51, 55, 58], [50, 53, 57], [49, 52, 56], [48, 51, 55], [49, 53, 56], [50, 53, 58], [46, 50, 53]]
    for i, ch in enumerate(chords):
        T.add(i * 8 * beat, choir([c + 12 for c in ch], 8 * beat + 0.8, 1100), -0.2, 0.30)
        T.add(i * 8 * beat, pad([c - 12 for c in ch], 8 * beat + 0.8, 500), 0.2, 0.22)
    # the wail: a slow, high line in the second half
    wail = [(32, 74, 4), (36, 75, 4), (40, 74, 2), (42, 72, 2), (44, 71, 4), (48, 74, 4), (52, 77, 2), (54, 75, 2), (56, 74, 8)]
    for b, m, d in wail:
        T.add(b * beat, choir([m], d * beat + 0.4, 2000), 0.3, 0.22)
    x = T.finish(2.2, 0.28, 2600, 0.6)
    return x


# ---------------------------------------------------------------- inside the bubble (F lydian, 60 bpm, 12 bars)
def bubble():
    bpm = 60
    beat = 60 / bpm
    bars = 12
    T = Track(bars * 4 * beat)
    chords = [[53, 57, 60, 64], [55, 59, 62, 67], [53, 57, 60, 65], [50, 55, 59, 64], [52, 55, 59, 62], [53, 57, 59, 64]]
    for i, ch in enumerate(chords):
        T.add(i * 8 * beat, choir(ch, 8 * beat + 2, 1400), -0.3, 0.16)
        T.add(i * 8 * beat, pad([c + 12 for c in ch], 8 * beat + 2, 2600, 0.004), 0.3, 0.06)
    # slow glass arpeggios that drift between the ears
    arp = []
    for i, ch in enumerate(chords):
        notes = [c + 12 for c in ch] + [ch[1] + 24]
        for k in range(8):
            if rng.random() < 0.75:
                arp.append((i * 8 + k, notes[(k * 3 + i) % len(notes)]))
    for b, m in arp:
        T.add(b * beat + rng.uniform(0, 0.08), glass(m, 3.5), np.sin(b * 0.7) * 0.7, 0.10)
    # a few very high shimmering bells, like light catching the film
    for k in range(10):
        T.add(rng.random() * bars * 4 * beat, bell(88 + int(rng.choice([0, 2, 4, 6, 7, 9, 11])), 5, 0.4), rng.uniform(-0.9, 0.9), 0.035)
    x = T.finish(6.0, 0.6, 5000, 0.36)
    return x


if __name__ == "__main__":
    which = os.environ.get("ONLY", "abyss,dreamer,bubble").split(",")
    for name in which:
        save(name, globals()[name]())
