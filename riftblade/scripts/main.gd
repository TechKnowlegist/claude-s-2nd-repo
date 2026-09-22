class_name Main
extends Node
## Root of the game: owns the HUD and swaps between worlds (the Nexus hub
## and each dimension) with a fade.

var hud: HUD
var world: World
var _traveling := false


func _ready() -> void:
	randomize()
	hud = HUD.new()
	add_child(hud)
	load_world(Dimensions.HUB)
	hud.banner("RIFT BLADE", "Pick a portal. Grow your blade. Conquer every dimension.", 4.0)


func travel(target: String, title := "", subtitle := "") -> void:
	if _traveling:
		return
	_traveling = true
	await hud.fade_to(1.0)
	load_world(target)
	if title != "":
		hud.banner(title, subtitle, 4.0)
	await hud.fade_to(0.0)
	_traveling = false


func load_world(id: String) -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
	world = World.new()
	world.dimension_id = id
	world.main = self
	world.hud = hud
	hud.world = world
	add_child(world)
