class_name Projectile
extends Area3D
## An enemy bolt: slow enough to see, stopped by walls and cover, harmless
## during dash invulnerability (Player.take_damage handles that).

var damage := 12.0
var speed := 18.0
var direction := Vector3.FORWARD
var color := Color.WHITE
var source := "an enemy"
var _life := 4.0
var _near_checked := false
var _spent := false


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
	mesh.mesh = Blockout.shared([&"bolt_mesh"], func() -> SphereMesh:
		var ball := SphereMesh.new()
		ball.radius = 0.22
		ball.height = 0.44
		return ball)
	mesh.material_override = Blockout.shared([&"bolt", color], func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = color.lightened(0.4)
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 5.0
		return mat)
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	if _spent:
		return
	var end := global_position + direction * speed * delta
	var ray := PhysicsRayQueryParameters3D.create(global_position, end, 1 | 2)
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		_on_body_entered(hit.collider)
		return
	if not _near_checked:
		for node in get_tree().get_nodes_in_group("player"):
			var p := node as Player
			var closest := Geometry3D.get_closest_point_to_segment(p.global_position + Vector3.UP * 1.2, global_position, end)
			if closest.distance_to(p.global_position + Vector3.UP * 1.2) < 1.4 and p.is_dashing():
				p.near_miss()
				_near_checked = true
	global_position = end
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if _spent:
		return
	_spent = true
	if body is Player:
		(body as Player).take_damage(damage, source)
	queue_free()
