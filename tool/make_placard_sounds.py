"""Writes the Placard's sounds (Round 17) into android/app/src/main/res/raw/:

- inflate.wav: a hold's length (3.2 s) of a soft, rising "stretch": a low
  tone sliding up with a little wobble, getting louder as it fills (no
  breathy noise: Round 18, it sounded like a TV's static). Stopped early
  when the finger lifts.
- pop.wav: a bubble popping (Round 29; a balloon's burst before): a
  short "blup", its pitch leaping up, a tiny click, a smaller one after.

Run from the repo root: python3 tool/make_placard_sounds.py
"""
import math
import random
import struct
import wave

RATE = 44100
random.seed(7)  # the same files every time


def write(name, samples):
    with wave.open('android/app/src/main/res/raw/%s.wav' % name, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(struct.pack(
            '<%dh' % len(samples),
            *[int(max(-1.0, min(1.0, v)) * 32767) for v in samples]))


def inflate():
    length = 3.2
    samples = []
    phase = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        k = t / length
        # 140 Hz up to 480 Hz, faster towards the end, with a wobble.
        freq = 140 + 340 * k ** 1.6 + 6 * math.sin(2 * math.pi * 7 * t)
        phase += 2 * math.pi * freq / RATE
        tone = math.sin(phase) + 0.25 * math.sin(2 * phase)
        # Drawn and unused: the noise that was here took these, and the
        # pop below (liked as it is) depends on what's left.
        random.uniform(-1, 1)
        loud = 0.15 + 0.4 * k
        fade_in = min(1.0, t / 0.08)
        fade_out = min(1.0, (length - t) / 0.05)
        samples.append(loud * fade_in * fade_out * 1.4 * tone)
    write('inflate', samples)


def pop():
    """A bubble popping (Round 29: was a balloon's burst): a short tone
    whose pitch leaps up as it dies away, the "blup" of a bubble, with a
    tiny click as it breaks, and a smaller second one just after."""
    length = 0.22
    samples = [0.0] * int(RATE * length)

    def bubble(at, base, rise, size):
        phase = 0.0
        start = int(RATE * at)
        for i in range(start, len(samples)):
            t = (i - start) / RATE
            # The pitch shoots up (a bubble's resonance as it shrinks).
            freq = base * math.exp(rise * t)
            phase += 2 * math.pi * freq / RATE
            attack = min(1.0, t / 0.002)
            samples[i] += size * attack * math.exp(-t * 38) * math.sin(phase)

    bubble(0.0, 420, 18, 0.95)
    bubble(0.055, 700, 16, 0.35)
    # The skin breaking: a few milliseconds of soft noise.
    for i in range(int(RATE * 0.006)):
        samples[i] += 0.35 * random.uniform(-1, 1) * (1 - i / (RATE * 0.006))
    fade = int(RATE * 0.03)
    for i in range(fade):
        samples[-1 - i] *= i / fade
    # As loud as the old pop (Round 25: keep its volume), not clipped.
    peak = max(abs(v) for v in samples)
    write('pop', [0.9 * v / peak for v in samples])


inflate()
pop()
