class_name CoinPickup
extends Node3D
## Attempt-local coins. Banking belongs to Game, never to this visual pickup.
signal collected(amount: int)
var amount := 1
var player: Player
var claimed := false

func _ready() -> void:
	add_to_group("coin")
	var mesh := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = 0.22
	shape.bottom_radius = 0.22
	shape.height = 0.12
	mesh.mesh = shape
	mesh.rotation_degrees.x = 90
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.8, 0.1)
	mesh.material_override = mat
	add_child(mesh)

func _process(delta: float) -> void:
	rotate_y(delta * 2.0)
	if claimed or not is_instance_valid(player) or player.dead:
		return
	var destination := player.global_position + Vector3.UP * 0.6
	if position.distance_to(destination) < 4.0:
		position = position.move_toward(destination, delta * 10.0)
	if position.distance_to(destination) < 1.0:
		claim()

func claim() -> void:
	if claimed:
		return
	claimed = true
	collected.emit(amount)
	queue_free()
