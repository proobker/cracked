class_name Ordnance
extends Node3D
## Swept world projectile. A single integration routine also draws the preview.
var kind: StringName = &"frag"
var motion := Vector3.ZERO
var fuse := 1.8
var player: Player
var effects := {}
var _field := false
var _tick := 0.0
var _mesh: MeshInstance3D

func _ready() -> void:
	add_to_group("ordnance")
	_mesh = MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 0.13
	sphere.height = 0.26
	_mesh.mesh = sphere
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color(0.2, 0.8, 1.0) if kind == &"emp" else Color(1.0, 0.4, 0.1)
	_mesh.material_override = material
	add_child(_mesh)
	if kind == &"plasma":
		fuse = 3.0

static func step(world: Node3D, at: Vector3, velocity: Vector3, delta: float, plasma := false) -> Dictionary:
	var next_velocity := velocity + (Vector3.ZERO if plasma else Vector3.DOWN * 14.0 * delta)
	var end := at + next_velocity * delta
	var query := PhysicsRayQueryParameters3D.create(at, end, 1 | (4 if plasma else 0))
	var collision := world.get_world_3d().direct_space_state.intersect_ray(query)
	if not collision.is_empty():
		end = collision.position + collision.normal * 0.04
		next_velocity = next_velocity.bounce(collision.normal) * 0.55
	return {"position": end, "velocity": next_velocity, "hit": not collision.is_empty()}

func _physics_process(delta: float) -> void:
	fuse -= delta
	if _field:
		_tick -= delta
		if _tick <= 0.0:
			_tick = 0.25
			_burn()
		if fuse <= 0.0:
			queue_free()
		return
	var state := step(self, global_position, motion, delta, kind == &"plasma")
	global_position = state.position
	motion = state.velocity
	if fuse <= 0.0 or (kind == &"plasma" and state.hit):
		if kind == &"incendiary":
			_field = true
			fuse = 4.0 * (1.0 + 0.2 * float(effects.get("burn_duration", 0)))
			_mesh.scale = Vector3(22.0, 1.0, 22.0)
			var fields := get_tree().get_nodes_in_group("burn_field")
			if fields.size() >= 8:
				fields[0].queue_free()
			add_to_group("burn_field")
		else:
			Combat.explode(get_parent(), global_position, kind, player, effects, 4.0 if kind == &"plasma" else 5.0, 95.0 if kind == &"plasma" else 110.0)
			queue_free()

func _burn() -> void:
	var radius := 3.0 * (1.0 + 0.08 * float(effects.get("blast_radius", 0)))
	for node in get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		var center := enemy.global_position + Vector3.UP
		if center.distance_to(global_position) <= radius and Combat.visible(self, global_position + Vector3.UP * 0.1, center):
			enemy.affected_left = 1.0
			enemy.slow_left = 0.4
			enemy.slow_factor = 1.0 - 0.08 * float(effects.get("burn_slow", 0))
			# Per-target interval shared across all fields prevents overlap stacking.
			if enemy.burn_lock <= 0.0:
				enemy.burn_lock = 0.24
				Combat.hit(enemy, 9.0, -1, &"incendiary", global_position, player, effects)
	if is_instance_valid(player) and player.global_position.distance_to(global_position) < radius and player.burn_lock <= 0.0 and Combat.visible(self, global_position + Vector3.UP * 0.1, player.global_position + Vector3.UP):
		player.burn_lock = 0.24
		player.take_damage(4.0, "your incendiary")
