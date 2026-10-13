"""Writes android/app/src/main/res/raw/fill.wav: an important medicine's
hold-to-take (Round 24) - a glass filling up over 5 seconds: a soft
"pouring" tone whose pitch rises as the glass fills (like the note of a
bottle being filled), with small bubbles coming faster towards the end.
Not Placard's stretching tone: brighter, and bubbly.
Run from the repo root: python3 tool/make_fill_sound.py
"""
import math
import random
import struct
import wave

RATE = 44100
LENGTH = 5.0  # seconds, the hold's length

random.seed(24)

samples = [0.0] * int(RATE * LENGTH)

# The pour: a tone rising from 220 Hz to 880 Hz, with a soft shimmer.
phase = 0.0
for i in range(len(samples)):
    t = i / RATE
    k = t / LENGTH
    freq = 220 * (4 ** k)  # two octaves up, evenly in pitch
    phase += 2 * math.pi * freq / RATE
    shimmer = 1 + 0.15 * math.sin(2 * math.pi * 9 * t)
    tone = math.sin(phase) + 0.3 * math.sin(2 * phase + 0.5)
    loud = 0.12 + 0.18 * k
    fade_in = min(1.0, t / 0.15)
    fade_out = min(1.0, (LENGTH - t) / 0.05)
    samples[i] += loud * shimmer * fade_in * fade_out * tone

# Bubbles: short pitch-rising blips, sparse at first, then busy.
t = 0.1
while t < LENGTH - 0.1:
    k = t / LENGTH
    start = int(t * RATE)
    base = random.uniform(500, 900) * (1 + k)
    length = random.uniform(0.025, 0.05)
    n = int(length * RATE)
    p = 0.0
    for j in range(n):
        if start + j >= len(samples):
            break
        u = j / n
        p += 2 * math.pi * base * (1 + 0.8 * u) / RATE
        env = math.sin(math.pi * u) ** 2
        samples[start + j] += (0.25 + 0.2 * k) * env * math.sin(p)
    t += random.uniform(0.18, 0.4) * (1 - 0.7 * k)

peak = max(abs(s) for s in samples)
scale = 0.89 / peak  # about -1 dB
with wave.open('android/app/src/main/res/raw/fill.wav', 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(struct.pack(
        '<%dh' % len(samples),
        *[int(max(-1.0, min(1.0, s * scale)) * 32767) for s in samples]))
