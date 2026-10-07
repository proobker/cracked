class_name Enemy
extends CharacterBody3D
## Shared enemy body (§6). Telegraphs before it can act or be hit (§2), aims
## at where the player *is* (§4), turns at a limited rate so it commits to a
## path, and takes no cover. Subclasses set numbers, build a silhouette, and
## decide what to do each tick in _act().

signal died(enemy: Enemy)

var kind := &"enemy"
var display_name := "an enemy"
var color := Color.WHITE
var max_health := 50.0
var speed := 5.5
var turn_rate := 2.4 # rad/s
var points := 100
var radius := 0.45
var height := 1.8
var weak_mult := 3.0
var telegraph_scale := 1.0

var target: Player
var health := 0.0
var active := false
var last_hit_by := &"rifle"
## Stationary practice dummies: never move or attack.
var dummy := false

var _dead := false
var _telegraph_left := 0.0
var _heading := Vector3.FORWARD
var _detour_dir := Vector3.ZERO
var _detour_left := 0.0
var _stagger_left := 0.0
var _flash_left := 0.0
var _body: Node3D
var _glow_mats: Array[StandardMaterial3D] = []
var _pillar: MeshInstance3D
var _weak_shape_idx := -1


func _ready() -> void:
	_configure()
	health = max_health
	_telegraph_left = Tuning.spawn_telegraph * telegraph_scale
	collision_layer = 0 # not hittable until the telegraph finishes (§2)
	# Enemies stop at the player instead of walking into them; the player is
	# never body-blocked by enemies (their mask leaves this layer out).
	collision_mask = 1 | 2 | 4

	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = radius
	capsule.height = height
	shape.shape = capsule
	shape.position.y = height / 2.0
	add_child(shape)

	_body = Node3D.new()
	_body.visible = false
	add_child(_body)
	_build_body(_body)

	# Spawn telegraph: a pulsing column of light where it will appear.
	_pillar = MeshInstance3D.new()
	var pillar_mesh := CylinderMesh.new()
	pillar_mesh.top_radius = radius + 0.2
	pillar_mesh.bottom_radius = radius + 0.2
	pillar_mesh.height = 6.0
	_pillar.mesh = pillar_mesh
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	pillar_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pillar_mat.albedo_color = Color(color, 0.35)
	_pillar.material_override = pillar_mat
	_pillar.position.y = 3.0
	add_child(_pillar)
	Audio.play_at(&"telegraph", global_position)


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

	if _flash_left > 0.0:
		_flash_left -= delta
		_set_glow(4.0 if _flash_left > 0.0 else 1.2)
	if dummy:
		return

	if not is_on_floor():
		velocity.y -= Tuning.gravity * delta

	var to := target.global_position - global_position
	to.y = 0.0
	if _stagger_left > 0.0:
		_stagger_left -= delta
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var move_dir := _act(delta, to)
	if _detour_left > 0.0:
		_detour_left -= delta
		_heading = _detour_dir
	elif move_dir.length() > 0.05:
		var angle := _heading.signed_angle_to(move_dir.normalized(), Vector3.UP)
		var step := clampf(angle, -turn_rate * delta, turn_rate * delta)
		_heading = _heading.rotated(Vector3.UP, step).normalized()
	var moving := move_dir.length() > 0.05 or _detour_left > 0.0
	var spd := speed if moving else 0.0
	velocity.x = _heading.x * spd
	velocity.z = _heading.z * spd
	move_and_slide()
	_face(to)

	# Not pathfinding (§6): an enemy pinned against a wall walks along it for
	# a moment, toward the player's side, then goes back to walking straight.
	var real := get_real_velocity()
	if moving and is_on_wall() and Vector2(real.x, real.z).length() < spd * 0.4 and _detour_left <= 0.0:
		var normal := get_wall_normal()
		var tangent := Vector3(normal.z, 0.0, -normal.x).normalized()
		if tangent.dot(to) < 0.0:
			tangent = -tangent
		_detour_dir = tangent
		_detour_left = 0.7


## Returns "none", "hit", "weak", or "kill" for the marker system (§9).
func take_hit(amount: float, shape_idx: int, source: StringName, stagger: float) -> String:
	if not active or _dead:
		return "none"
	var weak := shape_idx >= 0 and shape_idx == _weak_shape_idx
	health -= amount * (weak_mult if weak else 1.0)
	last_hit_by = source
	_stagger_left = maxf(_stagger_left, stagger)
	_flash_left = 0.06
	if health <= 0.0:
		_dead = true
		Audio.play_at(&"death_" + String(kind), global_position)
		died.emit(self)
		queue_free()
		return "kill"
	return "weak" if weak else "hit"


## Override: per-tick behaviour. Return the direction to walk (zero to hold).
func _act(_delta: float, to: Vector3) -> Vector3:
	return to


## Override: set kind, numbers, and color.
func _configure() -> void:
	pass


## Override: build the visible silhouette under parent.
func _build_body(parent: Node3D) -> void:
	_mesh(parent, CapsuleMesh.new(), Vector3(0, height / 2.0, 0), _glow_mat(color, 1.2))


## Faces the walking direction by default. Heavies face the player instead.
func _face(_to: Vector3) -> void:
	rotation.y = atan2(-_heading.x, -_heading.z)


func _activate() -> void:
	active = true
	collision_layer = 4
	add_to_group("enemy")
	_body.visible = true
	_pillar.queue_free()
	var to := target.global_position - global_position if target else Vector3.FORWARD
	to.y = 0.0
	if to.length() > 0.05:
		_heading = to.normalized()
		rotation.y = atan2(-_heading.x, -_heading.z)
	Audio.play_at(&"spawn_" + String(kind), global_position)


## Adds a weak-point collider (a separate shape on this body) with a glowing
## mesh over it. A ray that hits that shape is a "weak" hit (§6).
func _add_weak_point(size: Vector3, pos: Vector3) -> void:
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position = pos
	add_child(shape)
	_weak_shape_idx = _shape_index_of(shape)
	var mesh := BoxMesh.new()
	mesh.size = size * 1.05
	_mesh(_body, mesh, pos, _glow_mat(Color(0.3, 1.0, 1.0), 4.0), false)


func _shape_index_of(shape: CollisionShape3D) -> int:
	var idx := 0
	for owner_id in get_shape_owners():
		if shape_owner_get_owner(owner_id) == shape:
			return idx
		idx += shape_owner_get_shape_count(owner_id)
	return -1


func _mesh(parent: Node3D, mesh: Mesh, pos: Vector3, mat: StandardMaterial3D, track := true) -> MeshInstance3D:
	if mesh is CapsuleMesh:
		(mesh as CapsuleMesh).radius = radius
		(mesh as CapsuleMesh).height = height
	var inst := MeshInstance3D.new()
	inst.mesh = mesh
	inst.material_override = mat
	inst.position = pos
	parent.add_child(inst)
	if track:
		_glow_mats.append(mat)
	return inst


func _glow_mat(c: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.emission_enabled = true
	mat.emission = c
	mat.emission_energy_multiplier = energy
	return mat


func _set_glow(energy: float) -> void:
	for mat in _glow_mats:
		mat.emission_energy_multiplier = energy


func _visor(parent: Node3D, width: float, y: float, z: float) -> void:
	var mesh := BoxMesh.new()
	mesh.size = Vector3(width, 0.12, 0.2)
	_mesh(parent, mesh, Vector3(0.0, y, z), _glow_mat(Color.WHITE, 3.0), false)


func _has_line_of_sight(from: Vector3, to: Vector3) -> bool:
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	return get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _fire_projectile(from: Vector3, at: Vector3, damage: float, proj_speed: float) -> void:
	var p := Projectile.new()
	p.damage = damage
	p.speed = proj_speed
	p.color = color
	p.source = display_name
	p.direction = (at - from).normalized()
	p.position = from # enemies live under a parent at the world origin
	get_parent().add_child(p)
	Audio.play_at(&"shot_" + String(kind), from)
