class_name Player
extends CharacterBody3D
## The player: five moves (§4), health with contact-timer regen (§8), and the
## camera with light aim assist. Builds its own nodes so it needs no scene.

signal health_changed(health: float, max_health: float)
signal damaged
signal died(cause: String)
## Re-emitted for the equipped weapon only, and on every swap.
signal weapon_changed(weapon: Weapon)
signal shot_result(result: String)

const STAND_EYE := 1.6
const LOW_EYE := 1.0

var build := {}
var effects := {}
var grenade_kind := ""
var grenades := 2
var grenade_cap := 2
var burn_lock := 0.0
var dash_bonus := 0.0
var blast_bonus := 0.0
var focus_bonus := 0.0
var _near_bonus := 0.0
var _near_cooldown := 0.0
var _primed := false
var _hit_target: Object
var _hit_count := 0
var _throw_left := 0.0
var _preview := false
var _grenade_blocked := true
var _preview_mesh: MeshInstance3D
var _aim_velocity := Vector3.ZERO
var _sprint_ready := 0.0
var health: float
var dead := false
## Regen multiplier and extra wait before it starts; the endless level
## barely heals.
var regen_scale := 1.0
var regen_extra_delay := 0.0
var head: Node3D
var camera: Camera3D
var weapon: Weapon
var weapons: Array[Weapon] = []
var _slot := 0

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
## Recoil not yet recovered, in degrees: x pitch up, y yaw right.
var _recoil_debt := Vector2.ZERO
var _last_look := Vector2.ZERO
## Camera shake, 0–1; it is squared on use so small amounts stay subtle.
var _trauma := 0.0
var _shake_t := 0.0


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	health = Tuning.max_health
	if build.is_empty():
		build = Progress.snapshot()
	effects = build.get("effects", {}).duplicate()
	grenade_kind = String(build.get("grenade", ""))
	grenade_cap = 2 + int(effects.get("grenade_capacity", 0))
	grenades = 0 if grenade_kind.is_empty() else 2
	_preview_mesh = MeshInstance3D.new()
	_preview_mesh.top_level = true
	add_child(_preview_mesh)

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

	for id: String in build.get("guns", Arsenal.DEFAULT):
		var w := Arsenal.make(id)
		w.wielder = self
		w.effects = effects.duplicate()
		w.camera = camera
		w.fx_parent = get_parent() as Node3D
		camera.add_child(w)
		w.ammo_changed.connect(_on_weapon_ammo)
		w.fired.connect(func(result: String) -> void: shot_result.emit(result))
		w.set_equipped(false)
		weapons.append(w)
	weapon = weapons[0]
	weapon.set_equipped(true)


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

	var was_sprinting := sprinting
	sprinting = (
		PlayerInput.wants_sprint() and mv.y < -0.3 and sprint_meter > 0.0
		and not crouched and not sliding
	)
	if was_sprinting and not sprinting:
		_sprint_ready = 0.15 / (1.0 + 0.25 * skill("sprint_recovery"))
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
		_dash_cooldown_left = Tuning.dash_cooldown * (1.0 - 0.1 * skill("dash_cooldown"))
		dash_bonus = 2.0
		Audio.play(&"dash")

	if Input.is_action_just_pressed("crouch") and not sliding:
		var flat := Vector3(velocity.x, 0.0, velocity.z)
		if sprinting and is_on_floor() and flat.length() > 0.1:
			sliding = true
			_primed = effects.has("slide_stagger")
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
			_slide_vel = _slide_vel.move_toward(Vector3.ZERO, Tuning.slide_friction * (1.0 - 0.1 * skill("slide_distance")) * delta)
		h = _slide_vel
		if _slide_vel.length() < Tuning.slide_min_speed:
			sliding = false
	else:
		var speed: float = Tuning.walk_speed
		if sprinting:
			speed = Tuning.sprint_speed
		elif crouched:
			speed = Tuning.crouch_speed
		var accel: float = Tuning.ground_accel if is_on_floor() else Tuning.air_accel * (1.0 + 0.2 * skill("air_control"))
		h = h.move_toward(wish * speed * (1.2 if _near_bonus > 0.0 else 1.0), accel * delta)
	velocity.x = h.x
	velocity.z = h.z
	move_and_slide()

	var eye: float = LOW_EYE if (crouched or sliding) else STAND_EYE
	head.position.y = move_toward(head.position.y, eye, 6.0 * delta)

	_grenade_input(delta)
	if _throw_left <= 0.0:
		_weapon_input()
	var flat_speed := Vector2(velocity.x, velocity.z).length()
	weapon.set_motion(_last_look, flat_speed / Tuning.sprint_speed, not is_on_floor(), sprinting)
	var kick := Vector2.ZERO
	if _throw_left <= 0.0:
		kick = weapon.tick(delta, Input.is_action_pressed("fire") and _sprint_ready <= 0.0, Input.is_action_just_pressed("reload"), crouched)
	else:
		weapon._animate(delta)
	_recoil(kick, delta)
	var fov: float = weapon.scoped_fov if weapon.scoped else Tuning.fov
	camera.fov = move_toward(camera.fov, fov, 300.0 * (1.0 + 0.25 * skill("scope_speed")) * delta)
	_shake(delta)


func take_damage(amount: float, source: String) -> void:
	if dead or _iframes_left > 0.0:
		return
	if sliding:
		amount *= 1.0 - 0.1 * skill("slide_guard")
	if dash_bonus > 0.0:
		amount *= 1.0 - 0.08 * skill("dash_guard")
	health = maxf(0.0, health - amount)
	_since_damage = 0.0
	add_trauma(0.45)
	Audio.play(&"hurt")
	damaged.emit()
	health_changed.emit(health, Tuning.max_health)
	if health <= 0.0:
		dead = true
		died.emit(_cause_of_death(source))


func collect_ammo(kind: StringName, amount: int) -> void:
	for w in weapons:
		if w.kind == kind:
			w.add_ammo(amount)


func weapon_by_kind(kind: StringName) -> Weapon:
	for w in weapons:
		if w.kind == kind:
			return w
	return null


func equip(slot: int) -> void:
	if slot == _slot or slot < 0 or slot >= weapons.size():
		return
	weapon.set_equipped(false)
	_slot = slot
	weapon = weapons[slot]
	weapon.set_equipped(true)
	Audio.play(&"swap")
	weapon_changed.emit(weapon)


## Swap goes to the next weapon that can still shoot, so a dry gun costs one
## tap, not a hunt (§5). If every gun is dry, it simply cycles.
func swap_next() -> void:
	for step in range(1, weapons.size()):
		var slot := (_slot + step) % weapons.size()
		if not weapons[slot].is_dry():
			equip(slot)
			return
	equip((_slot + 1) % weapons.size())


func _weapon_input() -> void:
	if Input.is_action_just_pressed("swap"):
		swap_next()
	for i in weapons.size():
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			equip(i)
	if Input.is_action_just_pressed("scope") and weapon.can_scope and not weapon.reloading:
		weapon.scoped = not weapon.scoped
		weapon_changed.emit(weapon)


func _on_weapon_ammo(w: Weapon) -> void:
	if w == weapon:
		weapon_changed.emit(w)


## Shakes the camera by moving it, never turning it, so aim is untouched.
func add_trauma(amount: float) -> void:
	_trauma = minf(1.0, _trauma + amount)


## Recoil moves the real aim, so the shot goes where the crosshair is. Once
## the gun rests, the aim settles back toward where the burst began; any
## pull-down the player already made counts toward that.
func _recoil(kick: Vector2, delta: float) -> void:
	if kick != Vector2.ZERO:
		head.rotation.x = clampf(head.rotation.x + deg_to_rad(kick.x), -1.5, 1.5)
		rotate_y(deg_to_rad(-kick.y))
		_recoil_debt += kick
		add_trauma(weapon.shake * (0.3 if weapon.scoped else 1.0))
		return
	if not weapon.recovering():
		return
	var step := weapon.recoil_recover * delta
	var pitch := minf(_recoil_debt.x, step)
	if pitch > 0.0:
		head.rotation.x = clampf(head.rotation.x - deg_to_rad(pitch), -1.5, 1.5)
		_recoil_debt.x -= pitch
	var yaw := clampf(_recoil_debt.y, -step * 0.5, step * 0.5)
	if yaw != 0.0:
		rotate_y(deg_to_rad(yaw))
		_recoil_debt.y -= yaw


func _shake(delta: float) -> void:
	_trauma = maxf(0.0, _trauma - 2.2 * delta)
	_shake_t += delta
	var amount := _trauma * _trauma * 0.07
	camera.h_offset = amount * sin(_shake_t * 53.0)
	camera.v_offset = amount * sin(_shake_t * 47.0 + 1.3)


func is_dashing() -> bool:
	return _dash_left > 0.0


func dash_ready_fraction() -> float:
	return 1.0 - clampf(_dash_cooldown_left / Tuning.dash_cooldown, 0.0, 1.0)


func _look(delta: float) -> void:
	var look: Vector2 = PlayerInput.consume_look(delta)
	if Tuning.aim_assist_strength > 0.0 and _enemy_under_crosshair():
		look *= 1.0 - Tuning.aim_assist_strength
	if weapon.scoped:
		look *= Tuning.scoped_look_scale
	_last_look = look
	# Pulling down against recoil pays it off, so recovery never overshoots.
	if look.y > 0.0 and _recoil_debt.x > 0.0:
		_recoil_debt.x = maxf(0.0, _recoil_debt.x - look.y)
	rotate_y(deg_to_rad(-look.x))
	head.rotation.x = clampf(head.rotation.x - deg_to_rad(look.y), -1.5, 1.5)


func _tick_timers(delta: float) -> void:
	burn_lock = maxf(0.0, burn_lock - delta)
	dash_bonus = maxf(0.0, dash_bonus - delta)
	blast_bonus = maxf(0.0, blast_bonus - delta)
	focus_bonus = maxf(0.0, focus_bonus - delta)
	_near_bonus = maxf(0.0, _near_bonus - delta)
	_near_cooldown = maxf(0.0, _near_cooldown - delta)
	_throw_left = maxf(0.0, _throw_left - delta)
	_sprint_ready = maxf(0.0, _sprint_ready - delta)
	_dash_left = maxf(0.0, _dash_left - delta)
	_dash_cooldown_left = maxf(0.0, _dash_cooldown_left - delta)
	_iframes_left = maxf(0.0, _iframes_left - delta)
	_since_damage += delta
	if _since_damage >= Tuning.regen_delay + regen_extra_delay and health < Tuning.max_health:
		health = minf(Tuning.max_health, health + Tuning.regen_per_sec * regen_scale * delta)
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

func skill(id: String) -> float:
	return float(effects.get(id, 0))

func consume_stagger() -> float:
	var result := 0.6 if _primed else 0.0
	_primed = false
	return result

func hit_stagger(enemy: Enemy) -> float:
	if _hit_target != enemy:
		_hit_target = enemy
		_hit_count = 0
	_hit_count += 1
	if _hit_count % 4 == 0:
		if effects.has("focus_fire"):
			focus_bonus = 2.0
		return 0.1 * skill("sustained_stagger")
	return 0.0

func combat_hit(_enemy: Enemy, result: String, weak: bool, source: StringName) -> void:
	if result != "kill":
		return
	if weak and effects.has("precision_feed"):
		var gun := weapon_by_kind(source)
		if gun:
			var moved := mini(2, mini(gun.reserve, gun.mag_size - gun.mag))
			gun.reserve -= moved
			gun.mag += moved
			gun.ammo_changed.emit(gun)
	if Arsenal.GRENADES.has(String(source)) and effects.has("blast_reload"):
		blast_bonus = 3.0

func near_miss() -> void:
	if is_dashing() and effects.has("near_miss") and _near_cooldown <= 0.0:
		_near_bonus = 2.0
		_near_cooldown = 4.0

func cancel_grenade() -> void:
	_preview = false
	_grenade_blocked = true
	if is_instance_valid(_preview_mesh):
		_preview_mesh.visible = false

func _grenade_input(delta: float) -> void:
	if not Input.is_action_pressed("grenade"):
		if _preview and not _grenade_blocked:
			throw_grenade()
		_preview = false
		_grenade_blocked = false
		_preview_mesh.visible = false
		return
	if _grenade_blocked or grenades < 1 or _throw_left > 0.0:
		return
	_preview = true
	var deviation := Vector3(velocity.x, 0, velocity.z) * 0.18 * (1.0 - 0.25 * skill("throw_accuracy"))
	_aim_velocity = -camera.global_basis.z * 16.0 + Vector3.UP * 4.0 + deviation
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var at := camera.global_position
	var v := _aim_velocity
	for _i in 36:
		var state := Ordnance.step(self, at, v, 0.05)
		mesh.surface_add_vertex(at)
		mesh.surface_add_vertex(state.position)
		at = state.position
		v = state.velocity
	mesh.surface_end()
	_preview_mesh.mesh = mesh
	if not _preview_mesh.material_override:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(0.2, 1.0, 0.8)
		_preview_mesh.material_override = mat
	_preview_mesh.visible = true

func throw_grenade() -> void:
	if grenades < 1 or grenade_kind.is_empty() or _throw_left > 0.0:
		return
	var ball := Ordnance.new()
	ball.kind = StringName(grenade_kind)
	ball.position = camera.global_position
	ball.motion = _aim_velocity
	ball.player = self
	ball.effects = effects.duplicate()
	get_parent().add_child(ball)
	grenades -= 1
	_throw_left = 0.5 * (1.0 - 0.12 * skill("throw_recovery"))
	_preview = false
