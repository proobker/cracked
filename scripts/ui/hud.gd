class_name Hud
extends Control
## The HUD (§9): crosshair and markers, health, ammo, wave, combo, score.
## The minimap is cut by §9's own test. Nothing sits in the bottom corners,
## which belong to the thumbs.

## Emitted when an overlay button is pressed, with the button's id.
signal overlay_action(id: StringName)

var score_source: Score

var _health_bar: ProgressBar
var _progress: Label
var _ammo: Label
var _slots: Array[Label] = []
var _wave: Label
var _score: Label
var _combo: Label
var _grace_bar: ProgressBar
var _banner: Label
var _banner_left := 0.0
var _notice: Label
var _notice_left := 0.0
var _crosshair: Crosshair
var _hurt: ColorRect
var _overlay: ColorRect
var _overlay_title: Label
var _overlay_body: Label
var _overlay_buttons: HBoxContainer
var _combo_flash := 0.0
## Debug builds only: frame rate and draw calls, refreshed twice a second.
var _perf: Label
var _perf_left := 0.0


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_hurt = ColorRect.new()
	_hurt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_hurt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hurt.color = Color(1.0, 0.0, 0.15, 0.0)
	add_child(_hurt)

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_place(_health_bar, 0.0, 0.0, 24, 20, 284, 38)
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	_health_bar.add_theme_stylebox_override("fill", _flat(Color(0.2, 1.0, 0.6)))
	_health_bar.add_theme_stylebox_override("background", _flat(Color(0.0, 0.0, 0.0, 0.45)))
	add_child(_health_bar)

	_progress = _label(17, HORIZONTAL_ALIGNMENT_LEFT)
	_place(_progress, 0.0, 0.0, 24, 45, 450, 98)
	add_child(_progress)
	_wave = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_wave, 0.5, 0.0, -300, 12, 300, 52)
	add_child(_wave)

	_banner = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_banner, 0.5, 0.5, -500, -190, 500, -120)
	add_child(_banner)
	# Separate from the banner, which wave countdowns keep rewriting.
	_notice = _label(24, HORIZONTAL_ALIGNMENT_CENTER)
	_notice.add_theme_color_override("font_color", Color(1.0, 0.35, 0.65))
	_place(_notice, 0.5, 0.0, -420, 56, 420, 92)
	add_child(_notice)

	_score = _label(26, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_score, 1.0, 0.0, -324, 12, -24, 48)
	add_child(_score)

	_combo = _label(40, HORIZONTAL_ALIGNMENT_RIGHT)
	_place(_combo, 1.0, 0.0, -324, 44, -24, 94)
	add_child(_combo)

	_grace_bar = ProgressBar.new()
	_grace_bar.show_percentage = false
	_place(_grace_bar, 1.0, 0.0, -144, 98, -24, 104)
	_grace_bar.max_value = 1.0
	_grace_bar.add_theme_stylebox_override("fill", _flat(Color(1.0, 0.2, 0.7)))
	_grace_bar.add_theme_stylebox_override("background", _flat(Color(0.0, 0.0, 0.0, 0.45)))
	add_child(_grace_bar)

	_ammo = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ammo, 0.5, 1.0, -250, -64, 250, -24)
	add_child(_ammo)

	var slot_row := HBoxContainer.new()
	slot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	slot_row.add_theme_constant_override("separation", 22)
	slot_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_place(slot_row, 0.5, 1.0, -250, -96, 250, -66)
	add_child(slot_row)
	for i in 3:
		var slot := _label(18, HORIZONTAL_ALIGNMENT_CENTER)
		slot_row.add_child(slot)
		_slots.append(slot)

	if OS.is_debug_build():
		_perf = _label(16, HORIZONTAL_ALIGNMENT_RIGHT)
		_place(_perf, 1.0, 0.0, -324, 108, -24, 130)
		add_child(_perf)

	_build_overlay()
	set_score(0, 1)


func _process(delta: float) -> void:
	if score_source:
		_grace_bar.value = score_source.grace_fraction()
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.text = ""
	if _notice_left > 0.0:
		_notice_left -= delta
		_notice.modulate.a = clampf(_notice_left, 0.0, 1.0)
		if _notice_left <= 0.0:
			_notice.text = ""
	if _combo_flash > 0.0:
		_combo_flash -= delta
		if _combo_flash <= 0.0:
			_combo.modulate = Color.WHITE
	if _hurt.color.a > 0.0:
		_hurt.color.a = maxf(0.0, _hurt.color.a - delta * 0.8)
	if _perf:
		_perf_left -= delta
		if _perf_left <= 0.0:
			_perf_left = 0.5
			_perf.text = "%d FPS  %d DRAWS" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]


func set_health(health: float, max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health


## Shows the equipped weapon's ammo and the three weapon slots.
func set_weapon(weapon: Weapon, all: Array[Weapon]) -> void:
	if weapon.reloading:
		_ammo.text = "RELOADING  /  %d" % weapon.reserve
		_ammo.modulate = Color(1, 1, 1, 0.6)
	else:
		_ammo.text = "%d  /  %d" % [weapon.mag, weapon.reserve]
		# Empty is announced before the trigger is pulled (§5).
		_ammo.modulate = Color(1.0, 0.25, 0.3) if weapon.mag == 0 else Color.WHITE
	for i in mini(all.size(), _slots.size()):
		var w := all[i]
		var slot := _slots[i]
		slot.text = w.weapon_name
		var c := w.color
		if w.is_dry():
			c = Color(1.0, 0.25, 0.3)
		slot.modulate = Color(c, 1.0 if w == weapon else 0.45)
		slot.add_theme_font_size_override("font_size", 22 if w == weapon else 16)
	_crosshair.scoped = weapon.scoped
	_crosshair.queue_redraw()


func set_wave_text(text: String) -> void:
	_wave.text = text


func set_score(score: int, multiplier: int) -> void:
	_score.text = str(score)
	_combo.text = "x%d" % multiplier


## A full reset is loud on purpose (§2); a step down is a smaller flash.
func flash_combo(full: bool) -> void:
	_combo.modulate = Color(1.0, 0.1, 0.2) if full else Color(1.0, 0.6, 0.2)
	_combo_flash = 0.6 if full else 0.25


func flash_hurt() -> void:
	_hurt.color.a = 0.28


## Opens the crosshair to a spread cone (half-angle, degrees) at this
## vertical field of view.
func set_spread(spread_deg: float, fov_deg: float) -> void:
	var px := tan(deg_to_rad(spread_deg)) / tan(deg_to_rad(fov_deg / 2.0)) * size.y / 2.0
	if absf(px - _crosshair.spread_px) > 0.25:
		_crosshair.spread_px = px
		_crosshair.queue_redraw()


func show_marker(kind: String) -> void:
	_crosshair.show_marker(kind)


func banner(text: String, seconds := 1.5) -> void:
	_banner.text = text
	_banner_left = seconds


## A system message that outlives wave banners; fades over its last second.
func notice(text: String, seconds := 5.0) -> void:
	_notice.text = text
	_notice.modulate.a = 1.0
	_notice_left = seconds


## buttons: an array of [id, label] pairs. The first one takes focus, so a
## gamepad or keyboard can confirm it straight away.
func show_overlay(title: String, body: String, buttons: Array) -> void:
	_overlay_title.text = title
	_overlay_body.text = body
	for child in _overlay_buttons.get_children():
		child.queue_free()
	var first: Button = null
	for pair: Array in buttons:
		var b := Button.new()
		b.text = pair[1]
		b.custom_minimum_size = Vector2(220, 72)
		b.add_theme_font_size_override("font_size", 28)
		var id: StringName = pair[0]
		b.pressed.connect(func() -> void:
			Audio.play(&"ui_click")
			overlay_action.emit(id))
		_overlay_buttons.add_child(b)
		if first == null:
			first = b
	_overlay.visible = true
	if first:
		first.grab_focus.call_deferred()


func hide_overlay() -> void:
	_overlay.visible = false


func is_overlay_visible() -> bool:
	return _overlay.visible


func _build_overlay() -> void:
	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.0, 0.08, 0.85)
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	_overlay.visible = false
	add_child(_overlay)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 24)
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(box)

	_overlay_title = _label(64, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.65))
	box.add_child(_overlay_title)
	_overlay_body = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(_overlay_body)
	_overlay_buttons = HBoxContainer.new()
	_overlay_buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	_overlay_buttons.add_theme_constant_override("separation", 28)
	box.add_child(_overlay_buttons)


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


func _flat(c: Color) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = c
	return box


## Pins a control to one anchor point with fixed pixel offsets from it.
func _place(control: Control, ax: float, ay: float, left: float, top: float, right: float, bottom: float) -> void:
	control.anchor_left = ax
	control.anchor_right = ax
	control.anchor_top = ay
	control.anchor_bottom = ay
	control.offset_left = left
	control.offset_top = top
	control.offset_right = right
	control.offset_bottom = bottom

func set_progress(level: int, coins: int, unbanked: int, grenade: String, charges: int, practice: bool) -> void:
	# Called every frame: set the text once, so an unchanged value costs no relayout.
	var text := "PRACTICE - no rewards" if practice else "LV %d  |  BANK %d  |  ROOM +%d" % [level, coins, unbanked]
	text += "\n%s  %d  [G / LB]" % [grenade.to_upper() if not grenade.is_empty() else "GRENADES LOCKED", charges]
	_progress.text = text
