extends Node3D
## The title screen: the plaza at night behind a slowly orbiting camera, and
## Play, Practice Range, Settings (and Quit on desktop).

var _camera: Camera3D
var _angle := 0.0
var _menu: VBoxContainer
var _settings: SettingsPanel


func _ready() -> void:
	get_tree().paused = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	add_child(Plaza.new())
	_camera = Camera3D.new()
	_camera.fov = 70.0
	add_child(_camera)
	_camera.make_current()
	_orbit(0.0)
	Audio.play_music(&"menu")
	Audio.set_intensity(1.0)

	var ui := CanvasLayer.new()
	add_child(ui)
	var shade := ColorRect.new()
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.color = Color(0.02, 0.0, 0.06, 0.45)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ui.add_child(shade)

	_menu = VBoxContainer.new()
	_menu.alignment = BoxContainer.ALIGNMENT_CENTER
	_menu.add_theme_constant_override("separation", 14)
	_menu.anchor_left = 0.5
	_menu.anchor_right = 0.5
	_menu.anchor_bottom = 1.0
	_menu.offset_left = -260
	_menu.offset_right = 260
	ui.add_child(_menu)

	var title := Label.new()
	title.text = "CRACKED"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 112)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.65))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.9, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	_menu.add_child(title)
	var tagline := Label.new()
	tagline.text = "a neon-lit death run, twenty waves deep"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.modulate = Color(1, 1, 1, 0.75)
	_menu.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	_menu.add_child(gap)

	var play := _button("PLAY", func() -> void: _start(Game.Mode.RUN))
	_button("PRACTICE RANGE", func() -> void: _start(Game.Mode.PRACTICE))
	_button("SETTINGS", _open_settings)
	if not OS.has_feature("mobile"):
		_button("QUIT", func() -> void: get_tree().quit())
	play.grab_focus.call_deferred()

	var version := Label.new()
	version.text = "v%s" % ProjectSettings.get_setting("application/config/version", "1.0.0")
	version.anchor_left = 1.0
	version.anchor_right = 1.0
	version.anchor_top = 1.0
	version.anchor_bottom = 1.0
	version.offset_left = -200
	version.offset_top = -40
	version.offset_right = -20
	version.offset_bottom = -12
	version.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	version.modulate = Color(1, 1, 1, 0.5)
	ui.add_child(version)

	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(func() -> void:
		_menu.visible = true
		(_menu.get_child(3) as Button).grab_focus())
	ui.add_child(_settings)


func _process(delta: float) -> void:
	_orbit(delta)


func _orbit(delta: float) -> void:
	_angle += delta * 0.06
	_camera.position = Vector3(sin(_angle) * 30.0, 9.0, cos(_angle) * 30.0)
	_camera.look_at(Vector3(0.0, 2.0, 0.0))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 76)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		action.call())
	_menu.add_child(b)
	return b


func _open_settings() -> void:
	_menu.visible = false
	_settings.open()


func _start(mode: Game.Mode) -> void:
	Game.mode = mode
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
