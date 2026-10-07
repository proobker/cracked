class_name Plaza
extends Node3D
## The plaza (§3): a walled rooftop, mid-range cover, one raised platform
## with ramps to slide off, a few landmarks, and a skyline that is scenery
## only. A blockout — every shape here is a placeholder for tuning.

const HALF := 22.0 # the plaza is 44 m square inside the walls
const WALL_HEIGHT := 4.0

var _floor_mat := _flat(Color(0.09, 0.09, 0.14))
var _wall_mat := _flat(Color(0.06, 0.06, 0.1))
var _cover_mat := _flat(Color(0.16, 0.16, 0.24))
var _tower_mat := _flat(Color(0.03, 0.03, 0.06))


func _ready() -> void:
	_environment()
	_floor_and_walls()
	_cover()
	_platform()
	_landmarks()
	_skyline()


func spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	var r := HALF - 2.5
	for i in 12:
		var a := TAU * (float(i) + 0.5) / 12.0 # offset keeps points off the back ramp
		points.append(Vector3(cos(a) * r, 0.1, sin(a) * r))
	return points


func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.04, 0.02, 0.09)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.45, 0.4, 0.7)
	env.ambient_light_energy = 0.6
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
	env.glow_intensity = 0.9
	env.glow_bloom = 0.1
	env.fog_enabled = true
	env.fog_light_color = Color(0.25, 0.08, 0.35)
	env.fog_density = 0.006
	var world_env := WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.6, 0.55, 1.0)
	moon.light_energy = 0.5
	moon.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	moon.shadow_enabled = true
	add_child(moon)


func _floor_and_walls() -> void:
	var size := HALF * 2.0
	_box(Vector3(size + 2.0, 1.0, size + 2.0), Vector3(0.0, -0.5, 0.0), _floor_mat)
	var y := WALL_HEIGHT / 2.0
	_box(Vector3(size + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, y, -HALF - 0.5), _wall_mat)
	_box(Vector3(size + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, y, HALF + 0.5), _wall_mat)
	_box(Vector3(1.0, WALL_HEIGHT, size), Vector3(-HALF - 0.5, y, 0.0), _wall_mat)
	_box(Vector3(1.0, WALL_HEIGHT, size), Vector3(HALF + 0.5, y, 0.0), _wall_mat)
	# Neon trim along the wall tops, so the edge of the arena always reads.
	var trim := _glow(Color(0.1, 0.9, 1.0), 3.0)
	var ty := WALL_HEIGHT + 0.05
	_box(Vector3(size + 2.0, 0.1, 1.05), Vector3(0.0, ty, -HALF - 0.5), trim, false)
	_box(Vector3(size + 2.0, 0.1, 1.05), Vector3(0.0, ty, HALF + 0.5), trim, false)
	_box(Vector3(1.05, 0.1, size), Vector3(-HALF - 0.5, ty, 0.0), trim, false)
	_box(Vector3(1.05, 0.1, size), Vector3(HALF + 0.5, ty, 0.0), trim, false)


## Mid-range cover: low walls to crouch behind and tall blocks that break
## line of sight. Enough to use, not enough to camp in (§3).
func _cover() -> void:
	for spec in [
		[Vector3(4.0, 1.2, 1.0), Vector3(-10.0, 0.6, 6.0)],
		[Vector3(4.0, 1.2, 1.0), Vector3(10.0, 0.6, 6.0)],
		[Vector3(1.0, 1.2, 4.0), Vector3(-14.0, 0.6, -4.0)],
		[Vector3(1.0, 1.2, 4.0), Vector3(14.0, 0.6, -4.0)],
		[Vector3(2.0, 2.6, 2.0), Vector3(-6.0, 1.3, 14.0)],
		[Vector3(2.0, 2.6, 2.0), Vector3(6.0, 1.3, 14.0)],
		[Vector3(2.0, 2.6, 2.0), Vector3(0.0, 1.3, 4.0)],
	]:
		_box(spec[0], spec[1], _cover_mat)


## A raised deck with a ramp on each side: the level change that gives slide
## something to carry momentum off (§3, §4).
func _platform() -> void:
	var height := 1.5
	_box(Vector3(10.0, height, 8.0), Vector3(0.0, height / 2.0, -10.0), _cover_mat)
	_box(Vector3(10.0, 0.08, 8.05), Vector3(0.0, height + 0.04, -10.0), _glow(Color(1.0, 0.2, 0.7), 1.5), false)
	# Ramps span the deck's full width: a narrower ramp leaves concave corners
	# that trap enemies who walk straight at the player (§6).
	_ramp(height, 6.0, -6.0, 1.0)
	_ramp(height, 4.0, -14.0, -1.0) # shorter, to stay clear of the spawn ring


## A full-width ramp whose top edge meets the deck at z = top_z, running
## away from the deck in direction dir (+1 toward +z, -1 toward -z).
func _ramp(height: float, run: float, top_z: float, dir: float) -> void:
	var tilt := atan(height / run) * dir
	var ramp_len := sqrt(run * run + height * height)
	var center := Vector3(0.0, height / 2.0 - 0.1, top_z + dir * run / 2.0)
	_box(Vector3(10.0, 0.3, ramp_len), center, _cover_mat, true, Vector3(tilt, 0.0, 0.0))


## Shapes to navigate by without a minimap (§3): the sign, the spire, the arch.
func _landmarks() -> void:
	# The sign: a big magenta billboard on the north wall.
	_box(Vector3(12.0, 3.0, 0.3), Vector3(0.0, WALL_HEIGHT + 3.0, -HALF - 0.6), _glow(Color(1.0, 0.1, 0.55), 2.5), false)
	# The spire: a tall cyan-lit pillar in the south-east corner.
	_box(Vector3(1.5, 9.0, 1.5), Vector3(17.0, 4.5, 17.0), _cover_mat)
	_box(Vector3(1.6, 0.3, 1.6), Vector3(17.0, 9.1, 17.0), _glow(Color(0.1, 1.0, 0.9), 4.0), false)
	# The arch: a yellow gateway frame on the west side.
	var amber := _glow(Color(1.0, 0.7, 0.1), 2.5)
	_box(Vector3(0.6, 5.0, 0.6), Vector3(-17.0, 2.5, 3.0), amber)
	_box(Vector3(0.6, 5.0, 0.6), Vector3(-17.0, 2.5, 9.0), amber)
	_box(Vector3(0.6, 0.6, 6.6), Vector3(-17.0, 5.3, 6.0), amber)


## Scenery, not space (§3): no collision, never reachable.
func _skyline() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 2077
	var window_colors := [Color(0.1, 0.9, 1.0), Color(1.0, 0.2, 0.7), Color(1.0, 0.75, 0.2)]
	for i in 48:
		var a := TAU * float(i) / 48.0 + rng.randf_range(-0.05, 0.05)
		var dist := rng.randf_range(60.0, 110.0)
		var h := rng.randf_range(20.0, 80.0)
		var w := rng.randf_range(8.0, 16.0)
		var pos := Vector3(cos(a) * dist, h / 2.0 - 10.0, sin(a) * dist)
		var tower := _box(Vector3(w, h, w), pos, _tower_mat, false)
		tower.rotation.y = -a
		var glow := _glow(window_colors[i % window_colors.size()], 3.0)
		for _s in rng.randi_range(1, 3):
			var sy := rng.randf_range(-h / 2.0 + 5.0, h / 2.0 - 2.0)
			var strip := _box(Vector3(w + 0.1, 0.4, w + 0.1), Vector3(0.0, sy, 0.0), glow, false)
			strip.reparent(tower, false)


func _box(size: Vector3, pos: Vector3, mat: Material, collide := true, rot := Vector3.ZERO) -> Node3D:
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
	var box := BoxMesh.new()
	box.size = size
	mesh.mesh = box
	mesh.material_override = mat
	root.add_child(mesh)
	root.position = pos
	root.rotation = rot
	add_child(root)
	return root


func _flat(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.8
	return mat


func _glow(color: Color, energy: float) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.emission_enabled = true
	mat.emission = color
	mat.emission_energy_multiplier = energy
	return mat
