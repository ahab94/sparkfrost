extends RefCounted
## Sparkfrost's levels, easiest first. Each one teaches or combines one idea.
## Map format: see the top of scripts/rules.gd. Every row must be the same width.
## tests/rules_test.gd has the solver prove every level can be beaten, and
## that each level's "par" (3-star move count) is exactly the fewest moves possible.
##
## "intro" and "outro" are short story lines: [speaker, text], where speaker
## 0 = Frost, 1 = Spark, -1 = narrator. The story: the Northern Lights have
## gone dark, and the two sisters travel to the Aurora Spire to light them again.

const LEVELS := [
	{
		"name": "Pond Hop", "par": 12,
		"hint": "Frost (WASD + Space) freezes water into ice you can walk on. Get both sisters home!",
		"intro": [[-1, "The Northern Lights have gone dark..."], [0, "Don't worry, Spark. I'll make us a bridge!"]],
		"outro": [[1, "You're the best big sister!"]],
		"map": ["########", "#F..~.f#", "#S..~.s#", "########"],
	},
	{
		"name": "Lantern Light", "par": 19,
		"hint": "Spark (Arrows + Enter) lights lanterns. Light them all to open the gate.",
		"intro": [[0, "It's so dark in here..."], [1, "Leave that to me!"]],
		"outro": [[0, "Your light is so warm."]],
		"map": ["##########", "#F..l..#f#", "#......D.#", "#S.....#s#", "##########"],
	},
	{
		"name": "Helping Hands", "par": 23,
		"hint": "Spark melts ice blocks. Frost freezes water. Clear the way for each other!",
		"intro": [[0, "My door is blocked by ice..."], [1, "And mine is under water. Let's help each other!"]],
		"outro": [[1, "That's what sisters are for."]],
		"map": ["#########", "#F......#", "#S......#", "##B###~##", "##f###s##", "#########"],
	},
	{
		"name": "Block Party", "par": 17,
		"hint": "Push an ice block into water to build a bridge.",
		"intro": [[1, "I can't swim, Frost..."], [0, "Push the ice block in. It will hold you!"]],
		"outro": [[1, "I wasn't scared. Okay, maybe a little."]],
		"map": ["##########", "#S.B#..f.#", "#...~....#", "#F..#..s.#", "##########"],
	},
	{
		"name": "Make Way", "par": 16,
		"hint": "Your homes are on opposite sides. Take turns and make way!",
		"intro": [[1, "Excuse me, coming through!"]],
		"outro": [[0, "We'll always find a way."]],
		"map": ["#########", "#F.....s#", "#.##B##.#", "#S..~..f#", "#########"],
	},
	{
		"name": "Pocket Swap", "par": 18,
		"hint": "Each sister's home is on the other's path. Help her get there.",
		"intro": [[0, "Your home is on my side, and mine is on yours!"]],
		"outro": [[1, "Swap complete!"]],
		"map": ["##########", "#F...B.~s#", "#.######.#", "#S...~.Bf#", "##########"],
	},
	{
		"name": "Two Bridges", "par": 17,
		"hint": "Two rivers. Use the blocks, use your powers!",
		"intro": [[0, "Two rivers, two bridges."]],
		"outro": [[1, "Teamwork makes the dream work!"]],
		"map": ["##########", "#F.B.~~.f#", "#........#", "#S.B.~~.s#", "##########"],
	},
	{
		"name": "Sisters Together", "par": 22,
		"hint": "Light the lantern, then freeze the way home.",
		"intro": [[0, "Ready?"], [1, "Always, as long as it's with you."]],
		"outro": [[0, "The Aurora Spire is still far away..."], [1, "Then let's keep going!"]],
		"map": ["##########", "#F.l#....#", "#...D....#", "#S..#~~~~#", "#####f#s##", "##########"],
	},
	{
		"name": "Crossing", "par": 18,
		"hint": "Each sister's home is across the river. Swap sides!",
		"intro": [[0, "Stay close, okay?"], [1, "I'm right here."]],
		"outro": [[0, "See? Nothing to be scared of."]],
		"map": ["#########", "#F.~~..s#", "#..~~.B.#", "#S.~~..f#", "#########"],
	},
	{
		"name": "Melt the Way", "par": 22,
		"hint": "Spark can melt ice blocks that are stuck in the way.",
		"intro": [[1, "These blocks are in the way. Sorry, ice!"]],
		"outro": [[0, "Hey! That was MY ice!"], [1, "Hehe. Sorry, sis."]],
		"map": ["###########", "#F.B.B..~f#", "#.####.##.#", "#S.B~B...s#", "###########"],
	},
	{
		"name": "Narrow Bridge", "par": 22,
		"hint": "The bridges are narrow. Who crosses first?",
		"intro": [[0, "Careful, the way is narrow."], [1, "Hold my hand?"]],
		"outro": [[0, "Always."]],
		"map": ["###########", "#F..~~~..s#", "#.B.#.#.B.#", "#S..~~~..f#", "###########"],
	},
	{
		"name": "Gatekeepers", "par": 26,
		"hint": "Two lanterns, one gate. Frost will need to make a path.",
		"intro": [[0, "Two lanterns, and one of them is across the water."]],
		"outro": [[1, "We're almost there!"]],
		"map": ["############", "#F...#..l..#", "#....~.....#", "#S..l#...D##", "#########fs#", "############"],
	},
	{
		"name": "First Glow", "par": 29,
		"hint": "Open the gate first, then freeze the way across.",
		"intro": [[1, "Look! A little glow in the sky!"]],
		"outro": [[0, "The lights are coming back!"]],
		"map": ["###########", "#F..#..~~f#", "#.B.D..####", "#S.l#..~~s#", "###########"],
	},
	{
		"name": "Lantern Duo", "par": 26,
		"hint": "Light both lanterns. Frost will have to help Spark across.",
		"intro": [[1, "I'm so tired, Frost."], [0, "Then I'll carry the light with you."]],
		"outro": [[1, "I'm really glad you're my sister."]],
		"map": ["############", "#F...~..l#f#", "#....~...D.#", "#S..l~...#s#", "############"],
	},
	{
		"name": "Aurora Spire", "par": 22,
		"hint": "The last lanterns. Use everything you've learned!",
		"intro": [[-1, "At last: the Aurora Spire."], [0, "Together?"], [1, "Together."]],
		"outro": [[-1, "The sky bloomed with light again."], [-1, "And the sisters walked home, hand in hand."]],
		"map": ["###########", "#F.~l#...f#", "#.B.~.D...#", "#S..l#.~~s#", "###########"],
	},
]
