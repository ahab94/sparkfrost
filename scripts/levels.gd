extends RefCounted
## Sparkfrost's levels, easiest first. Each one teaches one new idea.
## Map format: see the top of scripts/rules.gd. Every row must be the same width.
## tests/rules_test.gd has the solver prove every level can be beaten, and
## that each level's "par" (3-star move count) is exactly the fewest moves possible.

const LEVELS := [
	{
		"name": "Pond Hop",
		"par": 11,   # fewest moves possible (from the solver)
		"hint": "Frost can freeze water into ice. Get both sisters home!",
		"map": [
			"########",
			"#F..~.f#",
			"#S..~.s#",
			"########",
		],
	},
	{
		"name": "Lantern Light",
		"par": 19,   # fewest moves possible (from the solver)
		"hint": "Spark lights lanterns. Light them all to open the gate.",
		"map": [
			"##########",
			"#F..l..#f#",
			"#......D.#",
			"#S.....#s#",
			"##########",
		],
	},
	{
		"name": "Slippery Hall",
		"par": 12,   # fewest moves possible (from the solver)
		"hint": "Ice is slippery! Spark can melt ice into water to make a stop.",
		"map": [
			"##########",
			"#F=======#",
			"###f.#####",
			"#S......s#",
			"##########",
		],
	},
	{
		"name": "Block Party",
		"par": 15,   # fewest moves possible (from the solver)
		"hint": "Push an ice block into water to build a bridge.",
		"map": [
			"##########",
			"#S.B#..f.#",
			"#...~....#",
			"#F..#..s.#",
			"##########",
		],
	},
	{
		"name": "Sisters Together",
		"par": 23,   # fewest moves possible (from the solver)
		"hint": "Light the lantern, cross the water, then slide home. Work together!",
		"map": [
			"############",
			"#F..l#.....#",
			"#.==.D.....#",
			"#....#~~~~~#",
			"#S...#f~#s~#",
			"############",
		],
	},
]
