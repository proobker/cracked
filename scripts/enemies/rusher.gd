class_name Rusher
extends CharacterBody3D
## Pressure (§6). Telegraphs, then walks straight at where the player *is*
## (§4: no leading), turning slowly so it overshoots a good slide. Melee on
## contact. Takes no cover, by design.

signal died(enemy: Rusher)

const KIND := "rusher"
const COLOR := Color(1.0, 0.15, 0.6)

var target: Player
var max_health := 50.0
var speed := 5.5
var turn_rate := 2.4 # rad/s — low on purpose, so it commits to a path
var melee_range := 1.7
var melee_damage := 20.0
var melee_cooldown := 1.0
var points := 100

var health := 0.0
var active := false
var _dead := false
var _telegraph_left := 0.0
var _melee_left := 0.0
var _heading := Vector3.FORWARD
var _detour_dir := Vector3.ZERO
var _detour_left := 0.0
var _body: MeshInstance3D
var _body_mat: StandardMaterial3D
var _pillar: MeshInstance3D
var _flash_left := 0.0


func _ready() -> void:
	health = max_health
	_telegraph_left = Tuning.spawn_telegraph
	collision_layer = 0 # not hittable until the telegraph finishes (§2)
	collision_mask = 1 | 4

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.45
	capsule.height = 1.8
	shape.shape = capsule
	shape.position.y = 0.9
	add_child(shape)

	_body_mat = StandardMaterial3D.new()
	_body_mat.albedo_color = COLOR
	_body_mat.emission_enabled = true
	_body_mat.emission = COLOR
	_body_mat.emission_energy_multiplier = 1.2
	_body = MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.45
	mesh.height = 1.8
	_body.mesh = mesh
	_body.material_override = _body_mat
	_body.position.y = 0.9
	_body.visible = false
	add_child(_body)

	var visor := MeshInstance3D.new()
	var visor_mesh := BoxMesh.new()
	visor_mesh.size = Vector3(0.6, 0.12, 0.2)
	visor.mesh = visor_mesh
	var visor_mat := StandardMaterial3D.new()
	visor_mat.albedo_color = Color.WHITE
	visor_mat.emission_enabled = true
	visor_mat.emission = Color.WHITE
	visor_mat.emission_energy_multiplier = 3.0
	visor.material_override = visor_mat
	visor.position = Vector3(0.0, 0.55, -0.4)
	_body.add_child(visor)

	# Spawn telegraph: a pulsing column of light where it will appear.
	_pillar = MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = 0.6
	pillar_mesh.bottom_radius = 0.6
	pillar_mesh.height = 6.0
	_pillar.mesh = pillar_mesh
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.albedo_color = Color(COLOR, 0.35)
	_pillar.material_override = pillar_mat
	_pillar.position.y = 3.0
	add_child(_pillar)


func _physics_process(delta: float) -> void:
	if _dead:
		return
	if not active:
		_telegraph_left -= delta
		_pillar.scale.x = 1.0 + 0.3 * sin(_telegraph_left * 30.0)
		_pillar.scale.z = _pillar.scale.x
		if _telegraph_left <= 0.0:
			_activate()
		return

	if not is_on_floor():
		velocity.y -= Tuning.gravity * delta

	var to := target.global_position - global_position
	to.y = 0.0
	if _detour_left > 0.0:
		_detour_left -= delta
		_heading = _detour_dir
	elif to.length() > 0.05:
		var desired := to.normalized()
		var angle := _heading.signed_angle_to(desired, Vector3.UP)
		var step := clampf(angle, -turn_rate * delta, turn_rate * delta)
		_heading = _heading.rotated(Vector3.UP, step).normalized()
	velocity.x = _heading.x * speed
	velocity.z = _heading.z * speed
	move_and_slide()
	rotation.y = atan2(-_heading.x, -_heading.z)

	# Not pathfinding (§6): a rusher pinned against a wall walks along it for
	# a moment, toward the player's side, then goes back to walking straight.
	var real := get_real_velocity()
	if is_on_wall() and Vector2(real.x, real.z).length() < speed * 0.4 and _detour_left <= 0.0:
		var normal := get_wall_normal()
		var tangent := Vector3(normal.z, 0.0, -normal.x).normalized()
		if tangent.dot(to) < 0.0:
			tangent = -tangent
		_detour_dir = tangent
		_detour_left = 0.7

	_melee_left -= delta
	if to.length() < melee_range and _melee_left <= 0.0 and not target.dead:
		target.take_damage(melee_damage, "a rusher")
		_melee_left = melee_cooldown

	if _flash_left > 0.0:
		_flash_left -= delta
		_body_mat.emission_energy_multiplier = 1.2 if _flash_left <= 0.0 else 4.0


## Returns "none", "hit", or "kill" for the marker system (§9).
func take_hit(amount: float, _point: Vector3) -> String:
	if not active or _dead:
		return "none"
	health -= amount
	_flash_left = 0.06
	if health <= 0.0:
		_dead = true
		died.emit(self)
		queue_free()
		return "kill"
	return "hit"


func _activate() -> void:
	active = true
	collision_layer = 4
	add_to_group("enemy")
	_body.visible = true
	_pillar.queue_free()
	var to := target.global_position - global_position
	to.y = 0.0
	if to.length() > 0.05:
		_heading = to.normalized()
