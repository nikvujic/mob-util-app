"""Writes the notification sounds one can pick per page into
android/app/src/main/res/raw/ (the phone's own default and silence need
none). Round 39: hacky 8-bit ones, square and triangle waves and noise
like an old game console, several to try (Round 31's Chime, Bell and
Soft are gone):

- notify_coin.wav: the classic pick-up: a short B5, then a long E6.
- notify_powerup.wav: a fast arpeggio climbing two octaves.
- notify_blip.wav: two quick blips, the second higher: a small "hey".
- notify_alert.wav: three beeps, the last one longer and lower.
- notify_zap.wav: a laser: a square wave diving down, with grit.
- notify_jingle.wav: a tiny four-note tune, triangle under square.

Round 41: each also as a quieter copy, `_medium` (half as loud) and
`_quiet` (a quarter), for the volume picked per page.

Run from the repo root: python3 tool/make_notify_sounds.py
"""
import math
import random
import struct
import wave

RATE = 44100


# The volumes (Round 41): how loud against the loud one, and the names'
# endings.
VOLUMES = [('', 1.0), ('_medium', 0.5), ('_quiet', 0.25)]


def write(name, samples):
    peak = max(abs(v) for v in samples) or 1.0
    for suffix, level in VOLUMES:
        path = 'android/app/src/main/res/raw/%s%s.wav' % (name, suffix)
        with wave.open(path, 'wb') as out:
            out.setnchannels(1)
            out.setsampwidth(2)
            out.setframerate(RATE)
            out.writeframes(struct.pack(
                '<%dh' % len(samples),
                *[int(0.8 * level * v / peak * 32767) for v in samples]))


def note(name):
    """A note's frequency, e.g. 'E6'."""
    names = {'C': -9, 'C#': -8, 'D': -7, 'D#': -6, 'E': -5, 'F': -4,
             'F#': -3, 'G': -2, 'G#': -1, 'A': 0, 'A#': 1, 'B': 2}
    pitch, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((names[pitch] + 12 * (octave - 4)) / 12)


def square(phase, duty=0.5):
    return 1.0 if (phase % 1.0) < duty else -1.0


def triangle(phase):
    p = phase % 1.0
    return 4 * p - 1 if p < 0.5 else 3 - 4 * p


def play(samples, start, length, freq, wave_fn=square, size=1.0,
         slide=None, decay=0.0):
    """Adds a chip-style note at [start] for [length] seconds; [slide]:
    the frequency it glides to by the end; [decay]: how fast it fades."""
    first = int(RATE * start)
    count = int(RATE * length)
    phase = 0.0
    for i in range(count):
        if first + i >= len(samples):
            break
        t = i / RATE
        f = freq if slide is None else freq + (slide - freq) * (i / count)
        phase += f / RATE
        # Hard edges, but no click: a 2 ms ramp in and out.
        edge = min(1.0, t / 0.002, (length - t) / 0.002)
        samples[first + i] += size * edge * math.exp(-t * decay) * wave_fn(phase)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def coin():
    s = silence(0.5)
    play(s, 0.0, 0.07, note('B5'), lambda p: square(p, 0.5))
    play(s, 0.07, 0.4, note('E6'), lambda p: square(p, 0.5), decay=5)
    write('notify_coin', s)


def powerup():
    s = silence(0.6)
    steps = ['C5', 'E5', 'G5', 'C6', 'E6', 'G6', 'C7']
    for i, n in enumerate(steps):
        play(s, i * 0.05, 0.06 if i < len(steps) - 1 else 0.25, note(n),
             lambda p: square(p, 0.25), decay=0 if i < len(steps) - 1 else 6)
    write('notify_powerup', s)


def blip():
    s = silence(0.3)
    play(s, 0.0, 0.05, note('A5'), lambda p: square(p, 0.125))
    play(s, 0.09, 0.08, note('E6'), lambda p: square(p, 0.125), decay=10)
    write('notify_blip', s)


def alert():
    s = silence(0.75)
    for i in range(2):
        play(s, i * 0.14, 0.08, note('A5'), lambda p: square(p, 0.5))
    play(s, 0.3, 0.35, note('E5'), lambda p: square(p, 0.5), decay=4)
    write('notify_alert', s)


def zap():
    s = silence(0.45)
    play(s, 0.0, 0.4, 1800.0, lambda p: square(p, 0.5), slide=120.0, decay=3)
    rng = random.Random(7)
    for i in range(int(RATE * 0.12)):
        s[i] += 0.25 * (rng.random() * 2 - 1) * (1 - i / (RATE * 0.12))
    write('notify_zap', s)


def jingle():
    s = silence(0.9)
    tune = [('E5', 0.0, 0.1), ('G5', 0.11, 0.1), ('E6', 0.22, 0.1),
            ('C6', 0.33, 0.45)]
    for n, start, length in tune:
        decay = 5 if length > 0.2 else 0
        play(s, start, length, note(n), lambda p: square(p, 0.25), 0.7,
             decay=decay)
        # A triangle an octave down, like the console's bass channel.
        play(s, start, length, note(n) / 2, triangle, 0.5, decay=decay)
    write('notify_jingle', s)


if __name__ == '__main__':
    coin()
    powerup()
    blip()
    alert()
    zap()
    jingle()
