#!/usr/bin/env python3
"""Original lesson sound effects for the mobile app (no third-party samples).

`python3 tools/content/sfx/synth_sfx.py` writes apps/mobile/assets/sfx/<name>.wav
(22.05 kHz, 16-bit mono PCM). Every sound is additive synthesis from sine partials,
envelopes and seeded noise written here, so the files are ours to ship (see
apps/mobile/assets/PROVENANCE.md). Timing and character follow the Duolingo lesson
feel: a bright two-note rising chime for a correct answer, a soft low falling
"bwomp" for a wrong one, a short sparkle when a combo milestone is hit, a falling pop
for a lost heart, a fanfare arpeggio for lesson complete and a whoosh + rising chime
for the streak extension. Deterministic: re-running produces identical bytes.
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.normpath(
    os.path.join(os.path.dirname(__file__), '..', '..', '..', 'apps', 'mobile', 'assets', 'sfx'))


def silence(seconds):
    return [0.0] * int(seconds * RATE)


def mix(base, layer, at=0.0, gain=1.0):
    start = int(at * RATE)
    need = start + len(layer)
    if len(base) < need:
        base.extend([0.0] * (need - len(base)))
    for i, v in enumerate(layer):
        base[start + i] += v * gain
    return base


def bell(freq, seconds, decay=6.0, partials=((1, 1.0), (2, 0.35), (3, 0.12), (4.2, 0.05)),
         attack=0.004):
    n = int(seconds * RATE)
    out = []
    phase = [0.0] * len(partials)
    for i in range(n):
        t = i / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        s = 0.0
        for k, (mult, amp) in enumerate(partials):
            phase[k] += 2 * math.pi * freq * mult / RATE
            s += amp * math.sin(phase[k]) * math.exp(-decay * (mult - 1) * 0.35 * t)
        out.append(s * env)
    return out


def soft(freq_from, freq_to, seconds, decay=7.0, attack=0.01):
    """Rounded low tone (sine + soft 2nd/3rd harmonics) with a pitch glide."""
    n = int(seconds * RATE)
    out, phase = [], 0.0
    for i in range(n):
        t = i / RATE
        f = freq_from + (freq_to - freq_from) * min(1.0, t / seconds)
        phase += 2 * math.pi * f / RATE
        env = min(1.0, t / attack) * math.exp(-decay * t)
        out.append(env * (math.sin(phase) + 0.28 * math.sin(2 * phase) + 0.08 * math.sin(3 * phase)))
    return out


def noise_sweep(seconds, f_from, f_to, seed=7, gain=1.0):
    """Band-limited noise whoosh: one-pole low-pass with a sweeping cutoff."""
    rnd = random.Random(seed)
    n = int(seconds * RATE)
    out, y = [], 0.0
    for i in range(n):
        t = i / n
        fc = f_from + (f_to - f_from) * t
        a = 1 - math.exp(-2 * math.pi * fc / RATE)
        y += a * (rnd.uniform(-1, 1) - y)
        out.append(y * math.sin(math.pi * t) ** 1.5 * gain)
    return out


def normalize(samples, peak_db=-3.0, fade=0.01):
    peak = max(1e-9, max(abs(s) for s in samples))
    g = 10 ** (peak_db / 20) / peak
    out = [s * g for s in samples]
    f = int(fade * RATE)
    for i in range(min(f, len(out))):
        out[-1 - i] *= i / f
    return out


def write(name, samples):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, f'{name}.wav')
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b''.join(struct.pack('<h', int(max(-1, min(1, s)) * 32767)) for s in samples))
    print(f'{name}.wav {len(samples) / RATE:.2f}s')


def note(n):
    """MIDI note number to Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def correct():
    s = silence(0.0)
    mix(s, bell(note(84), 0.30, decay=9), 0.0, 0.8)      # C6
    mix(s, bell(note(88), 0.45, decay=6.5), 0.075, 1.0)  # E6
    mix(s, bell(note(91), 0.40, decay=8), 0.075, 0.25)   # G6 shimmer
    return normalize(s, -2.5)


def incorrect():
    s = silence(0.0)
    mix(s, soft(note(51), note(49), 0.22, decay=9), 0.0, 1.0)    # Eb3 -> Db3
    mix(s, soft(note(46), note(43), 0.34, decay=7), 0.11, 0.95)  # Bb2 -> G2
    return normalize(s, -4.0)


def combo():
    s = silence(0.0)
    for i, n in enumerate([84, 88, 91, 96]):
        mix(s, bell(note(n), 0.35, decay=10), i * 0.055, 0.55 + 0.1 * i)
    mix(s, noise_sweep(0.35, 2500, 9000, seed=3, gain=0.18), 0.05)
    return normalize(s, -4.0)


def heart_loss():
    return normalize(soft(note(76), note(62), 0.20, decay=14, attack=0.002), -6.0)


def lesson_complete():
    s = silence(0.0)
    for i, n in enumerate([72, 76, 79, 84]):  # C5 E5 G5 C6 arpeggio
        mix(s, bell(note(n), 0.5, decay=5), i * 0.09, 0.75)
    for n in (72, 76, 79, 84, 88):  # sustained C major chord
        mix(s, bell(note(n), 1.25, decay=2.6, partials=((1, 1.0), (2, 0.25), (3, 0.08))), 0.40, 0.42)
    mix(s, noise_sweep(0.6, 3000, 11000, seed=11, gain=0.10), 0.38)
    return normalize(s, -2.5, fade=0.05)


def streak():
    s = noise_sweep(0.55, 300, 4000, seed=5, gain=1.0)
    for i, n in enumerate([79, 83, 86, 91]):  # G5 B5 D6 G6
        mix(s, bell(note(n), 0.6, decay=4.5), 0.30 + i * 0.07, 0.55)
    return normalize(s, -3.0, fade=0.05)


if __name__ == '__main__':
    write('correct', correct())
    write('incorrect', incorrect())
    write('combo', combo())
    write('heart_loss', heart_loss())
    write('lesson_complete', lesson_complete())
    write('streak', streak())
