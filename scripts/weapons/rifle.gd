class_name Rifle
extends Weapon
## The all-rounder (§5): full-auto, 30 rounds, damage drops off at range.
## Hold and control: the first shot is accurate, a held trigger climbs and
## blooms, and short bursts stay tight.


func _init() -> void:
	kind = &"rifle"
	weapon_name = "RIFLE"
	color = Color(0.2, 0.9, 1.0)
	mag_size = 30
	reserve_max = 180
	reserve_start = 90
	pickup_amount = 20
	fire_interval = 0.1
	automatic = true
	damage = 18.0
	falloff_start = 20.0
	falloff_end = 45.0
	falloff_min = 0.5
	reload_time = 1.6
	spread_deg = 0.5
	spread_crouched_deg = 0.25
	bloom_per_shot = 0.22
	bloom_max = 2.4
	bloom_decay = 7.0
	move_spread_deg = 1.0
	air_spread_deg = 2.0
	kick_deg = 0.32
	recoil_yaw_deg = 0.22
	recoil_recover = 7.0
	shake = 0.06
	tracer_width = 0.022
	tracer_life = 0.05


## Silhouette: long and flat, with a box magazine.
func _build_model() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.17, -0.14, -0.36)
	var body := _body_mat()
	_part(root, Vector3(0.09, 0.12, 0.6), Vector3.ZERO, body) # receiver
	_part(root, Vector3(0.04, 0.04, 0.35), Vector3(0.0, 0.02, -0.45), body) # barrel
	_part(root, Vector3(0.06, 0.18, 0.07), Vector3(0.0, -0.13, 0.05), body) # magazine
	_part(root, Vector3(0.095, 0.015, 0.5), Vector3(0.0, 0.065, 0.0), _trim_mat()) # rail
	muzzle = Vector3(0.0, 0.02, -0.63)
	return root
