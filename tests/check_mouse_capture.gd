extends Node
## Rendered regression: a touch-capable desktop must still capture real mice.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func _ready() -> void:
	if not Progress.isolated or DisplayServer.get_name() == "headless":
		printerr("Run through check_game.py --rendered")
		get_tree().quit(1)
		return
	AudioServer.set_bus_mute(0, true)
	Game.mode = Game.Mode.PRACTICE
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	game._set_paused(false)
	print("Touchscreen available: ", DisplayServer.is_touchscreen_available())
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Gameplay must capture mouse on desktop, including touchscreen laptops")
	var has_fire := false
	for event in InputMap.action_get_events("fire"):
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			has_fire = true
	check(has_fire, "Desktop left mouse must fire even with a touchscreen")
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_IN)
	game._process(0)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Returning focus repairs lost gameplay capture")
	var motion := InputEventMouseMotion.new()
	motion.relative = Vector2(100, 50)
	motion.screen_relative = Vector2(10, 5)
	PlayerInput._unhandled_input(motion)
	var expected := motion.screen_relative * Tuning.mouse_sens_deg_per_px * Tuning.sensitivity
	check(PlayerInput.consume_look(0).is_equal_approx(expected), "Mouse look uses unscaled relative movement")
	game._set_paused(true)
	check(Input.mouse_mode == Input.MOUSE_MODE_CONFINED, "Pause cursor stays visible inside window")
	PlayerInput._unhandled_input(motion)
	check(PlayerInput.consume_look(0) == Vector2.ZERO, "Menu motion cannot accumulate camera movement")
	game._set_paused(false)
	check(Input.mouse_mode == Input.MOUSE_MODE_CAPTURED, "Resume recaptures cursor")
	game._notification(Node.NOTIFICATION_WM_WINDOW_FOCUS_OUT)
	check(get_tree().paused and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Focus loss pauses and releases cursor")
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	check(Input.mouse_mode == Input.MOUSE_MODE_CONFINED, "Main menu confines visible cursor")
	menu._armory.open()
	check(Input.mouse_mode == Input.MOUSE_MODE_CONFINED, "Armory keeps menu confinement")
	menu._on_pointer_focus_exited()
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Alt-tab releases menu confinement")
	menu._on_pointer_focus_entered()
	check(Input.mouse_mode == Input.MOUSE_MODE_CONFINED, "Returning to menu restores confinement")
	menu.queue_free()
	await get_tree().process_frame
	PlayerInput.release_pointer()
	Audio.stop_all()
	print("MOUSE CAPTURE: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)
