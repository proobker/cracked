class_name Room
extends Node3D
## One room of a level (§3): a walled rectangle the player enters at the
## near short wall. Enemies come only through gates in the far short wall —
## alcoves behind the wall line — so nothing can appear behind the player.
## The entry door locks behind you; the exit door opens when the room is
## cleared. Positions are local: floor center at the origin, the entry wall
## at +z, the far wall at -z.

signal entered

const WALL_HEIGHT := 4.0
const DOOR_WIDTH := 4.0
const DOOR_HEIGHT := 3.2
const GATE_WIDTH := 3.8 # the boss is 3.2 m across
const GATE_DEPTH := 3.0
const GATE_SPACING := GATE_WIDTH + 0.6 # center to center, leaving a wall between
## Corridor between rooms, exit door to entry door.
const CORRIDOR := 6.0

var spec: Dictionary
var width := 20.0
var length := 36.0
var has_entry := true
var has_exit := true

var _floor_mat := Blockout.flat(Color(0.09, 0.09, 0.14))
var _wall_mat := Blockout.flat(Color(0.06, 0.06, 0.1))
var _cover_mat := Blockout.flat(Color(0.16, 0.16, 0.24))
var _gate_xs: Array[float] = []
var _entry_door: Node3D
var _exit_door: Node3D


func _init(room_spec: Dictionary, entry := true, exit := true) -> void:
	spec = room_spec
	width = room_spec["width"]
	length = room_spec["length"]
	has_entry = entry
	has_exit = exit
	_gate_xs = _place_gates(int(room_spec["gates"]))


func _ready() -> void:
	var half_w := width / 2.0
	var half_l := length / 2.0
	Blockout.box(self, Vector3(width + 2.0, 1.0, length + 2.0 + GATE_DEPTH * 2.0), Vector3(0.0, -0.5, -GATE_DEPTH / 2.0), _floor_mat)
	# Side walls, full length.
	var y := WALL_HEIGHT / 2.0
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, length), Vector3(-half_w - 0.5, y, 0.0), _wall_mat)
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, length), Vector3(half_w + 0.5, y, 0.0), _wall_mat)
	# Near wall, with a doorway when there is a room before this one.
	var near_gaps: Array = [[0.0, DOOR_WIDTH]] if has_entry else []
	_wall_across(half_l + 0.5, near_gaps)
	# Far wall: the gates, and a doorway when there is a room after this one.
	var far_gaps: Array = []
	for x in _gate_xs:
		far_gaps.append([x, GATE_WIDTH])
	if has_exit:
		far_gaps.append([0.0, DOOR_WIDTH])
	_wall_across(-half_l - 0.5, far_gaps)
	for x in _gate_xs:
		_gate(x)
	if has_entry:
		_entry_door = _door(half_l + 0.5)
		_set_door(_entry_door, false, true)
		_trigger()
	if has_exit:
		_exit_door = _door(-half_l - 0.5)
		_corridor(-half_l - 1.0)
	for piece: Array in spec["cover"]:
		Blockout.box(self, piece[0], piece[1], _cover_mat)
	_trim()


## Where enemies appear: inside the far-wall alcoves, in world space.
func spawn_points() -> Array[Vector3]:
	var points: Array[Vector3] = []
	for x in _gate_xs:
		points.append(to_global(Vector3(x, 0.1, -length / 2.0 - GATE_DEPTH / 2.0 - 0.5)))
	return points


## The room's interior plus its alcoves, in world space, for stray rescue.
func bounds() -> AABB:
	var size := Vector3(width, 17.0, length + GATE_DEPTH + 1.0)
	return AABB(to_global(Vector3(-width / 2.0, -5.0, -length / 2.0 - GATE_DEPTH - 1.0)), size)


## Where the player stands to start a level in this room.
func start_position() -> Vector3:
	return to_global(Vector3(0.0, 0.2, length / 2.0 - 3.0))


func close_entry() -> void:
	if _entry_door:
		_set_door(_entry_door, true)


func open_exit() -> void:
	if _exit_door:
		_set_door(_exit_door, false)


## Gate centers along the far wall, evenly spread. With an exit doorway in
## the middle they sit in pairs either side of it, clear of its corridor.
func _place_gates(count: int) -> Array[float]:
	var hi := width / 2.0 - 0.5 - GATE_WIDTH / 2.0
	var xs: Array[float] = []
	if not has_exit:
		var n := clampi(count, 1, floori(2.0 * hi / GATE_SPACING) + 1)
		for i in n:
			xs.append(0.0 if n == 1 else lerpf(-hi, hi, float(i) / float(n - 1)))
		return xs
	var lo := DOOR_WIDTH / 2.0 + 1.0 + 0.5 + GATE_WIDTH / 2.0
	var per_side := clampi(ceili(count / 2.0), 1, floori((hi - lo) / GATE_SPACING) + 1)
	for i in per_side:
		var x := lo if per_side == 1 else lerpf(lo, hi, float(i) / float(per_side - 1))
		xs.append(-x)
		xs.append(x)
	return xs


## A wall across the room at z with openings [center_x, width]. A doorway
## gets a lintel above it; a gate is open to the top so the boss fits.
func _wall_across(z: float, gaps: Array) -> void:
	gaps.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	var left := -width / 2.0 - 1.0
	for gap: Array in gaps:
		var g_left: float = gap[0] - gap[1] / 2.0
		_wall_piece(left, g_left, z)
		left = gap[0] + gap[1] / 2.0
		if gap[1] == DOOR_WIDTH:
			var lintel_h := WALL_HEIGHT - DOOR_HEIGHT
			Blockout.box(self, Vector3(DOOR_WIDTH, lintel_h, 1.0), Vector3(gap[0], DOOR_HEIGHT + lintel_h / 2.0, z), _wall_mat)
	_wall_piece(left, width / 2.0 + 1.0, z)


func _wall_piece(x0: float, x1: float, z: float) -> void:
	if x1 - x0 < 0.05:
		return
	Blockout.box(self, Vector3(x1 - x0, WALL_HEIGHT, 1.0), Vector3((x0 + x1) / 2.0, WALL_HEIGHT / 2.0, z), _wall_mat)


## An alcove behind the far wall, framed in light so the player can see
## where things will come from.
func _gate(x: float) -> void:
	var back_z := -length / 2.0 - 1.0 - GATE_DEPTH
	var mid_z := -length / 2.0 - 1.0 - GATE_DEPTH / 2.0
	var y := WALL_HEIGHT / 2.0
	Blockout.box(self, Vector3(GATE_WIDTH + 1.0, WALL_HEIGHT, 1.0), Vector3(x, y, back_z - 0.5), _wall_mat)
	Blockout.box(self, Vector3(0.5, WALL_HEIGHT, GATE_DEPTH), Vector3(x - GATE_WIDTH / 2.0 - 0.25, y, mid_z), _wall_mat)
	Blockout.box(self, Vector3(0.5, WALL_HEIGHT, GATE_DEPTH), Vector3(x + GATE_WIDTH / 2.0 + 0.25, y, mid_z), _wall_mat)
	var frame := Blockout.glow(Color(1.0, 0.15, 0.35), 3.0)
	var fz := -length / 2.0 - 0.02
	Blockout.box(self, Vector3(0.15, WALL_HEIGHT, 1.05), Vector3(x - GATE_WIDTH / 2.0, y, fz - 0.5), frame, false)
	Blockout.box(self, Vector3(0.15, WALL_HEIGHT, 1.05), Vector3(x + GATE_WIDTH / 2.0, y, fz - 0.5), frame, false)
	Blockout.box(self, Vector3(GATE_WIDTH, 0.08, GATE_DEPTH), Vector3(x, 0.04, mid_z), frame, false)


## A slab that fills a doorway when closed and sinks into the floor when
## open, glowing red while locked and cyan while open.
func _door(z: float) -> Node3D:
	var door := Blockout.box(self, Vector3(DOOR_WIDTH, DOOR_HEIGHT, 0.6), Vector3(0.0, DOOR_HEIGHT / 2.0, z), Blockout.glow(Color(1.0, 0.1, 0.3), 1.6))
	return door


func _set_door(door: Node3D, closed: bool, instant := false) -> void:
	var body := door as StaticBody3D
	body.collision_layer = 1 if closed else 0
	var mat := (door.get_child(1) as MeshInstance3D).material_override as StandardMaterial3D
	var c := Color(1.0, 0.1, 0.3) if closed else Color(0.1, 0.9, 1.0)
	mat.albedo_color = c
	mat.emission = c
	var y := DOOR_HEIGHT / 2.0 if closed else -DOOR_HEIGHT / 2.0 + 0.05
	if instant:
		door.position.y = y
	else:
		create_tween().tween_property(door, "position:y", y, 0.5)


## The way on to the next room, from the far wall's doorway.
func _corridor(z_start: float) -> void:
	var mid := z_start - CORRIDOR / 2.0
	var y := WALL_HEIGHT / 2.0
	var hw := DOOR_WIDTH / 2.0
	Blockout.box(self, Vector3(DOOR_WIDTH + 2.0, 1.0, CORRIDOR), Vector3(0.0, -0.5, mid), _floor_mat)
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, CORRIDOR), Vector3(-hw - 0.5, y, mid), _wall_mat)
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, CORRIDOR), Vector3(hw + 0.5, y, mid), _wall_mat)
	Blockout.box(self, Vector3(DOOR_WIDTH + 2.0, 0.5, CORRIDOR), Vector3(0.0, DOOR_HEIGHT + 0.25, mid), _wall_mat)
	Blockout.box(self, Vector3(0.1, 0.1, CORRIDOR), Vector3(0.0, 0.03, mid), Blockout.glow(Color(0.1, 0.9, 1.0), 3.0), false)


## Fires `entered` once the player is fully inside, so the door closes
## behind them and never on them.
func _trigger() -> void:
	var area := Area3D.new()
	area.collision_layer = 0
	area.collision_mask = 2
	area.monitorable = false
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(width, 3.0, 3.0)
	shape.shape = box
	area.add_child(shape)
	area.position = Vector3(0.0, 1.5, length / 2.0 - 5.0)
	add_child(area)
	area.body_entered.connect(func(body: Node3D) -> void:
		if body is Player:
			area.set_deferred("monitoring", false)
			entered.emit())


## Neon along the wall tops, so the edge of the room always reads.
func _trim() -> void:
	var trim := Blockout.glow(Color(0.1, 0.9, 1.0), 3.0)
	var ty := WALL_HEIGHT + 0.05
	Blockout.box(self, Vector3(1.05, 0.1, length), Vector3(-width / 2.0 - 0.5, ty, 0.0), trim, false)
	Blockout.box(self, Vector3(1.05, 0.1, length), Vector3(width / 2.0 + 0.5, ty, 0.0), trim, false)
	Blockout.box(self, Vector3(width + 2.0, 0.1, 1.05), Vector3(0.0, ty, length / 2.0 + 0.5), trim, false)
	Blockout.box(self, Vector3(width + 2.0, 0.1, 1.05), Vector3(0.0, ty, -length / 2.0 - 0.5), trim, false)
