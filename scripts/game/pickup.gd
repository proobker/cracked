class_name AmmoPickup
extends Area3D
## Ammo dropped by a kill (§5). Walk over it to collect.

var amount := 15
var _mesh: MeshInstance3D


func _ready() -> void:
	collision_layer = 8
	collision_mask = 2
	monitoring = true

	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 1.0
	shape.shape = sphere
	add_child(shape)

	_mesh = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.35, 0.2, 0.25)
	_mesh.mesh = box
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 1.0, 0.4)
	mat.emission_enabled = true
	mat.emission = Color(0.3, 1.0, 0.4)
	mat.emission_energy_multiplier = 2.0
	_mesh.material_override = mat
	add_child(_mesh)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_mesh.rotate_y(2.0 * delta)


func _on_body_entered(body: Node3D) -> void:
	if body.has_method("collect_ammo"):
		body.collect_ammo(amount)
		queue_free()
