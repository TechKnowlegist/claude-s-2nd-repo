extends Node
## Headless end-to-end test of the whole game loop. Run with:
##   godot --headless --fixed-fps 60 --path riftblade res://tests/smoke_test.tscn
## Exits with code 0 on success, 1 on any failed check.

var failures := 0
var checks := 0
var main: Main
var gs: Node


func _ready() -> void:
	_run.call_deferred()


func check(cond: bool, what: String) -> void:
	checks += 1
	if cond:
		print("  ok   ", what)
	else:
		failures += 1
		print("  FAIL ", what)


func frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _run() -> void:
	gs = get_node("/root/GameState")
	gs.save_path = "user://riftblade_test_save.json"
	gs.reset()

	print("Nexus hub")
	main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(10)
	var w: World = main.world
	check(w.is_hub and w.state == "hub", "game starts in the Nexus")
	var portals := w.get_children().filter(func(c): return c is Portal)
	check(portals.size() == 4, "Nexus has 3 dimension portals + online arena")
	check(gs.is_unlocked("pixel") and not gs.is_unlocked("ascii") and not gs.is_unlocked("geometry"), "only the Pixel Realm starts unlocked")

	print("Forge")
	gs.shards = 100
	var dmg_before: float = gs.sword_damage()
	check(gs.buy_upgrade("damage"), "can buy a damage upgrade")
	check(gs.sword_damage() > dmg_before and gs.shards == 90, "upgrade raises damage and costs shards")
	w.player.position = w.forge.position
	await frames(2)
	w.interact()
	check(main.hud.is_blocking(), "interacting at the Forge opens the upgrade menu")
	main.hud.close_forge()

	print("Walking into a portal")
	var pixel_portal: Portal = portals.filter(func(c): return c.target == "pixel")[0]
	w.player.position = pixel_portal.position + Vector2(0, 200)
	await frames(5)
	w.player.position = pixel_portal.position
	await frames(60)
	w = main.world
	check(w.dimension_id == "pixel" and w.style == "pixel", "portal leads into the Pixel Realm")

	print("Waves")
	await frames(200)
	check(w.wave == 1 and w.state == "fighting", "wave 1 starts")
	await frames(120)
	check(w.enemies.size() > 0, "enemies spawn (%d)" % w.enemies.size())
	var shards_before: int = gs.shards
	for e in w.enemies.duplicate():
		e.take_damage(9999.0, false, Vector2.RIGHT)
	await frames(30)
	check(w.get_children().any(func(c): return c is Pickup and c.kind == "shard"), "enemies drop shards")
	await frames(150)
	check(gs.shards > shards_before, "shards get collected (+%d)" % (gs.shards - shards_before))
	check(w.state == "intermission", "wave clears into an intermission")
	var chest: Pickup = w.get_children().filter(func(c): return c is Pickup and c.kind == "chest")[0]
	check(chest != null, "a Rift Chest appears after the wave")

	print("Sword combat")
	await frames(260)
	var target: Enemy = null
	for e in w.enemies:
		target = e
		break
	check(target != null, "wave 2 spawns enemies")
	if target:
		var hp_before := target.hp
		w.player.position = target.position - Vector2(30, 0)
		w.player.facing = Vector2.RIGHT
		w.player.attack()
		check(target.hp < hp_before, "sword swing damages an enemy in front")

	print("Items")
	gs.items.clear()
	gs.add_item({"type": "supercharge", "rarity": 3})
	gs.add_item({"type": "potion", "rarity": 0})
	w.player.use_item(0)
	check(w.player.has_buff("supercharge") and gs.items.size() == 1, "using an item applies its buff and consumes it")
	w.player.hp = 10.0
	w.player.use_item(0)
	check(w.player.hp > 10.0, "health potion heals")
	var rng := RandomNumberGenerator.new()
	var counts := [0, 0, 0, 0]
	for i in 4000:
		counts[Items.roll_rarity(rng)] += 1
	check(counts[0] > counts[1] and counts[1] > counts[2] and counts[2] > counts[3] and counts[3] > 0, "rarity RNG: common > rare > epic > legendary %s" % [counts])

	print("Boss")
	for e in w.enemies.duplicate():
		e.die()
	w.wave = w.total_waves
	w.state = "intermission"
	w.state_time = 0.0
	await frames(160)
	check(w.boss != null and w.state == "boss", "boss spawns after the last wave")
	w.player.buffs["shield"] = {"time": 999.0, "power": 1.0}
	await frames(240)
	check(w.enemies.size() >= 1, "boss fight runs (enemies alive: %d)" % w.enemies.size())
	w.boss.take_damage(99999.0, true, Vector2.RIGHT)
	await frames(5)
	check(w.state == "cleared" and gs.cleared.has("pixel"), "beating the boss clears the dimension")
	check(gs.is_unlocked("ascii"), "clearing the Pixel Realm unlocks the ASCII Void")
	var home: Portal = w.get_children().filter(func(c): return c is Portal)[0]
	w.player.position = home.position + Vector2(0, 200)
	await frames(5)
	w.player.position = home.position
	await frames(60)
	check(main.world.is_hub, "exit portal returns to the Nexus")

	for dim in ["ascii", "geometry"]:
		print("Dimension: ", dim)
		main.load_world(dim)
		w = main.world
		w.player.buffs["shield"] = {"time": 999.0, "power": 1.0}
		await frames(500)
		check(w.style == Dimensions.DATA[dim].style and w.enemies.size() > 0, "%s runs with enemies in %s style" % [dim, w.style])
		for i in 20:
			w.player.attack()
			await frames(30)

	print("Death")
	main.load_world("pixel")
	w = main.world
	await frames(10)
	w.run_shards = 20
	gs.shards = 50
	w.player.hurt(9999.0, Vector2.RIGHT)
	check(w.player.dead and w.state == "dead", "player can die")
	check(gs.shards == 40, "dying costs half the run's shards")
	await frames(240)
	check(main.world.is_hub, "death sends you back to the Nexus")

	print("Save / load")
	gs.shards = 1234
	gs.items = [{"type": "shield", "rarity": 2}]
	gs.save_game()
	gs.reset()
	gs.load_game()
	check(gs.shards == 1234 and gs.cleared.has("pixel") and gs.level("damage") == 1 and gs.items.size() == 1, "progress survives save/load")
	DirAccess.remove_absolute(ProjectSettings.globalize_path(gs.save_path))

	print("\n%d/%d checks passed" % [checks - failures, checks])
	get_tree().quit(1 if failures > 0 else 0)
