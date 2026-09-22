class_name Forge
extends Node2D
## The anvil in the Nexus. Stand near it and press interact to upgrade.

const USE_RANGE := 90.0

var world: World
var _t := 0.0


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()


func is_near() -> bool:
	return world.player.position.distance_to(position) < USE_RANGE


func _draw() -> void:
	var hot: Color = world.pal.accent
	draw_circle(Vector2(0, -6), 52.0 + 4.0 * sin(_t * 3.0), Color(hot, 0.08))
	var anvil := PackedVector2Array([
		Vector2(-42, -12), Vector2(42, -12), Vector2(32, 0), Vector2(15, 4),
		Vector2(15, 18), Vector2(28, 28), Vector2(-28, 28), Vector2(-15, 18),
		Vector2(-15, 4), Vector2(-36, 0),
	])
	draw_colored_polygon(anvil, world.pal.wall2)
	anvil.append(anvil[0])
	draw_polyline(anvil, world.pal.text, 2.0, true)
	for i in 5:
		var k := fposmod(_t * 0.9 + i * 0.2, 1.0)
		var p := Vector2(sin(i * 7.3) * 26.0, -16.0 - k * 50.0)
		draw_rect(Rect2(p, Vector2(3, 3)), Color(hot, 1.0 - k))
	var outline := Color(world.pal.bg, 0.8)
	Art.glyph(self, Vector2(0, 52), "THE FORGE", 18, world.pal.text, 0.0, outline)
	if is_near():
		Art.glyph(self, Vector2(0, -64), "[E] Upgrade your sword", 16, hot, 0.5, outline)
