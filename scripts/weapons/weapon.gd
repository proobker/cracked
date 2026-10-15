class_name Weapon
extends Node3D
## Base hitscan weapon: a real magazine, a separate reserve, reloads, damage
## falloff, and pellets (§5). Subclasses set the numbers and build the model.
##
## Feel (§5's feel notes), the stack most shooters share:
## - First-shot accuracy, then spread that blooms with sustained fire and
##   settles when you stop; moving and jumping widen it, crouching tightens
##   it. The crosshair opens with the spread so it is never hidden.
## - Recoil kicks the aim itself (the bullet goes where the crosshair is)
##   and the player recovers most of it back once the trigger is let go.
## - A muzzle flash that lights the room, a tracer, sparks where it lands.
## - The gun sways against your look, bobs as you run, drops for a sprint,
##   dips through a reload and rises on a swap.
## The model is drawn with viewmodel.gdshader, so it never clips into walls.

## The strongest result of one shot: "miss", "hit", "weak", or "kill" (§9).
signal fired(result: String)
signal ammo_changed(weapon: Weapon)

const VIEWMODEL_SHADER := preload("res://shaders/viewmodel.gdshader")
const FLASH_SHADER := preload("res://shaders/viewmodel_flash.gdshader")

var kind := &"weapon"
var weapon_name := "Weapon"
var color := Color.WHITE
var mag_size := 30
var reserve_max := 180
var reserve_start := 90
var pickup_amount := 20
var fire_interval := 0.1
var automatic := true
var damage := 18.0
var pellets := 1
var falloff_start := 20.0
var falloff_end := 45.0
var falloff_min := 0.5
var reload_time := 1.6
var spread_deg := 1.2 # first shot, standing still
var spread_crouched_deg := 0.5
var spread_scoped_deg := 0.0
var bloom_per_shot := 0.0 # spread added by each shot
var bloom_max := 0.0
var bloom_decay := 6.0 # degrees per second once the trigger rests
var move_spread_deg := 0.6 # added at full sprint speed
var air_spread_deg := 1.5
var kick_deg := 0.3 # recoil: aim pitch per shot
var recoil_yaw_deg := 0.1 # recoil: sideways wander per shot
var recoil_recover := 8.0 # degrees per second the aim settles back
var shake := 0.05 # camera shake per shot, 0–1
var stagger := 0.0 # seconds an enemy is stopped by one shot
var score_mult := 1.0
var can_scope := false
var scoped_fov := 30.0
## Tracer look: width in metres, seconds on screen, and how many of a
## shot's pellets draw one.
var tracer_width := 0.025
var tracer_life := 0.06
var tracer_pellets := 1
## The barrel's end in the model's own coordinates; set by _build_model().
var muzzle := Vector3(0.0, 0.0, -0.6)

var camera: Camera3D
## Where tracers and impacts go: the world, so they pause with it.
var fx_parent: Node3D
var mag := 0
var reserve := 0
var reloading := false
var scoped := false

var _cooldown := 0.0
var _reload_left := 0.0
var _trigger_was_down := false
var _model: Node3D
var _model_rest := Vector3.ZERO
var _flash_mat: ShaderMaterial
var _flash_light: OmniLight3D
var _flash := 0.0
var _bloom := 0.0
var _shot_index := 0
var _since_shot := 10.0
var _crouched := false
var _move := 0.0 # 0..1 of sprint speed
var _airborne := false
var _sprinting := false
var _look := Vector2.ZERO
var _sway := Vector2.ZERO
var _bob_t := 0.0
var _kick_pos := Vector3.ZERO
var _kick_rot := 0.0
var _raise := 0.0

const RANK := {"miss": 0, "hit": 1, "weak": 2, "kill": 3}


func _ready() -> void:
	mag = mag_size
	reserve = reserve_start
	_model = _build_model()
	_model.scale = Vector3.ONE * 0.45
	_model_rest = _model.position
	add_child(_model)
	_build_flash()


## What the player is doing, for spread and for how the gun moves. Call
## before tick(). look is this tick's look input in degrees.
func set_motion(look: Vector2, move_fraction: float, airborne: bool, sprinting: bool) -> void:
	_look = look
	_move = clampf(move_fraction, 0.0, 1.0)
	_airborne = airborne
	_sprinting = sprinting


## Returns the recoil to apply to the aim this tick, in degrees: x is pitch
## (up), y is yaw (right). Zero when nothing fired.
func tick(delta: float, trigger: bool, reload_pressed: bool, crouched: bool) -> Vector2:
	_cooldown -= delta
	_since_shot += delta
	_crouched = crouched
	if _since_shot > fire_interval + 0.05:
		_bloom = move_toward(_bloom, 0.0, bloom_decay * delta)
		if _bloom <= 0.0:
			_shot_index = 0
	var kicked := Vector2.ZERO
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	if reload_pressed:
		start_reload()
	var pulled := trigger and (automatic or not _trigger_was_down)
	if pulled and not reloading and _cooldown <= 0.0 and _raise < 0.6:
		if mag > 0:
			kicked = _fire()
		else:
			# A dry trigger starts a reload rather than clicking (§5).
			start_reload()
	_trigger_was_down = trigger
	_animate(delta)
	return kicked


## True once the trigger has rested long enough for recoil to settle.
func recovering() -> bool:
	return _since_shot > fire_interval + 0.05


## The spread a shot fired now would have, in degrees (half-angle).
func current_spread_deg() -> float:
	var base := spread_deg
	var bloom := _bloom
	if scoped:
		base = spread_scoped_deg
		bloom *= 0.25
	elif _crouched:
		base = spread_crouched_deg
		bloom *= 0.6
	var s := base + bloom + move_spread_deg * _move
	if _airborne:
		s += air_spread_deg
	return s


func start_reload() -> void:
	if reloading or mag == mag_size or reserve == 0:
		return
	reloading = true
	scoped = false
	_reload_left = reload_time
	Audio.play(&"reload_" + String(kind))
	ammo_changed.emit(self)


func cancel_reload() -> void:
	if reloading:
		reloading = false
		ammo_changed.emit(self)


func add_ammo(amount: int) -> void:
	reserve = mini(reserve_max, reserve + amount)
	ammo_changed.emit(self)


func is_dry() -> bool:
	return mag == 0 and reserve == 0


func set_equipped(on: bool) -> void:
	visible = on
	_trigger_was_down = true # a held trigger never fires the new gun by itself
	if on:
		_raise = 1.0 # comes up from below
	else:
		scoped = false
		cancel_reload()


func _finish_reload() -> void:
	var moved := mini(mag_size - mag, reserve)
	mag += moved
	reserve -= moved
	reloading = false
	ammo_changed.emit(self)


func _fire() -> Vector2:
	mag -= 1
	_cooldown = fire_interval
	_since_shot = 0.0
	Audio.play(&"shot_" + String(kind))
	ammo_changed.emit(self)

	var spread := deg_to_rad(current_spread_deg())
	var from := camera.global_position
	var space := camera.get_world_3d().direct_space_state
	var muzzle_at := _flash_light.global_position
	var best := "miss"
	var staggered := {}
	for i in pellets:
		# Uniform over a disc, not a square, so the cone is round.
		var r := tan(spread) * sqrt(randf())
		var a := randf() * TAU
		var local_dir := Vector3(cos(a) * r, sin(a) * r, -1.0)
		var dir := (camera.global_basis * local_dir).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 1 | 4)
		query.hit_from_inside = true # point-blank, even when overlapping
		var result := space.intersect_ray(query)
		var end := from + dir * 80.0
		var res := "miss"
		if not result.is_empty():
			end = result["position"]
			var collider: Object = result["collider"]
			if collider.has_method("take_hit"):
				# Stagger lands once per shot, not once per pellet.
				var stun := 0.0 if staggered.has(collider) else stagger
				staggered[collider] = true
				res = collider.take_hit(_damage_at(from.distance_to(end)), result["shape"], kind, stun)
				if res != "none" and fx_parent:
					var c: Color = (collider as Enemy).color if collider is Enemy else color
					ShotFx.impact(fx_parent, end, -dir, c, res == "kill")
			elif fx_parent:
				ShotFx.impact(fx_parent, end, result["normal"], color, false, true)
		if RANK.get(res, 0) > RANK[best]:
			best = res
		if fx_parent and i < tracer_pellets:
			ShotFx.tracer(fx_parent, muzzle_at, end, color, tracer_width, tracer_life)
	fired.emit(best)

	# Recoil: the first shots climb, then the burst wanders side to side.
	var yaw := recoil_yaw_deg * (sin(float(_shot_index) * 0.9) * 0.7 + randf_range(-0.5, 0.5))
	_shot_index += 1
	_bloom = minf(bloom_max, _bloom + bloom_per_shot)
	_flash = 1.0
	_kick_pos = Vector3(0.0, 0.015, 0.05 + 0.03 * kick_deg)
	_kick_rot = deg_to_rad(4.0 + 3.0 * kick_deg)
	return Vector2(kick_deg, yaw)


func _damage_at(distance: float) -> float:
	var t := inverse_lerp(falloff_start, falloff_end, distance)
	return damage * lerpf(1.0, falloff_min, clampf(t, 0.0, 1.0))


## Where the model sits this frame: rest, plus sway, bob, sprint pose,
## reload dip, swap raise, and the shot's kick, all eased.
func _animate(delta: float) -> void:
	var pos := _model_rest
	var rot := Vector3.ZERO
	# Sway: the gun lags behind the look, a little.
	var want := Vector2(clampf(-_look.x * 0.004, -0.04, 0.04), clampf(_look.y * 0.004, -0.04, 0.04))
	_sway = _sway.lerp(want, minf(1.0, 10.0 * delta))
	pos += Vector3(_sway.x, _sway.y, 0.0)
	rot += Vector3(_sway.y * 2.0, _sway.x * 3.0, 0.0)
	# Bob: a figure-eight while moving on the ground.
	if not _airborne and _move > 0.05:
		_bob_t += delta * lerpf(7.0, 12.0, _move)
	var bob := _move * (0.6 if scoped else 1.0) * (0.0 if _airborne else 1.0)
	pos += Vector3(sin(_bob_t) * 0.012, -absf(cos(_bob_t)) * 0.01, 0.0) * bob
	if _airborne:
		pos.y -= 0.015
	# Sprint: lowered and turned in.
	if _sprinting and not reloading:
		pos += Vector3(-0.03, -0.05, 0.03)
		rot += Vector3(-0.3, 0.5, 0.15)
	# Reload: dips and rolls out, then back.
	if reloading:
		var t := 1.0 - _reload_left / reload_time
		var dip := sin(PI * clampf(t, 0.0, 1.0))
		pos += Vector3(0.0, -0.1, 0.03) * dip
		rot += Vector3(-0.5, 0.0, 0.5) * dip
	# Scoped: centred, so it does not poke out from behind the scope ring.
	if scoped:
		pos.x = 0.0
		pos.y -= 0.06
	# Swap: rises into view.
	_raise = move_toward(_raise, 0.0, 4.0 * delta)
	pos.y -= 0.25 * _raise * _raise
	rot.x -= 0.9 * _raise * _raise
	# Kick: snaps back and up, settles fast.
	_kick_pos = _kick_pos.lerp(Vector3.ZERO, minf(1.0, 16.0 * delta))
	_kick_rot = lerpf(_kick_rot, 0.0, minf(1.0, 14.0 * delta))
	pos += _kick_pos
	rot.x += _kick_rot
	_model.position = _model.position.lerp(pos, minf(1.0, 18.0 * delta))
	_model.rotation = _model.rotation.lerp(rot, minf(1.0, 14.0 * delta))
	# Flash: a frame or two of light.
	_flash = maxf(0.0, _flash - delta * 18.0)
	_flash_mat.set_shader_parameter("strength", _flash)
	_flash_light.light_energy = 3.0 * _flash
	_flash_light.visible = _flash > 0.0


## The muzzle flash: a soft quad facing the camera, and a short-range light
## so the shot lights the room around you.
func _build_flash() -> void:
	var quad := MeshInstance3D.new()
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.55, 0.55)
	quad.mesh = mesh
	_flash_mat = ShaderMaterial.new()
	_flash_mat.shader = FLASH_SHADER
	_flash_mat.set_shader_parameter("color", color.lerp(Color(1.0, 0.85, 0.5), 0.5))
	quad.material_override = _flash_mat
	quad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	quad.position = muzzle + Vector3(0.0, 0.0, -0.08)
	_model.add_child(quad)
	_flash_light = OmniLight3D.new()
	_flash_light.light_color = color.lerp(Color(1.0, 0.85, 0.5), 0.6)
	_flash_light.omni_range = 6.0
	_flash_light.light_energy = 0.0
	_flash_light.visible = false
	_flash_light.position = muzzle
	_model.add_child(_flash_light)


## Override: return the first-person model, positioned relative to the camera.
func _build_model() -> Node3D:
	return Node3D.new()


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)


func _body_mat() -> ShaderMaterial:
	return _viewmodel_mat(Color(0.12, 0.13, 0.18), Color.BLACK, 0.0)


func _trim_mat() -> ShaderMaterial:
	return _viewmodel_mat(color, color, 0.9)


func _viewmodel_mat(albedo: Color, emission: Color, energy: float) -> ShaderMaterial:
	var mat := ShaderMaterial.new()
	mat.shader = VIEWMODEL_SHADER
	mat.set_shader_parameter("albedo", albedo)
	mat.set_shader_parameter("emission", emission)
	mat.set_shader_parameter("emission_energy", energy)
	return mat
