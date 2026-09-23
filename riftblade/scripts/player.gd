class_name Player
extends CharacterBody2D
## The hero: moves, dashes, swings the sword and uses items.

signal died

const RADIUS := 14.0
const BASE_SPEED := 250.0
const SWING_TIME := 0.16
const SWING_ARC := 2.27  # ~130 degrees
const DASH_TIME := 0.16
const DASH_SPEED := 900.0
const DASH_COOLDOWN := 0.7
const BUFF_NAMES := {"boost": "SPEED BOOST", "supercharge": "SUPERCHARGE", "shield": "RIFT SHIELD"}

var world: World
var max_hp := 100.0
var hp := 100.0
var facing := Vector2.RIGHT
var dead := false
## Active buffs: name -> {"time": seconds left, "power": rarity power}.
var buffs := {}

var _attack_cd := 0.0
var _swing := 0.0
var _swing_dir := Vector2.RIGHT
var _swing_arc := SWING_ARC
var _swing_reach := 60.0
var _dash_cd := 0.0
var _dash_time := 0.0
var _dash_dir := Vector2.RIGHT
var _invuln := 0.0
var _flash := 0.0
var _using_mouse := false
var _t := 0.0


func _ready() -> void:
	motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
	collision_layer = 1
	collision_mask = 4
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = RADIUS
	shape.shape = circle
	add_child(shape)
	max_hp = GameState.max_health()
	hp = max_hp


func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		_using_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_using_mouse = false
	elif event is InputEventJoypadMotion and absf((event as InputEventJoypadMotion).axis_value) > 0.5:
		_using_mouse = false


func _physics_process(delta: float) -> void:
	_t += delta
	_attack_cd -= delta
	_swing = maxf(_swing - delta, 0.0)
	_dash_cd -= delta
	_invuln -= delta
	_flash -= delta
	for b in buffs.keys():
		buffs[b].time -= delta
		if buffs[b].time <= 0.0:
			buffs.erase(b)
	queue_redraw()
	if dead or world.hud.is_blocking():
		return

	var input := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if _using_mouse:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 4.0:
			facing = to_mouse.normalized()
	elif input != Vector2.ZERO:
		facing = input.normalized()

	if Input.is_action_just_pressed("dash") and _dash_cd <= 0.0:
		_dash_dir = input.normalized() if input != Vector2.ZERO else facing
		_dash_time = DASH_TIME
		_dash_cd = DASH_COOLDOWN
		_invuln = maxf(_invuln, DASH_TIME + 0.05)

	if _dash_time > 0.0:
		_dash_time -= delta
		velocity = _dash_dir * DASH_SPEED
	elif world.is_hub:
		# The Nexus is weightless: you drift toward your input instead of
		# snapping to it, and keep gliding a little once you let go.
		var target := input * speed() * 0.85
		velocity = velocity.lerp(target, clampf(delta * 2.6, 0.0, 1.0))
	else:
		velocity = input * speed()
	move_and_slide()

	if Input.is_action_pressed("attack") and _attack_cd <= 0.0:
		attack()
	for i in GameState.MAX_ITEMS:
		if Input.is_action_just_pressed("item_%d" % (i + 1)):
			use_item(i)
	if Input.is_action_just_pressed("interact"):
		world.interact()
	if Input.is_action_just_pressed("inventory"):
		world.hud.toggle_inventory()


func speed() -> float:
	return BASE_SPEED * (1.5 if buffs.has("boost") else 1.0)


func has_buff(buff: String) -> bool:
	return buffs.has(buff)


func attack() -> void:
	_attack_cd = GameState.sword_cooldown()
	_swing = SWING_TIME
	_swing_dir = facing
	_swing_reach = GameState.sword_reach()
	_swing_arc = SWING_ARC
	var dmg := GameState.sword_damage()
	if has_buff("supercharge"):
		_swing_arc = TAU
		_swing_reach *= 1.35
		dmg *= 1.0 + 0.6 * buffs.supercharge.power
	Audio.play("swing", -6.0)
	for e in world.enemies.duplicate():
		if not is_instance_valid(e) or e.dead:
			continue
		var to: Vector2 = e.position - position
		if to.length() - e.radius > _swing_reach:
			continue
		if _swing_arc < TAU and to.length() > e.radius + RADIUS and absf(_swing_dir.angle_to(to)) > _swing_arc * 0.5:
			continue
		var crit := randf() < GameState.sword_crit()
		e.take_damage(dmg * (2.0 if crit else 1.0), crit, to.normalized())


func hurt(amount: float, _from_dir: Vector2) -> void:
	if dead or _invuln > 0.0 or has_buff("shield"):
		return
	amount *= 1.0 - GameState.damage_reduction()
	hp -= amount
	_invuln = 0.5
	_flash = 0.12
	world.shake(7.0)
	world.float_text(position + Vector2(0, -24), "-%d" % int(amount), Color("ff4d4d"))
	if hp <= 0.0:
		hp = 0.0
		dead = true
		world.burst(position, world.pal.player, 20)
		Audio.play("death_player", -3.0)
		died.emit()
	else:
		Audio.play("player_hit", -8.0)


func heal(amount: float) -> void:
	hp = minf(hp + amount, max_hp)
	world.float_text(position + Vector2(0, -24), "+%d" % int(amount), Color("5dff8a"))


func use_item(slot: int) -> void:
	if slot >= GameState.items.size():
		return
	if world.is_hub:
		world.float_text(position + Vector2(0, -30), "Save it for a dimension!", world.pal.text)
		return
	var item := GameState.take_item(slot)
	var power := Items.power(item)
	match item.type:
		"potion":
			heal(15.0 + 20.0 * power)
		"boost":
			buffs["boost"] = {"time": 4.0 * power, "power": power}
		"supercharge":
			buffs["supercharge"] = {"time": 4.0 * power, "power": power}
		"shield":
			buffs["shield"] = {"time": 2.0 * power, "power": power}
	Audio.play("equip" if Items.is_gear(item) else "pickup", -4.0)
	world.float_text(position + Vector2(0, -40), Items.label(item), Items.color(item))
	world.burst(position, Items.color(item), 12)
	GameState.save_game()


func _draw() -> void:
	var alpha := 1.0
	if _invuln > 0.0 and _dash_time <= 0.0 and int(_t * 20.0) % 2 == 0:
		alpha = 0.35
	if world.is_hub:
		draw_set_transform(Vector2(0, sin(_t * 1.6) * 4.0))
	if has_buff("shield"):
		draw_arc(Vector2.ZERO, RADIUS + 9.0, 0.0, TAU, 32, Color(world.pal.shard, 0.8), 3.0, true)
	if has_buff("supercharge"):
		draw_arc(Vector2.ZERO, RADIUS + 14.0, _t * 6.0, _t * 6.0 + PI * 1.2, 24, Color(world.pal.accent, 0.7), 2.0, true)
	var armor: Dictionary = GameState.equipped_armor_item()
	if not armor.is_empty():
		draw_arc(Vector2.ZERO, RADIUS + 5.0, 0.0, TAU, 20, Color(Items.color(armor), 0.9), 2.0, true)
	if _dash_time > 0.0:
		for i in range(1, 4):
			draw_set_transform(-_dash_dir * i * 14.0)
			Art.entity(self, "player", world.style, world.pal, RADIUS, facing, false, _t, 0.25 / i)
		draw_set_transform(Vector2.ZERO)
	Art.entity(self, "player", world.style, world.pal, RADIUS, facing, _flash > 0.0, _t, alpha)
	var blade: Color = world.pal.accent if has_buff("supercharge") else world.pal.blade
	var sword: Dictionary = GameState.equipped_sword_item()
	if not sword.is_empty():
		blade = blade.lerp(Items.color(sword), 0.55)
	if _swing > 0.0:
		Art.sword(self, world.style, _swing_dir, _swing_reach, _swing_arc, 1.0 - _swing / SWING_TIME, blade)
	else:
		Art.sword(self, world.style, facing, 0.0, 0.0, -1.0, blade)
