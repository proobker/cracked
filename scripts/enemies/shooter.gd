class_name Shooter
extends Enemy
## Spacing (§6). Holds a band of range and fires slow, visible bolts at where
## the player is — never where they will be (§4). Cover and breaking line of
## sight are the answer. Teaches: keep moving, deny it a clean line.
##
## Inside its band it strafes: it drifts sideways around the player, picks
## a new side or stops for a beat every couple of seconds, and settles at a
## range of its own. It plants and holds still while it charges, so the
## windup glow is always readable, then moves again.

const RANGE_MIN := 10.0
const RANGE_MAX := 18.0
const FIRE_INTERVAL := 1.8
const WINDUP := 0.4 # it glows before it fires
const BOLT_DAMAGE := 12.0
const BOLT_SPEED := 18.0

var _fire_left := 1.2
var _winding := false
var _preferred := 14.0
var _strafe_side := 1.0
var _strafe_left := 0.0


func _configure() -> void:
	kind = &"shooter"
	display_name = "a shooter"
	color = Color(0.65, 1.0, 0.1)
	max_health = 60.0
	speed = 4.0
	turn_rate = 4.0
	points = 150
	# An eye drone: it hovers at head height, so its hitbox is a sphere up
	# there and nothing below it.
	model_path = "res://models/enemies/Enemy_EyeDrone.gltf"
	model_scale = 1.1
	flying = true
	radius = 0.55
	height = 2.1
	wander_angle = 0.25
	juke_speed = 7.0
	juke_time = 0.3
	juke_cooldown = Vector2(2.5, 5.0)
	juke_aimed_rate = 1.0
	juke_idle_rate = 0.05
	_preferred = randf_range(RANGE_MIN + 1.0, RANGE_MAX - 1.0)
	_fire_left = randf_range(0.9, 1.8) # a wave's shooters do not fire in unison


func _build_body(parent: Node3D) -> void:
	super(parent)
	if _model == null:
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
		if _model:
			_model.action(&"Charging")
	if _fire_left <= 0.0:
		_winding = false
		_set_glow(1.2)
		_fire_left = FIRE_INTERVAL * _rng.randf_range(0.85, 1.2)
		if sees and not target.dead:
			_fire_projectile(eye, aim, BOLT_DAMAGE, BOLT_SPEED)
			if _model:
				_model.action(&"Attack")

	if _winding:
		_juke_cd = maxf(_juke_cd, 0.3) # no dodging out of its own windup
		return Vector3.ZERO # planted while charging
	if dist > RANGE_MAX or not sees:
		return to
	if dist < RANGE_MIN:
		return -to

	_strafe_left -= delta
	var tangent := to.normalized().cross(Vector3.UP)
	if is_on_wall() and (tangent * _strafe_side).dot(get_wall_normal()) < -0.3:
		_strafe_side = -_strafe_side # strafing into a wall: go the other way
		_strafe_left = _rng.randf_range(1.0, 2.8)
	elif _strafe_left <= 0.0:
		_strafe_left = _rng.randf_range(1.0, 2.8)
		var roll := _rng.randf()
		if roll < 0.2:
			_strafe_side = 0.0 # hover for a beat
		elif roll < 0.6 or _strafe_side == 0.0:
			_strafe_side = -_strafe_side if _strafe_side != 0.0 else (1.0 if _rng.randf() < 0.5 else -1.0)
		if _rng.randf() < 0.3:
			_preferred = _rng.randf_range(RANGE_MIN + 1.0, RANGE_MAX - 1.0)
	var side := tangent * _strafe_side
	# Ease toward its own preferred range while circling.
	var radial := to.normalized() * clampf((dist - _preferred) / 3.0, -1.0, 1.0)
	return side + radial * 0.7


## Shooters always face the player, so the windup glow reads.
func _face(to: Vector3) -> void:
	if to.length() > 0.05:
		rotation.y = atan2(-to.x, -to.z)
