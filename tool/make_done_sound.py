"""Writes android/app/src/main/res/raw/done.wav: the medicine tracker's
"taken" sound (Round 14) - a soft, rising two-note chime (E6 then B6), each
note a sine with a little of its octave, a quick attack and a ringing
decay. Run from the repo root: python3 tool/make_done_sound.py
"""
import math
import struct
import wave

RATE = 44100
LENGTH = 0.55  # seconds


def note(freq, start, t):
    """One chime note at [freq], starting at [start] seconds."""
    if t < start:
        return 0.0
    x = t - start
    attack = min(1.0, x / 0.006)
    decay = math.exp(-x * 7.0)
    tone = math.sin(2 * math.pi * freq * x) + 0.3 * math.sin(4 * math.pi * freq * x)
    return attack * decay * tone


frames = []
for i in range(int(RATE * LENGTH)):
    t = i / RATE
    v = 0.55 * note(1318.5, 0.0, t) + 0.5 * note(1975.5, 0.09, t)
    fade = min(1.0, (LENGTH - t) / 0.05)  # no click at the end
    frames.append(int(max(-1.0, min(1.0, v * 0.6 * fade)) * 32767))

with wave.open('android/app/src/main/res/raw/done.wav', 'wb') as out:
    out.setnchannels(1)
    out.setsampwidth(2)
    out.setframerate(RATE)
    out.writeframes(struct.pack('<%dh' % len(frames), *frames))
