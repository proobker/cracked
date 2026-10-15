class_name Heavy
extends Enemy
## Priority target (§6). Slow, huge, soaks damage, and turns toward you at a
## crawl, with a glowing weak point on its back that takes triple damage.
## Teaches: aim for the weak point, or flank.

## Where the weak point sits, as a fraction of height.
const WEAK_HEIGHT := 0.7

var melee_range := 2.4
var melee_damage := 35.0
var melee_cooldown := 1.4
var _melee_left := 0.0


func _configure() -> void:
	kind = &"heavy"
	display_name = "a heavy"
	color = Color(1.0, 0.35, 0.05)
	max_health = 420.0
	speed = 2.6
	turn_rate = 1.2
	points = 400
	telegraph_scale = 1.5
	# A trilobite walker, as wide as it is tall.
	model_path = "res://models/enemies/Enemy_Trilobite.gltf"
	model_scale = 1.0
	radius = 1.1
	height = 2.5
	# Lumbers: a slight sway, no dodging, and a wide berth from the others.
	wander_angle = 0.2
	wander_period = Vector2(1.5, 3.0)
	separation = 1.5


func _build_body(parent: Node3D) -> void:
	super(parent)
	if _model == null:
		var shoulders := BoxMesh.new()
		shoulders.size = Vector3(radius * 3.0, 0.5, radius * 1.4)
		_mesh(parent, shoulders, Vector3(0.0, height * 0.75, 0.0), _glow_mat(color, 1.2))
		_visor(parent, radius * 1.2, height * 0.85, -radius * 0.75)
	# The weak point sits on its back (+z, since it faces -z).
	_add_weak_point(Vector3(radius * 1.1, 0.6, 0.3), Vector3(0.0, height * WEAK_HEIGHT, radius * 0.95))


func _act(delta: float, to: Vector3) -> Vector3:
	_melee_left -= delta
	if to.length() < melee_range and _melee_left <= 0.0 and not target.dead:
		target.take_damage(melee_damage, display_name)
		Audio.play_at(&"melee", global_position)
		if _model:
			_model.action(&"Attack")
		_melee_left = melee_cooldown
	return to
