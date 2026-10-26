class_name TouchControls
extends Control
## On-screen controls (§4, Controls). Owns no gameplay: it turns fingers into
## intents on PlayerInput. Handles raw multi-touch itself, so a thumb on the
## stick never steals a thumb on the fire button.

const STICK_RADIUS := 90.0
const SPRINT_RING := 1.15 # push this far past the stick's edge to sprint
## The stick never moves: a touch this many radii from its home grabs it.
const STICK_GRAB := 2.0
## Home of the stick, from the bottom-left corner.
const STICK_HOME := Vector2(180, -170)

## Button centers are offsets from the bottom-right corner, except "pause",
## which is offset from the top center.
var _buttons: Array[Dictionary] = [
	{"action": &"grenade", "label": "G", "offset": Vector2(-410, -180), "r": 36.0},
	{"action": &"fire", "label": "FIRE", "offset": Vector2(-170, -200), "r": 72.0},
	{"action": &"jump", "label": "JUMP", "offset": Vector2(-80, -86), "r": 48.0},
	{"action": &"crouch", "label": "SLIDE", "offset": Vector2(-205, -66), "r": 44.0},
	{"action": &"dash", "label": "DASH", "offset": Vector2(-310, -96), "r": 44.0},
	{"action": &"reload", "label": "R", "offset": Vector2(-78, -320), "r": 36.0},
	{"action": &"swap", "label": "SWAP", "offset": Vector2(-178, -345), "r": 38.0},
	{"action": &"scope", "label": "SCOPE", "offset": Vector2(-300, -252), "r": 38.0},
	{"action": &"pause", "label": "II", "offset": Vector2(0, 92), "r": 30.0, "top": true},
]

## Optional: lets buttons show when they are unavailable.
var player: Player

var _stick_finger := -1
var _stick_origin := Vector2.ZERO
var _stick_knob := Vector2.ZERO
var _look_finger := -1
var _button_fingers := {} # finger index -> action


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = DisplayServer.is_touchscreen_available()


func _process(_delta: float) -> void:
	if visible and player:
		queue_redraw()


func _exit_tree() -> void:
	reset()


## Hidden under overlays (pause, death, win) so no button sits on top of
## theirs. Only ever shown on a touchscreen.
func set_shown(shown: bool) -> void:
	visible = shown and DisplayServer.is_touchscreen_available()


## Releases every held finger. Called on pause so nothing stays pressed.
func reset() -> void:
	if is_instance_valid(player):
		player.cancel_grenade()
	for action in _button_fingers.values():
		PlayerInput.release(action)
	_button_fingers.clear()
	_stick_finger = -1
	_look_finger = -1
	PlayerInput.clear_touch()
	queue_redraw()


func _input(event: InputEvent) -> void:
	if not visible:
		return
	var touch := event as InputEventScreenTouch
	if touch:
		if touch.pressed:
			_on_down(touch.index, touch.position)
		else:
			_on_up(touch.index)
		return
	var drag := event as InputEventScreenDrag
	if drag:
		_on_drag(drag.index, drag.position, drag.relative)


func _on_down(finger: int, pos: Vector2) -> void:
	for b in _buttons:
		if pos.distance_to(_center(b)) <= float(b["r"]) * Tuning.touch_scale:
			var action: StringName = b["action"]
			_button_fingers[finger] = action
			PlayerInput.press(action)
			# The fire button doubles as a look zone: drag while firing (§4).
			if action == &"fire" and _look_finger == -1:
				_look_finger = finger
			queue_redraw()
			return
	var home := _stick_home()
	if _stick_finger == -1 and pos.distance_to(home) <= STICK_RADIUS * Tuning.touch_scale * STICK_GRAB:
		_stick_finger = finger
		_stick_origin = home
		_move_stick(pos)
	elif _look_finger == -1:
		_look_finger = finger


func _on_drag(finger: int, pos: Vector2, relative: Vector2) -> void:
	if _button_fingers.get(finger) == &"grenade":
		for b in _buttons:
			if b.action == &"grenade" and pos.distance_to(_center(b)) > float(b.r) * Tuning.touch_scale * 1.5:
				player.cancel_grenade()
				PlayerInput.release(&"grenade")
				_button_fingers.erase(finger)
	if finger == _stick_finger:
		_move_stick(pos)
	if finger == _look_finger:
		PlayerInput.add_touch_look(relative)


func _move_stick(pos: Vector2) -> void:
	var radius := STICK_RADIUS * Tuning.touch_scale
	var offset := pos - _stick_origin
	PlayerInput.touch_sprint = offset.length() / radius > SPRINT_RING
	PlayerInput.touch_move = offset.limit_length(radius) / radius
	_stick_knob = _stick_origin + offset.limit_length(radius)
	queue_redraw()


func _stick_home() -> Vector2:
	return Vector2(0.0, size.y) + STICK_HOME * Tuning.touch_scale


func _on_up(finger: int) -> void:
	if _button_fingers.has(finger):
		PlayerInput.release(_button_fingers[finger])
		_button_fingers.erase(finger)
	if finger == _stick_finger:
		_stick_finger = -1
		PlayerInput.clear_touch()
	if finger == _look_finger:
		_look_finger = -1
	queue_redraw()


## 1.0 when the action can be used now; a fraction while it recharges.
func _ready_fraction(action: StringName) -> float:
	if player == null:
		return 1.0
	match action:
		&"dash":
			return player.dash_ready_fraction()
		&"grenade":
			return 1.0 if player.grenades > 0 else 0.0
		&"scope":
			return 1.0 if player.weapon.can_scope else 0.0
	return 1.0


func _center(b: Dictionary) -> Vector2:
	var offset: Vector2 = b["offset"] * Tuning.touch_scale
	if b.get("top", false):
		return Vector2(size.x / 2.0, 0.0) + offset
	return size + offset


func _draw() -> void:
	var alpha: float = Tuning.touch_opacity
	var font := ThemeDB.fallback_font
	for b in _buttons:
		var c := _center(b)
		var r: float = float(b["r"]) * Tuning.touch_scale
		var held: bool = _button_fingers.values().has(b["action"])
		var ready := _ready_fraction(b["action"])
		var ring := Color(0.3, 0.95, 1.0, alpha * (1.0 if ready >= 1.0 else 0.35))
		draw_circle(c, r, Color(1, 1, 1, alpha * (0.5 if held else 0.18)))
		draw_arc(c, r, 0.0, TAU, 48, ring, 3.0)
		if ready < 1.0 and ready > 0.0:
			draw_arc(c, r, -PI / 2.0, -PI / 2.0 + TAU * ready, 48, Color(0.3, 0.95, 1.0, alpha), 3.0)
		var label: String = b["label"]
		var font_size := 18
		var text_size := font.get_string_size(label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
		draw_string(font, c + Vector2(-text_size.x / 2.0, font_size / 3.0), label,
			HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color(1, 1, 1, alpha * 1.6))

	# The stick always sits at home; only the knob moves.
	var radius := STICK_RADIUS * Tuning.touch_scale
	var home := _stick_home()
	var held := _stick_finger != -1
	draw_circle(home, radius, Color(1, 1, 1, alpha * (0.14 if held else 0.08)))
	draw_arc(home, radius, 0.0, TAU, 48, Color(1, 1, 1, alpha * (1.0 if held else 0.5)), 3.0 if held else 2.0)
	if held:
		draw_arc(home, radius * SPRINT_RING, 0.0, TAU, 48, Color(1, 0.8, 0.2, alpha * 0.6), 2.0)
	draw_circle(_stick_knob if held else home, radius * 0.4, Color(1, 1, 1, alpha * (1.0 if held else 0.45)))
