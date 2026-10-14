# Sparkfrost ❄️🔥

Two princess sisters, one of ice and one of fire, solve snowy puzzles together.

**Frost** freezes water into ice bridges. **Spark** melts ice and lights the lanterns that open the gates. Push ice blocks into water to build bridges. Get both sisters home!

## Play
**▶ [Play in your browser](https://ahab94.github.io/sparkfrost/)**: works on computers and phones, nothing to install.

Desktop downloads for Windows, macOS and Linux are on the [Releases](../../releases) page.

## Controls
| | Frost ❄️ | Spark 🔥 |
|---|---|---|
| Move (hold to keep walking) | WASD | Arrow keys |
| Use power | Space | Enter |

On phones and tablets, each sister gets an on-screen pad (Frost on the left, Spark on the right); the middle button uses her power.

Z undo · R restart · M music · [ ] change level. Play alone with both hands, or with a friend.

Beat each of the 15 levels in par moves for ⭐⭐⭐.

## Development
Made with [Godot 4.7](https://godotengine.org). Everything is drawn in code.

```bash
godot --path .              # play
bash checks/verify.sh       # tests + the solver proves every level is beatable
```

- Pushing a `v*` tag builds Windows, macOS, Linux and Web in GitHub Actions, attaches them to a release, and deploys the web version to GitHub Pages.
- Levels are ASCII maps in `scripts/levels.gd`. A built-in solver finds the fewest moves for each level, so every level is guaranteed beatable, and par is the true minimum.
