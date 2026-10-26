class_name ExpansionWeapon
extends Weapon
## Shared ammo/feel contract with distinct firing mechanisms and silhouettes.
var charge := 0.0
var _burst := 0
var _held := false

func _init(id := "smg") -> void:
	kind = StringName(id)
	weapon_name = id.to_upper()
	var index := maxi(0, ["smg", "burst", "lmg", "plasma", "railgun", "arc"].find(id))
	color = Color.from_hsv(0.12 + index * 0.13, 0.75, 1.0)
	mag_size = [36, 24, 70, 5, 4, 40][index]
	reserve_max = mag_size * 5
	reserve_start = mag_size * 3
	pickup_amount = maxi(2, mag_size / 2)
	damage = [11.0, 22.0, 19.0, 95.0, 160.0, 12.0][index]
	fire_interval = [0.06, 0.09, 0.12, 0.8, 0.9, 0.14][index]
	reload_time = [1.3, 1.8, 3.5, 2.6, 2.8, 2.0][index]
	spread_deg = [1.2, 0.3, 0.8, 0.1, 0.0, 0.2][index]
	falloff_start = 9.0 if id == "smg" else 25.0
	falloff_end = 22.0 if id == "smg" else 65.0
	move_spread_deg = 0.4 if id == "smg" else (2.4 if id == "lmg" else 0.8)
	bloom_per_shot = 0.15
	bloom_max = 3.0
	kick_deg = 0.2 if id == "smg" else 0.4
	can_scope = id in ["burst", "railgun"]
	sound_kind = &"marksman" if id == "railgun" else (&"shotgun" if id == "plasma" else &"rifle")
	sound_pitch = [1.35, 1.1, 0.75, 0.65, 0.8, 1.7][index]

func tick(delta: float, trigger: bool, reload_pressed: bool, crouched: bool) -> Vector2:
	var firing := trigger
	if kind == &"railgun":
		charge = minf(0.7, charge + delta) if trigger and not reloading and mag > 0 and _cooldown <= 0.0 else 0.0
		firing = charge >= 0.7
		if firing:
			charge = 0.0
	elif kind == &"burst":
		if trigger and not _held and not reloading and _cooldown <= 0.0:
			_burst = 3
		firing = _burst > 0
		if reload_pressed or mag == 0:
			_burst = 0
	_held = trigger
	var before := mag
	var kick := super.tick(delta, firing, reload_pressed, crouched)
	if kind == &"burst" and mag < before:
		_burst -= 1
		if _burst == 0:
			_cooldown = 0.35
	return kick

func set_equipped(on: bool) -> void:
	charge = 0.0
	_burst = 0
	_held = true
	super(on)

func _shoot() -> String:
	if kind == &"plasma":
		var ball := Ordnance.new()
		ball.kind = kind
		ball.position = camera.global_position
		ball.motion = -camera.global_basis.z * 24.0
		ball.player = wielder
		ball.effects = effects.duplicate()
		fx_parent.add_child(ball)
		return "miss"
	if kind == &"railgun":
		return _rail()
	if kind == &"arc":
		return _arc()
	return super._shoot()

func _rail() -> String:
	var from := camera.global_position
	var to := from - camera.global_basis.z * 200.0
	var excluded: Array[RID] = []
	var best := "miss"
	for _i in 8:
		var query := PhysicsRayQueryParameters3D.create(from, to, 1 | 4, excluded)
		var hit := get_world_3d().direct_space_state.intersect_ray(query)
		if hit.is_empty():
			break
		if not hit.collider is Enemy:
			to = hit.position
			break
		var enemy := hit.collider as Enemy
		var result := Combat.hit(enemy, damage, hit.shape, kind, from, wielder, effects, shot_stagger)
		if RANK.get(result, 0) > RANK[best]:
			best = result
		excluded.append(enemy.get_rid())
	ShotFx.tracer(fx_parent, camera.global_position, to, color, 0.06, 0.16)
	return best

func _arc() -> String:
	var from := camera.global_position
	var query := PhysicsRayQueryParameters3D.create(from, from - camera.global_basis.z * 16.0, 1 | 4)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or not hit.collider is Enemy:
		return "miss"
	var next := hit.collider as Enemy
	var visited: Array = []
	var best := "miss"
	for _hop in 4:
		if next == null:
			break
		visited.append(next)
		var end := next.global_position + Vector3.UP * next.height * 0.6
		var result := Combat.hit(next, damage, -1, kind, from, wielder, effects, shot_stagger)
		if RANK.get(result, 0) > RANK[best]:
			best = result
		ShotFx.tracer(fx_parent, from, end, color, 0.04, 0.1)
		from = end
		next = null
		var nearest := 6.0
		for node in get_tree().get_nodes_in_group("enemy"):
			var candidate := node as Enemy
			var center := candidate.global_position + Vector3.UP * candidate.height * 0.6
			var distance := from.distance_to(center)
			if candidate.active and not candidate._dead and not visited.has(candidate) and distance < nearest and Combat.visible(self, from, center):
				nearest = distance
				next = candidate
	return best

func _build_model() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.18, -0.14, -0.36)
	var length := 0.35 if kind == &"smg" else (0.9 if kind == &"railgun" else 0.6)
	var width := 0.18 if kind in [&"lmg", &"plasma"] else 0.09
	_part(root, Vector3(width, 0.12, length), Vector3.ZERO, _body_mat())
	_part(root, Vector3(width * 0.7, 0.2, 0.12), Vector3(0, -0.12, 0.06), _body_mat())
	var rails := 2 if kind in [&"arc", &"railgun"] else 1
	for i in rails:
		_part(root, Vector3(0.025, 0.025, length + 0.2), Vector3((i - (rails - 1) * 0.5) * 0.13, 0.08, -0.1), _trim_mat())
	if kind == &"plasma":
		_part(root, Vector3(0.22, 0.2, 0.2), Vector3(0, 0, -length / 2.0), _trim_mat())
	muzzle = Vector3(0, 0.05, -length / 2.0 - 0.2)
	return root
