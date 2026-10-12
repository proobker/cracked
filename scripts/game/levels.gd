class_name Levels
## The 99 levels (§7). Each is generated from its number with a seeded RNG,
## so level n is always the same level and nothing is stored. A level is a
## chain of rectangular rooms; a room is a size, its cover, how many gates
## its far wall has, and the waves that come through them.
##
## Escalation keeps §7's rule, composition before count: rushers only, then
## shooters, then heavies, then dense mixes. The last room of every tenth
## level, and of level 99, is a boss room.

const COUNT := 99

## Wave spec keys are WaveDirector's: r = rusher, s = shooter, h = heavy,
## b = boss, cap = how many may be alive at once.


static func get_level(n: int) -> Dictionary:
	n = clampi(n, 1, COUNT)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * n + 13
	var room_count := room_count_for(n)
	var rooms: Array[Dictionary] = []
	for i in room_count:
		rooms.append(_room(n, rng, is_boss_level(n) and i == room_count - 1))
	return {"n": n, "rooms": rooms, "boss": is_boss_level(n)}


static func is_boss_level(n: int) -> bool:
	return n % 10 == 0 or n == COUNT


static func room_count_for(n: int) -> int:
	if n < 10:
		return 1
	if n < 40:
		return 2
	if n < 80:
		return 3
	return 4


## Boss health multiplier: level 20's boss is the v1 boss.
static func boss_scale(n: int) -> float:
	return minf(0.5 + float(n) / 40.0, 2.5)


static func _room(n: int, rng: RandomNumberGenerator, boss_room: bool) -> Dictionary:
	var width := rng.randf_range(16.0, 24.0)
	var length := rng.randf_range(30.0, 46.0)
	if boss_room:
		width = 24.0 # the boss gets space to circle it
		length = 44.0
	var gates := 3 if width < 19.0 else rng.randi_range(4, 5)
	var waves: Array[Dictionary] = []
	if boss_room:
		waves.append(_boss_wave(n))
	else:
		for _w in _waves_per_room(n, rng):
			waves.append(_wave(n, rng))
	return {
		"width": width,
		"length": length,
		"gates": gates,
		"cover": _cover(width, length, rng),
		"waves": waves,
	}


static func _waves_per_room(n: int, rng: RandomNumberGenerator) -> int:
	if n < 5:
		return 1
	if n < 20:
		return rng.randi_range(1, 2)
	if n < 60:
		return 2
	return rng.randi_range(2, 3)


## One wave. Bodies grow slowly with the level; the band decides who they
## are. Counts are per wave, so a long level is long because of its rooms,
## never because one wave is padded (§2).
static func _wave(n: int, rng: RandomNumberGenerator) -> Dictionary:
	var bodies := 5 + floori(n / 6.0) + rng.randi_range(-1, 1)
	if n < 10:
		bodies = 3 + n # the opening levels teach one thing, a little more each time
	var spec := {}
	var heavies := 0
	var shooters := 0
	if n >= 60:
		heavies = 1 + floori((n - 60) / 20.0) + rng.randi_range(0, 1)
		shooters = roundi(bodies * 0.35)
	elif n >= 30:
		heavies = 1 + rng.randi_range(0, floori((n - 30) / 15.0))
		shooters = roundi(bodies * 0.3)
	elif n >= 10:
		shooters = maxi(1, roundi(bodies * (0.15 + 0.01 * float(n - 10))))
	spec["r"] = maxi(2, bodies - shooters - heavies)
	if shooters > 0:
		spec["s"] = shooters
	if heavies > 0:
		spec["h"] = heavies
	spec["cap"] = clampi(3 + floori(n / 9.0), 3, 12)
	return spec


## The boss, alone at first (§7's floor), with a rusher escort from level 30.
static func _boss_wave(n: int) -> Dictionary:
	var escort := maxi(0, (floori(n / 10.0) - 2) * 2)
	var spec := {"b": 1, "cap": 1 + mini(escort, 4)}
	if escort > 0:
		spec["r"] = escort
	return spec


## Cover in the middle band only (§3): low walls to crouch behind, tall
## blocks that break line of sight. Positions are room-local, origin at the
## floor's center, the entry wall at +z and the far wall at -z. Pieces keep
## clear of each other and of the side walls so nothing traps a walker.
static func _cover(width: float, length: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var count := rng.randi_range(4, 7)
	var tries := 0
	while pieces.size() < count and tries < 60:
		tries += 1
		var size: Vector3
		match rng.randi_range(0, 2):
			0:
				size = Vector3(4.0, 1.2, 1.0) # low wall, across
			1:
				size = Vector3(1.0, 1.2, 4.0) # low wall, along
			_:
				size = Vector3(2.0, 2.6, 2.0) # tall block
		var x := rng.randf_range(-width / 2.0 + 3.5, width / 2.0 - 3.5)
		var z := rng.randf_range(-length / 2.0 + 8.0, length / 2.0 - 8.0)
		var pos := Vector3(x, size.y / 2.0, z)
		var clear := true
		for p: Array in pieces:
			var other: Vector3 = p[1]
			if Vector2(other.x - x, other.z - z).length() < 5.0:
				clear = false
				break
		if clear:
			pieces.append([size, pos])
	return pieces
