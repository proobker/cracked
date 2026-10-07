class_name Player
extends CharacterBody3D
## The player: five moves (§4), health with contact-timer regen (§8), and the
## camera with light aim assist. Builds its own nodes so it needs no scene.

signal health_changed(health: float, max_health: float)
signal damaged
signal died(cause: String)

const STAND_EYE := 1.6
const LOW_EYE := 1.0

var health: float
var dead := false
var head: Node3D
var camera: Camera3D
var weapon: Weapon

var sprinting := false
var sliding := false
var crouched := false
var sprint_meter := 1.0

var _slide_vel := Vector3.ZERO
var _dash_vel := Vector3.ZERO
var _dash_left := 0.0
var _dash_cooldown_left := 0.0
var _iframes_left := 0.0
var _since_damage := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	health = Tuning.max_health

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	head = Node3D.new()
	head.position.y = STAND_EYE
	add_child(head)

	camera = Camera3D.new()
	camera.fov = Tuning.fov
	camera.near = 0.05
	head.add_child(camera)
	camera.make_current()

	weapon = Rifle.new()
	weapon.camera = camera
	camera.add_child(weapon)


func _physics_process(delta: float) -> void:
	if dead:
		return
	_look(delta)
	_tick_timers(delta)

	var mv: Vector2 = PlayerInput.move_vector()
	var wish := transform.basis * Vector3(mv.x, 0.0, mv.y)
	wish.y = 0.0
	if wish.length() > 1.0:
		wish = wish.normalized()

	sprinting = (
		PlayerInput.wants_sprint() and mv.y < -0.3 and sprint_meter > 0.0
		and not crouched and not sliding
	)
	if sprinting:
		sprint_meter = maxf(0.0, sprint_meter - delta / Tuning.sprint_meter_seconds)
	else:
		sprint_meter = minf(1.0, sprint_meter + delta / Tuning.sprint_refill_seconds)

	if Input.is_action_just_pressed("dash") and _dash_cooldown_left <= 0.0:
		var dir := wish if wish.length() > 0.1 else -transform.basis.z
		dir.y = 0.0
		_dash_vel = dir.normalized() * Tuning.dash_speed
		_dash_left = Tuning.dash_duration
		_iframes_left = Tuning.dash_iframes
		_dash_cooldown_left = Tuning.dash_cooldown # longer than the dash: no chaining

	if Input.is_action_just_pressed("crouch") and not sliding:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if sprinting and is_on_floor() and flat.length() > 0.1:
			sliding = true
			crouched = true
			_slide_vel = flat.normalized() * maxf(Tuning.slide_speed, flat.length())
		else:
			crouched = not crouched

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = Tuning.jump_velocity
		if sliding:
			# Slide-jump keeps the slide's momentum; the player chose to leave it.
			sliding = false
			crouched = false
			velocity.x = _slide_vel.x
			velocity.z = _slide_vel.z

	if not is_on_floor():
		velocity.y -= Tuning.gravity * delta

	var h := Vector3(velocity.x, 0.0, velocity.z)
	if _dash_left > 0.0:
		h = _dash_vel
	elif sliding:
		if is_on_floor():
			_slide_vel = _slide_vel.move_toward(Vector3.ZERO, Tuning.slide_friction * delta)
		h = _slide_vel
		if _slide_vel.length() < Tuning.slide_min_speed:
			sliding = false
	else:
		var speed: float = Tuning.walk_speed
		if sprinting:
			speed = Tuning.sprint_speed
		elif crouched:
			speed = Tuning.crouch_speed
		var accel: float = Tuning.ground_accel if is_on_floor() else Tuning.air_accel
		h = h.move_toward(wish * speed, accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()

	var eye: float = LOW_EYE if (crouched or sliding) else STAND_EYE
	head.position.y = move_toward(head.position.y, eye, 6.0 * delta)

	weapon.tick(delta, Input.is_action_pressed("fire"), Input.is_action_just_pressed("reload"), crouched)


func take_damage(amount: float, source: String) -> void:
	if dead or _iframes_left > 0.0:
		return
	health = maxf(0.0, health - amount)
	_since_damage = 0.0
	damaged.emit()
	health_changed.emit(health, Tuning.max_health)
	if health <= 0.0:
		dead = true
		died.emit(_cause_of_death(source))


func collect_ammo(amount: int) -> void:
	weapon.add_ammo(amount)


func is_dashing() -> bool:
	return _dash_left > 0.0


func dash_ready_fraction() -> float:
	return 1.0 - clampf(_dash_cooldown_left / Tuning.dash_cooldown, 0.0, 1.0)


func _look(delta: float) -> void:
	var look: Vector2 = PlayerInput.consume_look(delta)
	if Tuning.aim_assist_strength > 0.0 and _enemy_under_crosshair():
		look *= 1.0 - Tuning.aim_assist_strength
	rotate_y(deg_to_rad(-look.x))
	head.rotation.x = clampf(head.rotation.x - deg_to_rad(look.y), -1.5, 1.5)


func _tick_timers(delta: float) -> void:
	_dash_left = maxf(0.0, _dash_left - delta)
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_iframes_left = maxf(0.0, _iframes_left - delta)
	_since_damage += delta
	if _since_damage >= Tuning.regen_delay and health < Tuning.max_health:
		health = minf(Tuning.max_health, health + Tuning.regen_per_sec * delta)
		health_changed.emit(health, Tuning.max_health)


## Aim assist is slowdown only (§4): it never moves the camera by itself.
func _enemy_under_crosshair() -> bool:
	var origin := camera.global_position
	var forward := -camera.global_basis.z
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Node3D
		var to := enemy.global_position + Vector3(0.0, 1.0, 0.0) - origin
		if to.length() > 60.0:
			continue
		if rad_to_deg(forward.angle_to(to)) > Tuning.aim_assist_angle_deg:
			continue
		var query := PhysicsRayQueryParameters3D.create(origin, origin + to, 1)
		if get_world_3d().direct_space_state.intersect_ray(query).is_empty():
			return true
	return false


func _cause_of_death(source: String) -> String:
	var cause := "killed by " + source
	if weapon.reloading:
		cause += " while reloading"
	elif weapon.mag == 0:
		cause += " with an empty magazine"
	elif sliding:
		cause += " mid-slide"
	return cause
