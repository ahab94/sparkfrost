extends RefCounted
## Sparkfrost's puzzle rules with no graphics, so the game, the solver and
## the tests all share one source of truth.
##
## The board has two layers:
##   terrain: the ground (wall, snow, water, ice, lanterns, doors, exits)
##   blocks:  ice blocks sitting on the ground, which can be pushed
## Two sisters stand on it: Frost (index 0) makes ice, Spark (index 1) melts it.
##
## Level map characters (one per tile):
##   #  wall          .  snow (floor)     ~  water         =  ice (slippery)
##   l  lantern, unlit (solid; Spark lights it)            D  door, opens when every lantern is lit
##   f  Frost's exit  s  Spark's exit     B  ice block on snow
##   F  Frost starts here (on snow)       S  Spark starts here (on snow)
##
## Moving onto ice slides you until you reach a tile that isn't ice or hit
## something. Pushing a block into water fills it with ice: a bridge.

const WALL := 35       # '#'
const FLOOR := 46      # '.'
const WATER := 126     # '~'
const ICE := 61        # '='
const LANTERN := 108   # 'l'
const LIT := 76        # 'L'
const DOOR := 68       # 'D'
const OPEN_DOOR := 100 # 'd'
const EXIT_FROST := 102 # 'f'
const EXIT_SPARK := 115 # 's'

const FROST := 0
const SPARK := 1
const DIRS: Array[Vector2i] = [Vector2i.UP, Vector2i.RIGHT, Vector2i.DOWN, Vector2i.LEFT]

var w := 0
var h := 0
var terrain := PackedByteArray()
var blocks := PackedByteArray()   # 1 where an ice block stands
var pos: Array[Vector2i] = [Vector2i.ZERO, Vector2i.ZERO]
var facing: Array[Vector2i] = [Vector2i.RIGHT, Vector2i.RIGHT]


func load_map(rows: Array) -> void:
	h = rows.size()
	w = (rows[0] as String).length()
	terrain.resize(w * h)
	blocks.resize(w * h)
	blocks.fill(0)
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row.unicode_at(x)
			var i := y * w + x
			match ch:
				70:  # 'F'
					pos[FROST] = Vector2i(x, y)
					ch = FLOOR
				83:  # 'S'
					pos[SPARK] = Vector2i(x, y)
					ch = FLOOR
				66:  # 'B'
					blocks[i] = 1
					ch = FLOOR
			terrain[i] = ch


func copy():
	var c = get_script().new()
	c.w = w
	c.h = h
	c.terrain = terrain.duplicate()
	c.blocks = blocks.duplicate()
	c.pos = pos.duplicate()
	c.facing = facing.duplicate()
	return c


## A string that identifies this exact situation (for the solver's visited set).
func key() -> String:
	return "%s|%s|%d,%d|%d,%d" % [terrain.get_string_from_ascii(), blocks.hex_encode(),
			pos[0].x, pos[0].y, pos[1].x, pos[1].y]


func tile(c: Vector2i) -> int:
	if c.x < 0 or c.y < 0 or c.x >= w or c.y >= h:
		return WALL
	return terrain[c.y * w + c.x]


func has_block(c: Vector2i) -> bool:
	return tile(c) != WALL and blocks[c.y * w + c.x] == 1


func won() -> bool:
	return tile(pos[FROST]) == EXIT_FROST and tile(pos[SPARK]) == EXIT_SPARK


func lanterns_left() -> int:
	return terrain.count(LANTERN)


# --- Moving ------------------------------------------------------------------

## Moves sister `si` one step in `d` (sliding on ice). Returns the tiles she
## passed through, or an empty array if she couldn't move.
func move(si: int, d: Vector2i) -> Array[Vector2i]:
	facing[si] = d
	var path: Array[Vector2i] = []
	var n := pos[si] + d
	if has_block(n) and not _push_block(n, d):
		return path
	if not _can_stand(si, n):
		return path
	var p := n
	path.append(p)
	while tile(p) == ICE:
		var nx := p + d
		if has_block(nx) or not _can_stand(si, nx):
			break
		p = nx
		path.append(p)
	pos[si] = p
	return path


func _can_stand(si: int, c: Vector2i) -> bool:
	if c == pos[1 - si] or has_block(c):
		return false
	var t := tile(c)
	return t == FLOOR or t == ICE or t == EXIT_FROST or t == EXIT_SPARK or t == OPEN_DOOR


## A block at `c` pushed toward `d`. It slides across ice, and drops into
## water to become an ice bridge. Returns whether it moved.
func _push_block(c: Vector2i, d: Vector2i) -> bool:
	var at := c
	var moved := false
	while true:
		var nx := at + d
		var t := tile(nx)
		if t == WATER:
			_set_block(at, false)
			terrain[nx.y * w + nx.x] = ICE
			return true
		var free := (t == FLOOR or t == ICE or t == OPEN_DOOR) and not has_block(nx) \
				and nx != pos[0] and nx != pos[1]
		if not free:
			break
		_set_block(at, false)
		_set_block(nx, true)
		at = nx
		moved = true
		if t != ICE:
			break  # blocks stop sliding once they reach snow
	return moved


func _set_block(c: Vector2i, on: bool) -> void:
	blocks[c.y * w + c.x] = 1 if on else 0


# --- Powers ------------------------------------------------------------------

## Uses sister `si`'s power on the tile in direction `d`. Returns what
## happened ("freeze", "melt_block", "melt_ice", "light", "light_all"), or
## "" if nothing could happen there.
## Frost freezes water into ice. Spark melts ice blocks and ice (back into
## water) and lights lanterns. Ice blocks only come from the level itself:
## letting Frost make them anywhere made puzzles too open-ended.
func power(si: int, d: Vector2i) -> String:
	facing[si] = d
	var c := pos[si] + d
	var t := tile(c)
	var i := c.y * w + c.x
	var someone_there := c == pos[0] or c == pos[1]
	if si == FROST:
		if t == WATER:
			terrain[i] = ICE
			return "freeze"
	else:
		if has_block(c):
			_set_block(c, false)
			return "melt_block"
		if t == ICE and not someone_there:
			terrain[i] = WATER
			return "melt_ice"
		if t == LANTERN:
			terrain[i] = LIT
			if lanterns_left() == 0:
				for j in terrain.size():
					if terrain[j] == DOOR:
						terrain[j] = OPEN_DOOR
				return "light_all"
			return "light"
	return ""


# --- Actions (for the solver and replays) --------------------------------------
# An action is an int: sister * 8 + kind * 4 + direction, kind 0 = move, 1 = power.

static func action(si: int, is_power: bool, dir: int) -> int:
	return si * 8 + (4 if is_power else 0) + dir


func apply(a: int) -> bool:
	var si := a >> 3
	var d := DIRS[a & 3]
	if (a >> 2) & 1 == 1:
		return power(si, d) != ""
	return not move(si, d).is_empty()
