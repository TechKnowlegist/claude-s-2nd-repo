class_name Items
extends RefCounted
## Consumable items and the RNG that rolls them. Every item has a type and a
## rarity; rarer items are more powerful.

const RARITIES := [
	{"name": "Common", "weight": 60.0, "power": 1.0, "color": Color("c8c8c8")},
	{"name": "Rare", "weight": 26.0, "power": 1.4, "color": Color("4aa3ff")},
	{"name": "Epic", "weight": 11.0, "power": 1.9, "color": Color("b35cff")},
	{"name": "Legendary", "weight": 3.0, "power": 2.6, "color": Color("ffb020")},
]

const TYPES := {
	"potion": {"name": "Health Potion", "glyph": "+", "desc": "Restores health"},
	"boost": {"name": "Speed Boost", "glyph": ">", "desc": "Move 50% faster"},
	"supercharge": {"name": "Supercharge", "glyph": "*", "desc": "Spinning swings, more reach and damage"},
	"shield": {"name": "Rift Shield", "glyph": "O", "desc": "Become invulnerable"},
}

const TYPE_WEIGHTS := {"potion": 40.0, "boost": 20.0, "supercharge": 22.0, "shield": 18.0}


## Rolls a rarity index. `luck` > 0 makes everything above Common likelier.
static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0) -> int:
	var weights := PackedFloat32Array()
	for i in RARITIES.size():
		var w: float = RARITIES[i].weight
		if i > 0:
			w *= 1.0 + luck
		weights.append(w)
	return rng.rand_weighted(weights)


static func roll(rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var keys := TYPE_WEIGHTS.keys()
	var weights := PackedFloat32Array(TYPE_WEIGHTS.values())
	return {"type": keys[rng.rand_weighted(weights)], "rarity": roll_rarity(rng, luck)}


static func power(item: Dictionary) -> float:
	return RARITIES[item.rarity].power


static func color(item: Dictionary) -> Color:
	return RARITIES[item.rarity].color


static func glyph(item: Dictionary) -> String:
	return TYPES[item.type].glyph


static func label(item: Dictionary) -> String:
	return "%s %s" % [RARITIES[item.rarity].name, TYPES[item.type].name]
