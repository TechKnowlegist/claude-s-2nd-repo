class_name Portal
extends Node2D
## A swirling gate. In the Nexus it leads to a dimension (drawn in that
## dimension's style); in a cleared dimension it leads home. The "online"
## portal is a placeholder for the upcoming PvP arena.

const RADIUS := 46.0
const ONLINE := "online"

var world: World
var target := ""
var locked := false
var _armed := false
var _t := 0.0


func _ready() -> void:
	if target == ONLINE:
		locked = true
	elif target != Dimensions.HUB:
		locked = not GameState.is_unlocked(target)


func _physics_process(delta: float) -> void:
	_t += delta
	queue_redraw()
	var p := world.player
	if p == null or p.dead:
		return
	var d := position.distance_to(p.position)
	if d > RADIUS * 2.0:
		_armed = true
	if _armed and not locked and d < RADIUS * 0.7:
		_armed = false
		world.enter_portal(target)


func _draw() -> void:
	var alpha := 0.35 if locked else 1.0
	var info: Dictionary = Dimensions.DATA.get(target, Dimensions.DATA[Dimensions.HUB])
	var tp: Dictionary = info.palette
	match target:
		"pixel":
			draw_circle(Vector2.ZERO, RADIUS, Color(0.08, 0.16, 0.08, alpha))
			for i in 16:
				var p := (Vector2.from_angle(_t * 1.5 + TAU * i / 16.0) * RADIUS).snapped(Vector2(4, 4))
				var c: Color = tp.accent if i % 2 == 0 else tp.chaser
				draw_rect(Rect2(p - Vector2(5, 5), Vector2(10, 10)), Color(c, alpha))
			for i in 6:
				var p := (Vector2.from_angle(-_t * 2.0 + TAU * i / 6.0) * RADIUS * 0.45 * (1.0 + 0.3 * sin(_t * 3.0 + i))).snapped(Vector2(4, 4))
				draw_rect(Rect2(p, Vector2(4, 4)), Color(1, 1, 1, alpha))
		"ascii":
			draw_circle(Vector2.ZERO, RADIUS, Color(0, 0, 0, alpha))
			var chars := "#@%*+=-:."
			for i in 18:
				var p := Vector2.from_angle(-_t + TAU * i / 18.0) * RADIUS
				var ch := chars[(i + int(_t * 8.0)) % chars.length()]
				Art.glyph(self, p, ch, 16, Color(tp.accent, alpha), 0.8)
			Art.glyph(self, Vector2.ZERO, ">", 28 + int(4.0 * sin(_t * 4.0)), Color(tp.player, alpha), 1.2)
		"geometry":
			draw_circle(Vector2.ZERO, RADIUS, Color(tp.bg, alpha))
			var cols := [tp.chaser, tp.brute, tp.shooter]
			for i in 3:
				var ring := Art.ngon(RADIUS * (0.9 - i * 0.25), 3 + i, _t * (0.8 + i * 0.5) * (1 if i % 2 == 0 else -1))
				ring.append(ring[0])
				draw_polyline(ring, Color(cols[i], alpha), 3.0, true)
		ONLINE:
			for i in 12:
				var a := _t * 0.3 + TAU * i / 12.0
				draw_arc(Vector2.ZERO, RADIUS, a, a + TAU / 24.0, 6, Color(0.6, 0.6, 0.7, 0.6), 3.0, true)
			Art.glyph(self, Vector2.ZERO, "VS", 22, Color(0.7, 0.7, 0.8, 0.7))
		_:
			draw_circle(Vector2.ZERO, RADIUS, Color(world.pal.bg, 0.8))
			for i in 4:
				var r := fposmod(_t * 30.0 + i * 12.0, RADIUS)
				draw_arc(Vector2.ZERO, r, 0.0, TAU, 32, Color(world.pal.accent, 1.0 - r / RADIUS), 3.0, true)

	var title := "Online Arena" if target == ONLINE else str(info.name)
	var sub := ""
	if target == ONLINE:
		sub = "PvP - coming soon"
	elif target == Dimensions.HUB:
		title = "Return to the Nexus"
	elif locked:
		sub = "LOCKED - clear %s" % Dimensions.DATA[info.requires].name
	elif GameState.cleared.has(target):
		sub = "cleared - replay for shards"
	else:
		sub = str(info.tagline)
	var text_col: Color = world.pal.text
	Art.glyph(self, Vector2(0, RADIUS + 22), title, 18, text_col, 0.0, Color(world.pal.bg, 0.8))
	if sub != "":
		Art.glyph(self, Vector2(0, RADIUS + 42), sub, 13, Color(text_col, 0.7), 0.0, Color(world.pal.bg, 0.8))
