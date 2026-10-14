# Sparkfrost ❄️🔥

Two princess sisters, one of ice and one of fire, solve snowy puzzles together.

**Frost** freezes water into ice bridges. **Spark** melts ice and lights the lanterns that open the gates. The ice is slippery! Get both sisters home.

## Controls
| | Frost ❄️ | Spark 🔥 |
|---|---|---|
| Move (hold to keep walking) | WASD | Arrow keys |
| Use power | Space | Enter |

Z undo · R restart · M music · [ ] change level. Play alone with both hands, or with a friend.

Beat each of the 15 levels in par moves for ⭐⭐⭐.

## Development
Made with [Godot 4.7](https://godotengine.org). Everything is drawn in code.

```bash
godot --path .              # play
bash checks/verify.sh       # tests + the solver proves every level is beatable
```

Levels are ASCII maps in `scripts/levels.gd`. A built-in solver finds the fewest moves for each level, so every level is guaranteed beatable, and par is the true minimum.
