class_name Shotgun
extends Weapon
## Close-range brawl (§5): pump action, six shells, huge up close and useless
## past arm's length. A slow, total reload. The panic button, so it staggers.


func _init() -> void:
	kind = &"shotgun"
	weapon_name = "SHOTGUN"
	color = Color(1.0, 0.55, 0.1)
	mag_size = 6
	reserve_max = 30
	reserve_start = 12
	pickup_amount = 4
	fire_interval = 0.85 # the pump
	automatic = false
	damage = 14.0
	pellets = 9
	falloff_start = 4.0
	falloff_end = 12.0
	falloff_min = 0.05
	reload_time = 2.4
	spread_deg = 5.0
	spread_crouched_deg = 4.0
	kick_deg = 2.5
	stagger = 0.35


## Silhouette: short and fat, a wide barrel over a pump grip.
func _build_model() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.17, -0.15, -0.34)
	var body := _body_mat()
	_part(root, Vector3(0.12, 0.14, 0.45), Vector3.ZERO, body) # receiver
	_part(root, Vector3(0.1, 0.1, 0.32), Vector3(0.0, 0.03, -0.36), body) # barrel
	_part(root, Vector3(0.13, 0.08, 0.16), Vector3(0.0, -0.06, -0.3), _trim_mat()) # pump
	return root
