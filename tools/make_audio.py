#!/usr/bin/env python3
"""Synthesizes all of Sparkfrost's sound: sparkly, gentle effects and a music-box
waltz. Original sounds built from oscillators and noise, no samples, Python
standard library only.

    python3 tools/make_audio.py   ->  audio/sfx/*.wav, audio/music/waltz.wav

Deterministic: running it again rebuilds identical files. Sounds that repeat
a lot (footsteps) are kept soft and dark on purpose.
"""
import os
import random

import synth
from synth import Track, at, hz, layer, noise, tone

OUT = os.path.join(synth.HERE, "..", "audio")


def bell(note_or_freq, dur=1.2, vol=0.25, decay=0.35):
    """Music-box / celesta tone: a sine plus a quickly fading bright partial."""
    f = hz(note_or_freq) if isinstance(note_or_freq, str) else note_or_freq
    return layer(tone(f, dur, "sine", vol, attack=0.002, decay=decay),
                 tone(f * 3.0, dur * 0.4, "sine", vol * 0.18, attack=0.002, decay=decay * 0.25),
                 tone(f * 2.0, dur * 0.6, "sine", vol * 0.12, attack=0.002, decay=decay * 0.5))


def sparkle(dur=0.5, vol=0.12, seed=1):
    """A shower of tiny high bell pings."""
    rng = random.Random(seed)
    notes = ["E7", "G7", "B6", "D7", "A6", "F#7"]
    return layer(*[at(rng.uniform(0, dur * 0.6), tone(hz(rng.choice(notes)), 0.25, "sine", vol, attack=0.001, decay=0.06))
                   for _ in range(7)])


def sfx():
    s = {}
    # Soft snow crunch for each step: low, short and dark (it repeats a lot).
    s["step"] = noise(0.09, 0.4, decay=0.025, lowpass=650, highpass=90, seed=3, attack=0.01)
    # Sliding on ice: an airy rising whoosh with a thin shimmer.
    s["slide"] = layer(noise(0.45, 0.35, decay=None, lowpass=500, sweep_to=2600, highpass=200, seed=4, attack=0.05),
                       tone(1000, 0.45, "sine", 0.05, glide_to=1500, attack=0.05, release=0.2))
    # "Nope": a gentle two-note boop down.
    s["nope"] = layer(tone(hz("E4"), 0.09, "tri", 0.35, decay=0.06),
                      at(0.08, tone(hz("C4"), 0.14, "tri", 0.35, decay=0.08)))
    # Freeze: a rising icy chime with a crackle.
    s["freeze"] = layer(*[at(i * 0.05, bell(n, 0.7, 0.2, 0.18)) for i, n in enumerate(["E6", "B6", "E7"])],
                        noise(0.25, 0.25, decay=0.07, highpass=4000, seed=5))
    # Melt: a soft sizzle and a warm falling hum.
    s["melt"] = layer(noise(0.45, 0.3, decay=0.16, highpass=2500, seed=6),
                      tone(320, 0.4, "sine", 0.2, decay=0.18, glide_to=180))
    # Pushing an ice block: a hollow thunk.
    s["push"] = layer(tone(200, 0.18, "sine", 0.5, decay=0.05, glide_to=130),
                      noise(0.08, 0.2, decay=0.02, lowpass=900, seed=7))
    # A block dropping into water and freezing into a bridge.
    s["bridge"] = layer(noise(0.3, 0.4, decay=0.09, lowpass=1500, seed=8),
                        at(0.12, layer(*[at(i * 0.05, bell(n, 0.6, 0.18, 0.15)) for i, n in enumerate(["B5", "E6", "G#6"])])))
    # Lighting a lantern: one warm bell.
    s["light"] = layer(bell("G5", 1.4, 0.28, 0.5), bell("D6", 1.0, 0.1, 0.4))
    # The last lantern: the gates open with a rising magical arpeggio.
    s["gate"] = layer(*[at(i * 0.08, bell(n, 1.2, 0.2, 0.4)) for i, n in enumerate(["D5", "F#5", "A5", "D6", "F#6"])],
                      at(0.3, sparkle(0.8, 0.08, seed=9)))
    # Both sisters home: a twinkling fanfare.
    s["win"] = layer(*[at(i * 0.1, bell(n, 0.5, 0.22, 0.2)) for i, n in enumerate(["D5", "F#5", "A5"])],
                     at(0.3, layer(bell("D6", 1.6, 0.25, 0.7), bell("F#6", 1.6, 0.14, 0.7), bell("A5", 1.6, 0.14, 0.7))),
                     at(0.35, sparkle(1.0, 0.1, seed=10)))
    # Undo: a quick rewind blip. Arriving at an exit: a tiny ding.
    s["undo"] = tone(900, 0.12, "sine", 0.25, glide_to=480, decay=0.06)
    s["home"] = bell("A6", 0.6, 0.2, 0.2)
    return s


# A gentle music-box waltz in D major: 3/4 time, 88 BPM, 16 bars, loops.
BPM = 88
BEAT = 60 / BPM
CHORDS = ["D", "D", "Bm", "Bm", "G", "G", "A", "A", "D", "D", "F#m", "F#m", "G", "A", "D", "D"]
CHORD_NOTES = {"D": ["D3", "F#3", "A3"], "Bm": ["B2", "D3", "F#3"], "G": ["G2", "B2", "D3"],
               "A": ["A2", "C#3", "E3"], "F#m": ["F#2", "A2", "C#3"]}
MELODY = [  # (note, beats) for each bar; all original
    [("A5", 1), ("F#5", 1), ("D5", 1)], [("E5", 1), ("F#5", 1), ("A5", 1)],
    [("B5", 2), ("F#5", 1)], [("D6", 1), ("C#6", 1), ("B5", 1)],
    [("G5", 1), ("B5", 1), ("D6", 1)], [("E6", 2), ("D6", 1)],
    [("C#6", 1), ("B5", 1), ("A5", 1)], [("E5", 3)],
    [("F#5", 1), ("A5", 1), ("D6", 1)], [("F#6", 2), ("E6", 1)],
    [("C#6", 1), ("A5", 1), ("F#5", 1)], [("A5", 2), ("C#6", 1)],
    [("B5", 1), ("D6", 1), ("G6", 1)], [("F#6", 1), ("E6", 1), ("C#6", 1)],
    [("D6", 2), ("A5", 1)], [("D6", 3)],
]


def waltz():
    bar = 3 * BEAT
    length = len(CHORDS) * bar
    mix = Track(length, loop=True)
    box = Track(length, loop=True)
    rng = random.Random(11)
    for b, chord in enumerate(CHORDS):
        t0 = b * bar
        root, third, fifth = CHORD_NOTES[chord]
        # Oom-pah-pah: a soft bass on beat 1, a light chord on beats 2 and 3.
        mix.add(t0, tone(hz(root) / 2 * 2, bar * 0.9, "tri", 0.22, attack=0.01, decay=0.5, lowpass=700))
        for k in (1, 2):
            for n in (third, fifth):
                mix.add(t0 + k * BEAT, tone(hz(n) * 2, BEAT * 0.8, "sine", 0.07, attack=0.01, decay=0.25))
        # A soft string pad under it all.
        if b % 2 == 0:
            for n in (root, third, fifth):
                mix.add(t0, tone(hz(n) * 2, bar * 2, "tri", 0.035, attack=0.8, release=0.8, detune=0.004, lowpass=1500))
        # The music-box melody.
        t = t0
        for note, beats in MELODY[b]:
            box.add(t, bell(note, beats * BEAT + 0.6, 0.16, 0.45))
            t += beats * BEAT
        # Now and then, a little sparkle on the off-beat.
        if b % 4 == 3:
            box.add(t0 + 2.5 * BEAT, sparkle(0.6, 0.05, seed=rng.randrange(1000)))
    box.echo(BEAT * 0.75, feedback=0.3, mix=0.3)
    mix.mix(box)
    return mix.buf


def main():
    for name, samples in sfx().items():
        synth.write_wav(os.path.join(OUT, "sfx", name + ".wav"), samples)
    synth.SR = 22050
    synth.write_wav(os.path.join(OUT, "music", "waltz.wav"), waltz(), peak=0.6)


if __name__ == "__main__":
    main()
