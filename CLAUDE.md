# Sparkfrost — notes for Claude

A cozy two-sister puzzle game in Godot 4.7 (GDScript). Frost freezes water into ice; Spark melts ice and lights lanterns. Get both sisters to their exits. It's for girls and families (6+), inspired by the winter-princess genre and based on Andersen's public-domain *The Snow Queen*. This is the second game made with the user's game-launch recipe (see the Cardboard Espionage Action repo for the GitHub, release, browser and video tooling to copy).

## Copyright rules (important)
- Never use Disney names (Elsa, Anna, Olaf, Arendelle, "Frozen"), songs or song-alikes, or their character designs.
- Never put "Frozen" or "Elsa" in titles, tags or marketing.
- Light satire is fine.

## Run and check
- Play: `godot --path .`
- Every change: `bash checks/verify.sh` must end with `sparkfrost: all good` (~60s). It runs the smoke test, `tests/rules_test.gd` (mechanics, map validation, solver proves each level and that `par` equals the true minimum), `tests/input_test.gd` (hold-to-walk, buffered presses, per-sister keys, smart power, undo) and `checks/autoplay.sh` (the real game beats every level at par).
- Dev flags after `--`: `--level=N` (0-based), `--autoplay` (the solver plays), `--exit-on-end` (prints `RESULT …`, `--linger=S`), `--no-music`, `--screenshot=path.png --wait=S`.
- Sound: `python3 tools/make_audio.py` regenerates `audio/` (stdlib synth in `tools/synth.py`, shared with Cardboard). Keep repeated sounds (steps) very quiet.
- New levels: write the map, run verify, and set `par` to the minimum the test reports. Corridors one tile wide often deadlock the two sisters, so leave room to pass.
- Visual check: `godot --path . -- --level=N --screenshot=<scratchpad>/x.png`, then Read the PNG.

## Layout
- `scripts/rules.gd`: all puzzle rules, with no graphics. It has terrain + blocks layers, `move` (one step, pushing a block if needed), `power`, `won`, `key`/`copy` for the solver, and int-encoded actions. The map format is at the top.
- `scripts/solver.gd`: BFS over board states. It gives the shortest solution, proves levels beatable, and sets par.
- `scripts/levels.gd`: levels as ASCII maps with name, hint and par. When you change a map, run verify; the test reports the new minimum to use as par.
- `scripts/game.gd`: input, animation, particles, HUD, undo, stars, saves (`user://sparkfrost.cfg`), emotions and story. Frost is always WASD + Space and Spark is always Arrows + Enter (no switching). Input is polled each frame: hold to keep walking, presses mid-step are buffered, and smart power aims at the one valid neighbour. Changed tiles animate via `_tile_fx`. Moods (happy, joy, proud, surprised, worried, sad) and emotes (heart, !, ?, sparkle, sweat) react to events; Spark is worried next to water. Each level's intro/outro story lines come from levels.gd. It draws from board state every frame and refits to any window shape (the stretch aspect is "expand").
- `scripts/sound.gd`: an SFX pool plus the looping waltz on Music/SFX buses; M toggles music.
- `scripts/art.gd`: all art drawn in code (sky, snow-capped walls, tiles, sisters with moods, emote bubbles). Pastel aurora palette.

## Conventions
- Rules stay deterministic and graphics-free, so the solver and the game always agree.
- Ice is plain ground, with no sliding. The user found "ice slides and water stops you" confusing, so sliding was removed. Don't bring it back without asking. Blocks move one tile per push.
- Frost can't create ice blocks (that rule exploded the solver's state space and was hard for kids). Blocks come only from maps.
- Keep levels compact: big open rooms make the puzzles slack and make the solver slow (verify takes ~70s at 15 levels).
- Scripts use `preload`, not `class_name`. Declare explicit types on values from untyped objects (`var p: Vector2 = obj.thing`), or GDScript fails to parse.
- Comments explain why. The user is learning Godot, so briefly explain new engine concepts.
