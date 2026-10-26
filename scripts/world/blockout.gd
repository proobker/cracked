class_name Blockout
## Shared builders for the plaza and the rooms: boxes with or without
## collision, the two material kinds, the night environment, and the skyline.
## Every shape built here is a placeholder for tuning.
##
## Materials are shared by colour, and `merge()` bakes a finished build's
## boxes into one mesh per material: a room is a few draw calls, not hundreds.

static var _materials := {}


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


## Drops the shared materials and meshes. Called when a build leaves the tree, so a
## static never holds resources at engine shutdown.
static func clear_materials() -> void:
	_materials.clear()


## A resource shared under key until clear_materials(), made by make() the
## first time. For anything built over and over: materials, effect meshes.
static func shared(key: Array, make: Callable) -> Resource:
	if not _materials.has(key):
		_materials[key] = make.call()
	return _materials[key]


## Shared: never change one in place. Duplicate it for a material that changes.
static func flat(color: Color) -> StandardMaterial3D:
	var key := [color, -1.0]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.roughness = 0.8
		_materials[key] = mat
	return _materials[key]


## Shared, like flat().
static func glow(color: Color, energy: float) -> StandardMaterial3D:
	var key := [color, energy]
	if not _materials.has(key):
		var mat := StandardMaterial3D.new()
		mat.albedo_color = color
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = energy
		_materials[key] = mat
	return _materials[key]


## Bakes every box mesh under root into one mesh per material, then frees
## the originals (keeping their collision). Boxes under a node in `keep`
## stay as they are, for the ones that move.
static func merge(root: Node3D, keep: Array[Node] = []) -> void:
	var tools := {}
	for node in root.find_children("*", "MeshInstance3D", true, false):
		var inst := node as MeshInstance3D
		if not inst.mesh is BoxMesh or keep.any(func(k: Node) -> bool: return k == inst or k.is_ancestor_of(inst)):
			continue
		var mat := inst.material_override
		if not tools.has(mat):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			tools[mat] = st
		(tools[mat] as SurfaceTool).append_from(inst.mesh, 0, _relative(root, inst))
		var holder := inst.get_parent()
		holder.remove_child(inst)
		inst.free()
		# A box without collision was only a holder for its mesh.
		if holder != root and holder.get_class() == "Node3D" and holder.get_child_count() == 0:
			holder.get_parent().remove_child(holder)
			holder.free()
	for mat: Material in tools:
		var merged := MeshInstance3D.new()
		merged.mesh = (tools[mat] as SurfaceTool).commit()
		merged.material_override = mat
		root.add_child(merged)


## node's transform in root's space, without needing the scene tree.
static func _relative(root: Node3D, node: Node3D) -> Transform3D:
	var xf := node.transform
	var up := node.get_parent() as Node3D
	while up != root:
		xf = up.transform * xf
		up = up.get_parent() as Node3D
	return xf


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
	# Shadows re-render every box in the level each frame: too much for a phone.
	moon.shadow_enabled = not OS.has_feature("mobile")
	parent.add_child(moon)


## Scenery, not space (§3): no collision, never reachable. Towers ring
## `center` at 60–110 m plus `extra` (so a long level stays inside the ring).
static func skyline(parent: Node3D, center := Vector3.ZERO, extra := 0.0, theme := {}, rng_seed := 2077) -> void:
	var city := Node3D.new()
	city.name = "Skyline"
	parent.add_child(city)
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
		var tower := box(city, Vector3(w, h, w), pos, tower_mat, false)
		tower.rotation.y = -a
		var strip_mat := glow(window_colors[i % window_colors.size()], 3.0)
		for _s in rng.randi_range(1, 3):
			var sy := rng.randf_range(-h / 2.0 + 5.0, h / 2.0 - 2.0)
			box(tower, Vector3(w + 0.1, 0.4, w + 0.1), Vector3(0.0, sy, 0.0), strip_mat, false)
	merge(city)
