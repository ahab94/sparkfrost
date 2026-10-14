extends SceneTree
## Rules and level checks. Run: godot --headless --path . --script res://tests/rules_test.gd
## - each mechanic behaves as designed, on tiny hand-made boards
## - every level is well-formed, beatable, and its par is the true minimum

const Rules := preload("res://scripts/rules.gd")
const Levels := preload("res://scripts/levels.gd")
const Solver := preload("res://scripts/solver.gd")
const TILES := "#.~=lDfsFSB"

var failures := 0


func _initialize() -> void:
	_test_mechanics()
	_test_levels()
	print("RULES OK" if failures == 0 else "RULES FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func board(rows: Array):
	var b = Rules.new()
	b.load_map(rows)
	return b


func _test_mechanics() -> void:
	var b = board(["#######", "#F.~..#", "#S....#", "#######"])
	_expect(b.move(Rules.FROST, Vector2i.RIGHT).size() == 1, "walking one step")
	_expect(b.move(Rules.FROST, Vector2i.RIGHT).is_empty(), "water blocks walking")
	_expect(b.power(Rules.FROST, Vector2i.RIGHT) == "freeze", "Frost freezes water")
	_expect(b.tile(Vector2i(3, 1)) == Rules.ICE, "frozen water becomes ice")
	var path: Array = b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(path.size() == 1 and b.pos[Rules.FROST] == Vector2i(3, 1), "ice is solid ground: one step, no sliding")
	_expect(b.power(Rules.SPARK, Vector2i.RIGHT) == "", "Spark can't do anything to snow")

	b = board(["#######", "#FB..##", "#S....#", "#######"])
	b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(b.has_block(Vector2i(3, 1)) and b.pos[Rules.FROST] == Vector2i(2, 1), "a pushed block moves one tile")
	b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(b.has_block(Vector2i(4, 1)), "and again")
	_expect(b.move(Rules.FROST, Vector2i.RIGHT).is_empty(), "a block against a wall won't move")

	b = board(["#######", "#FB~..#", "#S....#", "#######"])
	b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(b.tile(Vector2i(3, 1)) == Rules.ICE and not b.has_block(Vector2i(2, 1)), "a block pushed into water becomes an ice bridge")
	_expect(b.pos[Rules.FROST] == Vector2i(2, 1), "the pusher steps into the block's place")

	b = board(["#####", "#FB.#", "#S..#", "#####"])
	_expect(b.power(Rules.SPARK, Vector2i.UP) == "", "Spark has to face the block")
	b.move(Rules.SPARK, Vector2i.RIGHT)
	_expect(b.power(Rules.SPARK, Vector2i.UP) == "melt_block" and not b.has_block(Vector2i(2, 1)), "Spark melts ice blocks")

	b = board(["######", "#F.l.#", "#S.D.#", "######"])
	_expect(b.move(Rules.SPARK, Vector2i.RIGHT).size() == 1 and b.move(Rules.SPARK, Vector2i.RIGHT).is_empty(), "a closed gate blocks the way")
	b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(b.power(Rules.FROST, Vector2i.RIGHT) == "", "Frost can't light lanterns")
	b.move(Rules.FROST, Vector2i.LEFT)
	b.move(Rules.SPARK, Vector2i.UP)
	_expect(b.power(Rules.SPARK, Vector2i.RIGHT) == "light_all", "lighting the last lantern opens every gate")
	_expect(b.tile(Vector2i(3, 2)) == Rules.OPEN_DOOR, "the gate is open")

	b = board(["#####", "#FS.#", "#####"])
	_expect(b.move(Rules.FROST, Vector2i.RIGHT).is_empty(), "sisters can't walk through each other")

	b = board(["#####", "#Ff.#", "#Ss.#", "#####"])
	b.move(Rules.FROST, Vector2i.RIGHT)
	_expect(not b.won(), "both sisters must be home")
	b.move(Rules.SPARK, Vector2i.RIGHT)
	_expect(b.won(), "both home wins")

	var copy = b.copy()
	copy.move(Rules.FROST, Vector2i.RIGHT)
	_expect(b.pos[Rules.FROST] == Vector2i(2, 1), "copies don't share state with the original")


func _test_levels() -> void:
	for lv in Levels.LEVELS:
		var rows: Array = lv["map"]
		var title: String = lv["name"]
		var w := (rows[0] as String).length()
		var counts := {}
		for row in rows:
			_expect((row as String).length() == w, "%s: rows have different widths" % title)
			for ch in (row as String):
				_expect(TILES.contains(ch), "%s: unknown tile '%s'" % [title, ch])
				counts[ch] = counts.get(ch, 0) + 1
		for ch in ["F", "S", "f", "s"]:
			_expect(counts.get(ch, 0) == 1, "%s needs exactly one '%s'" % [title, ch])
		_expect(counts.get("D", 0) == 0 or counts.get("l", 0) > 0, "%s has a gate but no lantern" % title)
		_expect(lv.has("hint") and lv.has("par"), "%s needs a hint and a par" % title)
		var r := Solver.solve(rows)
		_expect(r.solved, "%s can't be beaten" % title)
		if r.solved:
			_expect(r.actions.size() == int(lv.get("par", -1)),
					"%s: par is %s but the fewest moves is %d" % [title, lv.get("par"), r.actions.size()])


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
