extends Node
## The single input layer (plans.md §4, Controls). Touch, gamepad, and
## keyboard/mouse all become the same intents. Gameplay reads intents from
## here and from Input actions, never raw touch events. Autoloaded as
## `PlayerInput`.

## Set by the touch stick. Wins over keyboard/gamepad while non-zero.
var touch_move := Vector2.ZERO
var touch_sprint := false

var _look_accum := Vector2.ZERO # degrees: x = yaw, y = pitch


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_key("move_forward", KEY_W)
	_axis("move_forward", JOY_AXIS_LEFT_Y, -1.0)
	_key("move_back", KEY_S)
	_axis("move_back", JOY_AXIS_LEFT_Y, 1.0)
	_key("move_left", KEY_A)
	_axis("move_left", JOY_AXIS_LEFT_X, -1.0)
	_key("move_right", KEY_D)
	_axis("move_right", JOY_AXIS_LEFT_X, 1.0)
	_axis("look_left", JOY_AXIS_RIGHT_X, -1.0)
	_axis("look_right", JOY_AXIS_RIGHT_X, 1.0)
	_axis("look_up", JOY_AXIS_RIGHT_Y, -1.0)
	_axis("look_down", JOY_AXIS_RIGHT_Y, 1.0)
	_key("sprint", KEY_SHIFT)
	_button("sprint", JOY_BUTTON_LEFT_STICK)
	_key("jump", KEY_SPACE)
	_button("jump", JOY_BUTTON_A)
	_key("crouch", KEY_C)
	_key("crouch", KEY_CTRL)
	_button("crouch", JOY_BUTTON_B)
	_key("dash", KEY_Q)
	_button("dash", JOY_BUTTON_RIGHT_SHOULDER)
	_key("reload", KEY_R)
	_button("reload", JOY_BUTTON_X)
	_mouse("fire", MOUSE_BUTTON_LEFT)
	_axis("fire", JOY_AXIS_TRIGGER_RIGHT, 1.0)
	_key("swap", KEY_TAB)
	_mouse("swap", MOUSE_BUTTON_WHEEL_DOWN)
	_mouse("swap", MOUSE_BUTTON_WHEEL_UP)
	_button("swap", JOY_BUTTON_Y)
	_key("weapon_1", KEY_1)
	_key("weapon_2", KEY_2)
	_key("weapon_3", KEY_3)
	_mouse("scope", MOUSE_BUTTON_RIGHT)
	_axis("scope", JOY_AXIS_TRIGGER_LEFT, 1.0)
	_key("pause", KEY_ESCAPE)
	_button("pause", JOY_BUTTON_START)


func move_vector() -> Vector2:
	if touch_move != Vector2.ZERO:
		return touch_move
	return Input.get_vector("move_left", "move_right", "move_forward", "move_back")


func wants_sprint() -> bool:
	return touch_sprint or Input.is_action_pressed("sprint")


## Returns this frame's look in degrees and clears the accumulator.
func consume_look(delta: float) -> Vector2:
	var pad := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	var out: Vector2 = (_look_accum + pad * Tuning.pad_look_deg_per_sec * delta) * Tuning.sensitivity
	_look_accum = Vector2.ZERO
	return out


func add_touch_look(relative: Vector2) -> void:
	var height: float = get_viewport().get_visible_rect().size.y
	_look_accum += relative / height * Tuning.touch_look_deg_per_screen


func press(action: StringName) -> void:
	Input.action_press(action)


func release(action: StringName) -> void:
	Input.action_release(action)


func clear_touch() -> void:
	touch_move = Vector2.ZERO
	touch_sprint = false


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	if motion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_look_accum += motion.relative * Tuning.mouse_sens_deg_per_px


func _ensure(action: StringName) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)


func _key(action: StringName, keycode: Key) -> void:
	_ensure(action)
	var ev := InputEventKey.new()
	ev.physical_keycode = keycode
	InputMap.action_add_event(action, ev)


## Mouse bindings exist for editor testing only. On a touchscreen, touches
## are also emulated as mouse clicks (so menus work), and a touch must never
## fire the gun.
func _mouse(action: StringName, button: MouseButton) -> void:
	_ensure(action)
	if DisplayServer.is_touchscreen_available():
		return
	var ev := InputEventMouseButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _button(action: StringName, button: JoyButton) -> void:
	_ensure(action)
	var ev := InputEventJoypadButton.new()
	ev.button_index = button
	InputMap.action_add_event(action, ev)


func _axis(action: StringName, axis: JoyAxis, value: float) -> void:
	_ensure(action)
	var ev := InputEventJoypadMotion.new()
	ev.axis = axis
	ev.axis_value = value
	InputMap.action_add_event(action, ev)
