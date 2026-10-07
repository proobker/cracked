class_name SettingsPanel
extends Control
## The v1 settings (§11): look sensitivity, FOV, aim assist, touch control
## size and opacity, and volume. Changes apply live and save on close.

signal closed

const ROWS := [
	["sensitivity", "LOOK SENSITIVITY", 0.05],
	["fov", "FIELD OF VIEW", 1.0],
	["aim_assist_strength", "AIM ASSIST", 0.05],
	["touch_scale", "CONTROL SIZE", 0.05],
	["touch_opacity", "CONTROL OPACITY", 0.05],
	["master_volume", "VOLUME", 0.05],
	["music_volume", "MUSIC", 0.05],
]

var _values := {}
var _first: Control


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS

	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.0, 0.08, 0.92)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override("separation", 10)
	box.anchor_left = 0.5
	box.anchor_right = 0.5
	box.anchor_top = 0.0
	box.anchor_bottom = 1.0
	box.offset_left = -360
	box.offset_right = 360
	add_child(box)

	var title := Label.new()
	title.text = "SETTINGS"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 48)
	title.add_theme_color_override("font_color", Color(0.2, 0.9, 1.0))
	box.add_child(title)

	for row: Array in ROWS:
		var key: String = row[0]
		var range_: Array = Tuning.SETTINGS[key]
		var line := HBoxContainer.new()
		line.add_theme_constant_override("separation", 16)
		var name_label := Label.new()
		name_label.text = row[1]
		name_label.custom_minimum_size.x = 260
		name_label.add_theme_font_size_override("font_size", 22)
		line.add_child(name_label)
		var slider := HSlider.new()
		slider.min_value = range_[0]
		slider.max_value = range_[1]
		slider.step = row[2]
		slider.value = Tuning.get(key)
		slider.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		slider.custom_minimum_size.y = 44
		slider.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		line.add_child(slider)
		var value_label := Label.new()
		value_label.custom_minimum_size.x = 80
		value_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		value_label.add_theme_font_size_override("font_size", 22)
		line.add_child(value_label)
		_values[key] = value_label
		slider.value_changed.connect(_on_changed.bind(key))
		_show_value(key)
		box.add_child(line)
		if _first == null:
			_first = slider

	var back := Button.new()
	back.text = "BACK"
	back.custom_minimum_size = Vector2(240, 72)
	back.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back.add_theme_font_size_override("font_size", 28)
	back.pressed.connect(close)
	box.add_child(back)


func open() -> void:
	visible = true
	if _first:
		_first.grab_focus.call_deferred()


func close() -> void:
	Audio.play(&"ui_click")
	Tuning.save_settings()
	visible = false
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and (event.is_action_pressed("ui_cancel") or event.is_action_pressed("pause")):
		get_viewport().set_input_as_handled()
		close()


func _on_changed(value: float, key: String) -> void:
	Tuning.set(key, value)
	_show_value(key)
	if key.ends_with("volume"):
		Audio.apply_volumes()


func _show_value(key: String) -> void:
	var v: float = Tuning.get(key)
	var label: Label = _values[key]
	if key == "fov":
		label.text = "%d°" % roundi(v)
	elif key == "sensitivity" or key == "touch_scale":
		label.text = "%.2fx" % v
	else:
		label.text = "%d%%" % roundi(v * 100.0)
