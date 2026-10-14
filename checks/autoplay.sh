#!/bin/bash
# Done when: the real game, driven by the solver's moves, beats every level
# at par. That exercises game.gd's input path, not just rules.gd.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT=$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)
count=$(grep -c '"name":' scripts/levels.gd)
fail=0
for ((i = 0; i < count; i++)); do
	line=$("$GODOT" --headless --path . --fixed-fps 60 -- --level=$i --autoplay --exit-on-end 2>&1 | grep RESULT || true)
	echo "${line:-RESULT level=$((i + 1)) did not finish}"
	[[ "$line" == *"complete"*"stars=3"* ]] || fail=1
done
[ $fail -eq 0 ] && echo "autoplay: every level beaten at par" || { echo "autoplay: some levels failed"; exit 1; }
