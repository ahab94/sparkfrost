extends SceneTree
## Design helper: solves maps (from levels.gd, or a JSON file of candidates)
## and prints each one's fewest moves. Not part of verify.
const Solver := preload("res://scripts/solver.gd")
const Levels := preload("res://scripts/levels.gd")

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var cands: Array = Levels.LEVELS if args.is_empty() else JSON.parse_string(FileAccess.get_file_as_string(args[0]))
	for c in cands:
		var t := Time.get_ticks_msec()
		var r := Solver.solve(c["map"], 600000)
		print("%-20s solved=%s par=%d states=%d (%dms)" % [c["name"], r.solved, r.actions.size(), r.states, Time.get_ticks_msec() - t])
	quit()
