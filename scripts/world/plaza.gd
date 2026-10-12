class_name Plaza
extends Node3D
## The plaza (§3): a walled rooftop, mid-range cover, one raised platform
## with ramps to slide off, a few landmarks, and a skyline that is scenery
## only. The v1 arena; now the menu backdrop and the practice range.

const HALF := 22.0 # the plaza is 44 m square inside the walls
const WALL_HEIGHT := 4.0

var _floor_mat := Blockout.flat(Color(0.09, 0.09, 0.14))
var _wall_mat := Blockout.flat(Color(0.06, 0.06, 0.1))
var _cover_mat := Blockout.flat(Color(0.16, 0.16, 0.24))


func _ready() -> void:
	Blockout.environment(self)
	_floor_and_walls()
	_cover()
	_platform()
	_landmarks()
	Blockout.skyline(self)


func _floor_and_walls() -> void:
	var size := HALF * 2.0
	Blockout.box(self, Vector3(size + 2.0, 1.0, size + 2.0), Vector3(0.0, -0.5, 0.0), _floor_mat)
	var y := WALL_HEIGHT / 2.0
	Blockout.box(self, Vector3(size + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, y, -HALF - 0.5), _wall_mat)
	Blockout.box(self, Vector3(size + 2.0, WALL_HEIGHT, 1.0), Vector3(0.0, y, HALF + 0.5), _wall_mat)
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, size), Vector3(-HALF - 0.5, y, 0.0), _wall_mat)
	Blockout.box(self, Vector3(1.0, WALL_HEIGHT, size), Vector3(HALF + 0.5, y, 0.0), _wall_mat)
	# Neon trim along the wall tops, so the edge of the arena always reads.
	var trim := Blockout.glow(Color(0.1, 0.9, 1.0), 3.0)
	var ty := WALL_HEIGHT + 0.05
	Blockout.box(self, Vector3(size + 2.0, 0.1, 1.05), Vector3(0.0, ty, -HALF - 0.5), trim, false)
	Blockout.box(self, Vector3(size + 2.0, 0.1, 1.05), Vector3(0.0, ty, HALF + 0.5), trim, false)
	Blockout.box(self, Vector3(1.05, 0.1, size), Vector3(-HALF - 0.5, ty, 0.0), trim, false)
	Blockout.box(self, Vector3(1.05, 0.1, size), Vector3(HALF + 0.5, ty, 0.0), trim, false)


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
		Blockout.box(self, spec[0], spec[1], _cover_mat)


## A raised deck with a ramp on each side: the level change that gives slide
## something to carry momentum off (§3, §4).
func _platform() -> void:
	var height := 1.5
	Blockout.box(self, Vector3(10.0, height, 8.0), Vector3(0.0, height / 2.0, -10.0), _cover_mat)
	Blockout.box(self, Vector3(10.0, 0.08, 8.05), Vector3(0.0, height + 0.04, -10.0), Blockout.glow(Color(1.0, 0.2, 0.7), 1.5), false)
	# Ramps span the deck's full width: a narrower ramp leaves concave corners
	# that trap enemies who walk straight at the player (§6).
	_ramp(height, 6.0, -6.0, 1.0)
	_ramp(height, 4.0, -14.0, -1.0) # shorter, to leave a lane along the north wall


## A full-width ramp whose top edge meets the deck at z = top_z, running
## away from the deck in direction dir (+1 toward +z, -1 toward -z).
func _ramp(height: float, run: float, top_z: float, dir: float) -> void:
	var tilt := atan(height / run) * dir
	var ramp_len := sqrt(run * run + height * height)
	var center := Vector3(0.0, height / 2.0 - 0.1, top_z + dir * run / 2.0)
	Blockout.box(self, Vector3(10.0, 0.3, ramp_len), center, _cover_mat, true, Vector3(tilt, 0.0, 0.0))


## Shapes to navigate by without a minimap (§3): the sign, the spire, the arch.
func _landmarks() -> void:
	# The sign: a big magenta billboard on the north wall.
	Blockout.box(self, Vector3(12.0, 3.0, 0.3), Vector3(0.0, WALL_HEIGHT + 3.0, -HALF - 0.6), Blockout.glow(Color(1.0, 0.1, 0.55), 2.5), false)
	# The spire: a tall cyan-lit pillar in the south-east corner.
	Blockout.box(self, Vector3(1.5, 9.0, 1.5), Vector3(17.0, 4.5, 17.0), _cover_mat)
	Blockout.box(self, Vector3(1.6, 0.3, 1.6), Vector3(17.0, 9.1, 17.0), Blockout.glow(Color(0.1, 1.0, 0.9), 4.0), false)
	# The arch: a yellow gateway frame on the west side.
	var amber := Blockout.glow(Color(1.0, 0.7, 0.1), 2.5)
	Blockout.box(self, Vector3(0.6, 5.0, 0.6), Vector3(-17.0, 2.5, 3.0), amber)
	Blockout.box(self, Vector3(0.6, 5.0, 0.6), Vector3(-17.0, 2.5, 9.0), amber)
	Blockout.box(self, Vector3(0.6, 0.6, 6.6), Vector3(-17.0, 5.3, 6.0), amber)
