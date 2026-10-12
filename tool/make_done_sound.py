"""Writes android/app/src/main/res/raw/done.wav: the medicine tracker's
"taken" sound - a soft gulp (Round 16; the chime before it was too
sharp): two low "bloops", each a sine whose pitch slides up quickly, like
a swallow of water, the second a little higher and quieter. No high
frequencies, so it's gentle at any volume.
Run from the repo root: python3 tool/make_done_sound.py
"""
import math
import wave
import struct

RATE = 44100
LENGTH = 0.32  # seconds


def bloop(start, low, high, slide, t):
    """One bloop at [start] seconds: from [low] Hz up to [high] Hz over
    [slide] seconds, a quick attack and a fast decay."""
    if t < start:
        return 0.0
    x = t - start
    attack = min(1.0, x / 0.004)
    decay = math.exp(-x * 26.0)
    # The phase of a sweep: the integral of the frequency over time.
    k = min(x, slide) / slide
    if x < slide:
        phase = low * x + (high - low) * x * k / 2
    else:
        phase = low * slide + (high - low) * slide / 2 + high * (x - slide)
    return attack * decay * math.sin(2 * math.pi * phase)


frames = []
for i in range(int(RATE * LENGTH)):
    t = i / RATE
    v = bloop(0.0, 170, 430, 0.06, t) + 0.6 * bloop(0.11, 210, 520, 0.05, t)
    fade = min(1.0, (LENGTH - t) / 0.04)  # no click at the end
    frames.append(int(max(-1.0, min(1.0, v * 0.7 * fade)) * 32767))

with wave.open('android/app/src/main/res/raw/done.wav', 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(struct.pack('<%dh' % len(frames), *frames))
