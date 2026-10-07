class_name AmmoPickup
extends Area3D
## Ammo dropped by a kill (§5), colored by the weapon it feeds. Walk over it
## to collect.

var kind := &"rifle"
var amount := 20
var color := Color(0.3, 1.0, 0.4)
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
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 2.5
	_mesh.material_override = mat
	add_child(_mesh)

	body_entered.connect(_on_body_entered)


func _process(delta: float) -> void:
	_mesh.rotate_y(2.0 * delta)


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).collect_ammo(kind, amount)
		Audio.play(&"pickup")
		queue_free()
