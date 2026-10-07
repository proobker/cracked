class_name Marksman
extends Weapon
## Long-range precision (§5): semi-auto, five rounds, the highest damage per
## shot, no falloff, and a slow recovery so a panic miss is felt. Wild from
## the hip; exact through the scope.


func _init() -> void:
	kind = &"marksman"
	weapon_name = "MARKSMAN"
	color = Color(0.75, 0.4, 1.0)
	mag_size = 5
	reserve_max = 25
	reserve_start = 10
	pickup_amount = 3
	fire_interval = 0.9
	automatic = false
	damage = 110.0
	falloff_start = 1000.0
	falloff_end = 2000.0
	falloff_min = 1.0
	reload_time = 2.0
	spread_deg = 3.0
	spread_crouched_deg = 2.0
	spread_scoped_deg = 0.0
	kick_deg = 3.0
	score_mult = 1.25
	can_scope = true
	scoped_fov = 30.0


## Silhouette: very long and thin, with a scope on top.
func _build_model() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.16, -0.14, -0.38)
	var body := _body_mat()
	_part(root, Vector3(0.07, 0.1, 0.7), Vector3.ZERO, body) # stock and receiver
	_part(root, Vector3(0.03, 0.03, 0.5), Vector3(0.0, 0.01, -0.58), body) # long barrel
	_part(root, Vector3(0.05, 0.05, 0.28), Vector3(0.0, 0.09, -0.05), _trim_mat()) # scope
	return root
