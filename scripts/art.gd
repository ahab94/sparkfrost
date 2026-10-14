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
			ci.draw_line(r.position + Vector2(s * 0.15, s * 0.2), r.position + Vector2(s * 0.45, s * 0.2), Color(1, 1, 1, 0.35), s * 0.06)
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
static func sister(ci: CanvasItem, c: Vector2, tile_size: float, which: int, facing: Vector2i, t: float, active: bool) -> void:
	var s := tile_size * 1.25   # a little bigger than a tile, so the sisters read clearly
	c += Vector2(0, -tile_size * 0.08)
	var bob := sin(t * 4.0) * s * 0.025 if active else 0.0
	var base := c + Vector2(0, s * 0.08 + bob)
	# A flat oval shadow (a circle squashed by the draw transform), and a
	# glowing ring under whichever sister you're controlling.
	var feet := c + Vector2(0, s * 0.38)
	ci.draw_set_transform(feet, 0.0, Vector2(1.0, 0.35))
	ci.draw_circle(Vector2.ZERO, s * 0.26, Color(0.2, 0.15, 0.4, 0.18))
	if active:
		ci.draw_arc(Vector2.ZERO, s * 0.34, 0, TAU, 32, Color(1, 1, 1, 0.6 + 0.3 * sin(t * 5.0)), s * 0.08)
	ci.draw_set_transform(Vector2.ZERO)
	var frost := which == Rules.FROST
	var dress := Color("9db4ff") if frost else Color("ff8a7a")
	var trim := Color.WHITE if frost else Color("ffd27a")
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
	# Face: eyes glance the way she's facing.
	var look := Vector2(facing) * s * 0.025
	for side in [-1.0, 1.0]:
		ci.draw_circle(head + Vector2(side * hr * 0.4, hr * 0.05) + look, s * 0.028, INK)
		ci.draw_circle(head + Vector2(side * hr * 0.62, hr * 0.38), s * 0.03, Color(1.0, 0.55, 0.6, 0.45))
	ci.draw_arc(head + Vector2(0, hr * 0.32) + look * 0.5, hr * 0.22, 0.3, PI - 0.3, 8, INK, s * 0.02)
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
