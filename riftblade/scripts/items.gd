class_name Items
extends RefCounted
## Loot and the RNG that rolls it.
##   - Consumables (potion/boost/supercharge/shield): held in 3 quick-use
##     slots, consumed on use.
##   - Gear (sword/armor): permanent. Dropped items go straight into your
##     gear inventory and can be equipped from there at any time.
## Every item has a type and a rarity; rarer items are more powerful.

const RARITIES := [
	{"name": "Common", "weight": 60.0, "power": 1.0, "color": Color("c8c8c8")},
	{"name": "Rare", "weight": 26.0, "power": 1.4, "color": Color("4aa3ff")},
	{"name": "Epic", "weight": 11.0, "power": 1.9, "color": Color("b35cff")},
	{"name": "Legendary", "weight": 3.0, "power": 2.6, "color": Color("ffb020")},
]

const TYPES := {
	"potion": {"name": "Health Potion", "glyph": "+", "desc": "Restores health", "gear": false},
	"boost": {"name": "Speed Boost", "glyph": ">", "desc": "Move 50% faster", "gear": false},
	"supercharge": {"name": "Supercharge", "glyph": "*", "desc": "Spinning swings, more reach and damage", "gear": false},
	"shield": {"name": "Rift Shield", "glyph": "O", "desc": "Become invulnerable", "gear": false},
	"sword": {"name": "Blade", "glyph": "/", "desc": "+damage, +reach", "gear": true},
	"armor": {"name": "Armor", "glyph": "[]", "desc": "+max health, -damage taken", "gear": true},
}

const TYPE_WEIGHTS := {"potion": 34.0, "boost": 17.0, "supercharge": 18.0, "shield": 15.0, "sword": 8.0, "armor": 8.0}
const GEAR_TYPE_WEIGHTS := {"sword": 55.0, "armor": 45.0}

const SWORD_ADJECTIVES := ["Rusted", "Honed", "Rift-Forged", "Prismatic", "Voidglass", "Sunfire", "Ashen", "Echo"]
const ARMOR_ADJECTIVES := ["Padded", "Chainweave", "Runed", "Rift-Plated", "Starforged", "Hollow", "Ember", "Wraith"]


static func roll_rarity(rng: RandomNumberGenerator, luck := 0.0) -> int:
	var weights := PackedFloat32Array()
	for i in RARITIES.size():
		var w: float = RARITIES[i].weight
		if i > 0:
			w *= 1.0 + luck
		weights.append(w)
	return rng.rand_weighted(weights)


## Rolls a random consumable OR gear item (used for common enemy/chest drops).
static func roll(rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var keys := TYPE_WEIGHTS.keys()
	var weights := PackedFloat32Array(TYPE_WEIGHTS.values())
	var type: String = keys[rng.rand_weighted(weights)]
	return _make(type, roll_rarity(rng, luck), rng)


## Rolls only gear (used for the guaranteed boss drop).
static func roll_gear(rng: RandomNumberGenerator, luck := 0.0) -> Dictionary:
	var keys := GEAR_TYPE_WEIGHTS.keys()
	var weights := PackedFloat32Array(GEAR_TYPE_WEIGHTS.values())
	var type: String = keys[rng.rand_weighted(weights)]
	return _make(type, roll_rarity(rng, luck), rng)


static func _make(type: String, rarity: int, rng: RandomNumberGenerator) -> Dictionary:
	var item := {"type": type, "rarity": rarity, "id": ""}
	if is_gear(item):
		var adjectives: Array = SWORD_ADJECTIVES if type == "sword" else ARMOR_ADJECTIVES
		item.id = "%s_%d_%d" % [type, rarity, rng.randi()]
		item.adjective = adjectives[rng.randi() % adjectives.size()]
	return item


static func is_gear(item: Dictionary) -> bool:
	return TYPES[item.type].gear


static func power(item: Dictionary) -> float:
	return RARITIES[item.rarity].power


static func color(item: Dictionary) -> Color:
	return RARITIES[item.rarity].color


static func glyph(item: Dictionary) -> String:
	return TYPES[item.type].glyph


static func label(item: Dictionary) -> String:
	if is_gear(item):
		return "%s %s %s" % [RARITIES[item.rarity].name, item.get("adjective", ""), TYPES[item.type].name]
	return "%s %s" % [RARITIES[item.rarity].name, TYPES[item.type].name]


## Flat stat bonuses a piece of gear grants when equipped.
static func sword_bonus(item: Dictionary) -> Dictionary:
	var p := power(item)
	return {"damage": 6.0 * p, "reach": 8.0 * p}


static func armor_bonus(item: Dictionary) -> Dictionary:
	var p := power(item)
	return {"health": 18.0 * p, "reduction": 0.05 * p}
