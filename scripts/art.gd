extends RefCounted
## All of Sparkfrost's art, drawn in code. Each function draws onto the
## CanvasItem it's given (Godot's _draw() API), at a centre point and tile
## size, so the same art works at any screen size.
##
## Look: pastel aurora. Snow is lavender-white, ice is pale cyan, Frost is
## periwinkle and white, Spark is coral and gold.

const Rules := preload("res://scripts/rules.gd")

const SKY_TOP := Color("2a2350")
const SKY_BOTTOM := Color("1b3a5a")
const SNOW := Color("f3f0ff")
const SNOW_SHADE := Color("dcd6f7")
const WALL := Color("6b6fb8")
const WALL_TOP := Color("9095d8")
const WATER := Color("3fb8d8")
const WATER_LIGHT := Color("9ae6f5")
const ICE := Color("c9f2ff")
const ICE_EDGE := Color("8fdcf2")
const LANTERN_GLOW := Color("ffcf6b")
const GOLD := Color("e8b45a")
const FROST_BLUE := Color("8fd8ff")
const SPARK_ORANGE := Color("ffb36b")
const INK := Color("3b2f5c")


static func sky(ci: CanvasItem, size: Vector2, t: float) -> void:
	ci.draw_polygon(PackedVector2Array([Vector2.ZERO, Vector2(size.x, 0), size, Vector2(0, size.y)]),
			PackedColorArray([SKY_TOP, SKY_TOP, SKY_BOTTOM, SKY_BOTTOM]))
	# Aurora ribbons: soft sine bands drifting slowly.
	var bands := [[Color(0.45, 1.0, 0.8, 0.10), 0.18, 0.7], [Color(0.95, 0.6, 1.0, 0.08), 0.28, 1.1],
			[Color(0.5, 0.85, 1.0, 0.09), 0.38, 0.9]]
	for b in bands:
		var col: Color = b[0]
		var y0: float = size.y * b[1]
		var pts := PackedVector2Array()
		var n := 24
		for i in n + 1:
			var x := size.x * i / n
			pts.append(Vector2(x, y0 + sin(x * 0.006 + t * b[2]) * size.y * 0.05))
		for i in range(n, -1, -1):
			var x := size.x * i / n
			pts.append(Vector2(x, y0 + size.y * 0.09 + sin(x * 0.007 + t * b[2] + 1.0) * size.y * 0.05))
		ci.draw_colored_polygon(pts, col)
	# Twinkling stars, placed by a fixed pattern so they don't jump around.
	for i in 40:
		var p := Vector2(fposmod(i * 197.3, size.x), fposmod(i * 71.9, size.y * 0.6))
		var a := 0.3 + 0.3 * sin(t * 2.0 + i)
		ci.draw_circle(p, 1.2 + (i % 3) * 0.5, Color(1, 1, 1, a))


static func tile(ci: CanvasItem, r: Rect2, kind: int, cell: Vector2i, t: float) -> void:
	var s := r.size.x
	match kind:
		Rules.WALL:
			ci.draw_rect(r, WALL)
			ci.draw_rect(Rect2(r.position, Vector2(s, s * 0.72)), WALL_TOP)
			# A fluffy snow cap with little drips, so walls look like snowy hedges.
			ci.draw_rect(Rect2(r.position, Vector2(s, s * 0.22)), SNOW)
			for k in 3:
				ci.draw_circle(r.position + Vector2(s * (0.2 + 0.3 * k), s * 0.22), s * (0.09 if (cell.x + k) % 2 == 0 else 0.06), SNOW)
			ci.draw_line(r.position + Vector2(s * 0.15, s * 0.45), r.position + Vector2(s * 0.4, s * 0.45), Color(1, 1, 1, 0.3), s * 0.05)
		Rules.WATER:
			ci.draw_rect(r, WATER)
			for k in 2:
				var y := r.position.y + s * (0.35 + 0.3 * k)
				var off := sin(t * 2.5 + cell.x * 1.3 + k) * s * 0.08
				ci.draw_line(Vector2(r.position.x + s * 0.15 + off, y), Vector2(r.position.x + s * 0.55 + off, y), WATER_LIGHT, s * 0.05)
		Rules.ICE:
			_snow(ci, r, cell)
			var inner := r.grow(-s * 0.04)
			ci.draw_rect(inner, ICE)
			ci.draw_rect(inner, ICE_EDGE, false, s * 0.04)
			ci.draw_line(inner.position + Vector2(s * 0.2, s * 0.7), inner.position + Vector2(s * 0.5, s * 0.2), Color(1, 1, 1, 0.8), s * 0.05)
			ci.draw_line(inner.position + Vector2(s * 0.45, s * 0.75), inner.position + Vector2(s * 0.65, s * 0.4), Color(1, 1, 1, 0.6), s * 0.035)
		_:
			_snow(ci, r, cell)
	match kind:
		Rules.LANTERN, Rules.LIT:
			lantern(ci, r.get_center(), s, kind == Rules.LIT, t)
		Rules.DOOR:
			_gate(ci, r, false)
		Rules.OPEN_DOOR:
			_gate(ci, r, true)
		Rules.EXIT_FROST:
			_portal(ci, r.get_center(), s, FROST_BLUE, true, t)
		Rules.EXIT_SPARK:
			_portal(ci, r.get_center(), s, SPARK_ORANGE, false, t)


static func _snow(ci: CanvasItem, r: Rect2, cell: Vector2i) -> void:
	var s := r.size.x
	ci.draw_rect(r, SNOW)
	ci.draw_rect(Rect2(r.position + Vector2(0, s * 0.9), Vector2(s, s * 0.1)), SNOW_SHADE)
	# A few sparkles, at spots fixed per tile.
	var h := (cell.x * 73856093) ^ (cell.y * 19349663)
	for k in 3:
		var p := r.position + Vector2(((h >> (k * 4)) & 15) / 15.0, ((h >> (k * 4 + 12)) & 15) / 15.0) * s * 0.8 + Vector2(s * 0.1, s * 0.1)
		ci.draw_circle(p, s * 0.025, Color("c9c2f0"))


static func block(ci: CanvasItem, r: Rect2) -> void:
	var s := r.size.x
	var b := r.grow(-s * 0.08)
	ci.draw_rect(b, Color(0.75, 0.94, 1.0, 0.95))
	ci.draw_rect(Rect2(b.position, Vector2(b.size.x, b.size.y * 0.25)), Color(0.9, 0.98, 1.0))
	ci.draw_rect(b, ICE_EDGE.darkened(0.15), false, s * 0.05)
	ci.draw_line(b.position + Vector2(s * 0.15, s * 0.65), b.position + Vector2(s * 0.4, s * 0.35), Color.WHITE, s * 0.05)


static func lantern(ci: CanvasItem, c: Vector2, s: float, lit: bool, t: float) -> void:
	if lit:
		var pulse := 0.85 + 0.15 * sin(t * 3.0)
		ci.draw_circle(c, s * 0.62 * pulse, Color(LANTERN_GLOW, 0.18))
		ci.draw_circle(c, s * 0.42 * pulse, Color(LANTERN_GLOW, 0.28))
	ci.draw_rect(Rect2(c + Vector2(-s * 0.05, s * 0.05), Vector2(s * 0.1, s * 0.4)), INK)
	var glass := Rect2(c + Vector2(-s * 0.17, -s * 0.3), Vector2(s * 0.34, s * 0.38))
	ci.draw_rect(glass, LANTERN_GLOW if lit else Color("9a93b8"))
	ci.draw_rect(glass, INK, false, s * 0.05)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-s * 0.24, -s * 0.3), c + Vector2(s * 0.24, -s * 0.3), c + Vector2(0, -s * 0.46)]), INK)


static func _gate(ci: CanvasItem, r: Rect2, open: bool) -> void:
	var s := r.size.x
	if open:
		ci.draw_arc(r.get_center() + Vector2(0, s * 0.15), s * 0.38, PI, TAU, 16, Color(GOLD, 0.5), s * 0.06)
		return
	var g := r.grow(-s * 0.06)
	ci.draw_rect(g, Color("c99a5b"))
	for k in 3:
		var x := g.position.x + g.size.x * (0.2 + 0.3 * k)
		ci.draw_line(Vector2(x, g.position.y), Vector2(x, g.end.y), Color("a87a40"), s * 0.05)
	ci.draw_rect(g, GOLD, false, s * 0.06)
	snowflake(ci, r.get_center(), s * 0.18, Color.WHITE, 0.0)


static func _portal(ci: CanvasItem, c: Vector2, s: float, col: Color, frost: bool, t: float) -> void:
	ci.draw_circle(c, s * 0.4, Color(col, 0.25 + 0.1 * sin(t * 3.0)))
	ci.draw_arc(c, s * 0.38, 0, TAU, 32, col, s * 0.06)
	if frost:
		snowflake(ci, c, s * 0.2, col.darkened(0.2), t * 0.6)
	else:
		sun(ci, c, s * 0.16, col.darkened(0.15), t)


static func snowflake(ci: CanvasItem, c: Vector2, r: float, col: Color, spin: float) -> void:
	for k in 6:
		var a := spin + k * TAU / 6.0
		var tip := c + Vector2.from_angle(a) * r
		ci.draw_line(c, tip, col, r * 0.22)
		for side in [-1.0, 1.0]:
			var mid := c + Vector2.from_angle(a) * r * 0.6
			ci.draw_line(mid, mid + Vector2.from_angle(a + side * 0.7) * r * 0.35, col, r * 0.16)


static func sun(ci: CanvasItem, c: Vector2, r: float, col: Color, t: float) -> void:
	for k in 8:
		var a := t * 0.8 + k * TAU / 8.0
		ci.draw_line(c + Vector2.from_angle(a) * r * 1.15, c + Vector2.from_angle(a) * r * 1.6, col, r * 0.25)
	ci.draw_circle(c, r, col)


## A sister, drawn standing at `c` (tile centre), roughly one tile tall.
## `mood` is one of: happy, joy, proud, surprised, worried, sad.
## `squash` > 0 squashes her down (landing), < 0 stretches her up (hopping).
static func sister(ci: CanvasItem, c: Vector2, tile_size: float, which: int, facing: Vector2i, t: float,
		active: bool, mood := "happy", squash := 0.0) -> void:
	var s := tile_size * 1.25   # a little bigger than a tile, so the sisters read clearly
	c += Vector2(0, -tile_size * 0.08)
	var bob := sin(t * 4.0) * s * 0.025 if active else 0.0
	var base0 := Vector2(0, s * 0.08 + bob)
	# A flat oval shadow (a circle squashed by the draw transform), and a
	# glowing ring under whichever sister you're controlling.
	var feet := c + Vector2(0, s * 0.38)
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, s * 0.26, Color(0.2, 0.15, 0.4, 0.18))
	if active:
		ci.draw_arc(Vector2.ZERO, s * 0.34, 0, TAU, 32, Color(1, 1, 1, 0.6 + 0.3 * sin(t * 5.0)), s * 0.08)
	ci.draw_set_transform(Vector2.ZERO)
	# Squash and stretch: scale the whole body around her feet.
	ci.draw_set_transform(feet, 0.0, Vector2(1.0 + squash * 0.5, 1.0 - squash))
	c -= feet
	var frost := which == Rules.FROST
	var dress := Color("9db4ff") if frost else Color("ff8a7a")
	var trim := Color.WHITE if frost else Color("ffd27a")
	var base := (c - Vector2.ZERO) + base0
	# Dress: a soft bell shape.
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(-s * 0.13, -s * 0.06), base + Vector2(s * 0.13, -s * 0.06),
			base + Vector2(s * 0.3, s * 0.3), base + Vector2(-s * 0.3, s * 0.3)]), dress)
	ci.draw_line(base + Vector2(-s * 0.3, s * 0.3), base + Vector2(s * 0.3, s * 0.3), trim, s * 0.06)
	# Arms (mittens for Frost, little sparks of light for Spark).
	for side in [-1.0, 1.0]:
		var hand := base + Vector2(side * s * 0.24, s * 0.08)
		ci.draw_line(base + Vector2(side * s * 0.1, -s * 0.02), hand, dress.darkened(0.1), s * 0.07)
		ci.draw_circle(hand, s * 0.055, Color.WHITE if frost else Color("ffe08a"))
	var head := base + Vector2(0, -s * 0.24)
	var hr := s * 0.2
	if frost:
		ci.draw_circle(head + Vector2(0, s * 0.04), hr * 1.08, Color("d9d2ff"))   # short lilac bob
	else:
		for k in 5:   # big golden curls
			ci.draw_circle(head + Vector2.from_angle(PI + k * PI / 4.0) * hr * 0.95, hr * 0.42, Color("ffb347"))
	ci.draw_circle(head, hr, Color("ffe3d3"))
	# Face: the eyes glance the way she's facing; the expression shows her mood.
	var look := Vector2(facing) * s * 0.025
	var blink := fmod(t * 0.9 + which * 1.7, 3.6) < 0.13
	_face(ci, head, hr, s, look, mood, blink)
	if frost:
		# Knit beanie with a pom-pom and a snowflake.
		ci.draw_colored_polygon(PackedVector2Array([head + Vector2(-hr * 1.05, -hr * 0.25), head + Vector2(hr * 1.05, -hr * 0.25),
				head + Vector2(hr * 0.6, -hr * 1.05), head + Vector2(-hr * 0.6, -hr * 1.05)]), Color.WHITE)
		ci.draw_line(head + Vector2(-hr * 1.05, -hr * 0.3), head + Vector2(hr * 1.05, -hr * 0.3), Color("c9d6ff"), s * 0.05)
		ci.draw_circle(head + Vector2(0, -hr * 1.15), hr * 0.3, Color.WHITE)
		snowflake(ci, head + Vector2(0, -hr * 0.65), hr * 0.25, Color("9db4ff"), 0.0)
	else:
		# Flame hair clip.
		var clip := head + Vector2(hr * 0.75, -hr * 0.75)
		ci.draw_colored_polygon(PackedVector2Array([clip + Vector2(-hr * 0.22, hr * 0.15), clip + Vector2(hr * 0.22, hr * 0.15),
				clip + Vector2(0, -hr * 0.45)]), Color("ff6a3d"))
		ci.draw_circle(clip + Vector2(0, hr * 0.05), hr * 0.16, Color("ffd27a"))
	ci.draw_set_transform(Vector2.ZERO)


static func _face(ci: CanvasItem, head: Vector2, hr: float, s: float, look: Vector2, mood: String, blink: bool) -> void:
	var blush := 0.7 if mood == "joy" else 0.45
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.62, hr * 0.38), s * 0.032, Color(1.0, 0.55, 0.6, blush))
	var lw := s * 0.022
	for side in [-1.0, 1.0]:
		var e := head + Vector2(side * hr * 0.4, hr * 0.05) + look
		match mood:
			"joy", "proud":
				ci.draw_arc(e + Vector2(0, s * 0.012), s * 0.03, PI + 0.3, TAU - 0.3, 8, INK, lw)   # happy closed eyes ^ ^
			"surprised":
				ci.draw_circle(e, s * 0.045, Color.WHITE)
				ci.draw_arc(e, s * 0.045, 0, TAU, 12, INK, lw * 0.6)
				ci.draw_circle(e + look * 0.5, s * 0.022, INK)
			_:
				if blink:
					ci.draw_line(e - Vector2(s * 0.026, 0), e + Vector2(s * 0.026, 0), INK, lw)
				else:
					ci.draw_circle(e, s * 0.03, INK)
					ci.draw_circle(e + Vector2(-s * 0.01, -s * 0.012), s * 0.009, Color.WHITE)   # eye shine
		if mood == "worried" or mood == "sad":
			# Eyebrows: worried tilts up toward the middle, sad droops at the ends.
			var inner := e + Vector2(-side * s * 0.03, -s * (0.055 if mood == "worried" else 0.045))
			var outer := e + Vector2(side * s * 0.03, -s * (0.04 if mood == "worried" else 0.03))
			ci.draw_line(inner, outer, INK, lw * 0.8)
	var m := head + Vector2(0, hr * 0.36) + look * 0.5
	match mood:
		"joy":
			ci.draw_colored_polygon(PackedVector2Array([m + Vector2(-s * 0.05, -s * 0.01), m + Vector2(s * 0.05, -s * 0.01),
					m + Vector2(s * 0.03, s * 0.04), m + Vector2(0, s * 0.05), m + Vector2(-s * 0.03, s * 0.04)]), INK)
			ci.draw_circle(m + Vector2(0, s * 0.03), s * 0.016, Color("ff8fa3"))
		"proud":
			ci.draw_arc(m + Vector2(s * 0.01, -s * 0.01), hr * 0.25, 0.2, PI - 0.6, 8, INK, lw)
		"surprised":
			ci.draw_circle(m + Vector2(0, s * 0.01), s * 0.022, INK)
		"worried":
			ci.draw_polyline(PackedVector2Array([m + Vector2(-s * 0.035, s * 0.01), m + Vector2(-s * 0.012, -s * 0.004),
					m + Vector2(s * 0.012, s * 0.01), m + Vector2(s * 0.035, -s * 0.004)]), INK, lw * 0.8)
		"sad":
			ci.draw_arc(m + Vector2(0, s * 0.03), hr * 0.2, PI + 0.5, TAU - 0.5, 8, INK, lw)
		_:
			ci.draw_arc(m - Vector2(0, s * 0.01), hr * 0.22, 0.3, PI - 0.3, 8, INK, lw)


## A little speech-bubble emote above a sister: heart, !, ?, sparkle or sweat.
static func emote(ci: CanvasItem, at: Vector2, s: float, kind: String, t: float, alpha: float) -> void:
	var pop := 1.0 + 0.12 * sin(t * 8.0)
	var r := s * 0.2 * pop
	if kind == "sweat":
		var d := at + Vector2(s * 0.28, s * 0.1)
		ci.draw_circle(d, s * 0.06, Color(0.55, 0.85, 1.0, alpha))
		ci.draw_colored_polygon(PackedVector2Array([d + Vector2(-s * 0.055, -s * 0.02), d + Vector2(s * 0.055, -s * 0.02), d + Vector2(0, -s * 0.13)]),
				Color(0.55, 0.85, 1.0, alpha))
		return
	ci.draw_circle(at, r, Color(1, 1, 1, 0.95 * alpha))
	ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.3, r * 0.8), at + Vector2(r * 0.3, r * 0.8), at + Vector2(-r * 0.1, r * 1.35)]),
			Color(1, 1, 1, 0.95 * alpha))
	match kind:
		"heart":
			var hc := Color(1.0, 0.4, 0.55, alpha)
			ci.draw_circle(at + Vector2(-r * 0.25, -r * 0.1), r * 0.3, hc)
			ci.draw_circle(at + Vector2(r * 0.25, -r * 0.1), r * 0.3, hc)
			ci.draw_colored_polygon(PackedVector2Array([at + Vector2(-r * 0.53, 0), at + Vector2(r * 0.53, 0), at + Vector2(0, r * 0.55)]), hc)
		"!":
			ci.draw_line(at + Vector2(0, -r * 0.55), at + Vector2(0, r * 0.15), Color(1.0, 0.35, 0.35, alpha), r * 0.28)
			ci.draw_circle(at + Vector2(0, r * 0.45), r * 0.15, Color(1.0, 0.35, 0.35, alpha))
		"?":
			ci.draw_arc(at + Vector2(0, -r * 0.22), r * 0.3, PI, TAU + PI * 0.5, 10, Color(0.45, 0.4, 0.9, alpha), r * 0.2)
			ci.draw_line(at + Vector2(0, r * 0.08), at + Vector2(0, r * 0.25), Color(0.45, 0.4, 0.9, alpha), r * 0.2)
			ci.draw_circle(at + Vector2(0, r * 0.5), r * 0.12, Color(0.45, 0.4, 0.9, alpha))
		_:
			snowflake(ci, at, r * 0.6, Color(0.55, 0.75, 1.0, alpha), t)
