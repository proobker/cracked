class_name Enemy
extends CharacterBody3D
## Shared enemy body (§6). Telegraphs before it can act or be hit (§2), aims
## at where the player *is* (§4), turns at a limited rate so it commits to a
## path, and takes no cover. Subclasses set numbers, pick a model, and
## decide what to do each tick in _act(). The collision shape is fitted to
## the model, so what you see is what you can hit.
##
## Motion is steering, not pathfinding (§6): the direction _act() asks for
## is bent by a slow wander, pushed apart from other enemies, and now and
## then broken by a juke — a short sidestep, most often when the player's
## crosshair is on it. Every enemy rolls its own speed and rhythm, so no two
## walk alike.

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
## The robot to show (EnemyModel); empty, or failing to load, shows the
## placeholder capsule.
var model_path := ""
var model_scale := 1.0
## Flyers hover: no gravity, and a sphere at the top of `height` instead of
## a capsule standing on the floor.
var flying := false

var target: Player
var health := 0.0
var active := false
var last_hit_by := &"rifle"
## Stationary practice dummies: never move or attack.
var dummy := false
## Set before entering the tree: the level's speed multiplier.
var speed_scale := 1.0

# Steering, set per type in _configure().
## How far the wander may bend the path, in radians, when far from the player.
var wander_angle := 0.35
## Seconds between new wander targets (random in this range).
var wander_period := Vector2(0.6, 1.6)
## Sidestep speed and length; 0 speed means this type never jukes.
var juke_speed := 0.0
var juke_time := 0.3
## Seconds between jukes (random in this range).
var juke_cooldown := Vector2(2.5, 5.0)
## Chance per second of a juke while the player aims at it, and otherwise.
var juke_aimed_rate := 1.2
var juke_idle_rate := 0.08
## How hard it keeps its distance from other enemies.
var separation := 1.0

var hit_origin := Vector3.ZERO
var affected_left := 0.0
var shield_disabled := 0.0
var slow_left := 0.0
var slow_factor := 1.0
var burn_lock := 0.0
var control_lock := 0.0
var _dead := false
var _telegraph_left := 0.0
var _heading := Vector3.FORWARD
var _detour_dir := Vector3.ZERO
var _detour_left := 0.0
var _stagger_left := 0.0
var _flash_left := 0.0
var _rng := RandomNumberGenerator.new()
var _wander := 0.0
var _wander_target := 0.0
var _wander_left := 0.0
var _juke_vel := Vector3.ZERO
var _juke_left := 0.0
var _juke_cd := 0.0
var _body: Node3D
var _model: EnemyModel
var _glow_mats: Array[StandardMaterial3D] = []
var _pillar: MeshInstance3D
var _weak_shape_idx := -1


func _ready() -> void:
	_configure()
	_rng.randomize()
	# No two alike: each one walks a little faster or slower than its type.
	speed *= speed_scale * _rng.randf_range(0.9, 1.1)
	_juke_cd = _rng.randf_range(juke_cooldown.x * 0.5, juke_cooldown.y)
	_wander_target = _rng.randf_range(-wander_angle, wander_angle)
	health = max_health
	_telegraph_left = Tuning.spawn_telegraph * telegraph_scale
	collision_layer = 0 # not hittable until the telegraph finishes (§2)
	# Enemies stop at the player instead of walking into them; the player is
	# never body-blocked by enemies (their mask leaves this layer out).
	collision_mask = 1 | 2 | 4

	var shape := CollisionShape3D.new()
	if flying:
		var sphere := SphereShape3D.new()
		sphere.radius = radius
		shape.shape = sphere
		shape.position.y = height - radius
	else:
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
	affected_left = maxf(0.0, affected_left - delta)
	shield_disabled = maxf(0.0, shield_disabled - delta)
	slow_left = maxf(0.0, slow_left - delta)
	burn_lock = maxf(0.0, burn_lock - delta)
	control_lock = maxf(0.0, control_lock - delta)
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

	if flying:
		velocity.y = 0.0
	elif not is_on_floor():
		velocity.y -= Tuning.gravity * delta

	var to := target.global_position - global_position
	to.y = 0.0
	if _stagger_left > 0.0:
		_stagger_left -= delta
		_juke_vel = Vector3.ZERO
		_juke_left = 0.0
		velocity.x = 0.0
		velocity.z = 0.0
		move_and_slide()
		return

	var move_dir := _steer(delta, _act(delta, to), to)
	_tick_juke(delta, to)
	if _detour_left > 0.0:
		_detour_left -= delta
		_heading = _detour_dir
	elif move_dir.length() > 0.05:
		var angle := _heading.signed_angle_to(move_dir.normalized(), Vector3.UP)
		var step := clampf(angle, -turn_rate * delta, turn_rate * delta)
		_heading = _heading.rotated(Vector3.UP, step).normalized()
	var moving := move_dir.length() > 0.05 or _detour_left > 0.0
	var spd := speed * _speed_factor() * (slow_factor if slow_left > 0.0 else 1.0) if moving else 0.0
	velocity.x = _heading.x * spd + _juke_vel.x
	velocity.z = _heading.z * spd + _juke_vel.z
	move_and_slide()
	_face(to)
	if _model:
		var flat := Vector2(velocity.x, velocity.z).length()
		_model.locomote(flat > 0.3, flat / maxf(speed, 0.1))

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
	if stagger > 0.0 and _model:
		_model.action(&"Hit")
	if stagger > 0.0 and control_lock <= 0.0:
		_stagger_left = minf(stagger, 0.15 if kind == &"boss" else 0.6)
		control_lock = _stagger_left + 0.7
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


## Override: multiplies speed this tick (a rusher's surge, say).
func _speed_factor() -> float:
	return 1.0


## Bends the wanted direction: a wander that drifts smoothly toward a new
## random angle every second or so (not a per-frame jitter, which reads as
## twitching), fading out up close so a rusher still connects; plus a push
## away from any enemy within a few metres, so a wave spreads out instead
## of walking in single file.
func _steer(delta: float, wanted: Vector3, to: Vector3) -> Vector3:
	if wanted.length() < 0.05:
		return wanted
	_wander_left -= delta
	if _wander_left <= 0.0:
		_wander_left = _rng.randf_range(wander_period.x, wander_period.y)
		_wander_target = _rng.randf_range(-wander_angle, wander_angle)
	_wander = move_toward(_wander, _wander_target, 1.5 * delta)
	var near := clampf((to.length() - 3.0) / 8.0, 0.0, 1.0)
	var dir := wanted.normalized().rotated(Vector3.UP, _wander * near)
	if separation > 0.0:
		var push := Vector3.ZERO
		for node in get_tree().get_nodes_in_group("enemy"):
			var other := node as Enemy
			if other == self:
				continue
			var away := global_position - other.global_position
			away.y = 0.0
			var reach := radius + other.radius + 1.5
			var d := away.length()
			if d > 0.01 and d < reach:
				push += away / d * (1.0 - d / reach)
		dir += push * separation
	return dir.normalized() if dir.length() > 0.05 else wanted


## A juke is a sidestep across the player's line of fire, on top of the
## walk. It is likelier while the crosshair is on this enemy, so it reads
## as a dodge, but it has a cooldown, it is never on a stagger, and it only
## moves the body: aim is still at where the player is (§4).
func _tick_juke(delta: float, to: Vector3) -> void:
	if _juke_left > 0.0:
		_juke_left -= delta
		if _juke_left <= 0.0:
			_juke_vel = Vector3.ZERO
		return
	_juke_cd -= delta
	if juke_speed <= 0.0 or _juke_cd > 0.0 or to.length() < 2.5:
		return
	var rate := juke_aimed_rate if _player_aiming_at_me() else juke_idle_rate
	if _rng.randf() < rate * delta:
		juke(to)


func juke(to: Vector3) -> void:
	var side := to.normalized().cross(Vector3.UP)
	if _rng.randf() < 0.5:
		side = -side
	# Prefer the side that is not into a wall.
	if is_on_wall() and side.dot(get_wall_normal()) < 0.0:
		side = -side
	_juke_vel = side * juke_speed
	_juke_left = juke_time
	_juke_cd = _rng.randf_range(juke_cooldown.x, juke_cooldown.y)


func _player_aiming_at_me() -> bool:
	if target == null or target.camera == null:
		return false
	var cam := target.camera
	var to_me := global_position + Vector3(0.0, height * 0.5, 0.0) - cam.global_position
	return rad_to_deg((-cam.global_basis.z).angle_to(to_me)) < 8.0


## Override: set kind, numbers, and color.
func _configure() -> void:
	pass


## Override to add detail: builds the model under parent, or the
## placeholder capsule when there is no model.
func _build_body(parent: Node3D) -> void:
	if model_path != "":
		_model = EnemyModel.create(model_path, model_scale, color)
	if _model:
		parent.add_child(_model)
		_model.set_glow(1.2)
		if flying:
			_model.position.y = height - radius
		return
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
	if _model:
		_model.set_glow(energy)


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

## Control windows have a lockout so repeated grenades cannot stun-lock.
func apply_emp(duration: float, shield_bonus: float) -> void:
	affected_left = maxf(affected_left, duration)
	shield_disabled = maxf(shield_disabled, duration + shield_bonus)
	if control_lock > 0.0:
		return
	if kind == &"boss":
		slow_left = 1.0
		slow_factor = 0.7
		control_lock = 2.0
	else:
		_stagger_left = minf(duration, 3.2)
		control_lock = _stagger_left + 1.0
