extends Node
## Autoload holding everything that persists between runs: shards, sword
## upgrades, cleared dimensions/stages, carried consumables and the
## permanent gear inventory (swords and armor you've looted and equipped).
## Also sets up the input map (keyboard, mouse and controller).

signal changed

const MAX_ITEMS := 3
const MAX_LEVEL := 10
const MAX_GEAR := 30

const UPGRADES := {
	"damage": {"name": "Sharpen", "desc": "+5 damage", "base_cost": 10},
	"speed": {"name": "Balance", "desc": "swing 8% faster", "base_cost": 12},
	"reach": {"name": "Lengthen", "desc": "+12 reach", "base_cost": 12},
	"crit": {"name": "Rift Edge", "desc": "+5% crit chance", "base_cost": 15},
	"vitality": {"name": "Rift Heart", "desc": "+15 max health", "base_cost": 14},
}
const UPGRADE_ORDER := ["damage", "speed", "reach", "crit", "vitality"]
const SWORD_STATS := ["damage", "speed", "reach", "crit"]

const SWORD_NAMES := [
	"Basic Sword", "Iron Sword", "Tempered Blade", "Rift-Touched Blade",
	"Prism Edge", "Dimension Cleaver", "Blade of All Worlds",
]

var save_path := "user://riftblade_save.json"
var shards := 0
var levels := {}
## Dimension id -> highest room/stage index cleared in it.
var cleared := {}
var items: Array = []
## Owned gear: id -> item dict. Equipped gear is also kept here.
var gear: Dictionary = {}
var equipped_sword := ""
var equipped_armor := ""
var kills := 0


func _ready() -> void:
	_setup_input()
	reset()
	load_game()


func reset() -> void:
	shards = 0
	levels = {}
	for k in UPGRADE_ORDER:
		levels[k] = 0
	cleared = {}
	items = []
	gear = {}
	equipped_sword = ""
	equipped_armor = ""
	kills = 0
	changed.emit()


# --- Sword and player stats -------------------------------------------------

func level(stat: String) -> int:
	return int(levels.get(stat, 0))


func equipped_sword_item() -> Dictionary:
	return gear.get(equipped_sword, {})


func equipped_armor_item() -> Dictionary:
	return gear.get(equipped_armor, {})


func sword_damage() -> float:
	var base := 10.0 + 5.0 * level("damage")
	var sw := equipped_sword_item()
	if not sw.is_empty():
		base += Items.sword_bonus(sw).damage
	return base


func sword_cooldown() -> float:
	return 0.42 * pow(0.92, level("speed"))


func sword_reach() -> float:
	var base := 62.0 + 12.0 * level("reach")
	var sw := equipped_sword_item()
	if not sw.is_empty():
		base += Items.sword_bonus(sw).reach
	return base


func sword_crit() -> float:
	return 0.05 + 0.05 * level("crit")


func max_health() -> float:
	var base := 100.0 + 15.0 * level("vitality")
	var ar := equipped_armor_item()
	if not ar.is_empty():
		base += Items.armor_bonus(ar).health
	return base


## Fraction of incoming damage blocked by equipped armor (0..~0.4).
func damage_reduction() -> float:
	var ar := equipped_armor_item()
	if ar.is_empty():
		return 0.0
	return clampf(Items.armor_bonus(ar).reduction, 0.0, 0.6)


func sword_name() -> String:
	var sw := equipped_sword_item()
	if not sw.is_empty():
		return Items.label(sw)
	var total := 0
	for k in SWORD_STATS:
		total += level(k)
	return SWORD_NAMES[mini(int(total / 6.0), SWORD_NAMES.size() - 1)]


func armor_name() -> String:
	var ar := equipped_armor_item()
	return Items.label(ar) if not ar.is_empty() else "No armor"


func upgrade_cost(stat: String) -> int:
	var base: int = UPGRADES[stat].base_cost
	return int(round(base * pow(1.55, level(stat))))


func can_upgrade(stat: String) -> bool:
	return level(stat) < MAX_LEVEL and shards >= upgrade_cost(stat)


func buy_upgrade(stat: String) -> bool:
	if not can_upgrade(stat):
		return false
	shards -= upgrade_cost(stat)
	levels[stat] = level(stat) + 1
	save_game()
	changed.emit()
	return true


# --- Gear (swords & armor) ---------------------------------------------------------

## Adds a piece of gear to the permanent inventory. Auto-equips it if it's
## strictly better than what's currently worn, or if that slot is empty.
func add_gear(item: Dictionary) -> void:
	if gear.size() >= MAX_GEAR:
		# Drop the weakest unequipped piece of the same type to make room.
		var worst := ""
		var worst_power := INF
		for id in gear:
			var g: Dictionary = gear[id]
			if g.type == item.type and id != equipped_sword and id != equipped_armor and Items.power(g) < worst_power:
				worst = id
				worst_power = Items.power(g)
		if worst != "":
			gear.erase(worst)
		else:
			changed.emit()
			return
	gear[item.id] = item
	if item.type == "sword" and (equipped_sword == "" or Items.power(item) > Items.power(equipped_sword_item())):
		equipped_sword = item.id
	elif item.type == "armor" and (equipped_armor == "" or Items.power(item) > Items.power(equipped_armor_item())):
		equipped_armor = item.id
	save_game()
	changed.emit()


func equip(id: String) -> void:
	if not gear.has(id):
		return
	var item: Dictionary = gear[id]
	if item.type == "sword":
		equipped_sword = id
	elif item.type == "armor":
		equipped_armor = id
	save_game()
	changed.emit()


func gear_of_type(type: String) -> Array:
	var out := []
	for id in gear:
		if gear[id].type == type:
			out.append(gear[id])
	out.sort_custom(func(a, b): return Items.power(a) > Items.power(b))
	return out


# --- Progress -----------------------------------------------------------------

func add_shards(amount: int) -> void:
	shards = maxi(shards + amount, 0)
	changed.emit()


func is_unlocked(dim: String) -> bool:
	var req: String = Dimensions.DATA[dim].requires
	return req == "" or is_fully_cleared(req)


## Highest room index cleared in `dim` (0 if none).
func rooms_cleared(dim: String) -> int:
	return int(cleared.get(dim, 0))


## True once the dimension's boss room (the final room) has been cleared.
func is_fully_cleared(dim: String) -> bool:
	return rooms_cleared(dim) > int(Dimensions.DATA[dim].waves)


func mark_room_cleared(dim: String, room: int) -> void:
	if room > rooms_cleared(dim):
		cleared[dim] = room
		save_game()
		changed.emit()


func add_item(item: Dictionary) -> bool:
	if items.size() >= MAX_ITEMS:
		return false
	items.append(item)
	changed.emit()
	return true


func take_item(slot: int) -> Dictionary:
	if slot < 0 or slot >= items.size():
		return {}
	var item: Dictionary = items[slot]
	items.remove_at(slot)
	changed.emit()
	return item


# --- Save / load ----------------------------------------------------------------

func save_game() -> void:
	var data := {
		"version": 2,
		"shards": shards,
		"levels": levels,
		"cleared": cleared,
		"items": items,
		"gear": gear.values(),
		"equipped_sword": equipped_sword,
		"equipped_armor": equipped_armor,
		"kills": kills,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Could not write save file: %s" % save_path)
		return
	f.store_string(JSON.stringify(data, "  "))


func load_game() -> void:
	if not FileAccess.file_exists(save_path):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("Ignoring unreadable save file.")
		return
	shards = maxi(int(data.get("shards", 0)), 0)
	var saved_levels = data.get("levels", {})
	if typeof(saved_levels) == TYPE_DICTIONARY:
		for k in UPGRADE_ORDER:
			levels[k] = clampi(int(saved_levels.get(k, 0)), 0, MAX_LEVEL)
	cleared = {}
	var saved_cleared = data.get("cleared", {})
	if typeof(saved_cleared) == TYPE_DICTIONARY:
		for d in saved_cleared:
			if Dimensions.DATA.has(d):
				cleared[d] = int(saved_cleared[d])
	elif typeof(saved_cleared) == TYPE_ARRAY:
		# Older save format: a list of fully-cleared dimension ids.
		for d in saved_cleared:
			if Dimensions.DATA.has(d):
				cleared[d] = Dimensions.DATA[d].waves + 1
	items = []
	for it in data.get("items", []):
		if typeof(it) == TYPE_DICTIONARY and Items.TYPES.has(it.get("type")) and items.size() < MAX_ITEMS:
			items.append({
				"type": str(it.type),
				"rarity": clampi(int(it.get("rarity", 0)), 0, Items.RARITIES.size() - 1),
			})
	gear = {}
	for g in data.get("gear", []):
		if typeof(g) == TYPE_DICTIONARY and Items.TYPES.has(g.get("type")) and Items.is_gear(g) and gear.size() < MAX_GEAR:
			var id := str(g.get("id", ""))
			if id == "":
				continue
			gear[id] = {
				"type": str(g.type),
				"rarity": clampi(int(g.get("rarity", 0)), 0, Items.RARITIES.size() - 1),
				"id": id,
				"adjective": str(g.get("adjective", "")),
			}
	equipped_sword = str(data.get("equipped_sword", "")) if gear.has(data.get("equipped_sword", "")) else ""
	equipped_armor = str(data.get("equipped_armor", "")) if gear.has(data.get("equipped_armor", "")) else ""
	kills = int(data.get("kills", 0))
	changed.emit()


# --- Input ----------------------------------------------------------------------

func _setup_input() -> void:
	_action("move_left", [KEY_A, KEY_LEFT], [], [JOY_BUTTON_DPAD_LEFT], JOY_AXIS_LEFT_X, -1.0)
	_action("move_right", [KEY_D, KEY_RIGHT], [], [JOY_BUTTON_DPAD_RIGHT], JOY_AXIS_LEFT_X, 1.0)
	_action("move_up", [KEY_W, KEY_UP], [], [JOY_BUTTON_DPAD_UP], JOY_AXIS_LEFT_Y, -1.0)
	_action("move_down", [KEY_S, KEY_DOWN], [], [JOY_BUTTON_DPAD_DOWN], JOY_AXIS_LEFT_Y, 1.0)
	_action("attack", [KEY_SPACE, KEY_J], [MOUSE_BUTTON_LEFT], [JOY_BUTTON_X])
	_action("dash", [KEY_SHIFT, KEY_K], [MOUSE_BUTTON_RIGHT], [JOY_BUTTON_A])
	_action("interact", [KEY_E], [], [JOY_BUTTON_Y])
	_action("inventory", [KEY_I], [], [JOY_BUTTON_BACK])
	_action("item_1", [KEY_1], [], [JOY_BUTTON_LEFT_SHOULDER])
	_action("item_2", [KEY_2], [], [JOY_BUTTON_RIGHT_SHOULDER])
	_action("item_3", [KEY_3], [], [JOY_BUTTON_B])
	_action("pause", [KEY_ESCAPE, KEY_P], [], [JOY_BUTTON_START])


func _action(action: String, keys: Array, mouse: Array = [], joy: Array = [], axis := -1, axis_dir := 0.0) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action, 0.25)
	for k in keys:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		InputMap.action_add_event(action, ev)
	for b in mouse:
		var ev := InputEventMouseButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	for b in joy:
		var ev := InputEventJoypadButton.new()
		ev.button_index = b
		InputMap.action_add_event(action, ev)
	if axis >= 0:
		var ev := InputEventJoypadMotion.new()
		ev.axis = axis
		ev.axis_value = axis_dir
		InputMap.action_add_event(action, ev)
