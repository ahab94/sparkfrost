#!/bin/bash
# Records raw gameplay for the marketing videos into build/footage/, at full
# size for crisp video (learned from Cardboard: Movie Maker records at the
# project's window size and ignores --resolution, so each recording writes a
# temporary override.cfg with the exact layout and window size):
#   p-NN.mp4   portrait 1080x1920 autoplay of level NN (Shorts)
#   l-NN.mp4   landscape 1920x1080 autoplay of level NN (trailer)
#   events-NN.txt  timestamps of moments (freeze, light_all, push, home_*, win)
# Footage has game sound effects only (--no-music); the videos add music.
set -euo pipefail
cd "$(dirname "$0")/../.."
GODOT=$(command -v godot || echo /Applications/Godot.app/Contents/MacOS/Godot)
out=build/footage
mkdir -p "$out"
trap 'rm -f override.cfg' EXIT
count=$(grep -c '"name":' scripts/levels.gd)
levels=("$@")
[ ${#levels[@]} -gt 0 ] || levels=($(seq 1 "$count"))

window() {  # layout-w layout-h window-w window-h
	printf '[display]\nwindow/size/viewport_width=%s\nwindow/size/viewport_height=%s\nwindow/size/window_width_override=%s\nwindow/size/window_height_override=%s\n' "$@" > override.cfg
}

record() {  # name size level
	local name=$1 size=$2 level=$3
	if [ "$size" = 1080x1920 ]; then window 648 1152 1080 1920; else window 1152 648 1920 1080; fi
	"$GODOT" --path . --write-movie "$out/$name.avi" --fixed-fps 30 \
		-- --level="$level" --autoplay --exit-on-end --linger=4 --no-music | grep RESULT | sed "s/^/$name: /" || true
	rm -f override.cfg
	ffmpeg -loglevel error -y -i "$out/$name.avi" -c:v libx264 -preset fast -crf 16 -pix_fmt yuv420p \
		-c:a aac -b:a 192k "$out/$name.mp4"
	rm "$out/$name.avi"
	local got; got=$(ffprobe -v error -select_streams v -show_entries stream=width,height -of csv=p=0:s=x "$out/$name.mp4")
	[ "$got" = "$size" ] || { echo "$name recorded at $got, expected $size"; exit 1; }
}

for n in "${levels[@]}"; do
	id=$(printf %02d "$n")
	"$GODOT" --headless --path . --fixed-fps 30 -- --level=$((n - 1)) --autoplay --exit-on-end --log-events 2>/dev/null \
		| grep EVENT > "$out/events-$id.txt" || true
	record "p-$id" 1080x1920 $((n - 1))
	record "l-$id" 1920x1080 $((n - 1))
done
