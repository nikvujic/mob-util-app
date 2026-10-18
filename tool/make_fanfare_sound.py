"""Writes Pip's fanfare (Round 63) into android/app/src/main/res/raw/:
played once, as he registers as an adventurer and holds his sword up
high. 8-bit, like the notification sounds (tool/make_notify_sounds.py):
a quick climb (G4 C5 E5), a held G5, a short drop and a last long C6,
square on top, triangle under it, about 2.6 seconds.

Run from the repo root: python3 tool/make_fanfare_sound.py
"""
import math
import struct
import wave

RATE = 44100


def note(name):
    """A note's frequency, e.g. 'C6'."""
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4,
             'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


# (melody, bass, seconds): the bass a triangle an octave or two down.
TUNE = [
    ('G4', 'C3', 0.12), (None, None, 0.03),
    ('C5', 'C3', 0.12), (None, None, 0.03),
    ('E5', 'G3', 0.12), (None, None, 0.03),
    ('G5', 'C4', 0.45), (None, None, 0.05),
    ('E5', 'G3', 0.14), (None, None, 0.03),
    ('G5', 'C4', 0.14), (None, None, 0.03),
    ('C6', 'C3', 1.1),
]


def main():
    samples = []
    for melody, bass, seconds in TUNE:
        n = int(RATE * seconds)
        for i in range(n):
            t = i / RATE
            if melody is None:
                samples.append(0.0)
                continue
            # A quick attack, a gentle fall, a short release.
            env = min(1.0, t / 0.005) * (0.75 + 0.25 * math.exp(-t * 6))
            env *= min(1.0, (n - i) / (RATE * 0.02))
            # A little vibrato on the long last note.
            wobble = 1 + (0.006 * math.sin(2 * math.pi * 6 * t)
                          if seconds > 1 else 0)
            v = 0.55 * square(note(melody) * wobble * t, 0.25)
            v += 0.45 * triangle(note(bass) * t)
            samples.append(env * v)
    peak = max(abs(v) for v in samples) or 1.0
    with wave.open('android/app/src/main/res/raw/fanfare.wav', 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(struct.pack(
            '<%dh' % len(samples),
            *[int(0.8 * v / peak * 32767) for v in samples]))


main()
