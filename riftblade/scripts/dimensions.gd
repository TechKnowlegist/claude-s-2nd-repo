class_name Dimensions
extends RefCounted
## Static data for the Nexus hub and every dimension. Each dimension has its
## own art style and palette, and is unlocked by clearing the one before it.

const HUB := "hub"
const ORDER := ["pixel", "ascii", "geometry"]

const DATA := {
	"hub": {
		"name": "The Nexus",
		"tagline": "home between worlds",
		"style": "minimal",
		"tier": 0,
		"requires": "",
		"size": Vector2(1400, 900),
		"waves": 0,
		"boss_name": "",
		"clear_bonus": 0,
		"intro": "",
		"palette": {
			"bg": Color("0d0f1e"), "bg2": Color("181b36"),
			"wall": Color("2b3060"), "wall2": Color("4a52a0"),
			"text": Color("e8e8ff"), "accent": Color("ff4fd8"),
			"blade": Color("e8f6ff"), "shard": Color("5ff2ff"),
			"player": Color("7df9ff"), "chaser": Color("ff5f6d"),
			"brute": Color("ffa94d"), "shooter": Color("c77dff"),
			"boss": Color("ff4fd8"), "projectile": Color("ff4fd8"),
		},
	},
	"pixel": {
		"name": "The Pixel Realm",
		"tagline": "blocky 16-bit wilds",
		"style": "pixel",
		"tier": 1,
		"requires": "",
		"size": Vector2(1800, 1100),
		"waves": 4,
		"boss_name": "King Blob",
		"clear_bonus": 60,
		"intro": "Survive 4 waves of blocky beasts, then face King Blob.",
		"palette": {
			"bg": Color("3e8a3c"), "bg2": Color("367b34"),
			"wall": Color("6d6d80"), "wall2": Color("4b4b5a"),
			"text": Color("ffffff"), "accent": Color("ffd84a"),
			"blade": Color("e6e6f0"), "shard": Color("6ff7ff"),
			"player": Color("3d6be0"), "chaser": Color("58d05a"),
			"brute": Color("d8413a"), "shooter": Color("9b4fd6"),
			"boss": Color("f08a24"), "projectile": Color("ff5a2a"),
		},
	},
	"ascii": {
		"name": "The ASCII Void",
		"tagline": "a world of pure text",
		"style": "ascii",
		"tier": 2,
		"requires": "pixel",
		"size": Vector2(1800, 1100),
		"waves": 5,
		"boss_name": "The Glyph Daemon",
		"clear_bonus": 120,
		"intro": "Letters with teeth. Survive 5 waves, then face the Glyph Daemon.",
		"palette": {
			"bg": Color("030703"), "bg2": Color("12301a"),
			"wall": Color("2fbf4f"), "wall2": Color("1a6b2c"),
			"text": Color("b8ffc8"), "accent": Color("33ff77"),
			"blade": Color("d8ffe4"), "shard": Color("66e0ff"),
			"player": Color("f5ff66"), "chaser": Color("ff5555"),
			"brute": Color("ff9933"), "shooter": Color("cc66ff"),
			"boss": Color("ff2244"), "projectile": Color("ffee55"),
		},
	},
	"geometry": {
		"name": "The Geometric Rift",
		"tagline": "perfect, merciless shapes",
		"style": "minimal",
		"tier": 3,
		"requires": "ascii",
		"size": Vector2(1800, 1100),
		"waves": 6,
		"boss_name": "The Perfect Form",
		"clear_bonus": 200,
		"intro": "Nothing here is wasted, least of all its attacks. 6 waves, then the Perfect Form.",
		"palette": {
			"bg": Color("f1ede4"), "bg2": Color("e0dace"),
			"wall": Color("1f1f24"), "wall2": Color("3a3a44"),
			"text": Color("1f1f24"), "accent": Color("e63946"),
			"blade": Color("1f1f24"), "shard": Color("2a9d8f"),
			"player": Color("1f1f24"), "chaser": Color("e63946"),
			"brute": Color("457b9d"), "shooter": Color("f4a261"),
			"boss": Color("2a9d8f"), "projectile": Color("e63946"),
		},
	},
}


## The dimension that clearing `id` unlocks, or "" if none.
static func next_after(id: String) -> String:
	for d in ORDER:
		if DATA[d].requires == id:
			return d
	return ""
