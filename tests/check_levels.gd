extends Node
## Checks every generated level: run with
##   godot --headless --path . res://tests/check_levels.tscn
## Exits 1 and prints each failure if any rule is broken. A scene rather than
## a -s script, so the autoloads exist.

var _failures: Array[String] = []


func _ready() -> void:
	var total_enemies := 0
	for n in range(1, Levels.COUNT + 1):
		var level := Levels.get_level(n)
		_check(level == Levels.get_level(n), n, "not deterministic")
		var rooms: Array = level["rooms"]
		_check(rooms.size() >= 1 and rooms.size() <= 4, n, "%d rooms" % rooms.size())
		for i in rooms.size():
			var spec: Dictionary = rooms[i]
			var waves: Array = spec["waves"]
			_check(not waves.is_empty(), n, "room %d has no waves" % (i + 1))
			var boss_room := Levels.is_boss_level(n) and i == rooms.size() - 1
			for w: Dictionary in waves:
				var count := int(w.get("r", 0)) + int(w.get("s", 0)) + int(w.get("h", 0)) + int(w.get("b", 0)) + int(w.get("shield", 0)) + int(w.get("support", 0))
				_check(n >= 15 or not w.has("shield"), n, "shield introduced early")
				_check(n >= 25 or not w.has("support"), n, "support introduced early")
				total_enemies += count
				_check(count > 0 and int(w["cap"]) >= 1, n, "empty wave in room %d" % (i + 1))
				_check(w.has("b") == boss_room, n, "boss in the wrong room (%d)" % (i + 1))
			_check_cover(spec, n, i)
			var room := Room.new(spec, i > 0, i < rooms.size() - 1)
			add_child(room)
			var points := room.spawn_points()
			_check(points.size() >= 2, n, "room %d has %d gates" % [i + 1, points.size()])
			for p in points:
				# Every spawn is behind the far wall, inside the room's width.
				_check(p.z < -room.length / 2.0 - 1.0, n, "gate in front of the far wall")
				_check(absf(p.x) + Room.GATE_WIDTH / 2.0 <= room.width / 2.0, n, "gate outside the walls")
			room.free()
		# Freed rendering resources are only released at frame sync. Building
		# every level in one frame reached ~1.6 GB and Android's low-memory
		# killer ended the check on an emulator; one frame per level stays flat.
		await get_tree().process_frame
		if n % 25 == 0:
			print("checked %d levels" % n)
	print("%d levels, %d enemies in all" % [Levels.COUNT, total_enemies])
	_check_finale()
	_check_names()
	for f in _failures:
		printerr(f)
	print("OK" if _failures.is_empty() else "%d FAILURES" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)


## Cover must never trap a walker (§3, §6): pieces either touch (a deck
## and its ramps, a catwalk and the wall) or leave a 3 m gap, and they stay
## in the middle band, well clear of the doors and gates.
func _check_cover(spec: Dictionary, n: int, i: int) -> void:
	var hw: float = spec["width"] / 2.0
	var band: float = spec["length"] / 2.0 - 8.0
	var rects: Array[Rect2] = []
	for p: Array in spec["cover"]:
		var size: Vector3 = p[0]
		var pos: Vector3 = p[1]
		var rot: Vector3 = p[2]
		var ext_z := size.z * cos(rot.x) / 2.0
		rects.append(Rect2(pos.x - size.x / 2.0, pos.z - ext_z, size.x, ext_z * 2.0))
	for a in rects.size():
		var r := rects[a]
		_check(r.position.y >= -band - 1.0 and r.end.y <= band + 1.0, n, "room %d: cover outside the middle band" % (i + 1))
		for wall_gap: float in [r.position.x + hw, hw - r.end.x]:
			_check(wall_gap < 0.05 or wall_gap > 2.95, n, "room %d: %.1f m between cover and a side wall" % [i + 1, wall_gap])
		for b in range(a + 1, rects.size()):
			var o := rects[b]
			var dx := maxf(0.0, maxf(o.position.x - r.end.x, r.position.x - o.end.x))
			var dz := maxf(0.0, maxf(o.position.y - r.end.y, r.position.y - o.end.y))
			var gap := Vector2(dx, dz).length()
			_check(gap < 0.05 or gap > 2.95, n, "room %d: %.1f m between two cover pieces (%s)" % [i + 1, gap, spec["layout"]])


## Level 100: one open room, 25 waves, a boss in every one, and few enough
## alive at once for a phone. Level 101 never runs out of waves.
func _check_finale() -> void:
	var finale := Levels.get_level(Levels.FINALE)
	var rooms: Array = finale["rooms"]
	_check(rooms.size() == 1 and (rooms[0]["cover"] as Array).is_empty(), Levels.FINALE, "finale is one open room")
	var waves: Array = rooms[0]["waves"]
	_check(waves.size() == 25, Levels.FINALE, "%d waves" % waves.size())
	var bosses := 0
	for w: Dictionary in waves:
		_check(w.has("b") and int(w["cap"]) <= 9, Levels.FINALE, "wave without a boss or too many alive")
		bosses = maxi(bosses, int(w.get("b", 0)))
	_check(bosses == 3, Levels.FINALE, "bosses peak at three")
	var endless := Levels.get_level(Levels.ENDLESS)
	_check(endless.get("endless", false) and not Levels.is_boss_level(Levels.ENDLESS), Levels.ENDLESS, "endless flag")
	for w in range(1, 200):
		var spec := Levels.endless_wave(w)
		_check(int(spec["cap"]) <= 10 and int(spec["r"]) >= 2, Levels.ENDLESS, "wave %d cap or body count" % w)
		_check(spec.has("b") == (w % 5 == 0), Levels.ENDLESS, "wave %d boss rhythm" % w)


## Stars have names, never numbers, and no two share one.
func _check_names() -> void:
	var seen := {}
	for n in range(1, Levels.COUNT + 1):
		var star_name := Levels.name_for(n)
		_check(not star_name.is_empty() and not seen.has(star_name), n, "name '%s' empty or repeated" % star_name)
		_check(not RegEx.create_from_string("[0-9]").search(star_name), n, "name '%s' has a digit" % star_name)
		seen[star_name] = true


func _check(ok: bool, level: int, what: String) -> void:
	if not ok:
		_failures.append("level %d: %s" % [level, what])
