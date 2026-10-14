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
		"name": "Pond Hop", "par": 11,
		"hint": "Frost (WASD + Space) freezes water into ice. Get both sisters home!",
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
		"name": "Slippery Hall", "par": 12,
		"hint": "Ice is slippery! Spark can melt ice into water to make a place to stop.",
		"intro": [[0, "Whoa, it's slippery!"], [1, "I'll melt you a puddle to stop at."]],
		"outro": [[1, "We make a great team."]],
		"map": ["##########", "#F=======#", "###f.#####", "#S......s#", "##########"],
	},
	{
		"name": "Block Party", "par": 15,
		"hint": "Push an ice block into water to build a bridge.",
		"intro": [[1, "I can't swim, Frost..."], [0, "Push the ice block in. It will hold you!"]],
		"outro": [[1, "I wasn't scared. Okay, maybe a little."]],
		"map": ["##########", "#S.B#..f.#", "#...~....#", "#F..#..s.#", "##########"],
	},
	{
		"name": "Sisters Together", "par": 23,
		"hint": "Light the lantern, cross the water, then slide home.",
		"intro": [[0, "Ready?"], [1, "Always, as long as it's with you."]],
		"outro": [[0, "The Aurora Spire is still far away..."], [1, "Then let's keep going!"]],
		"map": ["############", "#F..l#.....#", "#.==.D.....#", "#....#~~~~~#", "#S...#f~#s~#", "############"],
	},
	{
		"name": "Slippery Swap", "par": 8,
		"hint": "Slide all the way across, then find your way home.",
		"intro": [[1, "Race you to the other side!"]],
		"outro": [[0, "Wheee! Let's do that again!"]],
		"map": ["##########", "#F=====.s#", "#.##.##..#", "#S=====.f#", "##########"],
	},
	{
		"name": "Ice Maze", "par": 9,
		"hint": "Every slide stops somewhere. Plan where you'll land!",
		"intro": [[0, "Every slide has to stop somewhere..."]],
		"outro": [[1, "You're so clever, Frost!"]],
		"map": ["##########", "#F=====#f#", "#==#====.#", "#====#===#", "#S==B==s=#", "##########"],
	},
	{
		"name": "Lean on Me", "par": 13,
		"hint": "A sister makes a great stopper. Stand where the other needs to stop.",
		"intro": [[1, "Need somewhere to stop? Lean on me!"]],
		"outro": [[0, "Thanks for standing by me."]],
		"map": ["#########", "#F======#", "####.#f##", "#S.....s#", "#########"],
	},
	{
		"name": "Two Bridges", "par": 13,
		"hint": "Blocks slide across ice. Push one into the water!",
		"intro": [[0, "Two rivers, two bridges."]],
		"outro": [[1, "Teamwork makes the dream work!"]],
		"map": ["###########", "#F.B.==~~f#", "#.........#", "#S.B.==~~s#", "###########"],
	},
	{
		"name": "First Glow", "par": 15,
		"hint": "Open the gate first, then freeze the way across.",
		"intro": [[1, "Look! A little glow in the sky!"]],
		"outro": [[0, "The lights are coming back!"]],
		"map": ["#############", "#F..#...~~~f#", "#.B.D.=====.#", "#S.l#......s#", "#############"],
	},
	{
		"name": "Crossing", "par": 16,
		"hint": "Each sister's home is on the other side. Swap places!",
		"intro": [[0, "Stay close, okay?"], [1, "I'm right here."]],
		"outro": [[0, "See? Nothing to be scared of."]],
		"map": ["##########", "#F..~~..s#", "#.B.~~.B.#", "#S..~~..f#", "##########"],
	},
	{
		"name": "Melt the Way", "par": 20,
		"hint": "Spark can melt ice blocks that are stuck in the way.",
		"intro": [[1, "These blocks are in the way. Sorry, ice!"]],
		"outro": [[0, "Hey! That was MY ice!"], [1, "Hehe. Sorry, sis."]],
		"map": ["###########", "#F.B.B..~f#", "#.####.##.#", "#S.B~B...s#", "###########"],
	},
	{
		"name": "Gatekeepers", "par": 24,
		"hint": "Two lanterns, one gate. Frost will need to make a path.",
		"intro": [[0, "Two lanterns, and one of them is across the water."]],
		"outro": [[1, "We're almost there!"]],
		"map": ["############", "#F...#..l..#", "#....~.....#", "#S..l#...D##", "#########fs#", "############"],
	},
	{
		"name": "Lantern Duo", "par": 25,
		"hint": "Light both lanterns. Frost will have to help Spark across.",
		"intro": [[1, "I'm so tired, Frost."], [0, "Then I'll carry the light with you."]],
		"outro": [[1, "I'm really glad you're my sister."]],
		"map": ["############", "#F...~..l#f#", "#....~...D.#", "#S..l~...#s#", "############"],
	},
	{
		"name": "Aurora Spire", "par": 18,
		"hint": "The last lanterns. Use everything you've learned!",
		"intro": [[-1, "At last: the Aurora Spire."], [0, "Together?"], [1, "Together."]],
		"outro": [[-1, "The sky bloomed with light again."], [-1, "And the sisters walked home, hand in hand."]],
		"map": ["############", "#F..~~..l.f#", "#....#.===.#", "#.B..D.=#=.#", "#S.l.#....s#", "############"],
	},
]
