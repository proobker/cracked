class_name ShotFx
## The world side of a shot: tracers and impacts. Each is a short-lived node
## that fades and frees itself. Meshes and materials are shared (Blockout.shared)
## and a fade is the instance's transparency, so a shot allocates no resources.


## A thin bright line from the muzzle to where the shot ended.
static func tracer(parent: Node3D, from: Vector3, to: Vector3, color: Color, width: float, life: float) -> void:
	var length := from.distance_to(to)
	if length < 0.3:
		return
	var inst := MeshInstance3D.new()
	inst.mesh = _box(1.0)
	inst.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	inst.material_override = _glow_mat(color.lerp(Color.WHITE, 0.4))
	parent.add_child(inst)
	var up := Vector3.UP if absf((to - from).normalized().y) < 0.95 else Vector3.RIGHT
	inst.look_at_from_position((from + to) / 2.0, to, up)
	inst.scale = Vector3(width, width, length)
	var tween := inst.create_tween()
	tween.tween_property(inst, "transparency", 1.0, life)
	tween.tween_callback(inst.queue_free)


## Sparks where a shot lands. On the world they are the gun's colour and
## leave a glowing mark that fades; on an enemy they are the enemy's
## colour, and a kill throws a bigger burst.
static func impact(parent: Node3D, at: Vector3, normal: Vector3, color: Color, big := false, mark := false) -> void:
	var sparks := CPUParticles3D.new()
	sparks.one_shot = true
	sparks.explosiveness = 1.0
	sparks.amount = 22 if big else 8
	sparks.lifetime = 0.45 if big else 0.28
	sparks.direction = Vector3.FORWARD
	sparks.spread = 55.0
	sparks.initial_velocity_min = 3.0 if big else 2.0
	sparks.initial_velocity_max = 8.0 if big else 5.0
	sparks.gravity = Vector3(0.0, -12.0, 0.0)
	sparks.scale_amount_min = 0.6
	sparks.scale_amount_max = 1.4
	sparks.mesh = _box(0.06 if big else 0.04)
	sparks.material_override = _glow_mat(color.lerp(Color.WHITE, 0.3))
	parent.add_child(sparks)
	var n := normal.normalized() if normal.length() > 0.01 else Vector3.UP
	var up := Vector3.UP if absf(n.y) < 0.95 else Vector3.RIGHT
	sparks.look_at_from_position(at + n * 0.05, at + n, up)
	sparks.emitting = true
	sparks.create_tween().tween_callback(sparks.queue_free).set_delay(sparks.lifetime + 0.3)
	if not mark:
		return
	var dot := MeshInstance3D.new()
	dot.mesh = Blockout.shared([&"fx_mark"], func() -> QuadMesh:
		var quad := QuadMesh.new()
		quad.size = Vector2(0.14, 0.14)
		return quad)
	dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	dot.material_override = _glow_mat(color)
	parent.add_child(dot)
	# A quad faces +z; turn it to face out of the surface.
	dot.look_at_from_position(at + n * 0.02, at + n * 0.02 - n, up)
	var tween := dot.create_tween()
	tween.tween_property(dot, "transparency", 1.0, 1.6).set_delay(0.3)
	tween.tween_callback(dot.queue_free)


static func _glow_mat(color: Color) -> StandardMaterial3D:
	return Blockout.shared([&"fx_glow", color], func() -> StandardMaterial3D:
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		mat.albedo_color = color
		return mat)


static func _box(size: float) -> BoxMesh:
	return Blockout.shared([&"fx_box", size], func() -> BoxMesh:
		var mesh := BoxMesh.new()
		mesh.size = Vector3.ONE * size
		return mesh)
