#!/usr/bin/env python3
"""Music and comedy sound effects for Sparkfrost's marketing videos (not used
in the game). Original, synthesized from scratch with tools/synth.py.

    python3 tools/video/make_video_audio.py   ->  build/video_audio/*.wav

The stingers are the ones that worked for Cardboard Espionage Action's
Shorts (pop, boing, slide whistle, ding, sad trombone), plus a sparkle
shimmer. "bounce" is an upbeat, sparkly theme for the Shorts: livelier than
the calm in-game waltz.
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
import synth  # noqa: E402
from synth import Track, at, hz, layer, noise, tone  # noqa: E402

OUT = os.path.join(synth.HERE, "..", "build", "video_audio")


def vibrato(freq, dur, vol, depth, rate, shape="sine", glide_to=None, decay=None, lowpass=None):
    n = int(dur * synth.SR)
    out = [0.0] * n
    p = y = 0.0
    k = 1 - math.exp(-synth.TAU * lowpass / synth.SR) if lowpass else None
    for i in range(n):
        t = i / synth.SR
        f = freq if glide_to is None else freq * (glide_to / freq) ** (t / dur)
        f *= 1 + depth * math.sin(synth.TAU * rate * t)
        p = (p + f / synth.SR) % 1.0
        s = synth._wave(shape, p)
        if k:
            y += k * (s - y)
            s = y
        env = min(1.0, t / 0.02) * (math.exp(-t / decay) if decay else 1.0) * min(1.0, (dur - t) / 0.04)
        out[i] = s * env * vol
    return out


def bell(note, dur=1.0, vol=0.25, decay=0.3):
    f = hz(note)
    return layer(tone(f, dur, "sine", vol, attack=0.002, decay=decay),
                 tone(f * 3.0, dur * 0.4, "sine", vol * 0.18, attack=0.002, decay=decay * 0.25))


def sparkle(dur=0.6, vol=0.12, seed=1):
    rng = random.Random(seed)
    notes = ["E7", "G7", "B6", "D7", "A6", "F#7"]
    return layer(*[at(rng.uniform(0, dur * 0.6), tone(hz(rng.choice(notes)), 0.25, "sine", vol, attack=0.001, decay=0.06))
                   for _ in range(8)])


def sfx():
    s = {}
    s["pop"] = layer(tone(900, 0.08, "sine", 0.6, decay=0.015, glide_to=1800), noise(0.03, 0.2, decay=0.006, highpass=2000, seed=23))
    s["boing"] = vibrato(180, 0.6, 0.6, 0.35, 11, shape="tri", glide_to=320, decay=0.25)
    s["slide_up"] = vibrato(500, 0.55, 0.5, 0.012, 7, glide_to=1900)
    s["slide_down"] = vibrato(1900, 0.6, 0.5, 0.012, 7, glide_to=420)
    s["ding"] = layer(tone(hz("E6"), 0.9, "sine", 0.4, decay=0.3), tone(hz("E6") * 2.76, 0.4, "sine", 0.1, decay=0.1))
    s["sparkle"] = sparkle(0.8, 0.14, seed=3)
    s["whoosh"] = noise(0.45, 0.5, decay=None, lowpass=300, sweep_to=5000, highpass=150, seed=24, attack=0.2)
    s["aww"] = layer(vibrato(hz("A5"), 0.5, 0.35, 0.02, 5, shape="tri", glide_to=hz("F#5")),
                     at(0.05, vibrato(hz("C#6"), 0.5, 0.18, 0.02, 5, shape="sine", glide_to=hz("A5"))))
    s["uh_oh"] = layer(vibrato(hz("A5"), 0.18, 0.4, 0.01, 6, shape="tri"),
                       at(0.2, vibrato(hz("E5"), 0.32, 0.4, 0.01, 6, shape="tri", glide_to=hz("D5"))))
    s["tada"] = layer(*[at(i * 0.08, bell(n, 0.8, 0.22, 0.3)) for i, n in enumerate(["C6", "E6", "G6"])],
                      at(0.24, bell("C7", 1.2, 0.2, 0.45)), at(0.25, sparkle(0.8, 0.08, seed=7)))
    return s


def bounce():
    """Upbeat and sparkly: C major, 120 BPM, 16 bars. Bouncy bass, bell melody,
    claps on 2 and 4, a shaker, and a sparkle at every phrase end. Loops."""
    beat = 0.5
    bar = 4 * beat
    chords = ["C", "G", "Am", "F"] * 4
    roots = {"C": "C3", "G": "G2", "Am": "A2", "F": "F2"}
    triads = {"C": ["C5", "E5", "G5"], "G": ["B4", "D5", "G5"], "Am": ["A4", "C5", "E5"], "F": ["A4", "C5", "F5"]}
    melody = [["E6", "G6", "E6", "D6"], ["D6", "B5", "G5", None], ["C6", "E6", "A6", "G6"], ["F6", "E6", "C6", None]]
    mix = Track(len(chords) * bar, loop=True)
    bells = Track(len(chords) * bar, loop=True)
    rng = random.Random(9)
    for b, ch in enumerate(chords):
        t0 = b * bar
        r = hz(roots[ch])
        for k, mult in enumerate([1, 2, 1, 2, 1.5, 2, 1, 2]):   # bouncy octave bass on eighths
            mix.add(t0 + k * beat / 2, tone(r * mult, beat * 0.4, "tri", 0.3, decay=0.08, lowpass=900))
        for k in (1, 3):   # claps
            mix.add(t0 + k * beat, noise(0.12, 0.3, decay=0.035, lowpass=6000, highpass=900, seed=b * 4 + k))
        for k in range(8):   # shaker
            mix.add(t0 + k * beat / 2, noise(0.05, 0.05 if k % 2 else 0.03, decay=0.012, highpass=6000, seed=500 + b * 8 + k))
        mix.add(t0, tone(110, 0.2, "sine", 0.4, decay=0.08, glide_to=45))   # soft kick
        mix.add(t0 + 2 * beat, tone(110, 0.2, "sine", 0.35, decay=0.08, glide_to=45))
        for n in triads[ch]:   # chord stabs on the off-beats
            for k in (0.5, 1.5, 2.5, 3.5):
                mix.add(t0 + k * beat, tone(hz(n), beat * 0.3, "square", 0.025, decay=0.06, lowpass=3000))
        for k, n in enumerate(melody[b % 4]):
            if n and b >= 2:
                bells.add(t0 + k * beat, bell(n, 0.7, 0.14, 0.25))
        if b % 4 == 3:
            bells.add(t0 + 3.5 * beat, sparkle(0.5, 0.05, seed=rng.randrange(1000)))
    bells.echo(beat * 0.75, feedback=0.25, mix=0.25)
    mix.mix(bells)
    return mix.buf


def main():
    for name, samples in sfx().items():
        synth.write_wav(os.path.join(OUT, name + ".wav"), samples)
    synth.SR = 22050
    synth.write_wav(os.path.join(OUT, "bounce.wav"), bounce(), peak=0.7)


if __name__ == "__main__":
    main()
