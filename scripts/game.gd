extends Node2D
## Runs Sparkfrost: shows the board, takes input, animates the sisters, and
## handles winning, undo, stars and saves. The puzzle logic itself lives in
## rules.gd; this script only asks it what happens and draws the result.
##
## Controls: Frost is always WASD + Space, Spark is always Arrows + Enter.
## No switching needed; one player uses both hands, or two players share the
## keyboard. Holding a direction keeps walking, and a key pressed mid-step is
## remembered and played as soon as the step ends.
##
## Everything is drawn in _draw() each frame from the current board, so the
## layout refits whenever the window changes shape (wide or tall).

const Rules := preload("res://scripts/rules.gd")
const Levels := preload("res://scripts/levels.gd")
const Solver := preload("res://scripts/solver.gd")
const Art := preload("res://scripts/art.gd")
const Sound := preload("res://scripts/sound.gd")

const SAVE_PATH := "user://sparkfrost.cfg"
const STEP_TIME := 0.15      # seconds per tile walked
const BUFFER_TIME := 0.3     # how long an early key press is remembered
const NAMES := ["Frost", "Spark"]
const KEYS := ["WASD + Space", "Arrows + Enter"]
const DIR_ACTIONS := [["f_up", "f_right", "f_down", "f_left"], ["s_up", "s_right", "s_down", "s_left"]]
const POWER_ACTIONS := ["f_power", "s_power"]

var level_index := 0
var board                      # rules.gd instance
var active := Rules.FROST      # the sister who acted last (highlighted)
var moves := 0
var won := false
var history: Array = []        # undo stack of [board copy, moves, active]
var best_stars := {}           # level index -> stars earned
var save_enabled := true
var sound

var _t := 0.0
var _level_t := 0.0
var _vis: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]   # drawn positions, in tiles
var _paths: Array = [[], []]                                 # tiles still to animate through
var _seg: Array = [{}, {}]                                   # current animation segment per sister
var _squash: Array[float] = [0.0, 0.0]
var _buffer: Array = [null, null]                            # [action, time] pressed early
var _mood: Array = [["happy", 0.0], ["happy", 0.0]]          # [mood, until]
var _emote: Array = [["", 0.0], ["", 0.0]]                   # [kind, until]
var _wiggle: Array[float] = [0.0, 0.0]
var _tile_fx := {}                                           # cell -> [old tile, new tile, start time]
var _block_fx := {}                                          # cell -> start time (a block melting away)
var _particles: Array = []
var _snow: Array = []
var _font: Font
var _tile := 64.0
var _origin := Vector2.ZERO
var _autoplay: Array = []
var _auto_timer := 0.0
var _first_move_t := -1.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_setup_input()
	sound = Sound.new()
	add_child(sound)
	if _dev_flag("autoplay"):
		save_enabled = false
	if _dev_flag("no-music"):
		sound.music_on = false
	_load_progress()
	for i in 70:
		_snow.append([randf(), randf(), randf_range(0.4, 1.0), randf() * TAU])
	load_level(clampi(int(_dev_arg("level", "0")), 0, Levels.LEVELS.size() - 1))
	sound.start_music()
	if _dev_flag("autoplay"):
		_autoplay = Solver.solve(Levels.LEVELS[level_index]["map"])["actions"]
		_auto_timer = 1.2
	var shot := _dev_arg("screenshot", "")
	if shot != "":
		_save_screenshot_and_quit(shot)


func load_level(index: int) -> void:
	level_index = index
	board = Rules.new()
	board.load_map(Levels.LEVELS[index]["map"])
	active = Rules.FROST
	moves = 0
	won = false
	history.clear()
	_particles.clear()
	_tile_fx.clear()
	_block_fx.clear()
	_level_t = 0.0
	_first_move_t = -1.0
	for si in 2:
		_vis[si] = Vector2(board.pos[si])
		_paths[si] = []
		_seg[si] = {}
		_buffer[si] = null
		_mood[si] = ["happy", 0.0]
		_emote[si] = ["", 0.0]


func par() -> int:
	return int(Levels.LEVELS[level_index].get("par", 0))


func stars_for(move_count: int) -> int:
	var p := par()
	if p == 0 or move_count <= p:
		return 3
	return 2 if move_count <= int(ceil(p * 1.5)) else 1


func _busy(si: int) -> bool:
	return not (_paths[si].is_empty() and _seg[si].is_empty())


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		load_level(level_index)
	elif event.is_action_pressed("next_level"):
		load_level((level_index + 1) % Levels.LEVELS.size())
	elif event.is_action_pressed("prev_level"):
		load_level((level_index - 1 + Levels.LEVELS.size()) % Levels.LEVELS.size())
	elif event.is_action_pressed("music"):
		sound.toggle_music()
	elif won and event.is_action_pressed("s_power"):   # Enter
		load_level((level_index + 1) % Levels.LEVELS.size())
	elif event.is_action_pressed("undo"):
		undo()


## Polled every frame so holding a key keeps walking. Presses that arrive
## while a sister is mid-step are buffered and played when she's free.
func _poll_input() -> void:
	if won:
		return
	for si in 2:
		for i in 4:
			if Input.is_action_just_pressed(DIR_ACTIONS[si][i]):
				_buffer[si] = [Rules.action(si, false, i), _t]
		if Input.is_action_just_pressed(POWER_ACTIONS[si]):
			_buffer[si] = [-1, _t]   # -1 = "use power, aim it smartly"
		if _busy(si):
			continue
		var b = _buffer[si]
		if b != null:
			_buffer[si] = null
			if _t - float(b[1]) <= BUFFER_TIME:
				if int(b[0]) == -1:
					_player_power(si)
				else:
					do_action(int(b[0]), true)
				continue
		for i in 4:
			if Input.is_action_pressed(DIR_ACTIONS[si][i]):
				do_action(Rules.action(si, false, i), false)
				break


## Powers aim where you're facing. If nothing can happen there but exactly
## one neighbouring tile would work, aim there instead, so kids don't have to
## line up perfectly.
func _player_power(si: int) -> void:
	var facing_dir := Rules.DIRS.find(board.facing[si])
	var test = board.copy()
	if test.power(si, Rules.DIRS[facing_dir]) != "":
		do_action(Rules.action(si, true, facing_dir), true)
		return
	var options: Array[int] = []
	for i in 4:
		var t2 = board.copy()
		if t2.power(si, Rules.DIRS[i]) != "":
			options.append(i)
	if options.size() == 1:
		do_action(Rules.action(si, true, options[0]), true)
	else:
		_nope(si)


## Applies an action to the board (from the player or the autoplay), records
## undo, and starts its animation, effects, sounds and emotions. `pressed` is
## false for held-key repeats, so bumping a wall while holding doesn't spam.
func do_action(a: int, pressed := true) -> void:
	var si := a >> 3
	var d: Vector2i = Rules.DIRS[a & 3]
	var before = board.copy()
	if (a >> 2) & 1 == 1:
		var effect: String = board.power(si, d)
		if effect == "":
			board.facing[si] = d
			_nope(si)
			return
		_on_power(si, effect, board.pos[si] + d)
	else:
		var path: Array[Vector2i] = board.move(si, d)
		if path.is_empty():
			if pressed:
				_nope(si)
			return
		_paths[si] = path.duplicate()
		var pushed := false
		for i in board.blocks.size():
			if board.blocks[i] != before.blocks[i]:
				pushed = true
		if pushed:
			sound.play("push", -3.0, 0.05)
			_set_mood(si, "proud", 0.5)
	_record_fx(before)
	active = si
	history.append([before, moves, active])
	moves += 1
	if _first_move_t < 0.0:
		_first_move_t = _level_t
	if board.tile(board.pos[si]) == (Rules.EXIT_FROST if si == Rules.FROST else Rules.EXIT_SPARK) \
			and before.tile(before.pos[si]) != board.tile(board.pos[si]):
		_set_mood(si, "joy", 1.5)
		_set_emote(si, "heart", 1.4)
		sound.play("home", -4.0)
	if board.won():
		_on_win()


func _on_power(si: int, effect: String, cell: Vector2i) -> void:
	_burst(cell, effect)
	_set_mood(si, "proud", 0.9)
	match effect:
		"freeze":
			sound.play("freeze", -2.0, 0.03)
			_set_emote(si, "sparkle", 0.8)
		"melt_block", "melt_ice":
			sound.play("melt", -3.0, 0.05)
		"light":
			sound.play("light", -2.0)
			_set_emote(si, "sparkle", 0.8)
		"light_all":
			sound.play("gate", -1.0)
			_set_emote(si, "sparkle", 1.0)
			_set_mood(1 - si, "joy", 1.2)
			_set_emote(1 - si, "!", 0.8)


func _on_win() -> void:
	won = true
	var s := stars_for(moves)
	if s > int(best_stars.get(level_index, 0)):
		best_stars[level_index] = s
		_save_progress()
	sound.play("win", -1.0)
	for si in 2:
		_set_mood(si, "joy", 999.0)
		_set_emote(si, "heart", 999.0)
		_burst(board.pos[si], "win")
	if _dev_flag("exit-on-end"):
		print("RESULT level=%d complete moves=%d stars=%d" % [level_index + 1, moves, s])
		get_tree().create_timer(float(_dev_arg("linger", "1.5"))).timeout.connect(get_tree().quit)


func _nope(si: int) -> void:
	_wiggle[si] = 0.3
	_set_mood(si, "sad", 0.5)
	_set_emote(si, "?", 0.6)
	sound.play("nope", -8.0, 0.05)


func undo() -> void:
	if history.is_empty():
		return
	var last: Array = history.pop_back()
	board = last[0]
	moves = last[1]
	active = last[2]
	won = false
	_tile_fx.clear()
	_block_fx.clear()
	sound.play("undo", -6.0)
	for si in 2:
		_paths[si] = []
		_seg[si] = {}
		_vis[si] = Vector2(board.pos[si])
		_mood[si] = ["happy", 0.0]
		_emote[si] = ["", 0.0]


## Remembers which tiles changed so they can animate (ice growing over water,
## ice melting away, a gate swinging open) instead of just popping.
func _record_fx(before) -> void:
	for i in board.terrain.size():
		var c := Vector2i(i % board.w, i / board.w)
		if board.terrain[i] != before.terrain[i]:
			_tile_fx[c] = [before.terrain[i], board.terrain[i], _t]
			if before.terrain[i] == Rules.WATER and board.terrain[i] == Rules.ICE and before.blocks.count(1) != board.blocks.count(1):
				sound.play("bridge", -2.0)
		if before.blocks[i] == 1 and board.blocks[i] == 0 and board.terrain[i] == before.terrain[i]:
			var moved_away: bool = board.blocks.count(1) == before.blocks.count(1)
			if not moved_away:
				_block_fx[c] = _t


func _set_mood(si: int, mood: String, secs: float) -> void:
	_mood[si] = [mood, _t + secs]


func _set_emote(si: int, kind: String, secs: float) -> void:
	_emote[si] = [kind, _t + secs]


## The mood a sister shows right now: a recent reaction, or else how she feels
## about where she's standing (Spark is nervous next to water).
func _current_mood(si: int) -> String:
	if _t < float(_mood[si][1]):
		return _mood[si][0]
	if si == Rules.SPARK and not won:
		for d in Rules.DIRS:
			if board.tile(board.pos[si] + d) == Rules.WATER:
				return "worried"
	return "happy"


# --- Animation & effects -------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	_level_t += delta
	_poll_input()
	for si in 2:
		_animate(si, delta)
		_squash[si] = move_toward(_squash[si], 0.0, delta * 1.5)
		_wiggle[si] = maxf(_wiggle[si] - delta, 0.0)
		if si == Rules.SPARK and _current_mood(si) == "worried" and _t > float(_emote[si][1]) and fmod(_t, 2.4) < delta:
			_set_emote(si, "sweat", 0.9)
		var other: Vector2i = board.pos[1 - si]
		if not won and (board.pos[si] - other).length_squared() == 1 and _t > float(_emote[si][1]) and fmod(_t + si * 1.3, 5.0) < delta:
			_set_emote(si, "heart", 0.9)   # the sisters like being together
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.96
		p.vel.y += p.get("gravity", 0.0) * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	for f in _snow:
		f[1] += delta * 0.03 * f[2]
		f[0] += sin(_t * 0.7 + f[3]) * delta * 0.006
		if f[1] > 1.02:
			f[1] = -0.02
			f[0] = randf()
	if not _autoplay.is_empty() and not won and not _busy(0) and not _busy(1):
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			do_action(_autoplay.pop_front(), true)
			_auto_timer = 0.3
	queue_redraw()


## Walks a sister through her queued tiles: an eased hop for each step and a
## little squash when she lands.
func _animate(si: int, delta: float) -> void:
	if _seg[si].is_empty():
		if _paths[si].is_empty():
			return
		var next: Vector2i = _paths[si].pop_front()
		_seg[si] = {"from": _vis[si], "to": Vector2(next), "u": 0.0, "slide": false, "dur": STEP_TIME}
		sound.play("step", -20.0, 0.15)
	var seg: Dictionary = _seg[si]
	seg.u = minf(seg.u + delta / seg.dur, 1.0)
	var e: float = seg.u if seg.slide else seg.u * seg.u * (3.0 - 2.0 * seg.u)   # smoothstep for steps
	_vis[si] = (seg.from as Vector2).lerp(seg.to, e)
	if seg.u >= 1.0:
		_seg[si] = {}
		if _paths[si].is_empty():
			_squash[si] = 0.18


func _hop(si: int) -> float:
	var seg: Dictionary = _seg[si]
	if seg.is_empty() or seg.slide:
		return 0.0
	return sin(PI * float(seg.u)) * 0.14


func _burst(cell: Vector2i, kind: String) -> void:
	var colors := {"freeze": [Color.WHITE, Art.FROST_BLUE], "melt_block": [Color(1, 1, 1, 0.7), Art.ICE],
			"melt_ice": [Color(1, 1, 1, 0.6), Art.WATER_LIGHT], "light": [Art.LANTERN_GLOW, Color("ffe9a8")],
			"light_all": [Art.LANTERN_GLOW, Color("ffe9a8"), Color("ffc2e0")], "win": [Color("fff4b0"), Color("ffc2e0"), Art.FROST_BLUE],
			"skid": [Color(1, 1, 1, 0.8)]}
	var palette: Array = colors.get(kind, [Color.WHITE])
	var count := 2 if kind == "skid" else (32 if kind == "win" or kind == "light_all" else 18)
	for i in count:
		var a := randf() * TAU
		var speed := randf_range(0.6, 2.6) * (0.35 if kind == "skid" else 1.0)
		_particles.append({"cell": Vector2(cell) + Vector2(0.5, 0.5), "pos": Vector2.ZERO, "vel": Vector2.from_angle(a) * speed,
				"life": randf_range(0.5, 1.2), "color": palette[i % palette.size()],
				"size": randf_range(0.03, 0.07), "flake": kind == "freeze" or kind == "win",
				"gravity": -0.6 if kind.begins_with("melt") else (0.8 if kind == "win" else 0.0)})


# --- Drawing -----------------------------------------------------------------

func _layout() -> void:
	var view := get_viewport_rect().size
	var portrait := view.y > view.x
	var top := 96.0 if portrait else 74.0
	var bottom := 150.0 if portrait else 110.0
	var avail := Vector2(view.x - 40.0, view.y - top - bottom)
	_tile = floorf(clampf(minf(avail.x / board.w, avail.y / board.h), 24.0, 110.0))
	var size := Vector2(board.w, board.h) * _tile
	_origin = Vector2((view.x - size.x) * 0.5, top + (avail.y - size.y) * 0.5).floor()


func _cell_rect(c: Vector2i) -> Rect2:
	return Rect2(_origin + Vector2(c) * _tile, Vector2(_tile, _tile))


func _draw() -> void:
	var view := get_viewport_rect().size
	_layout()
	Art.sky(self, view, _t)
	# The board sits on a soft rounded shadow, like a snow globe base.
	var board_rect := Rect2(_origin, Vector2(board.w, board.h) * _tile)
	_round_rect(Rect2(board_rect.position + Vector2(-10, -2), board_rect.size + Vector2(20, 20)), Color(0.05, 0.03, 0.15, 0.35), 18)
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			var r := _cell_rect(c)
			var fx = _tile_fx.get(c)
			if fx != null and _t - float(fx[2]) < 0.45:
				# Draw the old tile, then the new one growing out from the middle.
				var u := clampf((_t - float(fx[2])) / 0.45, 0.0, 1.0)
				u = 1.0 - pow(1.0 - u, 3.0)
				Art.tile(self, r, int(fx[0]), c, _t)
				var grow := r.grow(-r.size.x * 0.5 * (1.0 - u))
				Art.tile(self, grow, int(fx[1]), c, _t)
			else:
				Art.tile(self, r, board.tile(c), c, _t)
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			if board.has_block(c):
				Art.block(self, _cell_rect(c))
			elif _block_fx.has(c) and _t - float(_block_fx[c]) < 0.35:
				var u := (_t - float(_block_fx[c])) / 0.35
				Art.block(self, _cell_rect(c).grow(-_tile * 0.5 * u))
	var order := [0, 1] if _vis[0].y <= _vis[1].y else [1, 0]
	for si in order:
		var c := _origin + (_vis[si] + Vector2(0.5, 0.5 - _hop(si))) * _tile
		c.x += sin(_wiggle[si] * 40.0) * _wiggle[si] * _tile * 0.15
		var squash := _squash[si] - _hop(si) * 0.6
		Art.sister(self, c, _tile, si, board.facing[si], _t + si, si == active and not won, _current_mood(si), squash)
		if _t < float(_emote[si][1]) and _emote[si][0] != "":
			var a := clampf((float(_emote[si][1]) - _t) * 4.0, 0.0, 1.0)
			Art.emote(self, c + Vector2(_tile * 0.42, -_tile * 0.95), _tile, _emote[si][0], _t, a)
	for p in _particles:
		var at: Vector2 = _origin + (p.cell + p.pos) * _tile
		var col: Color = p.color
		col.a *= clampf(p.life * 2.0, 0.0, 1.0)
		if p.flake:
			Art.snowflake(self, at, _tile * p.size * 1.6, col, p.life * 3.0)
		else:
			draw_circle(at, _tile * p.size, col)
	for f in _snow:
		draw_circle(Vector2(f[0] * view.x, f[1] * view.y), 1.5 + f[2] * 2.0, Color(1, 1, 1, 0.35 + f[2] * 0.3))
	_draw_hud(view)


func _draw_hud(view: Vector2) -> void:
	var lv: Dictionary = Levels.LEVELS[level_index]
	var portrait := view.y > view.x
	_text(Vector2(24, 42), "%d. %s" % [level_index + 1, lv["name"]], 26, Color.WHITE)
	var right := "Moves %d · Par %d" % [moves, par()]
	_text(Vector2(view.x - 24, 42), right, 20, Color("dcd6f7"), HORIZONTAL_ALIGNMENT_RIGHT)
	# A pill for each sister showing her keys; it glows when she just acted.
	var pill_y := 58.0 if portrait else 18.0
	for si in 2:
		var w := 200.0
		var r := Rect2(Vector2(view.x * 0.5 - w - 8 + si * (w + 16), pill_y), Vector2(w, 34))
		var col := Art.FROST_BLUE if si == Rules.FROST else Art.SPARK_ORANGE
		_round_rect(r, Color(col, 0.92 if si == active else 0.45), 17)
		if si == Rules.FROST:
			Art.snowflake(self, r.position + Vector2(20, 17), 9, Art.INK, 0.0)
		else:
			Art.sun(self, r.position + Vector2(20, 17), 6, Art.INK, _t)
		_text(r.position + Vector2(36, 23), NAMES[si], 18, Art.INK)
		_text(r.position + Vector2(w - 12, 23), KEYS[si], 13, Color(Art.INK, 0.75), HORIZONTAL_ALIGNMENT_RIGHT)
	# Story line while the level begins; the hint afterwards.
	var box := Rect2(Vector2(view.x * 0.5 - minf(view.x - 40, 760) * 0.5, view.y - (130.0 if portrait else 96.0)),
			Vector2(minf(view.x - 40, 760), 62))
	var lines: Array = lv.get("intro", [])
	var story_on := not won and not lines.is_empty() and (_first_move_t < 0.0 or _level_t - _first_move_t < 1.5) and _level_t < 9.0
	if story_on:
		var idx := mini(int(_level_t / 3.0), lines.size() - 1)
		_dialogue(box, lines[idx])
	else:
		_text(Vector2(view.x * 0.5, box.position.y + 38), lv["hint"], 18, Color("f3f0ff"), HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(view.x * 0.5, view.y - 16), "Z undo  ·  R restart  ·  M music  ·  [ ] change level", 14,
			Color(1, 1, 1, 0.5), HORIZONTAL_ALIGNMENT_CENTER)
	if won:
		_draw_win(view, lv)


func _dialogue(box: Rect2, line: Array) -> void:
	var speaker := int(line[0])
	_round_rect(box, Color(1, 1, 1, 0.92), 20)
	var text_x := box.position.x + 24
	if speaker >= 0:
		var col := Art.FROST_BLUE if speaker == Rules.FROST else Art.SPARK_ORANGE
		var face := box.position + Vector2(36, 34)
		draw_circle(face, 24, Color(col, 0.6))
		Art.sister(self, face + Vector2(0, 12), 40, speaker, Vector2i.DOWN, _t, false, "happy")
		_text(Vector2(box.position.x + 70, box.position.y + 24), NAMES[speaker], 16, col.darkened(0.35))
		text_x = box.position.x + 70
		_text(Vector2(text_x, box.position.y + 48), line[1], 20, Art.INK)
	else:
		_text(Vector2(box.get_center().x, box.position.y + 40), line[1], 20, Color("5b4b8a"), HORIZONTAL_ALIGNMENT_CENTER)


## The win screen: both sisters together, hugging, with hearts, stars and
## the level's closing story line.
func _draw_win(view: Vector2, lv: Dictionary) -> void:
	var panel := Rect2(Vector2(view.x * 0.5 - 280, view.y * 0.5 - 150), Vector2(560, 300))
	_round_rect(Rect2(Vector2.ZERO, view), Color(0.1, 0.08, 0.25, 0.45), 0)
	_round_rect(panel, Color(0.16, 0.13, 0.36, 0.95), 28)
	_text(Vector2(view.x * 0.5, panel.position.y + 46), "Both sisters are home!", 32, Color("fff4b0"), HORIZONTAL_ALIGNMENT_CENTER)
	var hug := Vector2(view.x * 0.5, panel.position.y + 130)
	var bounce := absf(sin(_t * 3.0)) * 6.0
	Art.sister(self, hug + Vector2(-26, -bounce), 72, Rules.FROST, Vector2i.RIGHT, _t, false, "joy")
	Art.sister(self, hug + Vector2(26, -bounce), 72, Rules.SPARK, Vector2i.LEFT, _t + 0.5, false, "joy")
	for k in 3:
		var rise := fmod(_t * 18 + k * 9, 22.0)
		Art.emote(self, hug + Vector2((k - 1) * 34, -52 - rise), 44, "heart", _t, 1.0 - rise / 22.0)
	var s := stars_for(moves)
	for k in 3:
		_star(Vector2(view.x * 0.5 + (k - 1) * 52, panel.position.y + 196), 20, Color("ffd34d") if k < s else Color(1, 1, 1, 0.18))
	var outro: Array = lv.get("outro", [])
	if not outro.is_empty():
		var idx := mini(int(_level_t / 3.0) % outro.size(), outro.size() - 1)
		var line: Array = outro[idx]
		var who: String = "" if int(line[0]) < 0 else NAMES[int(line[0])] + ": "
		_text(Vector2(view.x * 0.5, panel.position.y + 244), who + String(line[1]), 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(view.x * 0.5, panel.end.y - 18), "Press Enter for the next level", 15, Color(1, 1, 1, 0.65), HORIZONTAL_ALIGNMENT_CENTER)


func _round_rect(r: Rect2, col: Color, radius: int) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = col
	sb.set_corner_radius_all(radius)
	draw_style_box(sb, r)


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - (width if align == HORIZONTAL_ALIGNMENT_RIGHT else (width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
	if col.v > 0.6:   # light text gets a soft outline so it reads over the sky
		draw_string_outline(_font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(4, size / 5), Color(0.1, 0.08, 0.25, 0.8))
	draw_string(_font, Vector2(x, pos.y), s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		pts.append(c + Vector2.from_angle(-PI / 2 + k * PI / 5) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)


# --- Save data -------------------------------------------------------------

func _load_progress() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		for i in Levels.LEVELS.size():
			best_stars[i] = int(cfg.get_value("stars", str(i), 0))


func _save_progress() -> void:
	if not save_enabled:
		return
	var cfg := ConfigFile.new()
	for i in best_stars:
		cfg.set_value("stars", str(i), best_stars[i])
	cfg.save(SAVE_PATH)


# --- Input map & dev flags -------------------------------------------------------

func _setup_input() -> void:
	var bindings := {
		"f_up": [KEY_W], "f_down": [KEY_S], "f_left": [KEY_A], "f_right": [KEY_D], "f_power": [KEY_SPACE, KEY_E],
		"s_up": [KEY_UP], "s_down": [KEY_DOWN], "s_left": [KEY_LEFT], "s_right": [KEY_RIGHT],
		"s_power": [KEY_ENTER, KEY_KP_ENTER, KEY_SLASH],
		"undo": [KEY_Z, KEY_BACKSPACE], "restart": [KEY_R], "music": [KEY_M],
		"next_level": [KEY_BRACKETRIGHT, KEY_PAGEDOWN], "prev_level": [KEY_BRACKETLEFT, KEY_PAGEUP],
	}
	for action in bindings:
		if InputMap.has_action(action):
			continue
		InputMap.add_action(action)
		for key in bindings[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = key
			InputMap.action_add_event(action, ev)


# Dev flags go after `--`: --level=N (0-based), --autoplay (solver plays),
# --exit-on-end (with --linger=S), --no-music, --screenshot=path.png with --wait=S.
func _dev_flag(key: String) -> bool:
	return ("--" + key) in OS.get_cmdline_user_args()


func _dev_arg(key: String, fallback: String) -> String:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--%s=" % key):
			return arg.trim_prefix("--%s=" % key)
	return fallback


func _save_screenshot_and_quit(path: String) -> void:
	await get_tree().create_timer(float(_dev_arg("wait", "1.0"))).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(path)
	get_tree().quit()
