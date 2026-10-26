class_name LevelMap
extends Control
## The galaxy. Every level is a star scattered along loose spiral arms; the
## finale burns at the core and the endless level hides past the rim. Dust
## that cannot be chosen fills the arms, so nobody can count the levels.
## Stars appear as they come within reach, and a level only lights once
## unlocked.
##
## Built for phones: everything is circles drawn in one _draw, the layout
## is generated once and cached, and the canvas redraws only while the
## camera moves, plus a slow pulse for the current star.

signal picked(level: int)
signal activated(level: int)
signal arrived(level: int)

const WORLD := Vector2(4000.0, 2600.0)
const ARMS := 3
const MIN_GAP := 120.0
const DUST := 420
## Pixels per world unit when looking at one star.
const CLOSE := 0.8
const PICK_RADIUS := 46.0
const BOSS := Color(1.0, 0.2, 0.65)

static var _stars: Array[Vector2] = []
static var _dust: PackedVector2Array
static var _dust_look: PackedColorArray # rgb tint, a = alpha; size packed in _dust_size
static var _dust_size: PackedFloat32Array
static var _haze: PackedVector2Array

## Set by the level select from Progress.
var unlocked := 1
var cleared := {}
var selected := 1

var _center := Vector2.ZERO
var _zoom := CLOSE
var _tween: Tween
var _dragging := false
var _travel := 0.0
var _touches := {}
var _pulse := 0.0
var _pulse_wait := 0.0


## Star positions, index n - 1, in world units around the galaxy's core.
static func star_positions() -> Array[Vector2]:
	if _stars.is_empty():
		_generate()
	return _stars


static func star(n: int) -> Vector2:
	return star_positions()[clampi(n, 1, Levels.COUNT) - 1]


static func _generate() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 90210
	var rim := WORLD.x * 0.42
	for n in range(1, Levels.CAMPAIGN + 1):
		# Further levels lie further out, but each one picks its own arm, so
		# the next star is usually across the galaxy from the last.
		var t := float(n - 1) / float(Levels.CAMPAIGN - 1)
		var placed := false
		for _try in 60:
			var r := lerpf(300.0, rim, pow(t, 0.85)) + rng.randf_range(-90.0, 90.0)
			var arm := rng.randi() % ARMS
			var angle := TAU * float(arm) / ARMS + r / rim * 2.7 + rng.randf_range(-0.38, 0.38)
			var at := Vector2(cos(angle), sin(angle) * 0.62) * r
			if _far_enough(at):
				_stars.append(at)
				placed = true
				break
		if not placed:
			_stars.append(Vector2(cos(n), sin(n) * 0.62) * (rim + 120.0))
	_stars.append(Vector2.ZERO) # the finale: the core itself
	_stars.append(Vector2(WORLD.x * 0.44, WORLD.y * 0.42)) # the abyss, alone past the rim
	# Dust: mostly along the arms, a little everywhere.
	_dust = PackedVector2Array()
	_dust_look = PackedColorArray()
	_dust_size = PackedFloat32Array()
	for i in DUST:
		var at: Vector2
		if i % 10 < 7:
			var r := rng.randf_range(120.0, rim * 1.08)
			var angle := TAU * float(rng.randi() % ARMS) / ARMS + r / rim * 2.7 + rng.randfn(0.0, 0.22)
			at = Vector2(cos(angle), sin(angle) * 0.62) * r
		else:
			at = Vector2(rng.randf_range(-0.5, 0.5) * WORLD.x, rng.randf_range(-0.5, 0.5) * WORLD.y)
		_dust.append(at)
		var tint := Color(0.75, 0.85, 1.0).lerp(Color(1.0, 0.7, 0.9), rng.randf())
		tint.a = rng.randf_range(0.15, 0.55)
		_dust_look.append(tint)
		_dust_size.append(rng.randf_range(0.7, 2.2))
	_haze = PackedVector2Array()
	for i in 54:
		var r := rim * (0.12 + 0.95 * float(i % 18) / 18.0)
		var angle := TAU * floorf(i / 18.0) / ARMS + r / rim * 2.7
		_haze.append(Vector2(cos(angle), sin(angle) * 0.62) * r)


static func _far_enough(at: Vector2) -> bool:
	if at.length() < 220.0:
		return false # the core belongs to the finale
	for other in _stars:
		if other.distance_to(at) < MIN_GAP:
			return false
	return true


func _ready() -> void:
	clip_contents = true
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	visibility_changed.connect(func() -> void: set_process(is_visible_in_tree()))


## A star you can see: unlocked, or one of the next two as an unknown glint.
## The abyss stays dark until it is unlocked.
func is_visible_star(n: int) -> bool:
	if n == Levels.ENDLESS:
		return unlocked >= Levels.ENDLESS
	return n <= unlocked + 2


func is_open(n: int) -> bool:
	return n <= unlocked


func fit_zoom() -> float:
	return minf(size.x / WORLD.x, size.y / WORLD.y) * 0.98


func to_screen(world: Vector2) -> Vector2:
	return (world - _center) * _zoom + size / 2.0


## Jumps straight to a star, no flight.
func look_at_star(n: int) -> void:
	_stop()
	_center = star(n)
	_zoom = CLOSE
	queue_redraw()


## Shows the whole galaxy.
func look_at_all() -> void:
	_stop()
	_center = Vector2.ZERO
	_zoom = fit_zoom()
	queue_redraw()


## The flight between levels: out until the whole galaxy is in view, a
## breath, then down onto star n.
func travel_to(n: int) -> void:
	_stop()
	selected = n
	var from_center := _center
	var from_zoom := _zoom
	var fit := fit_zoom()
	var to := star(n)
	_tween = create_tween()
	var out := 0.5 if from_zoom > fit * 1.3 else 0.01
	_tween.tween_method(func(t: float) -> void:
		_camera(from_center.lerp(Vector2.ZERO, t), _zoom_lerp(from_zoom, fit, t)), 0.0, 1.0, out) \
		.set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_interval(0.15)
	_tween.tween_method(func(t: float) -> void:
		_camera(Vector2.ZERO.lerp(to, t), _zoom_lerp(fit, CLOSE, t)), 0.0, 1.0, 0.7) \
		.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_callback(func() -> void:
		_tween = null
		arrived.emit(n))


func is_travelling() -> bool:
	return _tween != null


## Finishes the flight at once.
func skip() -> void:
	if _tween:
		_tween.custom_step(10.0)


func _stop() -> void:
	if _tween:
		_tween.kill()
		_tween = null


func _camera(center: Vector2, zoom: float) -> void:
	_center = center
	_zoom = zoom
	queue_redraw()


## Zoom changes feel even when interpolated in log space.
static func _zoom_lerp(a: float, b: float, t: float) -> float:
	return exp(lerpf(log(a), log(b), t))


func _zoom_by(factor: float, anchor: Vector2) -> void:
	var world := (anchor - size / 2.0) / _zoom + _center
	_zoom = clampf(_zoom * factor, fit_zoom() * 0.9, 1.8)
	_center = world - (anchor - size / 2.0) / _zoom
	_clamp_center()
	queue_redraw()


func _clamp_center() -> void:
	_center = _center.clamp(-WORLD / 2.0, WORLD / 2.0)


func _process(delta: float) -> void:
	# The pulse on the current star, at a gentle frame rate.
	_pulse = fmod(_pulse + delta / 1.8, 1.0)
	_pulse_wait -= delta
	if _pulse_wait <= 0.0 and _tween == null:
		_pulse_wait = 1.0 / 20.0
		queue_redraw()


func pick(at: Vector2) -> int:
	var nearest := 0
	var best := PICK_RADIUS
	for n in range(1, Levels.COUNT + 1):
		if not is_visible_star(n) or not is_open(n):
			continue
		var d := at.distance_to(to_screen(star(n)))
		if d < best:
			best = d
			nearest = n
	return nearest


func _gui_input(event: InputEvent) -> void:
	if _tween and (event is InputEventMouseButton and event.pressed or event is InputEventScreenTouch and event.pressed):
		skip()
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
			_zoom_by(1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
			_zoom_by(1.0 / 1.15, event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_dragging = event.pressed
			if event.pressed:
				_travel = 0.0
				grab_focus()
			elif _travel < 12.0 and _touches.size() <= 1:
				_tap(event.position)
	elif event is InputEventMouseMotion and _dragging and _touches.size() < 2:
		_center -= event.relative / _zoom
		_travel += event.relative.length()
		_clamp_center()
		queue_redraw()
	elif event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() > 1:
				_travel = 100.0 # a pinch is never a tap
		else:
			_touches.erase(event.index)
	elif event is InputEventScreenDrag and _touches.size() == 2:
		var points: Array = _touches.values()
		var before: float = points[0].distance_to(points[1])
		_touches[event.index] = event.position
		points = _touches.values()
		if before > 1.0:
			_zoom_by(points[0].distance_to(points[1]) / before, (points[0] + points[1]) / 2.0)
	elif event is InputEventMagnifyGesture:
		_zoom_by(event.factor, event.position)
	elif event is InputEventKey and event.pressed:
		var direction := Vector2.ZERO
		match event.keycode:
			KEY_LEFT: direction = Vector2.LEFT
			KEY_RIGHT: direction = Vector2.RIGHT
			KEY_UP: direction = Vector2.UP
			KEY_DOWN: direction = Vector2.DOWN
			KEY_ENTER, KEY_SPACE, KEY_KP_ENTER: activated.emit(selected)
			KEY_EQUAL, KEY_PLUS: _zoom_by(1.2, size / 2.0)
			KEY_MINUS: _zoom_by(1.0 / 1.2, size / 2.0)
		if direction != Vector2.ZERO:
			_step(direction)
		accept_event()
	elif event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_A:
		activated.emit(selected)
		accept_event()
	elif event is InputEventJoypadMotion and absf(event.axis_value) > 0.6 and event.axis <= JOY_AXIS_LEFT_Y:
		var dir := Vector2(signf(event.axis_value), 0.0) if event.axis == JOY_AXIS_LEFT_X else Vector2(0.0, signf(event.axis_value))
		_step(dir)
		accept_event()


func _tap(at: Vector2) -> void:
	var n := pick(at)
	if n == 0:
		return
	if n == selected:
		activated.emit(n)
	else:
		picked.emit(n)


## Keyboard/gamepad: hop to the nearest open star roughly that way.
func _step(direction: Vector2) -> void:
	if _tween:
		return
	var from := star(selected)
	var best := 0
	var score := INF
	for n in range(1, Levels.COUNT + 1):
		if n == selected or not is_visible_star(n) or not is_open(n):
			continue
		var delta := star(n) - from
		if delta.normalized().dot(direction) > 0.45 and delta.length() < score:
			score = delta.length()
			best = n
	if best != 0:
		picked.emit(best)


func _draw() -> void:
	var view := Rect2(Vector2(-40, -40), size + Vector2(80, 80))
	# Arm haze and the core: the galaxy's shape from afar, fading out as
	# the camera closes in so near views stay clean.
	var far := clampf(1.0 - (_zoom / fit_zoom() - 1.0) / 1.5, 0.0, 1.0)
	if far > 0.0:
		for at in _haze:
			var p := to_screen(at)
			var r := 260.0 * _zoom
			if view.grow(r).has_point(p):
				draw_circle(p, r, Color(0.45, 0.25, 0.8, 0.035 * far))
	var core := to_screen(Vector2.ZERO)
	var glow := 0.35 + 0.65 * far
	for i in 5:
		draw_circle(core, (520.0 - i * 95.0) * _zoom, Color(1.0, 0.55 + i * 0.08, 0.75, (0.03 + i * 0.025) * glow))
	for i in _dust.size():
		var p := to_screen(_dust[i])
		if view.has_point(p):
			draw_circle(p, _dust_size[i] * clampf(_zoom * 1.6, 0.6, 1.6), _dust_look[i])
	var font := ThemeDB.fallback_font
	var names := _zoom >= 0.65 # closer in, labels would overlap
	for n in range(1, Levels.COUNT + 1):
		if not is_visible_star(n):
			continue
		var p := to_screen(star(n))
		if not view.has_point(p):
			continue
		var k := clampf(_zoom / CLOSE, 0.45, 1.5)
		if not is_open(n):
			# Within reach but uncharted: a dim glint, no colour, no name.
			draw_circle(p, 3.0 * k, Color(0.7, 0.75, 0.9, 0.35))
			draw_arc(p, 9.0 * k, 0.0, TAU, 16, Color(0.7, 0.75, 0.9, 0.12), 1.0, true)
			continue
		var color: Color = Levels.theme_for(n)["trim"]
		var big := n == Levels.FINALE or n == Levels.ENDLESS
		var r := (11.0 if big else 6.5) * k
		draw_circle(p, r * 3.2, Color(color, 0.08))
		draw_circle(p, r * 1.8, Color(color, 0.2))
		draw_circle(p, r, color.lightened(0.45))
		draw_circle(p, r * 0.45, Color.WHITE)
		if Levels.is_boss_level(n):
			draw_arc(p, r * 2.3, 0.0, TAU, 28, Color(BOSS, 0.75), 2.0, true)
		if cleared.has(str(n)):
			draw_arc(p, r * 1.55, 0.0, TAU, 24, Color(color, 0.9), 1.5, true)
		if n == unlocked:
			var grow := 1.6 + _pulse * 2.2
			draw_arc(p, r * grow, 0.0, TAU, 32, Color(1, 1, 1, 0.55 * (1.0 - _pulse)), 2.0, true)
		if n == selected:
			draw_arc(p, r * 2.9, 0.0, TAU, 36, Color.WHITE, 2.5, true)
			_label(font, p + Vector2(0, r * 2.9 + 24), Levels.name_for(n), 22, Color.WHITE)
		elif names:
			_label(font, p + Vector2(0, r * 2.0 + 16), Levels.name_for(n), 13, Color(color.lightened(0.3), 0.6))


func _label(font: Font, at: Vector2, text: String, font_size: int, color: Color) -> void:
	var w := font.get_string_size(text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size).x
	draw_string(font, at - Vector2(w / 2.0, 0.0), text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, color)
