class_name Rusher
extends Enemy
## Pressure (§6). Walks straight at the player, turning slowly so it
## overshoots a good slide, and hits on contact. Teaches: do not stand still.

const MELEE_RANGE := 1.7
const MELEE_DAMAGE := 20.0
const MELEE_COOLDOWN := 1.0

var _melee_left := 0.0


func _configure() -> void:
	kind = &"rusher"
	display_name = "a rusher"
	color = Color(1.0, 0.15, 0.6)
	max_health = 50.0
	speed = 5.5
	turn_rate = 2.4
	points = 100


func _build_body(parent: Node3D) -> void:
	super(parent)
	_visor(parent, 0.6, 1.45, -0.4)


func _act(delta: float, to: Vector3) -> Vector3:
	_melee_left -= delta
	if to.length() < MELEE_RANGE and _melee_left <= 0.0 and not target.dead:
		target.take_damage(MELEE_DAMAGE, display_name)
		Audio.play_at(&"melee", global_position)
		_melee_left = MELEE_COOLDOWN
	return to
