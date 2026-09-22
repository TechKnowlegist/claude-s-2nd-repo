class_name World
extends Node2D
## One playable space: the Nexus hub or a dimension arena. Builds the walls,
## runs the wave state machine and owns every entity inside it.

const WALL := 32.0
const TIER_HP := [1.0, 1.0, 1.8, 3.0]
const TIER_DMG := [1.0, 1.0, 1.35, 1.8]
const TIER_SPEED := [1.0, 1.0, 1.08, 1.16]

var dimension_id := Dimensions.HUB
var main: Main
var hud: HUD

var data: Dictionary
var style := "minimal"
var pal: Dictionary
var size := Vector2.ZERO
var tier := 0
var is_hub := true

var player: Player
var camera: Camera2D
var solids: Array[Rect2] = []
var enemies: Array = []
var boss: Enemy
var forge: Forge
var rng := RandomNumberGenerator.new()

## "hub", "intermission", "fighting", "boss", "cleared", "dead" or "leaving".
var state := "hub"
var state_time := 0.0
var wave := 0
var total_waves := 0
var pending_spawns := 0
var run_shards := 0

var _shake := 0.0
var _decor_seed := 0
var _death_message := ""


func _ready() -> void:
	data = Dimensions.DATA[dimension_id]
	style = data.style
	pal = data.palette
	size = data.size
	tier = data.tier
	is_hub = dimension_id == Dimensions.HUB
	rng.randomize()
	_decor_seed = rng.randi()
	_build_walls()

	player = Player.new()
	player.world = self
	player.position = Vector2(size.x * 0.5, size.y * 0.72) if is_hub else size * 0.5
	add_child(player)
	player.died.connect(_on_player_died)

	camera = Camera2D.new()
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = int(size.x)
	camera.limit_bottom = int(size.y)
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.position = player.position
	add_child(camera)
	camera.make_current()
	camera.reset_smoothing()

	if is_hub:
		_build_hub()
	else:
		_start_run()


func _process(delta: float) -> void:
	camera.position = player.position
	_shake = move_toward(_shake, 0.0, delta * 40.0)
	camera.offset = Vector2(rng.randf_range(-1.0, 1.0), rng.randf_range(-1.0, 1.0)) * _shake


func _physics_process(delta: float) -> void:
	match state:
		"intermission":
			state_time -= delta
			if state_time <= 0.0:
				_next_wave()
		"fighting":
			if pending_spawns == 0 and enemies.is_empty():
				_wave_cleared()
		"dead":
			state_time -= delta
			if state_time <= 0.0:
				state = "leaving"
				main.travel(Dimensions.HUB, "YOU FELL", _death_message)


# --- Layout -----------------------------------------------------------------------

func _build_walls() -> void:
	var body := StaticBody2D.new()
	body.collision_layer = 4
	body.collision_mask = 0
	add_child(body)
	var rects: Array[Rect2] = [
		Rect2(0, 0, size.x, WALL),
		Rect2(0, size.y - WALL, size.x, WALL),
		Rect2(0, 0, WALL, size.y),
		Rect2(size.x - WALL, 0, WALL, size.y),
	]
	if not is_hub:
		var center := size * 0.5
		var tries := 0
		while rects.size() < 11 + tier and tries < 300:
			tries += 1
			var s := Vector2(rng.randi_range(2, 5), rng.randi_range(2, 5)) * WALL
			var p := Vector2(
				rng.randf_range(WALL * 3.0, size.x - WALL * 3.0 - s.x),
				rng.randf_range(WALL * 3.0, size.y - WALL * 3.0 - s.y)
			).snapped(Vector2(WALL, WALL))
			var r := Rect2(p, s)
			if r.grow(170.0).has_point(center):
				continue
			var overlaps := false
			for o in rects:
				if o.grow(WALL * 2.0).intersects(r):
					overlaps = true
					break
			if not overlaps:
				rects.append(r)
	solids = rects
	for r in rects:
		var cs := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = r.size
		cs.shape = shape
		cs.position = r.get_center()
		body.add_child(cs)


func _build_hub() -> void:
	state = "hub"
	var spots := [
		Vector2(size.x * 0.25, size.y * 0.36),
		Vector2(size.x * 0.5, size.y * 0.3),
		Vector2(size.x * 0.75, size.y * 0.36),
	]
	for i in Dimensions.ORDER.size():
		_add_portal(Dimensions.ORDER[i], spots[i])
	_add_portal(Portal.ONLINE, Vector2(size.x * 0.78, size.y * 0.74))
	forge = Forge.new()
	forge.world = self
	forge.position = Vector2(size.x * 0.22, size.y * 0.74)
	add_child(forge)


func _add_portal(target: String, pos: Vector2) -> Portal:
	var portal := Portal.new()
	portal.world = self
	portal.target = target
	portal.position = pos
	add_child(portal)
	return portal


func is_free(p: Vector2, r := 0.0) -> bool:
	if not Rect2(Vector2.ZERO, size).has_point(p):
		return false
	for s in solids:
		if s.grow(r).has_point(p):
			return false
	return true


func random_spawn_point(min_dist := 280.0) -> Vector2:
	for i in 80:
		var p := Vector2(rng.randf_range(WALL * 2.0, size.x - WALL * 2.0), rng.randf_range(WALL * 2.0, size.y - WALL * 2.0))
		if is_free(p, 40.0) and p.distance_to(player.position) >= min_dist:
			return p
	return size * 0.5


func free_point_near(origin: Vector2, radius: float) -> Vector2:
	for i in 30:
		var p := origin + Vector2.from_angle(rng.randf() * TAU) * radius * rng.randf_range(0.6, 1.0)
		if is_free(p, 30.0):
			return p
	return random_spawn_point(0.0)


# --- Run flow ---------------------------------------------------------------------

func _start_run() -> void:
	state = "intermission"
	state_time = 2.5
	wave = 0
	total_waves = data.waves
	run_shards = 0
	hud.banner(data.name, data.intro)


func _next_wave() -> void:
	wave += 1
	if wave > total_waves:
		state = "boss"
		hud.banner(data.boss_name, "BOSS FIGHT")
		spawn_marker("boss", random_spawn_point(360.0), 1.6)
		return
	state = "fighting"
	hud.banner("Wave %d / %d" % [wave, total_waves], "")
	var count := 3 + wave * 2 + tier
	for i in count:
		spawn_marker(_roll_enemy_kind(), random_spawn_point(), 0.9 + i * 0.12)


func _roll_enemy_kind() -> String:
	var advanced := wave >= 2 or tier >= 2
	var weights := PackedFloat32Array([
		1.0,
		(0.25 + 0.05 * tier) if advanced else 0.0,
		0.3 if advanced else 0.0,
	])
	return ["chaser", "brute", "shooter"][rng.rand_weighted(weights)]


func _wave_cleared() -> void:
	state = "intermission"
	state_time = 4.0
	player.heal(10.0)
	hud.banner("Wave cleared!", "A Rift Chest appeared.")
	spawn_chest(free_point_near(player.position, 110.0))


func _dimension_cleared() -> void:
	state = "cleared"
	for e in enemies.duplicate():
		e.die()
	var first := GameState.mark_cleared(dimension_id)
	var bonus: int = data.clear_bonus if first else int(data.clear_bonus / 2)
	collect_shards(bonus)
	var sub := "+%d shards." % bonus
	var unlocked := Dimensions.next_after(dimension_id)
	if first and unlocked != "":
		sub += " %s unlocked!" % Dimensions.DATA[unlocked].name
	elif first:
		sub += " You have conquered every dimension!"
	hud.banner("DIMENSION CLEARED", sub + " Take the portal home.", 5.0)
	_add_portal(Dimensions.HUB, free_point_near(player.position, 150.0))
	GameState.save_game()


func _on_player_died() -> void:
	state = "dead"
	state_time = 2.5
	var lost := int(run_shards / 2)
	GameState.add_shards(-lost)
	GameState.save_game()
	_death_message = "Lost %d of the %d shards from this run. Upgrade and try again." % [lost, run_shards]
	hud.banner("YOU FELL", "", 2.5)


## Leave a run early from the pause menu. Costs half the run's shards.
func retreat() -> void:
	if is_hub or state == "leaving":
		return
	var lost := int(run_shards / 2)
	GameState.add_shards(-lost)
	GameState.save_game()
	state = "leaving"
	main.travel(Dimensions.HUB, "Retreated", "Lost %d shards fleeing the rift." % lost)


func enter_portal(target: String) -> void:
	state = "leaving"
	if target == Dimensions.HUB:
		main.travel(target, "Back in the Nexus", "Spend your shards at the Forge.")
	else:
		main.travel(target)


func interact() -> void:
	if forge != null and forge.is_near():
		hud.open_forge()


# --- Spawning ---------------------------------------------------------------------

func spawn_marker(kind: String, pos: Vector2, delay: float) -> void:
	pending_spawns += 1
	var m := Fx.SpawnMarker.new()
	m.world = self
	m.kind = kind
	m.position = pos
	m.delay = delay
	m.color = pal[kind]
	add_child(m)


func marker_done(kind: String, pos: Vector2) -> void:
	pending_spawns -= 1
	if state == "cleared" or state == "leaving":
		return
	spawn_enemy(kind, pos)


func spawn_enemy(kind: String, pos: Vector2) -> Enemy:
	var e := Enemy.new()
	e.world = self
	e.kind = kind
	e.position = pos
	e.hp_mult = TIER_HP[tier] * (1.0 + 0.08 * maxi(wave - 1, 0))
	e.dmg_mult = TIER_DMG[tier]
	e.spd_mult = TIER_SPEED[tier]
	e.shard_mult = maxi(tier, 1)
	add_child(e)
	e.died.connect(_on_enemy_died)
	enemies.append(e)
	if kind == "boss":
		boss = e
	return e


func _on_enemy_died(e: Enemy) -> void:
	enemies.erase(e)
	GameState.kills += 1
	burst(e.position, e.color(), 24 if e == boss else 10)
	var total := e.shard_value
	while total > 0:
		var v := 5 if total >= 5 else 1
		total -= v
		spawn_shard(e.position, v)
	if e == boss:
		boss = null
		spawn_item(e.position, Items.roll(rng, 2.0))
		spawn_item(e.position, Items.roll(rng, 2.0))
		_dimension_cleared()
		return
	var drop_chance := 0.05 + 0.01 * tier
	if e.kind == "brute":
		drop_chance *= 2.0
	if rng.randf() < drop_chance:
		spawn_item(e.position, Items.roll(rng))


func spawn_projectile(pos: Vector2, velocity: Vector2, damage: float) -> void:
	var p := Projectile.new()
	p.world = self
	p.position = pos
	p.velocity = velocity
	p.damage = damage
	add_child(p)


func _spawn_pickup(kind: String, pos: Vector2, fling: float) -> Pickup:
	var p := Pickup.new()
	p.world = self
	p.kind = kind
	p.position = pos
	p.velocity = Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(fling * 0.4, fling)
	add_child(p)
	return p


func spawn_shard(pos: Vector2, value: int) -> void:
	_spawn_pickup("shard", pos, 220.0).value = value


func spawn_item(pos: Vector2, item: Dictionary) -> void:
	_spawn_pickup("item", pos, 160.0).item = item


func spawn_chest(pos: Vector2) -> void:
	_spawn_pickup("chest", pos, 0.0)


func open_chest(chest: Pickup) -> void:
	burst(chest.position, pal.accent, 16)
	shake(4.0)
	for i in rng.randi_range(4, 8):
		spawn_shard(chest.position, maxi(tier, 1))
	spawn_item(chest.position, Items.roll(rng, 0.5))
	chest.queue_free()


func collect_shards(value: int) -> void:
	GameState.add_shards(value)
	run_shards += value


# --- Effects ----------------------------------------------------------------------

func shake(amount: float) -> void:
	_shake = maxf(_shake, amount)


func float_text(pos: Vector2, text: String, color: Color, font_size := 16) -> void:
	var f := Fx.FloatText.new()
	f.text = text
	f.color = color
	f.font_size = font_size
	f.outline = Color(pal.bg, 0.7)
	f.position = pos
	f.z_index = 10
	add_child(f)


func burst(pos: Vector2, color: Color, count: int) -> void:
	var b := Fx.Burst.new()
	b.color = color
	b.style = style
	b.position = pos
	b.z_index = 5
	b.setup(count)
	add_child(b)


# --- Drawing ----------------------------------------------------------------------

func _draw() -> void:
	var drng := RandomNumberGenerator.new()
	drng.seed = _decor_seed
	draw_rect(Rect2(Vector2.ZERO, size), pal.bg)
	match style:
		"pixel":
			_draw_pixel_ground(drng)
		"ascii":
			_draw_ascii_ground(drng)
		_:
			_draw_minimal_ground()
	for r in solids:
		_draw_solid(r)
	if is_hub:
		var outline := Color(pal.bg, 0.8)
		Art.glyph(self, Vector2(size.x * 0.5, 96), "RIFT BLADE", 60, pal.accent, 1.0)
		Art.glyph(self, Vector2(size.x * 0.5, 146), "step into a portal to enter a dimension", 16, Color(pal.text, 0.6), 0.0, outline)


func _draw_pixel_ground(drng: RandomNumberGenerator) -> void:
	var tile := 32.0
	for i in int(size.x / tile):
		for j in int(size.y / tile):
			if (i + j) % 2 == 0:
				draw_rect(Rect2(i * tile, j * tile, tile, tile), pal.bg2)
	var flowers := [Color("ffe14d"), Color("ff6b9a"), Color("ffffff")]
	for i in 160:
		var p := Vector2(drng.randf_range(0, size.x), drng.randf_range(0, size.y)).snapped(Vector2(4, 4))
		if drng.randf() < 0.3:
			var c: Color = flowers[drng.randi() % flowers.size()]
			draw_rect(Rect2(p, Vector2(4, 4)), c)
			draw_rect(Rect2(p + Vector2(0, 4), Vector2(4, 4)), Color("2a5e28"))
		else:
			var dark := Color(pal.bg2).darkened(0.25)
			draw_rect(Rect2(p, Vector2(4, 8)), dark)
			draw_rect(Rect2(p + Vector2(4, 4), Vector2(4, 4)), dark)


func _draw_ascii_ground(drng: RandomNumberGenerator) -> void:
	var f := Art.font()
	var fs := 14
	var cw := f.get_string_size(".", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	var line_h := 22.0
	var cols := int(size.x / cw)
	var noise := [".", ".", ",", "'", "`", ":"]
	for row in int(size.y / line_h):
		var s := ""
		for c in cols:
			s += noise[drng.randi() % noise.size()] if drng.randf() < 0.18 else " "
		draw_string(f, Vector2(0, row * line_h + fs), s, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pal.bg2)


func _draw_minimal_ground() -> void:
	var step := 64.0
	for i in int(size.x / step) + 1:
		draw_line(Vector2(i * step, 0), Vector2(i * step, size.y), pal.bg2, 1.0)
	for j in int(size.y / step) + 1:
		draw_line(Vector2(0, j * step), Vector2(size.x, j * step), pal.bg2, 1.0)
	if is_hub:
		var c := size * 0.5
		for r in [120.0, 220.0, 340.0]:
			draw_arc(c, r, 0.0, TAU, 96, Color(pal.wall2, 0.25), 2.0, true)


func _draw_solid(r: Rect2) -> void:
	match style:
		"pixel":
			draw_rect(r, pal.wall)
			var row := 0
			var y := r.position.y
			while y < r.end.y:
				draw_line(Vector2(r.position.x, y), Vector2(r.end.x, y), pal.wall2, 2.0)
				var x := r.position.x + (16.0 if row % 2 == 1 else 0.0)
				while x < r.end.x:
					draw_line(Vector2(x, y), Vector2(x, minf(y + 16.0, r.end.y)), pal.wall2, 2.0)
					x += 32.0
				y += 16.0
				row += 1
			draw_rect(Rect2(r.position, Vector2(r.size.x, 4)), Color(pal.wall).lightened(0.25))
		"ascii":
			draw_rect(r, pal.bg)
			var f := Art.font()
			var fs := 16
			var cw := f.get_string_size("#", HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			var n := maxi(int(r.size.x / cw), 1)
			var line := "#".repeat(n)
			for i in maxi(int(r.size.y / 16.0), 1):
				draw_string(f, Vector2(r.position.x, r.position.y + 13.0 + i * 16.0), line, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, pal.wall)
		_:
			draw_rect(r, pal.wall)
			draw_rect(r, pal.wall2, false, 2.0)
