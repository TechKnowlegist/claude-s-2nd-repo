class_name HUD
extends CanvasLayer
## Screen-space UI: health, shards, sword stats, buffs, item slots, banners,
## the Forge upgrade menu and the pause menu.

var world: World
var overlay: Control
var font: Font

var _banner_title := ""
var _banner_sub := ""
var _banner_time := 0.0
var _banner_len := 1.0
var _forge_root: CenterContainer
var _forge_info: Label
var _forge_buttons := {}
var _forge_close: Button
var _pause_root: CenterContainer
var _pause_resume: Button
var _pause_retreat: Button
var _fade: ColorRect


func _ready() -> void:
	layer = 10
	process_mode = Node.PROCESS_MODE_ALWAYS
	font = Art.font()
	overlay = Control.new()
	overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay)
	overlay.draw.connect(_draw_overlay)
	_build_forge()
	_build_pause()
	_fade = ColorRect.new()
	_fade.color = Color.BLACK
	_fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fade.modulate.a = 0.0
	add_child(_fade)


func _process(delta: float) -> void:
	_banner_time = maxf(_banner_time - delta, 0.0)
	if Input.is_action_just_pressed("pause"):
		if _forge_root.visible:
			close_forge()
		else:
			toggle_pause()
	overlay.queue_redraw()


func is_blocking() -> bool:
	return _forge_root.visible or get_tree().paused


func banner(title: String, sub := "", duration := 3.5) -> void:
	_banner_title = title
	_banner_sub = sub
	_banner_time = duration
	_banner_len = duration


func fade_to(alpha: float) -> Signal:
	var tw := create_tween()
	tw.tween_property(_fade, "modulate:a", alpha, 0.3)
	return tw.finished


# --- Menus ------------------------------------------------------------------------

func _make_panel(title: String) -> CenterContainer:
	var root := CenterContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.visible = false
	add_child(root)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.06, 0.12, 0.95)
	sb.border_color = Color("ff4fd8")
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(8)
	sb.set_content_margin_all(24)
	panel.add_theme_stylebox_override("panel", sb)
	root.add_child(panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	var label := Label.new()
	label.text = title
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", 30)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(label)
	return root


func _panel_box(root: CenterContainer) -> VBoxContainer:
	return root.get_child(0).get_child(0)


func _button(box: VBoxContainer, text: String, callback: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(560, 42)
	b.add_theme_font_override("font", font)
	b.add_theme_font_size_override("font_size", 17)
	b.pressed.connect(callback)
	box.add_child(b)
	return b


func _build_forge() -> void:
	_forge_root = _make_panel("THE FORGE")
	var box := _panel_box(_forge_root)
	_forge_info = Label.new()
	_forge_info.add_theme_font_override("font", font)
	_forge_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(_forge_info)
	for stat in GameState.UPGRADE_ORDER:
		_forge_buttons[stat] = _button(box, "", _on_upgrade.bind(stat))
	_forge_close = _button(box, "Close  [Esc]", close_forge)


func open_forge() -> void:
	_refresh_forge()
	_forge_root.visible = true
	for stat in GameState.UPGRADE_ORDER:
		var b: Button = _forge_buttons[stat]
		if not b.disabled:
			b.grab_focus()
			return
	_forge_close.grab_focus()


func close_forge() -> void:
	_forge_root.visible = false


func _refresh_forge() -> void:
	_forge_info.text = "%s   |   DMG %d   REACH %d   CRIT %d%%   |   Shards: %d" % [
		GameState.sword_name(), int(GameState.sword_damage()), int(GameState.sword_reach()),
		int(round(GameState.sword_crit() * 100.0)), GameState.shards,
	]
	for stat in GameState.UPGRADE_ORDER:
		var u: Dictionary = GameState.UPGRADES[stat]
		var lvl := GameState.level(stat)
		var b: Button = _forge_buttons[stat]
		if lvl >= GameState.MAX_LEVEL:
			b.text = "%s  -  MAXED" % u.name
			b.disabled = true
		else:
			var cost := GameState.upgrade_cost(stat)
			b.text = "%s (%s)   Lv %d -> %d   |   %d shards" % [u.name, u.desc, lvl, lvl + 1, cost]
			b.disabled = GameState.shards < cost


func _on_upgrade(stat: String) -> void:
	if GameState.buy_upgrade(stat):
		banner("Sword upgraded!", "%s is now level %d" % [GameState.UPGRADES[stat].name, GameState.level(stat)], 1.5)
		if world != null and world.player != null:
			world.player.max_hp = GameState.max_health()
			world.player.hp = world.player.max_hp
			world.burst(world.forge.position, world.pal.accent, 18)
	_refresh_forge()
	var b: Button = _forge_buttons[stat]
	if b.disabled:
		_forge_close.grab_focus()


func _build_pause() -> void:
	_pause_root = _make_panel("PAUSED")
	var box := _panel_box(_pause_root)
	_pause_resume = _button(box, "Resume", toggle_pause)
	_pause_retreat = _button(box, "Retreat to the Nexus (lose half this run's shards)", _on_retreat)
	_button(box, "Quit Game", func() -> void: get_tree().quit())
	var help := Label.new()
	help.add_theme_font_override("font", font)
	help.add_theme_font_size_override("font_size", 14)
	help.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help.text = "Move: WASD / arrows / stick     Attack: Space / J / left click / X\nDash: Shift / K / right click / A     Items: 1 2 3 / LB RB B     Interact: E / Y"
	box.add_child(help)


func toggle_pause() -> void:
	var paused := not get_tree().paused
	get_tree().paused = paused
	_pause_root.visible = paused
	if paused:
		_pause_retreat.visible = world != null and not world.is_hub
		_pause_resume.grab_focus()


func _on_retreat() -> void:
	toggle_pause()
	if world != null:
		world.retreat()


# --- Overlay ----------------------------------------------------------------------

func _text(pos: Vector2, s: String, size: int, color: Color, outline: Color) -> void:
	overlay.draw_string_outline(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 5, outline)
	overlay.draw_string(font, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, color)


func _text_center(y: float, s: String, size: int, color: Color, outline: Color) -> void:
	var w := overlay.size.x
	overlay.draw_string_outline(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, 5, outline)
	overlay.draw_string(font, Vector2(0, y), s, HORIZONTAL_ALIGNMENT_CENTER, w, size, color)


func _draw_overlay() -> void:
	if world == null or not is_instance_valid(world) or world.player == null:
		return
	var vs := overlay.size
	var pal := world.pal
	var txt: Color = pal.text
	var outline := Color(pal.bg, 0.85)
	var p := world.player

	# Health
	var bar := Rect2(20, 20, 280, 22)
	overlay.draw_rect(bar.grow(2), Color(0, 0, 0, 0.6))
	overlay.draw_rect(Rect2(bar.position, Vector2(bar.size.x * p.hp / p.max_hp, bar.size.y)), Color("e5484d"))
	_text(bar.position + Vector2(8, 16), "HP %d / %d" % [int(ceilf(p.hp)), int(p.max_hp)], 14, Color.WHITE, Color(0, 0, 0, 0.6))
	_text(Vector2(20, 70), "Shards: %d" % GameState.shards, 20, pal.shard, outline)
	_text(Vector2(20, 94), "%s   DMG %d  REACH %d  CRIT %d%%" % [
		GameState.sword_name(), int(GameState.sword_damage()), int(GameState.sword_reach()),
		int(round(GameState.sword_crit() * 100.0)),
	], 14, txt, outline)
	var y := 120.0
	for b in p.buffs:
		_text(Vector2(20, y), "%s  %.1fs" % [Player.BUFF_NAMES[b], p.buffs[b].time], 15, pal.accent, outline)
		y += 20.0

	# Location and progress
	_text_center(34, str(world.data.name), 22, txt, outline)
	if not world.is_hub:
		var sub := ""
		match world.state:
			"intermission":
				sub = "Next wave in %d" % int(ceilf(world.state_time)) if world.wave < world.total_waves else "The boss approaches..."
			"fighting":
				sub = "Wave %d / %d   -   %d enemies left" % [world.wave, world.total_waves, world.enemies.size() + world.pending_spawns]
			"boss":
				sub = str(world.data.boss_name)
			"cleared":
				sub = "Dimension cleared!"
		_text_center(58, sub, 16, Color(txt, 0.8), outline)
		if world.boss != null and is_instance_valid(world.boss):
			var bb := Rect2(vs.x * 0.5 - 260, 68, 520, 14)
			overlay.draw_rect(bb.grow(2), Color(0, 0, 0, 0.6))
			overlay.draw_rect(Rect2(bb.position, Vector2(bb.size.x * world.boss.hp / world.boss.max_hp, bb.size.y)), world.boss.color())

	# Item slots
	for i in GameState.MAX_ITEMS:
		var slot := Rect2(vs.x * 0.5 - 100 + i * 70, vs.y - 78, 58, 58)
		overlay.draw_rect(slot, Color(0, 0, 0, 0.55))
		overlay.draw_rect(slot, Color(txt, 0.4), false, 2.0)
		_text(slot.position + Vector2(4, 14), str(i + 1), 12, Color(txt, 0.7), outline)
		if i < GameState.items.size():
			var it: Dictionary = GameState.items[i]
			var col := Items.color(it)
			overlay.draw_rect(slot, col, false, 3.0)
			overlay.draw_string(font, Vector2(slot.position.x, slot.position.y + 40), Items.glyph(it), HORIZONTAL_ALIGNMENT_CENTER, slot.size.x, 28, col)
	if world.is_hub:
		_text_center(vs.y - 92, "WASD move  -  Space / click attack  -  Shift dash  -  1-3 items  -  E interact  -  Esc pause", 14, Color(txt, 0.7), outline)

	# Banner
	if _banner_time > 0.0:
		var a := clampf(minf(_banner_time, _banner_len - _banner_time + 0.3) / 0.3, 0.0, 1.0)
		_text_center(vs.y * 0.3, _banner_title, 46, Color(pal.accent, a), Color(outline, outline.a * a))
		if _banner_sub != "":
			_text_center(vs.y * 0.3 + 36, _banner_sub, 18, Color(txt, a), Color(outline, outline.a * a))
