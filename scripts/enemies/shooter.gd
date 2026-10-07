class_name Shooter
extends Enemy
## Spacing (§6). Holds a band of range and fires slow, visible bolts at where
## the player is — never where they will be (§4). Cover and breaking line of
## sight are the answer. Teaches: keep moving, deny it a clean line.

const RANGE_MIN := 10.0
const RANGE_MAX := 18.0
const FIRE_INTERVAL := 1.8
const WINDUP := 0.4 # it glows before it fires
const BOLT_DAMAGE := 12.0
const BOLT_SPEED := 18.0

var _fire_left := 1.2
var _winding := false


func _configure() -> void:
	kind = &"shooter"
	display_name = "a shooter"
	color = Color(0.65, 1.0, 0.1)
	max_health = 60.0
	speed = 4.0
	turn_rate = 4.0
	points = 150
	radius = 0.35
	height = 2.1


func _build_body(parent: Node3D) -> void:
	super(parent)
	_visor(parent, 0.5, 1.75, -0.32)
	var gun := BoxMesh.new()
	gun.size = Vector3(0.12, 0.12, 0.7)
	_mesh(parent, gun, Vector3(0.38, 1.2, -0.35), _glow_mat(color, 1.2))


func _act(delta: float, to: Vector3) -> Vector3:
	var dist := to.length()
	var eye := global_position + Vector3(0.0, 1.5, 0.0)
	var aim := target.global_position + Vector3(0.0, 1.2, 0.0)
	var sees := _has_line_of_sight(eye, aim)

	_fire_left -= delta
	if sees and _fire_left <= WINDUP and not _winding:
		_winding = true
		_set_glow(3.5)
	if _fire_left <= 0.0:
		_winding = false
		_set_glow(1.2)
		_fire_left = FIRE_INTERVAL
		if sees and not target.dead:
			_fire_projectile(eye, aim, BOLT_DAMAGE, BOLT_SPEED)

	if dist > RANGE_MAX or not sees:
		return to
	if dist < RANGE_MIN:
		return -to
	return Vector3.ZERO


## Shooters always face the player, so the windup glow reads.
func _face(to: Vector3) -> void:
	if to.length() > 0.05:
		rotation.y = atan2(-to.x, -to.z)
