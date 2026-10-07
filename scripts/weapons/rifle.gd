class_name Rifle
extends Weapon
## The all-rounder (§5): full-auto, 30 rounds, damage drops off at range.


func _init() -> void:
	weapon_name = "Rifle"
	mag_size = 30
	reserve_max = 180
	fire_interval = 0.1
	automatic = true
	damage = 18.0
	falloff_start = 20.0
	falloff_end = 45.0
	falloff_min = 0.5
	reload_time = 1.6
	spread_deg = 1.2
	spread_crouched_deg = 0.5


func _build_model() -> Node3D:
	var root := Node3D.new()
	root.position = Vector3(0.28, -0.24, -0.45)
	var body_mat := StandardMaterial3D.new()
	body_mat.albedo_color = Color(0.12, 0.13, 0.18)
	var trim_mat := StandardMaterial3D.new()
	trim_mat.albedo_color = Color(0.2, 0.9, 1.0)
	trim_mat.emission_enabled = true
	trim_mat.emission = Color(0.2, 0.9, 1.0)
	trim_mat.emission_energy_multiplier = 2.0
	_part(root, Vector3(0.09, 0.12, 0.6), Vector3.ZERO, body_mat) # receiver
	_part(root, Vector3(0.04, 0.04, 0.35), Vector3(0.0, 0.02, -0.45), body_mat) # barrel
	_part(root, Vector3(0.06, 0.18, 0.07), Vector3(0.0, -0.13, 0.05), body_mat) # magazine
	_part(root, Vector3(0.095, 0.015, 0.5), Vector3(0.0, 0.065, 0.0), trim_mat) # neon rail
	return root


func _part(parent: Node3D, size: Vector3, pos: Vector3, mat: Material) -> void:
	var mesh := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	mesh.position = pos
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mesh)
