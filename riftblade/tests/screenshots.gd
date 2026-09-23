extends Node
## Renders a screenshot of the Nexus and each dimension mid-fight.
## Needs a display (not --headless), e.g.:
##   xvfb-run godot --path riftblade res://tests/screenshots.tscn -- <out_dir>

var out_dir := "user://screenshots"


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	_run.call_deferred()


func frames(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _snap(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(name + ".png"))
	print("saved ", name)


func _run() -> void:
	var gs := get_node("/root/GameState")
	gs.save_path = "user://riftblade_shot_save.json"
	gs.reset()
	gs.cleared = {"pixel": Dimensions.DATA.pixel.waves + 1}
	gs.shards = 137
	gs.items = [{"type": "potion", "rarity": 1}, {"type": "supercharge", "rarity": 3}]
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	gs.add_gear(Items._make("sword", 3, rng))
	gs.add_gear(Items._make("armor", 2, rng))
	var main: Main = load("res://scenes/main.tscn").instantiate()
	get_tree().root.add_child(main)
	await frames(40)
	await _snap("1_nexus")

	for dim in ["pixel", "ascii", "geometry"]:
		main.load_world(dim)
		var w: World = main.world
		w.player.buffs["shield"] = {"time": 999.0, "power": 1.0}
		w.state_time = 0.0
		await frames(200)
		w.player.position = w.current_room_rect().get_center()
		await frames(2)
		w.spawn_item(w.player.position + Vector2(90, 60), {"type": "boost", "rarity": 2})
		w.spawn_chest(w.player.position + Vector2(-110, 70))
		for i in 6:
			w.spawn_shard(w.player.position + Vector2(-60, -80), 1)
		var near := w.spawn_enemy("brute", w.player.position + Vector2(140, -40))
		near.hp = near.max_hp * 0.6
		w.spawn_enemy("chaser", w.player.position + Vector2(-150, -30))
		w.spawn_enemy("shooter", w.player.position + Vector2(40, -170))
		await frames(20)
		w.player.facing = Vector2.RIGHT
		w.player.attack()
		await frames(4)
		await _snap("2_" + dim)

	# A puzzle room, mid-solve.
	main.load_world("pixel")
	var pw: World = main.world
	pw.player.buffs["shield"] = {"time": 999.0, "power": 1.0}
	for e in pw.enemies.duplicate():
		e.die()
	pw.wave = 2
	pw.state = "intermission"
	pw.state_time = 0.0
	await frames(10)
	if pw.state == "puzzle" and pw._puzzle != null:
		var ordered: Array = pw._puzzle.pads.duplicate()
		ordered.sort_custom(func(a, b): return a.number < b.number)
		if ordered.size() > 0:
			pw.player.position = ordered[0].pos
			pw.player.facing = Vector2.RIGHT
			await frames(3)
	await _snap("3_puzzle")

	gs.reset()
	get_tree().quit()
