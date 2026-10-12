class_name Boss
extends Heavy
## The boss of every tenth level, built to §7's floor: a single large enemy
## that advances slowly, soaks damage like a heavy, and adds exactly one new
## thing — a ranged volley. No new AI, no new navigation.

const VOLLEY_INTERVAL := 3.2
const VOLLEY_BOLTS := 5
const VOLLEY_SPREAD_DEG := 9.0
const BOLT_DAMAGE := 14.0
const BOLT_SPEED := 15.0

## Set by the level before spawning: level 20's boss is 1.0 (§7's floor).
var health_scale := 1.0
var _volley_left := 2.5


func _configure() -> void:
	super()
	kind = &"boss"
	display_name = "the boss"
	color = Color(1.0, 0.1, 0.2)
	max_health = 2600.0 * health_scale
	speed = 2.2
	turn_rate = 0.9
	points = 5000
	model_scale = 1.35
	radius = 1.6
	height = 3.4
	telegraph_scale = 2.5
	melee_range = 3.4
	melee_damage = 45.0


func _act(delta: float, to: Vector3) -> Vector3:
	_volley_left -= delta
	if _volley_left <= 0.0:
		_volley_left = VOLLEY_INTERVAL
		var from := global_position + Vector3(0.0, height * 0.8, 0.0)
		var aim := target.global_position + Vector3(0.0, 1.2, 0.0)
		if _has_line_of_sight(from, aim) and not target.dead:
			var forward := (aim - from).normalized()
			for i in VOLLEY_BOLTS:
				var t := float(i) / float(VOLLEY_BOLTS - 1) - 0.5
				var dir := forward.rotated(Vector3.UP, deg_to_rad(VOLLEY_SPREAD_DEG * 2.0 * t))
				_fire_projectile(from, from + dir, BOLT_DAMAGE, BOLT_SPEED)
			if _model:
				_model.action(&"AttackAuto")
	return super(delta, to)
