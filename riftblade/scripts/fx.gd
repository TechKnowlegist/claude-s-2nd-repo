class_name Fx
extends RefCounted
## Short-lived visual effects.


## Floating combat text (damage numbers, pickups).
class FloatText extends Node2D:
	var text := ""
	var color := Color.WHITE
	var font_size := 16
	var outline := Color(0, 0, 0, 0.6)
	var life := 0.9
	var _t := 0.0

	func _process(delta: float) -> void:
		_t += delta
		position.y -= 38.0 * delta
		if _t >= life:
			queue_free()
		queue_redraw()

	func _draw() -> void:
		var a := clampf(1.0 - _t / life, 0.0, 1.0)
		Art.glyph(self, Vector2.ZERO, text, font_size, Color(color, a), 0.0, Color(outline, outline.a * a))


## A burst of particles in the current dimension's style.
class Burst extends Node2D:
	const LIFE := 0.45
	var color := Color.WHITE
	var style := "minimal"
	var _parts: Array = []
	var _t := 0.0

	func setup(count: int) -> void:
		for i in count:
			_parts.append([Vector2.ZERO, Vector2.from_angle(randf() * TAU) * randf_range(80.0, 280.0)])

	func _process(delta: float) -> void:
		_t += delta
		if _t > LIFE:
			queue_free()
			return
		for p in _parts:
			p[0] += p[1] * delta
			p[1] *= 0.9
		queue_redraw()

	func _draw() -> void:
		var a := 1.0 - _t / LIFE
		var c := Color(color, a)
		for p in _parts:
			var pos: Vector2 = p[0]
			match style:
				"pixel":
					draw_rect(Rect2(pos.snapped(Vector2(4, 4)), Vector2(4, 4)), c)
				"ascii":
					Art.glyph(self, pos, "*", 12, c)
				_:
					draw_circle(pos, 1.0 + 3.0 * a, c)


## A telegraph that shows where an enemy is about to appear.
class SpawnMarker extends Node2D:
	var world
	var kind := ""
	var delay := 1.0
	var color := Color.WHITE
	var _t := 0.0

	func _physics_process(delta: float) -> void:
		_t += delta
		if _t >= delay:
			world.marker_done(kind, position)
			queue_free()
			return
		queue_redraw()

	func _draw() -> void:
		var k := _t / delay
		if world.style == "ascii":
			Art.glyph(self, Vector2.ZERO, "!", 22, Color(color, 0.3 + 0.7 * k), 1.0)
		else:
			var r := 34.0 * (1.0 - k) + 8.0
			draw_arc(Vector2.ZERO, r, 0.0, TAU, 24, Color(color, 0.3 + 0.7 * k), 3.0, true)
