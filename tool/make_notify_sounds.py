"""Writes the notification sounds one can pick per page (Round 31) into
android/app/src/main/res/raw/ (the phone's own default and silence need
none):

- notify_chime.wav: two bright notes going up (E6, B6), each with a soft
  octave above, ringing out.
- notify_bell.wav: one small bell: a tone with the inharmonic partials of
  a bell, a quick strike and a long ring.
- notify_soft.wav: two gentle low "bloops" sliding up, like the
  medicine's gulp but slower: easy on the ears at night.

Run from the repo root: python3 tool/make_notify_sounds.py
"""
import math
import struct
import wave

RATE = 44100


def write(name, samples):
    peak = max(abs(v) for v in samples) or 1.0
    with wave.open('android/app/src/main/res/raw/%s.wav' % name, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)
        out.setframerate(RATE)
        out.writeframes(struct.pack(
            '<%dh' % len(samples),
            *[int(0.85 * v / peak * 32767) for v in samples]))


def tone(samples, start, freq, partials, decay, size):
    """Adds a struck tone at [start] seconds: [partials] are (ratio,
    loudness) pairs over [freq]."""
    first = int(RATE * start)
    for i in range(first, len(samples)):
        t = (i - first) / RATE
        attack = min(1.0, t / 0.004)
        ring = math.exp(-t * decay)
        v = sum(level * math.sin(2 * math.pi * freq * ratio * t)
                for ratio, level in partials)
        samples[i] += size * attack * ring * v


def faded(samples, seconds=0.05):
    n = int(RATE * seconds)
    for i in range(n):
        samples[-1 - i] *= i / n
    return samples


def chime():
    samples = [0.0] * int(RATE * 0.9)
    notes = [(1.0, 0.5), (2.0, 0.18)]
    tone(samples, 0.0, 1318.5, notes, 6.0, 1.0)  # E6
    tone(samples, 0.14, 1975.5, notes, 5.0, 0.8)  # B6
    write('notify_chime', faded(samples))


def bell():
    samples = [0.0] * int(RATE * 1.3)
    # A bell's partials: hum, prime, tierce, quint, nominal.
    partials = [(0.5, 0.25), (1.0, 0.6), (1.19, 0.3), (1.5, 0.2),
                (2.0, 0.35), (2.74, 0.12)]
    tone(samples, 0.0, 880.0, partials, 3.2, 1.0)
    write('notify_bell', faded(samples, 0.15))


def soft():
    samples = [0.0] * int(RATE * 0.7)

    def bloop(start, low, high, slide, size):
        first = int(RATE * start)
        phase = 0.0
        for i in range(first, len(samples)):
            t = (i - first) / RATE
            freq = low + (high - low) * min(1.0, t / slide)
            phase += 2 * math.pi * freq / RATE
            attack = min(1.0, t / 0.01)
            samples[i] += size * attack * math.exp(-t * 9) * math.sin(phase)

    bloop(0.0, 330, 520, 0.09, 1.0)
    bloop(0.22, 390, 620, 0.09, 0.7)
    write('notify_soft', faded(samples))


chime()
bell()
soft()
