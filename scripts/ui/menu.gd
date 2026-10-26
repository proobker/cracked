extends Node3D
## The title screen: the plaza at night behind a slowly orbiting camera, and
## Play (the level select), Practice Range, Settings (and Quit on desktop).
## The Play Games name shows in the corner once signed in.

var _camera: Camera3D
var _angle := 0.0
var _menu: VBoxContainer
var _settings: SettingsPanel
var _levels: LevelSelect
var _gamer: Button
var _armory: Armory
var _from_levels := false
var _play_button: Button


func _ready() -> void:
	if not DeviceTest.scene().is_empty() and get_tree().current_scene == self:
		set_process(false)
		get_tree().change_scene_to_file.call_deferred(DeviceTest.scene())
		return
	get_tree().paused = false
	PlayerInput.set_mouse_capture(false)
	get_window().focus_entered.connect(_on_pointer_focus_entered)
	get_window().focus_exited.connect(_on_pointer_focus_exited)
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
	title.add_theme_font_size_override("font_size", 88)
	title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.65))
	title.add_theme_color_override("font_outline_color", Color(0.2, 0.9, 1.0))
	title.add_theme_constant_override("outline_size", 4)
	_menu.add_child(title)
	var tagline := Label.new()
	tagline.text = "a neon-lit death run across a hostile galaxy"
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.add_theme_font_size_override("font_size", 22)
	tagline.modulate = Color(1, 1, 1, 0.75)
	_menu.add_child(tagline)
	var gap := Control.new()
	gap.custom_minimum_size.y = 24
	_menu.add_child(gap)

	var play := _button("PLAY", _open_levels)
	_play_button = play
	_button("ARMORY", func() -> void: _open_armory(false))
	_button("PRACTICE RANGE", _open_practice_build)
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
		_play_button.grab_focus())
	ui.add_child(_settings)

	_levels = LevelSelect.new()
	_levels.visible = false
	_levels.closed.connect(func() -> void:
		_menu.visible = true
		_play_button.grab_focus())
	_levels.chosen.connect(func(n: int) -> void:
		Game.level = n
		_start(Game.Mode.RUN))
	ui.add_child(_levels)
	_levels.armory_requested.connect(func() -> void: _open_armory(true))
	_armory = Armory.new()
	_armory.visible = false
	_armory.closed.connect(func() -> void:
		if _from_levels:
			_levels.open()
		else:
			_menu.visible = true
			_play_button.grab_focus())
	ui.add_child(_armory)
	_armory.practice_requested.connect(func() -> void: _start(Game.Mode.PRACTICE))

	# Play Games: the gamer name once signed in, a sign-in button before.
	_gamer = Button.new()
	_gamer.flat = true
	_gamer.position = Vector2(16, 10)
	_gamer.custom_minimum_size.y = 56
	_gamer.add_theme_font_size_override("font_size", 22)
	_gamer.modulate = Color(1, 1, 1, 0.7)
	_gamer.pressed.connect(PlayGames.sign_in)
	ui.add_child(_gamer)
	_show_gamer()
	PlayGames.signed_in_changed.connect(_show_gamer)
	# Same layer as the panels and added after them: hide it with the title
	# menu, or it draws over the Armory/level map/settings headers.
	_menu.visibility_changed.connect(_show_gamer)
	# Back from a cleared star: straight onto the map for the flight onward.
	if LevelSelect.travel_from > 0:
		_open_levels()


func _on_pointer_focus_entered() -> void:
	PlayerInput.set_mouse_capture(false)


func _on_pointer_focus_exited() -> void:
	PlayerInput.release_pointer()


func _process(delta: float) -> void:
	_orbit(delta)


func _orbit(delta: float) -> void:
	_angle += delta * 0.06
	_camera.position = Vector3(sin(_angle) * 30.0, 9.0, cos(_angle) * 30.0)
	_camera.look_at(Vector3(0.0, 2.0, 0.0))


func _button(text: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 60)
	b.add_theme_font_size_override("font_size", 30)
	b.pressed.connect(func() -> void:
		Audio.play(&"ui_click")
		action.call())
	_menu.add_child(b)
	return b


func _open_levels() -> void:
	_menu.visible = false
	_levels.open()


func _show_gamer() -> void:
	_gamer.visible = PlayGames.available and _menu.visible
	_gamer.disabled = PlayGames.signed_in
	_gamer.text = PlayGames.player_name if PlayGames.signed_in else "SIGN IN TO PLAY GAMES"


func _open_settings() -> void:
	_menu.visible = false
	_settings.open()


func _start(mode: Game.Mode) -> void:
	if mode == Game.Mode.RUN:
		_armory.prepare_campaign()
	_launch(mode)

func _launch(mode: Game.Mode) -> void:
	Game.mode = mode
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")

func _open_practice_build() -> void:
	_from_levels = false
	_menu.visible = false
	_levels.visible = false
	_armory.open(true)

func _open_armory(from_levels: bool) -> void:
	_from_levels = from_levels
	_menu.visible = false
	_levels.visible = false
	_armory.open()
