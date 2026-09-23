class_name Puzzle
extends Node2D
## A puzzle room: a scatter of numbered pads. Step on them in ascending
## order to open the door forward; stepping on the wrong one resets your
## progress. No combat here - just a breather with its own music.

signal solved

var world: World
var pad_count := 4
var progress := 0
var pads: Array = []  # [{"pos": Vector2, "number": int, "state": String}]

var _touching := {}
var _wrong_flash := 0.0
var _t := 0.0


func setup(count: int, room: Rect2, rng: RandomNumberGenerator) -> void:
	pad_count = count
	var margin := 90.0
	var spots: Array[Vector2] = []
	var tries := 0
	while spots.size() < count and tries < 400:
		tries += 1
		var p := Vector2(
			rng.randf_range(room.position.x + margin, room.end.x - margin),
			rng.randf_range(room.position.y + margin, room.end.y - margin)
		)
		var ok := true
		for s in spots:
			if s.distance_to(p) < 110.0:
				ok = false
				break
		if ok:
			spots.append(p)
	var numbers: Array[int] = []
	for i in count:
		numbers.append(i + 1)
	numbers.shuffle()
	for i in spots.size():
		pads.append({"pos": spots[i], "number": numbers[i], "state": "idle"})


func _physics_process(delta: float) -> void:
	_t += delta
	_wrong_flash = maxf(_wrong_flash - delta, 0.0)
	queue_redraw()
	var p := world.player
	if p == null or p.dead:
		return
	for pad in pads:
		var near: bool = p.position.distance_to(pad.pos) < 30.0
		var was: bool = _touching.get(pad.number, false)
		_touching[pad.number] = near
		if near and not was and pad.state != "done":
			_press(pad)


func _press(pad: Dictionary) -> void:
	if pad.number == progress + 1:
		pad.state = "done"
		progress += 1
		Audio.play("puzzle_step", -6.0)
		world.burst(pad.pos, world.pal.shard, 8)
		if progress >= pad_count:
			Audio.play("puzzle_solved", -4.0)
			solved.emit()
	else:
		Audio.play("puzzle_wrong", -6.0)
		_wrong_flash = 0.35
		world.shake(3.0)
		for other in pads:
			other.state = "idle"
		progress = 0


func _draw() -> void:
	if pads.size() >= 2:
		var pts := PackedVector2Array()
		for pad in pads:
			pts.append(pad.pos)
		pts.append(pts[0])
		draw_polyline(pts, Color(world.pal.text, 0.08), 2.0)
	for pad in pads:
		var state: String = pad.state
		if state == "idle" and _wrong_flash > 0.0 and int(_t * 12.0) % 2 == 0:
			state = "wrong"
		draw_set_transform(pad.pos)
		Art.pad(self, world.style, world.pal, pad.number, state, 26.0)
	draw_set_transform(Vector2.ZERO)
