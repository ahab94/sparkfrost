extends Node2D
## Runs Sparkfrost: shows the board, takes input, animates the sisters, and
## handles winning, undo, stars and saves. The puzzle logic itself lives in
## rules.gd; this script only asks it what happens and draws the result.
##
## Everything is drawn in _draw() each frame from the current board, so the
## layout simply refits whenever the window changes shape (wide or tall).

const Rules := preload("res://scripts/rules.gd")
const Levels := preload("res://scripts/levels.gd")
const Solver := preload("res://scripts/solver.gd")
const Art := preload("res://scripts/art.gd")

const SAVE_PATH := "user://sparkfrost.cfg"
const STEP_TIME := 0.12      # seconds per tile walked
const SLIDE_TIME := 0.07     # seconds per tile slid on ice
const NAMES := ["Frost", "Spark"]

var level_index := 0
var board                      # rules.gd instance
var active := Rules.FROST      # which sister the player controls
var moves := 0
var won := false
var history: Array = []        # undo stack of [board copy, moves, active]
var best_stars := {}           # level index -> stars earned
var save_enabled := true

var _t := 0.0
var _vis: Array[Vector2] = [Vector2.ZERO, Vector2.ZERO]       # drawn positions, in tiles
var _paths: Array = [[], []]                                     # queued tiles to animate through
var _particles: Array = []
var _font: Font
var _tile := 64.0
var _origin := Vector2.ZERO
var _autoplay: Array = []
var _auto_timer := 0.0


func _ready() -> void:
	_font = ThemeDB.fallback_font
	_setup_input()
	if _dev_flag("autoplay"):
		save_enabled = false
	_load_progress()
	load_level(clampi(int(_dev_arg("level", "0")), 0, Levels.LEVELS.size() - 1))
	if _dev_flag("autoplay"):
		_autoplay = Solver.solve(Levels.LEVELS[level_index]["map"])["actions"]
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
	for si in 2:
		_vis[si] = Vector2(board.pos[si])
		_paths[si] = []


func par() -> int:
	return int(Levels.LEVELS[level_index].get("par", 0))


func stars_for(move_count: int) -> int:
	var p := par()
	if p == 0 or move_count <= p:
		return 3
	return 2 if move_count <= int(ceil(p * 1.5)) else 1


func _animating() -> bool:
	return not (_paths[0].is_empty() and _paths[1].is_empty())


# --- Input -------------------------------------------------------------------

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("restart"):
		load_level(level_index)
	elif event.is_action_pressed("next_level"):
		load_level((level_index + 1) % Levels.LEVELS.size())
	elif event.is_action_pressed("prev_level"):
		load_level((level_index - 1 + Levels.LEVELS.size()) % Levels.LEVELS.size())
	elif won:
		if event.is_action_pressed("confirm"):
			load_level((level_index + 1) % Levels.LEVELS.size())
	elif event.is_action_pressed("undo"):
		undo()
	elif event.is_action_pressed("switch"):
		active = 1 - active
	elif not _animating():
		for i in 4:
			if event.is_action_pressed(["move_up", "move_right", "move_down", "move_left"][i]):
				do_action(Rules.action(active, false, i))
		if event.is_action_pressed("power"):
			do_action(Rules.action(active, true, Rules.DIRS.find(board.facing[active])))


## Applies an action to the board (from the player or the autoplay), records
## undo, and kicks off its animation and effects.
func do_action(a: int) -> void:
	var si := a >> 3
	var d: Vector2i = Rules.DIRS[a & 3]
	var before = board.copy()
	if (a >> 2) & 1 == 1:
		var effect: String = board.power(si, d)
		if effect == "":
			board.facing[si] = d
			return
		_burst(board.pos[si] + d, effect)
	else:
		var path: Array[Vector2i] = board.move(si, d)
		if path.is_empty():
			return
		_paths[si] = path.duplicate()
	active = si
	history.append([before, moves, active])
	moves += 1
	if board.won():
		won = true
		var s := stars_for(moves)
		if s > int(best_stars.get(level_index, 0)):
			best_stars[level_index] = s
			_save_progress()
		_burst(board.pos[Rules.FROST], "win")
		_burst(board.pos[Rules.SPARK], "win")
		if _dev_flag("exit-on-end"):
			print("RESULT level=%d complete moves=%d stars=%d" % [level_index + 1, moves, s])
			get_tree().create_timer(1.5).timeout.connect(get_tree().quit)


func undo() -> void:
	if history.is_empty():
		return
	var last: Array = history.pop_back()
	board = last[0]
	moves = last[1]
	active = last[2]
	won = false
	for si in 2:
		_paths[si] = []
		_vis[si] = Vector2(board.pos[si])


# --- Animation & effects -------------------------------------------------------

func _process(delta: float) -> void:
	_t += delta
	for si in 2:
		var path: Array = _paths[si]
		if path.is_empty():
			continue
		var target := Vector2(path[0])
		var sliding: bool = board.tile(path[0]) == Rules.ICE or path.size() > 1
		var step := delta / (SLIDE_TIME if sliding else STEP_TIME)
		_vis[si] = _vis[si].move_toward(target, step)
		if _vis[si].distance_to(target) < 0.001:
			path.pop_front()
			if sliding:
				_burst(Vector2i(target), "skid")
	for p in _particles:
		p.life -= delta
		p.pos += p.vel * delta
		p.vel *= 0.96
		p.vel.y += p.get("gravity", 0.0) * delta
	_particles = _particles.filter(func(p): return p.life > 0.0)
	if not _autoplay.is_empty() and not _animating() and not won:
		_auto_timer -= delta
		if _auto_timer <= 0.0:
			do_action(_autoplay.pop_front())
			_auto_timer = 0.28
	queue_redraw()


func _burst(cell: Vector2i, kind: String) -> void:
	var colors := {"freeze": [Color.WHITE, Art.FROST_BLUE], "melt_block": [Color(1, 1, 1, 0.7), Art.ICE],
			"melt_ice": [Color(1, 1, 1, 0.6), Art.WATER_LIGHT], "light": [Art.LANTERN_GLOW, Color("ffe9a8")],
			"light_all": [Art.LANTERN_GLOW, Color("ffe9a8")], "win": [Color("fff4b0"), Color("ffc2e0"), Art.FROST_BLUE],
			"skid": [Color(1, 1, 1, 0.8)]}
	var palette: Array = colors.get(kind, [Color.WHITE])
	var count := 3 if kind == "skid" else (28 if kind == "win" or kind == "light_all" else 16)
	for i in count:
		var a := randf() * TAU
		var speed := randf_range(0.6, 2.4) * (0.4 if kind == "skid" else 1.0)
		_particles.append({"cell": Vector2(cell) + Vector2(0.5, 0.5), "pos": Vector2.ZERO, "vel": Vector2.from_angle(a) * speed,
				"life": randf_range(0.5, 1.1), "color": palette[i % palette.size()],
				"size": randf_range(0.03, 0.07), "flake": kind == "freeze" or kind == "win",
				"gravity": -0.6 if kind.begins_with("melt") else 0.0})


# --- Drawing -----------------------------------------------------------------

func _layout() -> void:
	var view := get_viewport_rect().size
	var top := 70.0
	var bottom := 70.0
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
	for y in board.h:
		for x in board.w:
			var c := Vector2i(x, y)
			Art.tile(self, _cell_rect(c), board.tile(c), c, _t)
	for y in board.h:
		for x in board.w:
			if board.has_block(Vector2i(x, y)):
				Art.block(self, _cell_rect(Vector2i(x, y)))
	# Draw the lower sister last so she overlaps correctly.
	var order := [0, 1] if _vis[0].y <= _vis[1].y else [1, 0]
	for si in order:
		var c := _origin + (_vis[si] + Vector2(0.5, 0.5)) * _tile
		Art.sister(self, c, _tile, si, board.facing[si], _t + si, si == active and not won)
	for p in _particles:
		var at: Vector2 = _origin + (p.cell + p.pos) * _tile
		var col: Color = p.color
		col.a *= clampf(p.life * 2.0, 0.0, 1.0)
		if p.flake:
			Art.snowflake(self, at, _tile * p.size * 1.6, col, p.life * 3.0)
		else:
			draw_circle(at, _tile * p.size, col)
	_draw_hud(view)


func _draw_hud(view: Vector2) -> void:
	var lv: Dictionary = Levels.LEVELS[level_index]
	_text(Vector2(24, 40), "%d. %s" % [level_index + 1, lv["name"]], 26, Color.WHITE)
	# Whose turn: a pill for each sister, the active one bright.
	for si in 2:
		var w := 120.0
		var r := Rect2(Vector2(view.x * 0.5 - w - 8 + si * (w + 16), 16), Vector2(w, 36))
		var col := Art.FROST_BLUE if si == Rules.FROST else Art.SPARK_ORANGE
		var on := si == active
		draw_rect(r, Color(col, 0.9 if on else 0.25))
		if si == Rules.FROST:
			Art.snowflake(self, r.position + Vector2(20, 18), 9, Art.INK if on else Color(1, 1, 1, 0.6), 0.0)
		else:
			Art.sun(self, r.position + Vector2(20, 18), 6, Art.INK if on else Color(1, 1, 1, 0.6), _t)
		_text(r.position + Vector2(38, 26), NAMES[si], 20, Art.INK if on else Color(1, 1, 1, 0.7))
	var right := "Moves %d   Par %d" % [moves, par()] if par() > 0 else "Moves %d" % moves
	_text(Vector2(view.x - 24, 40), right, 20, Color("dcd6f7"), HORIZONTAL_ALIGNMENT_RIGHT)
	_text(Vector2(view.x * 0.5, view.y - 40), lv["hint"], 18, Color("f3f0ff"), HORIZONTAL_ALIGNMENT_CENTER)
	_text(Vector2(view.x * 0.5, view.y - 14),
			"Arrows move  ·  Space power  ·  Tab switch sister  ·  Z undo  ·  R restart", 14,
			Color(1, 1, 1, 0.55), HORIZONTAL_ALIGNMENT_CENTER)
	if won:
		var s := stars_for(moves)
		draw_rect(Rect2(Vector2(0, view.y * 0.5 - 90), Vector2(view.x, 180)), Color(0.1, 0.08, 0.25, 0.75))
		_text(Vector2(view.x * 0.5, view.y * 0.5 - 30), "Both sisters are home!", 40, Color("fff4b0"), HORIZONTAL_ALIGNMENT_CENTER)
		for k in 3:
			var c := Vector2(view.x * 0.5 + (k - 1) * 56, view.y * 0.5 + 18)
			_star(c, 22, Color("ffd34d") if k < s else Color(1, 1, 1, 0.2))
		_text(Vector2(view.x * 0.5, view.y * 0.5 + 72), "Press Enter for the next level", 18, Color.WHITE, HORIZONTAL_ALIGNMENT_CENTER)


func _text(pos: Vector2, s: String, size: int, col: Color, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width := _font.get_string_size(s, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var x := pos.x - (width if align == HORIZONTAL_ALIGNMENT_RIGHT else (width * 0.5 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0))
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
		"move_up": [KEY_UP, KEY_W], "move_down": [KEY_DOWN, KEY_S],
		"move_left": [KEY_LEFT, KEY_A], "move_right": [KEY_RIGHT, KEY_D],
		"power": [KEY_SPACE, KEY_E], "switch": [KEY_TAB, KEY_Q],
		"undo": [KEY_Z, KEY_BACKSPACE], "restart": [KEY_R], "confirm": [KEY_ENTER, KEY_KP_ENTER],
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
# --exit-on-end, --screenshot=path.png with --wait=S.
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
