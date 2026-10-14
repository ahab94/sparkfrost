extends SceneTree
## Controls checks: holding a key keeps walking, a key pressed mid-step isn't
## lost, each sister has her own keys, and smart power aims for you.

var game
var failures := 0


func _initialize() -> void:
	game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	game.save_enabled = false
	root.add_child(game)
	_run.call_deferred()


func _run() -> void:
	await _frames(2)
	# Pond Hop: Frost starts at (1,1), water at (4,1).
	game.load_level(0)
	Input.action_press("f_right")
	await _frames(60)
	Input.action_release("f_right")
	await _frames(30)
	_expect(game.board.pos[0] == Vector2i(3, 1), "holding right walks Frost until the water (at %s)" % game.board.pos[0])
	_expect(game.board.pos[1] == Vector2i(1, 2), "Frost's keys don't move Spark")

	# Smart power: Frost faces right at the water, so Space freezes it.
	Input.action_press("f_power")
	await _frames(2)
	Input.action_release("f_power")
	await _frames(10)
	_expect(game.board.tile(Vector2i(4, 1)) == 61, "Space freezes the water in front of Frost")

	# Buffering: press right twice quickly; the second press lands mid-step.
	game.load_level(0)
	await _frames(2)
	Input.action_press("s_right")
	await _frames(1)
	Input.action_release("s_right")
	await _frames(3)
	Input.action_press("s_right")
	await _frames(1)
	Input.action_release("s_right")
	await _frames(40)
	_expect(game.board.pos[1] == Vector2i(3, 2), "a press during a step is remembered (Spark at %s)" % game.board.pos[1])

	game.undo()
	await _frames(2)
	_expect(game.board.pos[1] == Vector2i(2, 2) and game.moves == 1, "undo steps back one move")

	# On-screen controls: hold Frost's right arrow with a finger.
	game.load_level(0)
	game.touch_ui = true
	await _frames(2)
	var right: Dictionary = {}
	for b in game._buttons:
		if b.action == "f_right":
			right = b
	_expect(not right.is_empty(), "touch mode shows Frost's pad")
	if not right.is_empty():
		var touch := InputEventScreenTouch.new()
		touch.index = 0
		touch.position = (right.rect as Rect2).get_center()
		touch.pressed = true
		game._unhandled_input(touch)
		await _frames(40)
		touch.pressed = false
		game._unhandled_input(touch)
		await _frames(20)
		_expect(game.board.pos[0].x >= 2 and game.board.pos[0].y == 1, "holding the on-screen arrow walks Frost (at %s)" % game.board.pos[0])
		_expect(not Input.is_action_pressed("f_right"), "lifting the finger releases the arrow")
	print("INPUT OK" if failures == 0 else "INPUT FAILED (%d)" % failures)
	quit(0 if failures == 0 else 1)


func _frames(n: int) -> void:
	for i in n:
		await process_frame


func _expect(ok: bool, what: String) -> void:
	if not ok:
		failures += 1
		printerr("FAIL: " + what)
