class_name Weapon
extends Node3D
## Base hitscan weapon: a real magazine, a separate reserve, reloads, damage
## falloff, and pellets (§5). Subclasses set the numbers and build the model.

## The strongest result of one shot: "miss", "hit", "weak", or "kill" (§9).
signal fired(result: String)
signal ammo_changed(weapon: Weapon)

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
var spread_deg := 1.2
var spread_crouched_deg := 0.5
var spread_scoped_deg := 0.0
var kick_deg := 0.3 # camera pitch kick per shot
var stagger := 0.0 # seconds an enemy is stopped by one shot
var score_mult := 1.0
var can_scope := false
var scoped_fov := 30.0

var camera: Camera3D
var mag := 0
var reserve := 0
var reloading := false
var scoped := false

var _cooldown := 0.0
var _reload_left := 0.0
var _trigger_was_down := false
var _model: Node3D
var _model_rest := Vector3.ZERO

const RANK := {"miss": 0, "hit": 1, "weak": 2, "kill": 3}


func _ready() -> void:
	mag = mag_size
	reserve = reserve_start
	_model = _build_model()
	_model.scale = Vector3.ONE * 0.45
	_model_rest = _model.position
	add_child(_model)


## Returns the camera kick in degrees if a shot was fired this tick, else 0.
func tick(delta: float, trigger: bool, reload_pressed: bool, crouched: bool) -> float:
	_cooldown -= delta
	var kicked := 0.0
	if reloading:
		_reload_left -= delta
		if _reload_left <= 0.0:
			_finish_reload()
	if reload_pressed:
		start_reload()
	var pulled := trigger and (automatic or not _trigger_was_down)
	if pulled and not reloading and _cooldown <= 0.0:
		if mag > 0:
			_fire(crouched)
			kicked = kick_deg
		else:
			# A dry trigger starts a reload rather than clicking (§5).
			start_reload()
	_trigger_was_down = trigger
	_model.position = _model.position.lerp(_model_rest, 14.0 * delta)
	return kicked


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
	if not on:
		scoped = false
		cancel_reload()


func _finish_reload() -> void:
	var moved := mini(mag_size - mag, reserve)
	mag += moved
	reserve -= moved
	reloading = false
	ammo_changed.emit(self)


func _fire(crouched: bool) -> void:
	mag -= 1
	_cooldown = fire_interval
	_model.position = _model_rest + Vector3(0.0, 0.02, 0.06 + 0.04 * kick_deg)
	Audio.play(&"shot_" + String(kind))
	ammo_changed.emit(self)

	var spread_deg_now := spread_deg
	if scoped:
		spread_deg_now = spread_scoped_deg
	elif crouched:
		spread_deg_now = spread_crouched_deg
	var spread := tan(deg_to_rad(spread_deg_now))
	var from := camera.global_position
	var space := camera.get_world_3d().direct_space_state
	var best := "miss"
	var staggered := {}
	for i in pellets:
		var local_dir := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)
		var dir := (camera.global_basis * local_dir).normalized()
		var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 1 | 4)
		query.hit_from_inside = true # point-blank, even when overlapping
		var result := space.intersect_ray(query)
		if result.is_empty():
			continue
		var collider: Object = result["collider"]
		if not collider.has_method("take_hit"):
			continue
		var point: Vector3 = result["position"]
		var shape: int = result["shape"]
		# Stagger lands once per shot, not once per pellet.
		var stun := 0.0 if staggered.has(collider) else stagger
		staggered[collider] = true
		var res: String = collider.take_hit(_damage_at(from.distance_to(point)), shape, kind, stun)
		if RANK.get(res, 0) > RANK[best]:
			best = res
	fired.emit(best)


func _damage_at(distance: float) -> float:
	var t := inverse_lerp(falloff_start, falloff_end, distance)
	return damage * lerpf(1.0, falloff_min, clampf(t, 0.0, 1.0))


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


func _body_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.12, 0.13, 0.18)
	return mat


func _trim_mat() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 0.9
	return mat
