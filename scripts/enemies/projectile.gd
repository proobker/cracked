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


func _ready() -> void:
	collision_layer = 0
	collision_mask = 1 | 2
	var shape := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.22
	shape.shape = sphere
	add_child(shape)

	var mesh := MeshInstance3D.new()
	var ball := SphereMesh.new()
	ball.radius = 0.22
	ball.height = 0.44
	mesh.mesh = ball
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = color.lightened(0.4)
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = 5.0
	mesh.material_override = mat
	add_child(mesh)

	body_entered.connect(_on_body_entered)


func _physics_process(delta: float) -> void:
	global_position += direction * speed * delta
	_life -= delta
	if _life <= 0.0:
		queue_free()


func _on_body_entered(body: Node3D) -> void:
	if body is Player:
		(body as Player).take_damage(damage, source)
	queue_free()
