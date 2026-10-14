extends RefCounted
## Finds the shortest solution to a level by breadth-first search over every
## reachable board state. Used to prove each level can be beaten, to set its
## "par" (the move count for three stars), and to drive the autoplay demos.
##
## Each step tries all 16 actions (2 sisters x move/power x 4 directions) and
## keeps the new states it hasn't seen before. The first state that's a win is
## the shortest solution.

const Rules := preload("res://scripts/rules.gd")


## Returns {"solved": bool, "actions": Array[int], "states": int}.
static func solve(rows: Array, max_states := 400000) -> Dictionary:
	var start = Rules.new()
	start.load_map(rows)
	if start.won():
		return {"solved": true, "actions": [], "states": 1}
	var seen := {start.key(): -1}
	var parent := {}   # key -> [previous key, action]
	var frontier := [start]
	while not frontier.is_empty() and seen.size() < max_states:
		var next := []
		for board in frontier:
			var from_key: String = board.key()
			for a in 16:
				var b = board.copy()
				if not b.apply(a):
					continue
				var k: String = b.key()
				if seen.has(k):
					continue
				seen[k] = a
				parent[k] = [from_key, a]
				if b.won():
					return {"solved": true, "actions": _trace(parent, k), "states": seen.size()}
				next.append(b)
		frontier = next
	return {"solved": false, "actions": [], "states": seen.size()}


static func _trace(parent: Dictionary, k: String) -> Array[int]:
	var out: Array[int] = []
	while parent.has(k):
		var link: Array = parent[k]
		out.push_front(link[1])
		k = link[0]
	return out
