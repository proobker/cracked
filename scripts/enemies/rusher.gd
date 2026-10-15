class_name Rusher
extends Enemy
## Pressure (§6). Runs at the player on a weaving line, turning slowly so it
## overshoots a good slide, and hits on contact. Every few seconds it surges
## for a burst of speed, and it jukes sideways when it is being aimed at.
## Teaches: do not stand still, and track what you shoot.

const MELEE_RANGE := 1.7
const MELEE_DAMAGE := 20.0
const MELEE_COOLDOWN := 1.0

const SURGE_MULT := 1.45
const SURGE_TIME := 0.7

var _melee_left := 0.0
var _surge_left := 0.0
var _surge_cd := 0.0


func _configure() -> void:
	kind = &"rusher"
	display_name = "a rusher"
	color = Color(1.0, 0.15, 0.6)
	max_health = 50.0
	speed = 5.5
	turn_rate = 2.4
	points = 100
	# A four-legged runner: low and wide, so the capsule is too.
	model_path = "res://models/enemies/Enemy_QuadShell.gltf"
	model_scale = 0.8
	radius = 0.6
	height = 1.3
	wander_angle = 0.6
	wander_period = Vector2(0.5, 1.3)
	juke_speed = 8.5
	juke_time = 0.28
	juke_cooldown = Vector2(2.0, 4.5)
	juke_aimed_rate = 1.4
	juke_idle_rate = 0.15
	_surge_cd = randf_range(1.5, 4.0)


func _build_body(parent: Node3D) -> void:
	super(parent)
	if _model == null:
		_visor(parent, 0.6, 1.45, -0.4)


func _act(delta: float, to: Vector3) -> Vector3:
	_surge_left -= delta
	_surge_cd -= delta
	if _surge_cd <= 0.0 and to.length() > 5.0:
		_surge_left = SURGE_TIME
		_surge_cd = _rng.randf_range(3.0, 6.0)
	_melee_left -= delta
	if to.length() < MELEE_RANGE and _melee_left <= 0.0 and not target.dead:
		target.take_damage(MELEE_DAMAGE, display_name)
		Audio.play_at(&"melee", global_position)
		if _model:
			_model.action(&"Attack")
		_melee_left = MELEE_COOLDOWN
	return to


func _speed_factor() -> float:
	return SURGE_MULT if _surge_left > 0.0 else 1.0
