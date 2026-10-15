class_name Blockout
## Shared builders for the plaza and the rooms: boxes with or without
## collision, the two material kinds, the night environment, and the skyline.
## Every shape built here is a placeholder for tuning.


static func box(parent: Node3D, size: Vector3, pos: Vector3, mat: Material, collide := true, rot := Vector3.ZERO) -> Node3D:
	var root: Node3D
	if collide:
		var body := StaticBody3D.new()
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CollisionShape3D.new()
		var box_shape := BoxShape3D.new()
		box_shape.size = size
		shape.shape = box_shape
		body.add_child(shape)
		root = body
	else:
		root = Node3D.new()
	var mesh := MeshInstance3D.new()
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh.mesh = box_mesh
	mesh.material_override = mat
	root.add_child(mesh)
	root.position = pos
	root.rotation = rot
	parent.add_child(root)
	return root


static func flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat


## The night sky, fog and moon. A theme (Levels.THEMES) recolors them;
## `dark` is the blackout modifier: thicker fog, less ambient light.
static func environment(parent: Node3D, theme := {}, dark := false) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = theme.get("sky", Color(0.04, 0.02, 0.09))
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = theme.get("ambient", Color(0.45, 0.4, 0.7))
	env.ambient_light_energy = 0.15 if dark else 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = theme.get("fog", Color(0.25, 0.08, 0.35))
	env.fog_density = 0.035 if dark else 0.006
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	parent.add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.55, 1.0).lerp(theme.get("trim", Color(0.6, 0.55, 1.0)), 0.3)
	moon.light_energy = 0.12 if dark else 0.5
	moon.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	moon.shadow_enabled = true
	parent.add_child(moon)


## Scenery, not space (§3): no collision, never reachable. Towers ring
## `center` at 60–110 m plus `extra` (so a long level stays inside the ring).
static func skyline(parent: Node3D, center := Vector3.ZERO, extra := 0.0, theme := {}, rng_seed := 2077) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = rng_seed
	var tower_mat := flat(Color(0.03, 0.03, 0.06))
	var window_colors := [Color(0.1, 0.9, 1.0), Color(1.0, 0.2, 0.7), Color(1.0, 0.75, 0.2)]
	if not theme.is_empty():
		window_colors = [theme["trim"], theme["accent"], (theme["trim"] as Color).lerp(Color.WHITE, 0.5)]
	for i in 48:
		var a := TAU * float(i) / 48.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(60.0, 110.0) + extra
		var h := rng.randf_range(20.0, 80.0)
		var w := rng.randf_range(8.0, 16.0)
		var pos := center + Vector3(cos(a) * dist, h / 2.0 - 10.0, sin(a) * dist)
		var tower := box(parent, Vector3(w, h, w), pos, tower_mat, false)
		tower.rotation.y = -a
		var strip_mat := glow(window_colors[i % window_colors.size()], 3.0)
		for _s in rng.randi_range(1, 3):
			var sy := rng.randf_range(-h / 2.0 + 5.0, h / 2.0 - 2.0)
			box(tower, Vector3(w + 0.1, 0.4, w + 0.1), Vector3(0.0, sy, 0.0), strip_mat, false)
