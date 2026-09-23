class_name Pickup
extends Node2D
## Something on the ground: a shard (currency), an item, or a Rift Chest.

var world: World
var kind := "shard"  # "shard", "item" or "chest"
var value := 1
var item := {}
var velocity := Vector2.ZERO
var _t := 0.0
var _full_warned := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	_full_warned -= delta
	var next := position + velocity * delta
	if world.is_free(next, 6.0):
		position = next
	else:
		velocity = Vector2.ZERO
	velocity = velocity.move_toward(Vector2.ZERO, 700.0 * delta)
	queue_redraw()
	var p := world.player
	if p == null or p.dead or _t < 0.35:
		return
	var d := position.distance_to(p.position)
	match kind:
		"shard":
			if d < 140.0:
				position = position.move_toward(p.position, 560.0 * delta)
			if d < 20.0:
				world.collect_shards(value)
				Audio.play("shard", -6.0)
				queue_free()
		"item":
			if d < 26.0:
				if Items.is_gear(item):
					GameState.add_gear(item)
					world.float_text(position + Vector2(0, -20), Items.label(item) + " (inventory)", Items.color(item), 18)
					Audio.play("equip", -4.0)
					queue_free()
				elif GameState.add_item(item):
					world.float_text(position + Vector2(0, -20), Items.label(item), Items.color(item), 18)
					Audio.play("pickup", -4.0)
					queue_free()
				elif _full_warned <= 0.0:
					world.float_text(position + Vector2(0, -20), "Item slots full! Use one (1-3)", world.pal.text)
					_full_warned = 2.5
		"chest":
			if d < 34.0:
				world.open_chest(self)


func _draw() -> void:
	var bob := Vector2(0, sin(_t * 4.0) * 3.0)
	match kind:
		"shard":
			Art.shard(self, world.style, world.pal.shard, bob, value > 1)
		"item":
			Art.item(self, world.style, item, bob, _t)
		"chest":
			Art.chest(self, world.style, world.pal, bob * 0.5)
