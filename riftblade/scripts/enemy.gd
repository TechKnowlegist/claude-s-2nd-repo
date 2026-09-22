class_name Enemy
extends CharacterBody2D
## Every enemy type, including the boss that ends each dimension.
##   chaser  - fast and fragile, swarms you
##   brute   - slow and tanky, telegraphs then charges
##   shooter - keeps its distance and fires projectiles
##   boss    - radial bursts, summons minions, enrages at half health

signal died(enemy: Enemy)

const STATS := {
	"chaser": {"hp": 22.0, "speed": 150.0, "damage": 8.0, "radius": 13.0, "shards": 1},
	"brute": {"hp": 70.0, "speed": 75.0, "damage": 18.0, "radius": 19.0, "shards": 3},
	"shooter": {"hp": 30.0, "speed": 95.0, "damage": 10.0, "radius": 14.0, "shards": 2},
	"boss": {"hp": 650.0, "speed": 85.0, "damage": 22.0, "radius": 36.0, "shards": 40},
}

var world: World
var kind := "chaser"
var hp_mult := 1.0
var dmg_mult := 1.0
var spd_mult := 1.0
var shard_mult := 1

var max_hp := 1.0
var hp := 1.0
var speed := 100.0
var damage := 10.0
var radius := 14.0
var shard_value := 1
var facing := Vector2.LEFT
var dead := false

var _knock := Vector2.ZERO
var _flash := 0.0
var _contact_cd := 0.0
var _action_cd := 0.0
var _windup := 0.0
var _charge_time := 0.0
var _charge_dir := Vector2.ZERO
var _summon_cd := 8.0
var _stuck := 0.0
var _detour := Vector2.ZERO
var _detour_time := 0.0
var _t := 0.0


func _ready() -> void:
	var s: Dictionary = STATS[kind]
	max_hp = s.hp * hp_mult
	hp = max_hp
	speed = s.speed * spd_mult
	damage = s.damage * dmg_mult
	radius = s.radius
	shard_value = s.shards * shard_mult
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 2
	collision_mask = 2 | 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = radius
	shape.shape = circle
	add_child(shape)
	_action_cd = randf_range(1.0, 2.5)
	_t = randf() * 10.0


func color() -> Color:
	return world.pal[kind]


func _physics_process(delta: float) -> void:
	_t += delta
	_flash -= delta
	_contact_cd -= delta
	_action_cd -= delta
	queue_redraw()
	var p := world.player
	if p == null or p.dead:
		velocity = _knock
		move_and_slide()
		_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)
		return

	var to := p.position - position
	var dist := to.length()
	var dir := to / maxf(dist, 0.001)
	facing = dir
	var move := Vector2.ZERO
	match kind:
		"chaser":
			move = (dir + dir.orthogonal() * sin(_t * 5.0) * 0.35).normalized() * speed
		"brute":
			move = _brute(delta, dir, dist)
		"shooter":
			move = _shooter(dir, dist)
		"boss":
			move = _boss(delta, dir)

	# If a pillar is in the way, sidestep around it for a moment.
	if _detour_time > 0.0:
		_detour_time -= delta
		move = _detour * speed
	elif move.length() > 1.0 and get_real_velocity().length() < speed * 0.25 and _charge_time <= 0.0:
		_stuck += delta
		if _stuck > 0.4:
			_stuck = 0.0
			_detour = move.normalized().orthogonal() * (1.0 if randf() < 0.5 else -1.0)
			_detour_time = 0.6
	else:
		_stuck = 0.0

	velocity = move + _knock
	move_and_slide()
	_knock = _knock.move_toward(Vector2.ZERO, 900.0 * delta)

	if dist < radius + Player.RADIUS + 2.0 and _contact_cd <= 0.0:
		p.hurt(damage, dir)
		_contact_cd = 0.8


func _brute(delta: float, dir: Vector2, dist: float) -> Vector2:
	if _charge_time > 0.0:
		_charge_time -= delta
		return _charge_dir * speed * 5.5
	if _windup > 0.0:
		_windup -= delta
		_charge_dir = dir
		if _windup <= 0.0:
			_charge_time = 0.45
		return Vector2.ZERO
	if _action_cd <= 0.0 and dist < 380.0:
		_windup = 0.6
		_action_cd = 3.0
	return dir * speed


func _shooter(dir: Vector2, dist: float) -> Vector2:
	if _action_cd <= 0.0 and dist < 560.0:
		_action_cd = 1.9
		world.spawn_projectile(position + dir * radius, dir * 300.0, damage)
	if dist > 320.0:
		return dir * speed
	if dist < 200.0:
		return -dir * speed
	return dir.orthogonal() * speed * 0.6 * (1.0 if int(_t / 3.0) % 2 == 0 else -1.0)


func _boss(delta: float, dir: Vector2) -> Vector2:
	var enraged := hp < max_hp * 0.5
	_summon_cd -= delta
	if _summon_cd <= 0.0:
		_summon_cd = 7.0 if enraged else 10.0
		for i in 2 + world.tier:
			var spot := position + Vector2.from_angle(randf() * TAU) * 110.0
			if not world.is_free(spot, 20.0):
				spot = world.random_spawn_point(200.0)
			world.spawn_marker("chaser", spot, 0.8)
	if _windup > 0.0:
		_windup -= delta
		if _windup <= 0.0:
			_boss_burst(enraged, dir)
		return Vector2.ZERO
	if _action_cd <= 0.0:
		_windup = 0.55
		_action_cd = 2.4 if enraged else 3.4
	return dir * speed * (1.35 if enraged else 1.0)


func _boss_burst(enraged: bool, dir: Vector2) -> void:
	var n := 14 if enraged else 10
	var offset := randf() * TAU
	var shot_speed := 220.0 + 30.0 * world.tier
	for i in n:
		var d := Vector2.from_angle(offset + TAU * i / n)
		world.spawn_projectile(position + d * radius, d * shot_speed, damage * 0.6)
	if enraged:
		for a in [-0.2, 0.0, 0.2]:
			var d := dir.rotated(a)
			world.spawn_projectile(position + d * radius, d * shot_speed * 1.4, damage * 0.6)
	world.shake(4.0)


func take_damage(amount: float, crit: bool, dir: Vector2) -> void:
	if dead:
		return
	hp -= amount
	_flash = 0.1
	var knock_power := 320.0
	if kind == "brute":
		knock_power = 140.0
	elif kind == "boss":
		knock_power = 40.0
	_knock = dir * knock_power
	var txt := "%d" % int(amount)
	if crit:
		txt += "!"
	world.float_text(position + Vector2(0, -radius - 10.0), txt, world.pal.accent if crit else world.pal.text, 22 if crit else 16)
	world.shake(3.0 if crit else 1.5)
	if hp <= 0.0:
		die()


func die() -> void:
	if dead:
		return
	dead = true
	died.emit(self)
	queue_free()


func _draw() -> void:
	var col := color()
	if _windup > 0.0:
		var k := 1.0 - _windup / 0.6
		if kind == "brute":
			draw_line(Vector2.ZERO, _charge_dir * 140.0, Color(world.pal.accent, 0.3 + 0.5 * k), 4.0)
		draw_arc(Vector2.ZERO, radius + 10.0 - 6.0 * k, 0.0, TAU, 32, Color(world.pal.accent, 0.4 + 0.5 * k), 3.0, true)
	var offset := Vector2.ZERO
	if _windup > 0.0:
		offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
	draw_set_transform(offset)
	Art.entity(self, kind, world.style, world.pal, radius, facing, _flash > 0.0, _t)
	draw_set_transform(Vector2.ZERO)
	if hp < max_hp and kind != "boss":
		var r := Rect2(Vector2(-radius, -radius - 12.0), Vector2(radius * 2.0, 4.0))
		draw_rect(r, Color(0, 0, 0, 0.5))
		draw_rect(Rect2(r.position, Vector2(r.size.x * hp / max_hp, r.size.y)), col)
