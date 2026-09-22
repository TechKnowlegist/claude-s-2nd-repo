class_name Projectile
extends Node2D
## An enemy shot. Hurts the player on touch, dies on walls.

var world: World
var velocity := Vector2.ZERO
var damage := 10.0
var radius := 6.0
var _life := 4.0


func _physics_process(delta: float) -> void:
	position += velocity * delta
	_life -= delta
	if _life <= 0.0 or not world.is_free(position):
		queue_free()
		return
	var p := world.player
	if p != null and not p.dead and position.distance_to(p.position) < radius + Player.RADIUS:
		p.hurt(damage, velocity.normalized())
		queue_free()


func _draw() -> void:
	Art.projectile(self, world.style, world.pal.projectile, radius)
