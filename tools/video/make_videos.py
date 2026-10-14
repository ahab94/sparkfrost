#!/usr/bin/env python3
"""Builds the marketing videos from recorded footage.

    bash tools/video/record_footage.sh      # once: raw gameplay -> build/footage/
    /usr/bin/python3 tools/video/make_videos.py [video-id ...]

Needs Pillow (captions) and ffmpeg. Writes build/videos/<id>.mp4 plus
docs/marketing/youtube.md (titles, descriptions, tags for uploading).

Each video is a list of segments cut from the footage (optionally sped up),
with captions burned on top. Audio = the footage's game sound effects + an
upbeat music bed + comedy stingers (tools/video/make_video_audio.py).
Adapted from Cardboard Espionage Action's tools/video/make_videos.py.
"""
import json
import os
import subprocess
import sys
import tempfile

from PIL import Image, ImageDraw, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
FOOTAGE = os.path.join(ROOT, "build", "footage")
OUT = os.path.join(ROOT, "build", "videos")
FONT = "/System/Library/Fonts/Supplemental/Arial Rounded Bold.ttf"
VIDEO_AUDIO = os.path.join(ROOT, "build", "video_audio")   # tools/video/make_video_audio.py


def sfx_path(name):
    """Comedy effects (build/video_audio) first, then the game's own (audio/sfx)."""
    for folder in (VIDEO_AUDIO, os.path.join(ROOT, "audio", "sfx")):
        path = os.path.join(folder, name + ".wav")
        if os.path.exists(path):
            return path
    raise FileNotFoundError(name)

PLAY = "https://ahab94.github.io/sparkfrost/"
PLAY_SHORT = "ahab94.github.io/sparkfrost"   # shown on screen
REPO = "https://github.com/ahab94/sparkfrost"
RELEASES = REPO + "/releases/latest"

# Sparkfrost's pastel aurora palette.
CYAN = (143, 216, 255)      # Frost blue
YELLOW = (255, 211, 77)
GREEN = (255, 194, 224)     # used for counters: soft pink here
PINK = (255, 143, 177)
ORANGE = (255, 179, 107)    # Spark orange
NAVY = (42, 35, 80)         # sky
INK = (59, 47, 92)

LINKS = f"""⭐ Free and open source on GitHub, a star helps a lot: {REPO}
⬇ Windows / Mac / Linux downloads: {RELEASES}"""


def description(blurb, tags):
    return f"""▶ PLAY FREE in your browser (computer or phone): {PLAY}

{blurb}

{LINKS}

Sparkfrost is a free, cozy puzzle game about two princess sisters: Frost freezes water into ice bridges, and Spark melts ice and lights the lanterns. Get both sisters home across 15 levels. Play together on one keyboard, or with on-screen controls on a phone. Made with the Godot engine; every sound and pixel is made in code.

{" ".join("#" + t for t in tags)}"""


HASHTAGS = ["Sparkfrost", "puzzlegame", "indiegame", "princess", "cozygames"]
BASE_TAGS = ["sparkfrost", "puzzle game", "princess game", "sister game", "free game", "browser game",
             "co-op game", "2 player game", "cozy game", "indie game", "godot"]

# --- The videos --------------------------------------------------------------
# Times are in seconds. Segment times refer to the source clip; caption and
# sfx times refer to the finished video (after any intro card).
# "kids": True -> marked "Made for kids" on YouTube (aimed at children);
# False -> made for grown-ups (devlog, parents). Decided per video, honestly.

VIDEOS = [
    {
        "id": "01-sisters", "orient": "portrait", "kids": True,
        "intro": ("TWO PRINCESS\nSISTERS", 2.2),
        "segments": [("p-01", 1.2, 4.0, 1.0), ("p-02", 4.6, 7.4, 1.0), ("p-07", 1.2, 3.4, 1.0),
                     ("p-13", 4.8, 9.0, 1.4), ("p-15", 10.6, 14.6, 1.0)],
        "captions": [(0.0, 2.8, "FROST freezes water\ninto ice bridges", "hook"),
                     (2.8, 5.6, "SPARK lights\nthe magic lanterns", "hook"),
                     (5.6, 7.8, "Push the ice blocks!", "hook"),
                     (7.8, 10.8, "Work together...", "hook"),
                     (10.8, 14.8, "...and get home!", "hook")],
        "sfx": [(-2.0, "pop"), (-0.3, "slide_up"), (0.96, "sparkle"), (4.09, "sparkle"), (6.56, "pop"), (10.96, "tada")],
        "cut_whoosh": True, "outro": 3.0,
        "title": "Two princess sisters: one of ice, one of fire ❄️🔥 #shorts",
        "blurb": "Frost freezes water into ice bridges. Spark lights the magic lanterns. Can they both get home?",
        "tags": BASE_TAGS + ["shorts", "princess sisters"],
    },
    {
        "id": "02-both-home", "orient": "portrait", "kids": True,
        "segments": [("p-01", 0.0, 10.1, 1.0)],
        "captions": [(0.0, 2.1, "Can you get BOTH\nprincesses home?", "hook"),
                     (2.1, 3.7, "Frost freezes\nthe water...", "hook"),
                     (3.8, 6.0, "Now Spark can cross!", "hook"),
                     (6.1, 7.0, "YAY!", "big")],
        "sfx": [(0.4, "uh_oh", 0.7), (2.16, "sparkle"), (2.96, "sparkle"), (6.09, "tada")],
        "title": "Can you get BOTH princesses home? 👑 #shorts",
        "blurb": "Two princess sisters, one river. Frost freezes a bridge so they can both get home!",
        "tags": BASE_TAGS + ["shorts", "puzzle"],
    },
    {
        "id": "03-scared-of-water", "orient": "portrait", "kids": True,
        "segments": [("p-04", 0.0, 12.5, 1.0)],
        "captions": [(0.0, 2.6, "Spark is scared\nof water...", "hook"),
                     (2.6, 4.7, "Don't worry, sis!", "hook"),
                     (4.8, 8.4, "An ice bridge!\nNow she's safe", "hook"),
                     (8.6, 9.5, "So brave!", "big")],
        "sfx": [(0.3, "uh_oh"), (2.63, "sparkle"), (8.56, "tada"), (9.0, "aww", 0.8)],
        "title": "Spark is scared of water... 💧 #shorts",
        "blurb": "Spark can't swim, so her big sister Frost freezes the water into a bridge.",
        "tags": BASE_TAGS + ["shorts", "sisters", "cute"],
    },
    {
        "id": "04-lanterns", "orient": "portrait", "kids": True,
        "segments": [("p-02", 0.8, 10.2, 1.0), ("p-14", 5.8, 10.0, 1.0)],
        "captions": [(0.0, 2.5, "Spark has a\nmagic light", "hook"),
                     (2.5, 5.0, "Light the lantern...", "hook"),
                     (5.1, 7.6, "...and the gate\nOPENS!", "hook"),
                     (9.4, 13.6, "Light them ALL!", "hook")],
        "sfx": [(5.09, "sparkle"), (10.16, "pop"), (12.82, "tada")],
        "cut_whoosh": True,
        "title": "Lighting the magic lanterns ✨ #shorts",
        "blurb": "Spark lights the lanterns, and the golden gates swing open.",
        "tags": BASE_TAGS + ["shorts", "magic", "lanterns"],
    },
    {
        "id": "05-ice-bridge", "orient": "portrait", "kids": True,
        "segments": [("p-07", 0.8, 10.5, 1.0)],
        "captions": [(0.0, 1.4, "Push the\nice block...", "hook"),
                     (1.4, 3.4, "SPLASH!\nAn ice bridge!", "hook"),
                     (5.4, 7.4, "One more!", "hook"),
                     (7.8, 9.7, "Teamwork!", "hook")],
        "sfx": [(1.36, "boing", 0.7), (5.89, "boing", 0.7), (7.76, "tada")],
        "title": "Building a bridge out of ice! 🧊 #shorts",
        "blurb": "Push an ice block into the water and it turns into a bridge!",
        "tags": BASE_TAGS + ["shorts", "ice", "bridge"],
    },
    {
        "id": "06-hugs", "orient": "portrait", "kids": True,
        "segments": [("p-01", 5.9, 10.1, 1.0), ("p-05", 8.0, 12.2, 1.0), ("p-09", 8.7, 12.9, 1.0), ("p-15", 10.6, 14.7, 1.0)],
        "captions": [(0.0, 4.2, "When both sisters\nget home...", "hook"),
                     (4.2, 8.4, "...they HUG!", "hook"),
                     (8.4, 12.6, "Every. Single. Time.", "hook"),
                     (12.6, 16.7, "Aww!", "hook")],
        "sfx": [(0.6, "aww", 0.8), (4.8, "aww", 0.8), (9.0, "aww", 0.8), (13.1, "aww", 0.8)],
        "cut_whoosh": True,
        "title": "When both sisters get home... ❤️ #shorts",
        "blurb": "Every time Frost and Spark make it home, they hug. Every. Single. Time.",
        "tags": BASE_TAGS + ["shorts", "sisters", "wholesome"],
    },
    {
        "id": "07-final-level", "orient": "portrait", "kids": True,
        "segments": [("p-15", 0.0, 14.7, 1.15)],
        "captions": [(0.0, 1.9, "The FINAL level!", "hook"),
                     (1.9, 3.9, "Push the block...", "hook"),
                     (3.9, 6.5, "Light the last\nlanterns!", "hook"),
                     (6.5, 9.3, "Almost home...", "hook")],
        "sfx": [(4.19, "sparkle"), (9.36, "tada")],
        "title": "The final level: Aurora Spire 🌌 #shorts",
        "blurb": "The last lanterns at the top of the Aurora Spire. Can the sisters light up the sky?",
        "tags": BASE_TAGS + ["shorts", "final level"],
    },
    {
        "id": "08-i-made-a-game", "orient": "portrait", "kids": False,
        "segments": [("p-01", 1.5, 3.9, 1.2), ("p-02", 5.0, 7.4, 1.2), ("p-07", 1.3, 2.8, 1.0),
                     ("p-10", 4.8, 6.8, 1.2), ("p-13", 4.8, 8.6, 1.6), ("p-15", 10.6, 13.6, 1.0)],
        "captions": [(0.0, 2.0, "I made a free puzzle game\nabout two princess sisters", "hook"),
                     (2.0, 4.0, "One freezes water.\nOne melts ice.", "hook"),
                     (4.0, 5.5, "Ice blocks\nbecome bridges", "hook"),
                     (5.5, 7.2, "15 levels, all proven\nbeatable by a solver", "hook"),
                     (7.2, 9.6, "Every sound and pixel\nis made in code", "hook"),
                     (9.6, 12.6, "Free in your browser,\neven on phones", "hook")],
        "sfx": [(0.2, "pop"), (12.0, "tada")],
        "cut_whoosh": True, "caption_pop": True,
        "title": "I made a free puzzle game about two princess sisters #shorts",
        "blurb": "A cozy co-op puzzle game I built in Godot: one sister freezes water, the other melts ice. Free and open source.",
        "tags": BASE_TAGS + ["shorts", "devlog", "i made a game", "gamedev", "solo dev"],
    },
    {
        "id": "09-solver", "orient": "portrait", "kids": False,
        "segments": [("p-10", 0.0, 14.7, 2.0), ("p-13", 0.0, 17.6, 2.2), ("p-12", 0.0, 16.5, 2.2)],
        "captions": [(0.0, 3.5, "This isn't me playing.", "hook"),
                     (3.5, 7.4, "It's a solver: it tries\nevery possible move", "hook"),
                     (7.4, 11.4, "...and finds the\nshortest solution", "hook"),
                     (11.4, 15.4, "If a level can't be\nbeaten, the build fails", "hook"),
                     (15.4, 19.4, "It caught my broken\nlevel designs", "hook")],
        "sfx": [(5.38, "ding"), (13.57, "ding"), (21.06, "ding")],
        "cut_whoosh": True,
        "title": "My game has a bot that proves every level is beatable #shorts",
        "blurb": "A breadth-first search solver checks every level of my puzzle game, and sets each level's par to the fewest possible moves.",
        "tags": BASE_TAGS + ["shorts", "gamedev", "algorithm", "programming", "devlog"],
    },
    {
        "id": "10-siblings", "orient": "portrait", "kids": False,
        "segments": [("p-08", 0.8, 6.0, 1.2), ("p-touch-03", 3.0, 11.0, 1.3), ("p-11", 2.0, 11.0, 1.5), ("p-14", 12.0, 16.3, 1.0)],
        "captions": [(0.0, 4.3, "Looking for a game\nsiblings play TOGETHER?", "hook"),
                     (4.3, 10.5, "Phones get\non-screen controls", "hook"),
                     (10.5, 16.5, "One keyboard:\nWASD + Arrows", "hook"),
                     (16.5, 20.8, "Free. No ads.\nNo sign-up.", "hook")],
        "sfx": [(0.2, "pop"), (17.0, "tada")],
        "cut_whoosh": True,
        "title": "A free 2-player game siblings can play together #shorts",
        "blurb": "Sparkfrost is a cozy co-op puzzle game for two: one keyboard, or on-screen controls on a phone. Free, no ads, no sign-up.",
        "tags": BASE_TAGS + ["shorts", "games for kids", "family games", "local co-op", "parents"],
    },
    {
        "id": "11-trailer", "orient": "landscape", "kids": True,
        "intro": ("TWO PRINCESS SISTERS.\nONE OF ICE, ONE OF FIRE.", 3.0),
        "segments": [("l-01", 1.2, 4.0, 1.0), ("l-02", 4.6, 7.4, 1.0), ("l-07", 1.2, 3.4, 1.0),
                     ("l-12", 6.8, 10.4, 1.0), ("l-13", 4.8, 9.0, 1.4), ("l-15", 10.6, 14.6, 1.0)],
        "captions": [(0.0, 2.8, "Frost freezes water into bridges", "low"),
                     (2.8, 5.6, "Spark lights the lanterns", "low"),
                     (5.6, 7.8, "Push ice blocks into the river", "low"),
                     (7.8, 11.4, "Open the golden gates", "low"),
                     (11.4, 14.4, "15 cozy puzzles to solve together", "low"),
                     (14.4, 18.4, "...and get both sisters home!", "low")],
        "sfx": [(-2.7, "pop"), (-0.5, "slide_up"), (0.96, "sparkle"), (4.09, "sparkle"), (6.56, "pop"), (10.8, "sparkle"), (14.56, "tada")],
        "cut_whoosh": True, "caption_pop": False, "outro": 4.5,
        "title": "Sparkfrost: two princess sisters, one of ice and one of fire (free puzzle game trailer)",
        "blurb": "Two princess sisters journey to light the Northern Lights again. Frost freezes water, Spark melts ice and lights lanterns. Play together, free.",
        "tags": BASE_TAGS + ["game trailer", "puzzle game trailer", "kids game"],
    },
]


# --- Graphics ------------------------------------------------------------------

def frame_size(orient):
    return (1080, 1920) if orient == "portrait" else (1920, 1080)


def font(size):
    return ImageFont.truetype(FONT, size)


def draw_centered(draw, lines, y_center, size, fill, width, stroke=10, line_gap=1.12):
    f = font(size)
    heights = [size * line_gap] * len(lines)
    y = y_center - sum(heights) / 2
    for line, h in zip(lines, heights):
        w = draw.textlength(line, font=f)
        draw.text(((width - w) / 2, y), line, font=f, fill=fill, stroke_width=stroke, stroke_fill=INK)
        y += h


def caption_png(path, text, style, orient):
    """Full-frame transparent PNG with the caption placed for the format."""
    W, H = frame_size(orient)
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    lines = text.split("\n") if text else []
    portrait = orient == "portrait"
    if not lines:
        img.save(path)
        return
    if style == "big":
        draw_centered(d, lines, H * (0.29 if portrait else 0.5), 150 if portrait else 140, YELLOW, W, stroke=14)
    elif style == "note":
        draw_centered(d, lines, H * 0.39, 48, (200, 220, 230), W, stroke=6)
    elif style == "counter":
        draw_centered(d, lines, H * 0.84, 110, GREEN, W, stroke=12)
    elif style == "cta":   # call to action with the play link, above the Shorts UI
        cy = H * (0.66 if portrait else 0.78)
        f1, f2 = font(52 if portrait else 60), font(36 if portrait else 38)
        l1, l2 = "PLAY FREE IN YOUR BROWSER", PLAY_SHORT
        w = max(d.textlength(l1, font=f1), d.textlength(l2, font=f2)) + 140
        w = min(w, W - 60)
        h = 190 if portrait else 175
        d.rounded_rectangle([(W - w) / 2, cy - h / 2, (W + w) / 2, cy + h / 2], 30, fill=(255, 216, 74, 245))
        # a drawn "play" triangle, since the font has no symbol for it
        tx = (W - d.textlength(l1, font=f1)) / 2 - 10
        d.polygon([(tx - 46, cy - 62), (tx - 46, cy - 18), (tx - 8, cy - 40)], fill=INK)
        d.text(((W - d.textlength(l1, font=f1)) / 2 + 12, cy - 75), l1, font=f1, fill=INK)
        d.text(((W - d.textlength(l2, font=f2)) / 2, cy + 18), l2, font=f2, fill=(20, 40, 60))
    elif style == "low":   # landscape lower-third
        size = 76
        f = font(size)
        widths = [d.textlength(l, font=f) for l in lines]
        box_w, box_h = max(widths) + 80, len(lines) * size * 1.15 + 40
        y0 = H - box_h - 120
        d.rounded_rectangle([(W - box_w) / 2, y0, (W + box_w) / 2, y0 + box_h], 28, fill=(3, 10, 18, 190))
        draw_centered(d, lines, y0 + box_h / 2, size, (255, 255, 255), W, stroke=0)
    else:  # hook: the top band of a Short, where the platform UI doesn't cover it
        size = 84 if max(len(l) for l in lines) <= 18 else 70
        f = font(size)
        widths = [d.textlength(l, font=f) for l in lines]
        box_w, box_h = min(W - 40, max(widths) + 70), len(lines) * size * 1.15 + 44
        cy = H * 0.215
        d.rounded_rectangle([(W - box_w) / 2, cy - box_h / 2, (W + box_w) / 2, cy + box_h / 2], 34,
                            fill=(255, 255, 255, 235))
        draw_centered(d, lines, cy, size, INK, W, stroke=0)
    img.save(path)


def draw_icons(d, cx, cy, s):
    """Frost's snowflake and Spark's sun, side by side: the game's emblem."""
    import math
    fx, sx = cx - s * 1.1, cx + s * 1.1
    d.ellipse([fx - s, cy - s, fx + s, cy + s], fill=(143, 216, 255, 255))
    for k in range(6):
        a = k * math.pi / 3
        d.line([fx, cy, fx + math.cos(a) * s * 0.7, cy + math.sin(a) * s * 0.7], fill=INK, width=max(6, int(s * 0.14)))
    d.ellipse([sx - s, cy - s, sx + s, cy + s], fill=(255, 179, 107, 255))
    for k in range(8):
        a = k * math.pi / 4
        d.line([sx + math.cos(a) * s * 0.45, cy + math.sin(a) * s * 0.45, sx + math.cos(a) * s * 0.78, cy + math.sin(a) * s * 0.78],
               fill=INK, width=max(6, int(s * 0.12)))
    d.ellipse([sx - s * 0.32, cy - s * 0.32, sx + s * 0.32, cy + s * 0.32], fill=INK)


def _sky(W, H):
    """A soft aurora-sky background, like the game's."""
    img = Image.new("RGB", (W, H), NAVY)
    d = ImageDraw.Draw(img)
    for y in range(H):
        t = y / H
        d.line([0, y, W, y], fill=(int(42 + (27 - 42) * t), int(35 + (58 - 35) * t), int(80 + (90 - 80) * t)))
    for i, (col, yy) in enumerate([((110, 230, 200), 0.2), ((230, 160, 255), 0.3), ((140, 210, 255), 0.4)]):
        band = Image.new("RGBA", (W, H), (0, 0, 0, 0))
        bd = ImageDraw.Draw(band)
        bd.ellipse([-W * 0.3, H * yy - H * 0.05, W * 1.3, H * yy + H * 0.08], fill=col + (38,))
        img.paste(band, (0, 0), band)
    d = ImageDraw.Draw(img)
    import random
    rng = random.Random(5)
    for _ in range(80):
        x, y, r = rng.uniform(0, W), rng.uniform(0, H), rng.uniform(1.5, 4)
        d.ellipse([x - r, y - r, x + r, y + r], fill=(255, 255, 255))
    return img


def card_png(path, orient, title_lines, kind):
    W, H = frame_size(orient)
    img = _sky(W, H)
    d = ImageDraw.Draw(img)
    portrait = orient == "portrait"
    if kind == "intro":
        draw_icons(d, W // 2, int(H * (0.34 if portrait else 0.3)), 95 if portrait else 85)
        draw_centered(d, title_lines, H * (0.58 if portrait else 0.68), 104 if portrait else 100, (255, 255, 255), W, stroke=12)
    else:  # outro: title + call to action
        draw_icons(d, W // 2, int(H * (0.24 if portrait else 0.2)), 80 if portrait else 65)
        draw_centered(d, ["SPARKFROST"], H * (0.4 if portrait else 0.42), 130 if portrait else 120, CYAN, W, stroke=12)
        draw_centered(d, ["PLAY FREE", "IN YOUR BROWSER"] if portrait else ["PLAY FREE IN YOUR BROWSER"],
                      H * (0.56 if portrait else 0.6), 84 if portrait else 78, YELLOW, W, stroke=10)
        draw_centered(d, [PLAY_SHORT], H * (0.68 if portrait else 0.74), 52 if portrait else 46, (255, 255, 255), W, stroke=6)
        draw_centered(d, ["on a computer or a phone"], H * (0.75 if portrait else 0.84), 44 if portrait else 40, (220, 214, 247), W, stroke=6)
    img.save(path)


def thumbnail_png(path):
    """Custom thumbnail for the 16:9 trailer: a real frame of the sisters'
    win-screen hug, with a big title."""
    W, H = 1280, 720
    shot = os.path.join(FOOTAGE, "thumb-src.png")
    if os.path.exists(shot):
        src = Image.open(shot).convert("RGB")   # a 1920x1080 frame of the win screen
        img = src.crop((440, 250, 1480, 835)).resize((W, H))
    else:
        img = _sky(W, H)
    d = ImageDraw.Draw(img)
    d.rectangle([0, 0, W, 170], fill=(42, 35, 80))
    draw_centered(d, ["TWO SISTERS. ICE + FIRE."], 90, 92, (255, 255, 255), W, stroke=10)
    d.rectangle([0, H - 140, W, H], fill=(42, 35, 80))
    draw_centered(d, ["FREE PUZZLE GAME"], H - 70, 72, YELLOW, W, stroke=10)
    img.save(path)


# --- Assembly --------------------------------------------------------------------

def run(cmd):
    subprocess.run(cmd, check=True)


def atempo_chain(speed):
    # atempo accepts 0.5..2.0 per stage, so chain stages for bigger changes.
    parts, s = [], speed
    while s > 2.0:
        parts.append("atempo=2.0")
        s /= 2.0
    parts.append(f"atempo={s:.4f}")
    return ",".join(parts)


def cut(src, start, end, speed, path, W, H, keep_audio):
    vf = f"setpts=PTS/{speed},scale={W}:{H},fps=30"
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-ss", str(start), "-to", str(end),
           "-i", os.path.join(FOOTAGE, src + ".mp4"), "-vf", vf]
    if keep_audio:
        cmd += ["-af", atempo_chain(speed) + ",aresample=48000", "-c:a", "aac", "-b:a", "192k", "-ac", "2"]
    else:
        cmd += ["-an"]
    cmd += ["-c:v", "libx264", "-preset", "fast", "-crf", "16", "-pix_fmt", "yuv420p", path]
    run(cmd)


def still(png, seconds, path, keep_audio):
    cmd = ["ffmpeg", "-loglevel", "error", "-y", "-loop", "1", "-t", str(seconds), "-i", png]
    if keep_audio:
        cmd += ["-f", "lavfi", "-t", str(seconds), "-i", "anullsrc=r=48000:cl=stereo",
                "-c:a", "aac", "-b:a", "192k", "-shortest"]
    cmd += ["-vf", "fps=30,format=yuv420p", "-c:v", "libx264", "-preset", "fast", "-crf", "16", path]
    run(cmd)


def duration(path):
    out = subprocess.run(["ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", path],
                         capture_output=True, text=True, check=True).stdout
    return float(out.strip())


def build(v, tmp):
    W, H = frame_size(v["orient"])
    clip_audio = True   # always keep the footage's game sound effects
    parts = []
    if "intro" in v:
        text, secs = v["intro"]
        png = os.path.join(tmp, "intro.png")
        card_png(png, v["orient"], text.split("\n"), "intro")
        parts.append(os.path.join(tmp, "intro.mp4"))
        still(png, secs, parts[-1], clip_audio)
    for i, (src, a, b, speed) in enumerate(v["segments"]):
        parts.append(os.path.join(tmp, f"seg{i}.mp4"))
        cut(src, a, b, speed, parts[-1], W, H, clip_audio)
    if v.get("outro"):
        png = os.path.join(tmp, "outro.png")
        card_png(png, v["orient"], [], "outro")
        parts.append(os.path.join(tmp, "outro.mp4"))
        still(png, v["outro"], parts[-1], clip_audio)

    listing = os.path.join(tmp, "list.txt")
    with open(listing, "w") as f:
        f.writelines(f"file '{p}'\n" for p in parts)
    joined = os.path.join(tmp, "joined.mp4")
    run(["ffmpeg", "-loglevel", "error", "-y", "-f", "concat", "-safe", "0", "-i", listing, "-c", "copy", joined])
    total = duration(joined)
    offset = v["intro"][1] if "intro" in v else 0.0   # captions are timed from the first gameplay frame

    # Captions: one transparent full-frame PNG each, shown over its time window.
    # Every video ends with the play link on screen: links in Shorts
    # descriptions aren't clickable, so viewers need to see the address.
    gameplay_end = total - offset - (v.get("outro") or 0)
    captions = list(v["captions"])
    if not v.get("outro"):
        captions.append((max(0.0, gameplay_end - 3.0), gameplay_end, "cta", "cta"))
    inputs, filters, last = [], [], "[0:v]"
    for i, (t0, t1, text, style) in enumerate(captions):
        png = os.path.join(tmp, f"cap{i}.png")
        caption_png(png, text, style, v["orient"])
        # Loop the still image for the whole video: a single-frame input ends
        # immediately, so a caption that starts after an intro card would never show.
        inputs += ["-loop", "1", "-t", f"{total:.2f}", "-i", png]
        filters.append(f"{last}[{i + 1}:v]overlay=0:0:enable='between(t,{t0 + offset:.2f},{t1 + offset:.2f})'[v{i}]")
        last = f"[v{i}]"
    n_caps = len(captions)

    # Audio: the clip's game sound effects (footage is recorded without game
    # music), a playful music bed, comedy stingers from the spec, a soft pop
    # on every caption and a whoosh on every cut.
    cues = [(t + offset, name, vol) for t, name, vol in
            [(c[0], c[1], c[2] if len(c) > 2 else 1.0) for c in v.get("sfx", [])]]
    if v.get("caption_pop", True):
        cues += [(t0 + offset, "pop", 0.45) for t0, _, text, _ in v["captions"] if text]
    if v.get("cut_whoosh"):
        t = offset
        for _, a, b, speed in v["segments"][:-1]:
            t += (b - a) / speed
            cues.append((t - 0.15, "whoosh", 0.5))
    base = n_caps + 1
    audio_inputs = ["-stream_loop", "-1", "-i", os.path.join(VIDEO_AUDIO, v.get("music", "bounce") + ".wav")]
    mix = ["[0:a]volume=1.0[g]", f"[{base}:a]volume={v.get('music_volume', 0.5)}[m]"]
    labels = ["[g]", "[m]"]
    for j, (t, name, vol) in enumerate(cues):
        audio_inputs += ["-i", sfx_path(name)]
        ms = max(0, int(t * 1000))
        mix.append(f"[{base + 1 + j}:a]adelay={ms}|{ms},volume={vol * 1.2:.2f}[s{j}]")
        labels.append(f"[s{j}]")
    mix.append(f"{''.join(labels)}amix=inputs={len(labels)}:normalize=0:duration=first,atrim=0:{total:.2f},"
               f"loudnorm=I=-14:TP=-1.5:LRA=11,afade=t=in:d=0.2,afade=t=out:st={total - 0.8:.2f}:d=0.8,"
               f"aresample=48000[a]")
    audio_filter = ";".join(mix)

    graph = ";".join(filters + [audio_filter]) if filters else audio_filter
    vmap = last if filters else "0:v"
    out = os.path.join(OUT, v["id"] + ".mp4")
    run(["ffmpeg", "-loglevel", "error", "-y", "-i", joined, *inputs, *audio_inputs,
         "-filter_complex", graph, "-map", vmap, "-map", "[a]",
         "-c:v", "libx264", "-preset", "slow", "-crf", "18", "-pix_fmt", "yuv420p", "-r", "30",
         "-c:a", "aac", "-b:a", "192k", "-ac", "2", "-movflags", "+faststart", "-t", f"{total:.2f}", out])
    print(f"{v['id']}: {total:.1f}s -> {os.path.relpath(out, ROOT)}")
    return total


def write_metadata(lengths):
    path = os.path.join(ROOT, "docs", "marketing", "youtube.md")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    lines = ["# YouTube uploads", "",
             "Generated by `tools/video/make_videos.py`. Upload as **Private** first, then publish after review.",
             "Every video goes in the **Sparkfrost** playlist. The audience is set per video, honestly:",
             "*Made for kids* = aimed at children; *Not made for kids* = aimed at grown-ups (devlog, parents).", ""]
    for v in VIDEOS:
        aud = "Made for kids" if v["kids"] else "Not made for kids"
        lines += [f"## {v['id']} ({'Short' if v['orient'] == 'portrait' else 'video'}, {lengths.get(v['id'], 0):.0f}s, {aud})", "",
                  f"**Title:** {v['title']}", "", "**Description:**", "", "```",
                  description(v["blurb"], HASHTAGS), "```", "", f"**Tags:** {', '.join(v['tags'])}", ""]
    with open(path, "w") as f:
        f.write("\n".join(lines))
    with open(os.path.join(OUT, "metadata.json"), "w") as f:
        json.dump([{"id": v["id"], "file": v["id"] + ".mp4", "title": v["title"], "kids": v["kids"],
                    "description": description(v["blurb"], HASHTAGS), "tags": v["tags"],
                    "short": v["orient"] == "portrait"} for v in VIDEOS], f, indent=2, ensure_ascii=False)
    print("wrote", os.path.relpath(path, ROOT))


def main():
    os.makedirs(OUT, exist_ok=True)
    wanted = set(sys.argv[1:])
    lengths = {}
    for v in VIDEOS:
        if wanted and v["id"] not in wanted and v["id"].split("-")[0] not in wanted:
            continue
        with tempfile.TemporaryDirectory() as tmp:
            lengths[v["id"]] = build(v, tmp)
    thumbnail_png(os.path.join(OUT, "11-trailer-thumbnail.png"))
    if not wanted:
        write_metadata(lengths)


if __name__ == "__main__":
    main()
