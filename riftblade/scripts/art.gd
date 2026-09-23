class_name Art
extends RefCounted
## Procedural art. Everything in the game is drawn in code in one of three
## styles, so each dimension looks different without any image files:
##   "pixel"   - chunky 8x8 sprites
##   "ascii"   - glowing text glyphs
##   "minimal" - clean geometric shapes

const PX := 4.0

const SPRITES := {
	"player": [
		"..bbbb..",
		".bbbbbb.",
		".bskskb.",
		"..ssss..",
		".tttttt.",
		"s.tttt.s",
		"..llll..",
		"..l..l..",
	],
	"chaser": [
		"........",
		"...gg...",
		"..gggg..",
		".gwgwgg.",
		".gkgkgg.",
		"gggggggg",
		"gggggggg",
		".g.gg.g.",
	],
	"brute": [
		".rr..rr.",
		".rrrrrr.",
		"rryrryrr",
		"rrrrrrrr",
		".rkkkkr.",
		"rrrrrrrr",
		"rr.rr.rr",
		"rr....rr",
	],
	"shooter": [
		"..pppp..",
		".pwwwwp.",
		"pwwkkwwp",
		"pwwkkwwp",
		".pwwwwp.",
		"..pppp..",
		".p.pp.p.",
		"p..p..p.",
	],
	"boss": [
		"o..oo..o",
		"oooooooo",
		"oyyooyyo",
		"okyookyo",
		"oooooooo",
		"owowowow",
		".oooooo.",
		"oo.oo.oo",
	],
	"chest": [
		"........",
		".nnnnnn.",
		"nnnnnnnn",
		"yyyyyyyy",
		"nnnykynn",
		"nnnyyynn",
		"nnnnnnnn",
		".nnnnnn.",
	],
}

const SPRITE_COLORS := {
	"b": Color("3d6be0"), "s": Color("f2c79b"), "k": Color("16161d"),
	"t": Color("2f9e5b"), "l": Color("6b4426"), "g": Color("58d05a"),
	"w": Color("ffffff"), "r": Color("d8413a"), "y": Color("ffe14d"),
	"p": Color("9b4fd6"), "o": Color("f08a24"), "n": Color("8a5a2b"),
}

const GLYPHS := {"player": "@", "chaser": "x", "brute": "M", "shooter": "&", "boss": "D"}

static var _font: Font


static func font() -> Font:
	if _font == null:
		var f := SystemFont.new()
		f.font_names = PackedStringArray(["DejaVu Sans Mono", "Consolas", "Menlo", "Courier New", "monospace"])
		var fallbacks: Array[Font] = [ThemeDB.fallback_font]
		f.fallbacks = fallbacks
		_font = f
	return _font


static func ngon(radius: float, sides: int, rot: float, center := Vector2.ZERO) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in sides:
		pts.append(center + Vector2.from_angle(rot + TAU * i / sides) * radius)
	return pts


## Draws text centered on `center`, with optional glow and outline.
static func glyph(ci: CanvasItem, center: Vector2, text: String, size: int, color: Color, glow := 0.0, outline := Color(0, 0, 0, 0)) -> void:
	var f := font()
	var w := f.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size).x
	var pos := center + Vector2(-w * 0.5, (f.get_ascent(size) - f.get_descent(size)) * 0.5)
	if glow > 0.0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.55 * glow), Color(color, 0.12 * color.a))
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, int(size * 0.22 * glow), Color(color, 0.3 * color.a))
	if outline.a > 0.0:
		ci.draw_string_outline(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, outline)
	ci.draw_string(f, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


static func sprite(ci: CanvasItem, key: String, center: Vector2, px: float, tint := Color.WHITE, flash := false, flip := false) -> void:
	var rows: Array = SPRITES[key]
	var h := rows.size()
	var w: int = rows[0].length()
	var origin := center - Vector2(w, h) * px * 0.5
	for y in h:
		var row: String = rows[y]
		for x in w:
			var ch := row[x]
			if ch == ".":
				continue
			var c: Color = Color.WHITE if flash else SPRITE_COLORS[ch]
			var dx := (w - 1 - x) if flip else x
			ci.draw_rect(Rect2(origin + Vector2(dx, y) * px, Vector2(px, px)), c * tint)


## Draws the player or an enemy.
static func entity(ci: CanvasItem, kind: String, style: String, pal: Dictionary, radius: float, facing: Vector2, flash: bool, t: float, alpha := 1.0) -> void:
	match style:
		"pixel":
			var px := snappedf(radius * 2.5 / 8.0, 1.0)
			ci.draw_rect(Rect2(Vector2(-radius, radius * 0.85), Vector2(radius * 2.0, px)), Color(0, 0, 0, 0.25 * alpha))
			var bob := Vector2(0, -snappedf(absf(sin(t * 8.0)) * px * 0.6, 1.0))
			sprite(ci, kind, bob, px, Color(1, 1, 1, alpha), flash, facing.x < 0.0)
		"ascii":
			var col: Color = Color.WHITE if flash else pal[kind]
			glyph(ci, Vector2.ZERO, GLYPHS[kind], int(radius * 2.4), Color(col, alpha), 1.0)
		_:
			var col: Color = Color.WHITE if flash else pal[kind]
			col.a *= alpha
			match kind:
				"player":
					_minimal_hero(ci, pal, radius, facing, col, t, alpha)
				"chaser":
					var pts := PackedVector2Array([
						facing * radius * 1.35,
						facing.rotated(2.4) * radius,
						facing.rotated(-2.4) * radius,
					])
					ci.draw_colored_polygon(pts, col)
				"brute":
					ci.draw_colored_polygon(ngon(radius * 1.25, 4, t * 0.8 + PI / 4.0), col)
					ci.draw_colored_polygon(ngon(radius * 0.5, 4, -t * 1.6), pal.bg)
				"shooter":
					var ring := ngon(radius * 1.3, 4, 0.0)
					ring.append(ring[0])
					ci.draw_polyline(ring, col, 3.0, true)
					ci.draw_circle(facing * radius * 0.25, radius * 0.45, col)
				"boss":
					ci.draw_colored_polygon(ngon(radius, 6, t * 0.6), col)
					ci.draw_colored_polygon(ngon(radius * 0.6, 6, -t * 1.2), pal.bg)
					ci.draw_colored_polygon(ngon(radius * 0.3, 3, t * 2.0), col)


## A small humanoid figure for the "minimal" style: legs, a torso, a head
## and a trailing cape, instead of a plain circle.
static func _minimal_hero(ci: CanvasItem, pal: Dictionary, radius: float, facing: Vector2, col: Color, t: float, alpha: float) -> void:
	var stride := sin(t * 9.0) * radius * 0.3
	var skin := Color("f2c79b", alpha)
	var cape := Color(col, alpha * 0.75)
	# Cape, trailing behind the facing direction. Points go around the
	# perimeter in order so the quad stays simple (non-self-intersecting).
	var back := -facing * radius * 1.5
	var side := facing.orthogonal() * radius * 0.55
	var back_side := facing.orthogonal() * radius * 0.35
	ci.draw_colored_polygon(PackedVector2Array([
		side, back + back_side, back - back_side, -side,
	]), cape)
	# Legs.
	var leg_col := Color(col, alpha).darkened(0.35)
	ci.draw_line(Vector2(-radius * 0.28, radius * 0.15), Vector2(-radius * 0.28 + stride * 0.4, radius * 1.05), leg_col, radius * 0.32)
	ci.draw_line(Vector2(radius * 0.28, radius * 0.15), Vector2(radius * 0.28 - stride * 0.4, radius * 1.05), leg_col, radius * 0.32)
	# Torso.
	ci.draw_colored_polygon(ngon(radius * 0.72, 8, PI / 8.0, Vector2(0, radius * 0.05)), col)
	# Head + a hint of a face toward the facing direction.
	ci.draw_circle(Vector2(0, -radius * 0.85), radius * 0.52, skin)
	ci.draw_circle(Vector2(0, -radius * 0.85) + facing * radius * 0.3, radius * 0.12, Color(pal.bg, alpha))


## Draws the sword. `progress` is 0..1 during a swing, or < 0 when idle.
static func sword(ci: CanvasItem, style: String, facing: Vector2, reach: float, arc: float, progress: float, color: Color) -> void:
	var base := facing.angle()
	if progress < 0.0:
		_blade(ci, style, base + 1.1, 10.0, 30.0, color, 1.0)
		return
	var start := base - arc * 0.5
	var cur := start + arc * ease(progress, 0.4)
	var steps := 8
	for i in steps:
		var a := lerpf(start, cur, float(i) / steps)
		_blade(ci, style, a, reach * 0.4, reach, color, 0.08 + 0.3 * float(i) / steps)
	_blade(ci, style, cur, 10.0, reach, color, 1.0)


static func _blade(ci: CanvasItem, style: String, angle: float, r0: float, r1: float, color: Color, alpha: float) -> void:
	var dir := Vector2.from_angle(angle)
	var col := Color(color, color.a * alpha)
	match style:
		"pixel":
			var n := int((r1 - r0) / PX)
			for i in n:
				var p := (dir * (r0 + i * PX)).snapped(Vector2(PX, PX))
				ci.draw_rect(Rect2(p - Vector2(PX, PX) * 0.5, Vector2(PX, PX)), col)
			if alpha >= 1.0:
				var hilt := (dir * r0).snapped(Vector2(PX, PX))
				ci.draw_rect(Rect2(hilt - Vector2(PX, PX), Vector2(PX, PX) * 2.0), Color(SPRITE_COLORS.l, alpha))
		"ascii":
			var a := fposmod(angle, PI)
			var ch := "-"
			if a > PI / 8.0 and a <= 3.0 * PI / 8.0:
				ch = "\\"
			elif a > 3.0 * PI / 8.0 and a <= 5.0 * PI / 8.0:
				ch = "|"
			elif a > 5.0 * PI / 8.0 and a <= 7.0 * PI / 8.0:
				ch = "/"
			var d := r0
			while d <= r1:
				glyph(ci, dir * d, ch, 16, col, 0.6 if alpha >= 1.0 else 0.0)
				d += 11.0
		_:
			ci.draw_line(dir * r0, dir * r1, col, 4.0 if alpha >= 1.0 else 3.0, true)


static func shard(ci: CanvasItem, style: String, color: Color, pos: Vector2, big: bool) -> void:
	match style:
		"pixel":
			var p := PX * (1.5 if big else 1.0)
			ci.draw_rect(Rect2(pos - Vector2(p * 0.5, p * 1.5), Vector2(p, p * 3.0)), color)
			ci.draw_rect(Rect2(pos - Vector2(p * 1.5, p * 0.5), Vector2(p * 3.0, p)), color)
			ci.draw_rect(Rect2(pos - Vector2(p, p) * 0.5, Vector2(p, p)), Color.WHITE)
		"ascii":
			glyph(ci, pos, "$" if big else "*", 22 if big else 16, color, 1.0)
		_:
			var r := 8.0 if big else 5.5
			ci.draw_colored_polygon(ngon(r, 4, 0.0, pos), color)


static func item(ci: CanvasItem, style: String, it: Dictionary, pos: Vector2, t: float) -> void:
	var col := Items.color(it)
	var g := Items.glyph(it)
	if it.rarity >= 3:
		ci.draw_arc(pos, 20.0, t * 3.0, t * 3.0 + PI, 16, Color(col, 0.6), 2.0)
	match style:
		"pixel":
			ci.draw_rect(Rect2(pos - Vector2(12, 12), Vector2(24, 24)), Color(0, 0, 0, 0.55))
			ci.draw_rect(Rect2(pos - Vector2(12, 12), Vector2(24, 24)), col, false, PX)
			glyph(ci, pos, g, 16, col)
		"ascii":
			glyph(ci, pos, g, 28, col, 1.5)
		_:
			ci.draw_circle(pos, 14.0, Color(col, 0.25))
			ci.draw_arc(pos, 14.0, 0.0, TAU, 24, col, 2.5, true)
			glyph(ci, pos, g, 16, col)


static func chest(ci: CanvasItem, style: String, pal: Dictionary, pos: Vector2) -> void:
	match style:
		"pixel":
			sprite(ci, "chest", pos, PX)
		"ascii":
			glyph(ci, pos, "[$]", 22, pal.accent, 1.2)
		_:
			ci.draw_rect(Rect2(pos - Vector2(17, 12), Vector2(34, 24)), pal.accent)
			ci.draw_line(pos + Vector2(-17, -3), pos + Vector2(17, -3), pal.bg, 2.0)
			ci.draw_rect(Rect2(pos - Vector2(4, 6), Vector2(8, 8)), pal.bg)


## A puzzle pressure pad. `state` is "idle" (not pressed yet, shows its
## required order number), "done" (pressed correctly, stays lit) or
## "wrong" (briefly flashes red after a wrong-order press).
static func pad(ci: CanvasItem, style: String, pal: Dictionary, number: int, state: String, radius: float) -> void:
	var col: Color = pal.text
	match state:
		"done":
			col = pal.shard
		"wrong":
			col = Color("ff4444")
	match style:
		"pixel":
			var px := PX * 1.5
			var n := int(radius * 2.0 / px)
			for x in n:
				for y in n:
					if Vector2(x - n * 0.5, y - n * 0.5).length() < n * 0.5:
						ci.draw_rect(Rect2(Vector2(x, y) * px - Vector2(radius, radius), Vector2(px, px)), col)
			glyph(ci, Vector2.ZERO, str(number), 18, Color.BLACK if state == "done" else Color.WHITE)
		"ascii":
			var bracket := "[%d]" if state != "wrong" else "!%d!"
			glyph(ci, Vector2.ZERO, bracket % number, 20, col, 1.0 if state != "idle" else 0.3)
		_:
			ci.draw_circle(Vector2.ZERO, radius, Color(col, 0.28 if state == "idle" else 0.6))
			ci.draw_arc(Vector2.ZERO, radius, 0.0, TAU, 28, col, 3.0, true)
			glyph(ci, Vector2.ZERO, str(number), 20, col)


static func projectile(ci: CanvasItem, style: String, color: Color, radius: float) -> void:
	match style:
		"pixel":
			ci.draw_rect(Rect2(Vector2(-PX * 1.5, -PX * 1.5), Vector2(PX * 3.0, PX * 3.0)), color)
			ci.draw_rect(Rect2(Vector2(-PX * 0.5, -PX * 0.5), Vector2(PX, PX)), Color.WHITE)
		"ascii":
			glyph(ci, Vector2.ZERO, "o", 18, color, 1.2)
		_:
			ci.draw_circle(Vector2.ZERO, radius, color)
			ci.draw_arc(Vector2.ZERO, radius + 3.0, 0.0, TAU, 16, Color(color, 0.4), 1.5, true)
