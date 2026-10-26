class_name ShieldRobot
extends Heavy
## Frontal mitigation, not immunity: the starter arsenal always remains viable.
var _shield: MeshInstance3D

func _configure() -> void:
	super()
	kind = &"shield"
	display_name = "a shield robot"
	max_health = 180.0
	speed = 3.0
	points = 250
	color = Color(0.15, 0.55, 1.0)
	melee_damage = 22.0

func _build_body(parent: Node3D) -> void:
	super(parent)
	_shield = MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(2.0, 1.5, 0.12)
	_shield.mesh = box
	_shield.position = Vector3(0, 1.3, -1.05)
	var material := _glow_mat(color, 1.2)
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.albedo_color.a = 0.45
	_shield.material_override = material
	parent.add_child(_shield)

func _physics_process(delta: float) -> void:
	super(delta)
	if is_instance_valid(_shield):
		_shield.visible = shield_disabled <= 0.0

func take_hit(amount: float, shape_idx: int, source: StringName, stagger: float) -> String:
	var facing := -_body.global_basis.z
	var incoming := (hit_origin - global_position).normalized()
	if shield_disabled <= 0.0 and shape_idx != _weak_shape_idx and facing.dot(incoming) > 0.35:
		amount *= 0.35
	return super(amount, shape_idx, source, stagger)
