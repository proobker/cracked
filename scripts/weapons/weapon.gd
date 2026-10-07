class_name Weapon
extends Node3D
## Base hitscan weapon: a real magazine, a separate reserve, reloads, and
## damage falloff (§5). Subclasses set the numbers and build the model.

## kind is "hit", "weak", or "kill" — the three markers in §9.
signal hit(kind: String)
signal ammo_changed(mag: int, reserve: int, reloading: bool)

var weapon_name := "Weapon"
var mag_size := 30
var reserve_max := 180
var fire_interval := 0.1
var automatic := true
var damage := 18.0
var falloff_start := 20.0
var falloff_end := 45.0
var falloff_min := 0.5
var reload_time := 1.6
var spread_deg := 1.2
var spread_crouched_deg := 0.5

var camera: Camera3D
var mag := 0
var reserve := 0
var reloading := false

var _cooldown := 0.0
var _reload_left := 0.0
var _trigger_was_down := false
var _model: Node3D
var _model_rest := Vector3.ZERO


func _ready() -> void:
	mag = mag_size
	reserve = reserve_max / 2
	_model = _build_model()
	_model_rest = _model.position
	add_child(_model)
	_emit_ammo()


func tick(delta: float, trigger: bool, reload_pressed: bool, crouched: bool) -> void:
	_cooldown -= delta
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
		else:
			# A dry trigger starts a reload rather than clicking (§5).
			start_reload()
	_trigger_was_down = trigger
	_model.position = _model.position.lerp(_model_rest, 18.0 * delta)


func start_reload() -> void:
	if reloading or mag == mag_size or reserve == 0:
		return
	reloading = true
	_reload_left = reload_time
	_emit_ammo()


func add_ammo(amount: int) -> void:
	reserve = mini(reserve_max, reserve + amount)
	_emit_ammo()


func _finish_reload() -> void:
	var moved := mini(mag_size - mag, reserve)
	mag += moved
	reserve -= moved
	reloading = false
	_emit_ammo()


func _fire(crouched: bool) -> void:
	mag -= 1
	_cooldown = fire_interval
	_model.position = _model_rest + Vector3(0.0, 0.0, 0.08)
	_emit_ammo()

	var spread := tan(deg_to_rad(spread_crouched_deg if crouched else spread_deg))
	var local_dir := Vector3(randf_range(-spread, spread), randf_range(-spread, spread), -1.0)
	var dir := (camera.global_basis * local_dir).normalized()
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from + dir * 200.0, 1 | 4)
	var result := camera.get_world_3d().direct_space_state.intersect_ray(query)
	if result.is_empty():
		return
	var collider: Object = result["collider"]
	if collider.has_method("take_hit"):
		var point: Vector3 = result["position"]
		var kind: String = collider.take_hit(_damage_at(from.distance_to(point)), point)
		if kind != "none":
			hit.emit(kind)


func _damage_at(distance: float) -> float:
	var t := inverse_lerp(falloff_start, falloff_end, distance)
	return damage * lerpf(1.0, falloff_min, clampf(t, 0.0, 1.0))


func _emit_ammo() -> void:
	ammo_changed.emit(mag, reserve, reloading)


## Override: return the first-person model, positioned relative to the camera.
func _build_model() -> Node3D:
	return Node3D.new()
