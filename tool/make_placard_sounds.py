"""Writes the Placard's sounds (Round 17) into android/app/src/main/res/raw/:

- inflate.wav: a hold's length (3.2 s) of a soft, rising "stretch": a low
  tone sliding up with a little wobble, getting louder as it fills (no
  breathy noise: Round 18, it sounded like a TV's static). Stopped early
  when the finger lifts.
- pop.wav: a balloon pop - a short burst of noise that dies away fast,
  over a low thump.

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
    length = 0.25
    samples = []
    smooth = 0.0
    for i in range(int(RATE * length)):
        t = i / RATE
        noise = random.uniform(-1, 1)
        smooth = 0.6 * smooth + 0.4 * noise  # a little less hiss
        crack = smooth * math.exp(-t * 55)
        thump = math.sin(2 * math.pi * 85 * t) * math.exp(-t * 22)
        fade = min(1.0, (length - t) / 0.03)
        samples.append(fade * (0.9 * crack + 0.6 * thump))
    write('pop', samples)


inflate()
pop()
