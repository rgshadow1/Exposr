"""Generates Exposr's two result sounds.

    python tool/generate_sounds.py

Both sounds are synthesised here from plain sine waves, so they are original
to this project: there is nothing sampled, downloaded or licensed from anyone
else. They are written to assets/sounds/ and bundled with the app, which
never fetches audio at runtime.

  result_clear.wav   no known breaches: two soft notes rising a fifth
  result_breach.wav  breaches found: two soft notes falling a minor third

They are deliberately short (about half a second), quiet (the loudest sample
is about a quarter of full scale) and low in pitch. Neither is an alarm: no
repetition, no harsh overtones, no sweep.

Only the Python standard library is used.
"""

import math
import os
import struct
import wave

RATE = 44100
PEAK = 0.24  # of full scale; the app also plays them below full volume


def note(freq, start, length, tau):
    """One soft note: a sine with a little warmth, a quick fade in and a slow fade out."""

    def sample(t):
        local = t - start
        if local < 0 or local > length:
            return 0.0
        attack = min(1.0, local / 0.008)  # 8 ms, so the note doesn't click
        attack = 0.5 - 0.5 * math.cos(math.pi * attack)
        decay = math.exp(-local / tau)
        release = min(1.0, (length - local) / 0.02)  # reach silence by the end
        wave_value = (
            math.sin(2 * math.pi * freq * local)
            + 0.12 * math.sin(2 * math.pi * 2 * freq * local)
            + 0.03 * math.sin(2 * math.pi * 3 * freq * local)
        )
        return wave_value * attack * decay * release

    return sample


def render(path, notes, duration):
    count = int(RATE * duration)
    samples = [sum(n(i / RATE) for n in notes) for i in range(count)]
    loudest = max(abs(s) for s in samples) or 1.0
    scale = PEAK / loudest

    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as out:
        out.setnchannels(1)
        out.setsampwidth(2)  # 16-bit
        out.setframerate(RATE)
        out.writeframes(b''.join(struct.pack('<h', int(s * scale * 32767)) for s in samples))
    print(f'{path}: {duration:.2f}s, {os.path.getsize(path)} bytes')


def main():
    here = os.path.dirname(os.path.abspath(__file__))
    sounds = os.path.join(here, '..', 'assets', 'sounds')

    # C5 then G5: a rising fifth reads as "done, fine".
    render(
        os.path.normpath(os.path.join(sounds, 'result_clear.wav')),
        [note(523.25, 0.00, 0.30, 0.09), note(783.99, 0.11, 0.37, 0.10)],
        0.48,
    )

    # A4 then F#4: a falling minor third reads as "take note", not "danger".
    render(
        os.path.normpath(os.path.join(sounds, 'result_breach.wav')),
        [note(440.00, 0.00, 0.34, 0.11), note(369.99, 0.14, 0.40, 0.12)],
        0.54,
    )


if __name__ == '__main__':
    main()
