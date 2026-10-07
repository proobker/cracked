class_name Hud
extends Control
## The HUD (§9): crosshair and markers, health, ammo, wave, combo, score.
## No minimap yet — §9's test decides that once the plaza is played.
## Nothing sits in the bottom corners, which belong to the thumbs.

var score_source: Score

var _health_bar: ProgressBar
var _ammo: Label
var _wave: Label
var _score: Label
var _combo: Label
var _grace_bar: ProgressBar
var _banner: Label
var _banner_left := 0.0
var _crosshair: Crosshair
var _overlay: ColorRect
var _overlay_text: Label
var _combo_flash := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

	_crosshair = Crosshair.new()
	_crosshair.set_anchors_preset(Control.PRESET_FULL_RECT)
	_crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_crosshair)

	_health_bar = ProgressBar.new()
	_health_bar.show_percentage = false
	_health_bar.position = Vector2(24, 20)
	_health_bar.size = Vector2(260, 18)
	_health_bar.max_value = 100.0
	_health_bar.value = 100.0
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 1.0, 0.6)
	_health_bar.add_theme_stylebox_override("fill", fill)
	add_child(_health_bar)

	_wave = _label(28, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_wave, 0.5, 0.0, -300, 12, 300, 52)
	add_child(_wave)

	_banner = _label(44, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_banner, 0.5, 0.5, -500, -190, 500, -120)
	add_child(_banner)

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
	var grace_fill := StyleBoxFlat.new()
	grace_fill.bg_color = Color(1.0, 0.2, 0.7)
	_grace_bar.add_theme_stylebox_override("fill", grace_fill)
	add_child(_grace_bar)

	_ammo = _label(30, HORIZONTAL_ALIGNMENT_CENTER)
	_place(_ammo, 0.5, 1.0, -250, -64, 250, -24)
	add_child(_ammo)

	_overlay = ColorRect.new()
	_overlay.color = Color(0.03, 0.0, 0.08, 0.82)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overlay.visible = false
	add_child(_overlay)
	_overlay_text = _label(34, HORIZONTAL_ALIGNMENT_CENTER)
	_overlay_text.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay_text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_overlay.add_child(_overlay_text)

	set_score(0, 1)


func _process(delta: float) -> void:
	if score_source:
		_grace_bar.value = score_source.grace_fraction()
	if _banner_left > 0.0:
		_banner_left -= delta
		if _banner_left <= 0.0:
			_banner.text = ""
	if _combo_flash > 0.0:
		_combo_flash -= delta
		if _combo_flash <= 0.0:
			_combo.modulate = Color.WHITE


func set_health(health: float, max_health: float) -> void:
	_health_bar.max_value = max_health
	_health_bar.value = health


func set_ammo(mag: int, reserve: int, reloading: bool) -> void:
	if reloading:
		_ammo.text = "RELOADING  /  %d" % reserve
		_ammo.modulate = Color(1, 1, 1, 0.6)
	else:
		_ammo.text = "%d  /  %d" % [mag, reserve]
		# Empty is announced before the trigger is pulled (§5).
		_ammo.modulate = Color(1.0, 0.25, 0.3) if mag == 0 else Color.WHITE


func set_wave(wave: int, total: int) -> void:
	_wave.text = "WAVE %d / %d" % [wave, total]


func set_score(score: int, multiplier: int) -> void:
	_score.text = str(score)
	_combo.text = "x%d" % multiplier


## A full reset is loud on purpose (§2); a step down is a smaller flash.
func flash_combo(full: bool) -> void:
	_combo.modulate = Color(1.0, 0.1, 0.2) if full else Color(1.0, 0.6, 0.2)
	_combo_flash = 0.6 if full else 0.25


func show_marker(kind: String) -> void:
	_crosshair.show_marker(kind)


func banner(text: String, seconds := 1.5) -> void:
	_banner.text = text
	_banner_left = seconds


func show_overlay(text: String) -> void:
	_overlay_text.text = text
	_overlay.visible = true


func hide_overlay() -> void:
	_overlay.visible = false


func _label(font_size: int, align: HorizontalAlignment) -> Label:
	var label := Label.new()
	label.horizontal_alignment = align
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	label.add_theme_constant_override("outline_size", 6)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


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
