class_name Levels
## The levels (§7): a generated campaign, then a hand-built finale (one vast
## room, 25 boss waves) and an endless level. Players never see the count;
## the map shows named stars. Each campaign level is generated from its number with a seeded RNG,
## so level n is always the same level and nothing is stored. A level is a
## theme, an optional modifier, and a chain of rectangular rooms; a room is
## a shape, a layout of cover, how many gates its far wall has, and the
## waves that come through them.
##
## Escalation keeps §7's rule, composition before count: rushers only, then
## shooters, then heavies, then dense mixes. The last room of every tenth
## level, and of level 99, is a boss room. Variety comes from what the rooms
## look like and how they are laid out, never from breaking the bands.

const COUNT := 101
## The generated campaign; the two levels after it are hand-built.
const CAMPAIGN := 99
## One vast open room, 25 waves of bosses.
const FINALE := 100
## Endless waves, barely any regen: what is left after the galaxy falls.
const ENDLESS := 101

## Wave spec keys are WaveDirector's: r = rusher, s = shooter, h = heavy,
## b = boss, cap = how many may be alive at once.

## Each level is lit in one of these. Neighbouring levels never share one.
const THEMES := [
	{"name": "NEON", "trim": Color(0.1, 0.9, 1.0), "accent": Color(1.0, 0.2, 0.7),
		"floor": Color(0.09, 0.09, 0.14), "wall": Color(0.06, 0.06, 0.1), "cover": Color(0.16, 0.16, 0.24),
		"sky": Color(0.04, 0.02, 0.09), "fog": Color(0.25, 0.08, 0.35), "ambient": Color(0.45, 0.4, 0.7)},
	{"name": "EMBER", "trim": Color(1.0, 0.55, 0.1), "accent": Color(1.0, 0.15, 0.2),
		"floor": Color(0.13, 0.08, 0.07), "wall": Color(0.09, 0.05, 0.05), "cover": Color(0.24, 0.14, 0.11),
		"sky": Color(0.09, 0.03, 0.02), "fog": Color(0.28, 0.08, 0.04), "ambient": Color(0.7, 0.45, 0.35)},
	{"name": "TOXIC", "trim": Color(0.55, 1.0, 0.1), "accent": Color(0.1, 1.0, 0.6),
		"floor": Color(0.07, 0.11, 0.08), "wall": Color(0.04, 0.08, 0.05), "cover": Color(0.13, 0.2, 0.14),
		"sky": Color(0.02, 0.06, 0.03), "fog": Color(0.08, 0.22, 0.08), "ambient": Color(0.4, 0.65, 0.45)},
	{"name": "GLACIER", "trim": Color(0.6, 0.85, 1.0), "accent": Color(0.3, 0.5, 1.0),
		"floor": Color(0.14, 0.16, 0.2), "wall": Color(0.1, 0.12, 0.16), "cover": Color(0.24, 0.27, 0.34),
		"sky": Color(0.04, 0.06, 0.12), "fog": Color(0.14, 0.2, 0.32), "ambient": Color(0.55, 0.65, 0.85)},
	{"name": "ULTRAVIOLET", "trim": Color(0.7, 0.3, 1.0), "accent": Color(1.0, 0.3, 0.9),
		"floor": Color(0.1, 0.07, 0.15), "wall": Color(0.07, 0.04, 0.11), "cover": Color(0.2, 0.13, 0.28),
		"sky": Color(0.05, 0.01, 0.1), "fog": Color(0.3, 0.05, 0.45), "ambient": Color(0.55, 0.4, 0.8)},
	{"name": "GOLD", "trim": Color(1.0, 0.8, 0.2), "accent": Color(0.1, 0.9, 1.0),
		"floor": Color(0.12, 0.11, 0.08), "wall": Color(0.08, 0.07, 0.05), "cover": Color(0.22, 0.2, 0.14),
		"sky": Color(0.06, 0.05, 0.02), "fog": Color(0.22, 0.16, 0.06), "ambient": Color(0.65, 0.58, 0.42)},
	{"name": "CRIMSON", "trim": Color(1.0, 0.1, 0.25), "accent": Color(1.0, 0.85, 0.85),
		"floor": Color(0.11, 0.06, 0.08), "wall": Color(0.08, 0.03, 0.05), "cover": Color(0.22, 0.1, 0.13),
		"sky": Color(0.07, 0.0, 0.03), "fog": Color(0.25, 0.02, 0.08), "ambient": Color(0.65, 0.35, 0.45)},
]

## Room layouts, each a different way to fight the same rectangle.
const LAYOUTS := [&"scatter", &"pillars", &"lanes", &"deck", &"bunkers", &"spine", &"catwalks"]

## Level modifiers: a twist on a whole level, announced at its start. They
## reshape waves inside the level's band and never bring a type in early.
const MODIFIERS := {
	&"swarm": "SWARM  ·  rushers, and lots of them",
	&"crossfire": "CROSSFIRE  ·  shooters hold the far end",
	&"juggernaut": "JUGGERNAUT  ·  extra heavies",
	&"blackout": "BLACKOUT  ·  the lights are down",
	&"overdrive": "OVERDRIVE  ·  everything moves faster",
}


static func get_level(n: int) -> Dictionary:
	n = clampi(n, 1, COUNT)
	if n == FINALE:
		return _finale()
	if n == ENDLESS:
		return _endless()
	var rng := RandomNumberGenerator.new()
	rng.seed = 7919 * n + 13
	var modifier := _modifier(n, rng)
	var room_count := room_count_for(n)
	var rooms: Array[Dictionary] = []
	var last_layout := &""
	for i in room_count:
		var room := _room(n, rng, is_boss_level(n) and i == room_count - 1, modifier, last_layout)
		last_layout = room["layout"]
		rooms.append(room)
	return {
		"n": n,
		"rooms": rooms,
		"boss": is_boss_level(n),
		"theme": theme_for(n),
		"modifier": modifier,
	}


## The level's lighting, without building the level.
static func theme_for(n: int) -> Dictionary:
	if n == FINALE:
		return THEMES[6]
	if n == ENDLESS:
		return THEMES[4]
	return THEMES[(n * 3) % THEMES.size()]


static func is_boss_level(n: int) -> bool:
	if n == ENDLESS:
		return false
	return n % 10 == 0 or n == CAMPAIGN


static func is_endless(n: int) -> bool:
	return n == ENDLESS


static func room_count_for(n: int) -> int:
	if n >= FINALE:
		return 1
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


## Enemy speed multiplier for the level's modifier.
static func speed_scale(modifier: StringName) -> float:
	return 1.2 if modifier == &"overdrive" else 1.0


## The one-line description of a level for the level select.
static func describe(n: int) -> String:
	var level := get_level(n)
	var text := name_for(n)
	var modifier: StringName = level["modifier"]
	if modifier != &"":
		text += "  ·  " + String(MODIFIERS[modifier]).get_slice("  ·  ", 0)
	return text


const _ONSETS := ["V", "K", "Z", "TH", "S", "R", "N", "M", "X", "D", "Q", "L", "AZ", "OR", "EL", "KH", "VR", "SOL", "NY", "TR"]
const _VOWELS := ["A", "E", "I", "O", "U", "AE", "IO", "Y"]
const _CODAS := ["", "", "N", "X", "R", "TH", "S", "L", "K", "RA", "ON", "IS"]
const _SUFFIXES := ["", "", "", " PRIME", " MAJORIS", " MINOR", " REACH", " DRIFT", " GATE", " VEIL", " HOLLOW", " SPIRE"]
static var _names: Array[String] = []


## Every star has a name, never a number: 1..99 are built from syllables
## with a fixed seed (unique, so no two stars share one); the last two are
## named by hand.
static func name_for(n: int) -> String:
	if n == FINALE:
		return "THE CROWN"
	if n == ENDLESS:
		return "THE ABYSS"
	if _names.is_empty():
		var rng := RandomNumberGenerator.new()
		rng.seed = 424242
		var seen := {}
		while _names.size() < CAMPAIGN:
			var word := ""
			for _s in rng.randi_range(2, 3):
				word += _ONSETS[rng.randi() % _ONSETS.size()] + _VOWELS[rng.randi() % _VOWELS.size()]
			word += _CODAS[rng.randi() % _CODAS.size()]
			if word.length() > 9 or seen.has(word) or not _sounds_right(word):
				continue
			seen[word] = true
			_names.append(word + _SUFFIXES[rng.randi() % _SUFFIXES.size()])
	return _names[clampi(n, 1, CAMPAIGN) - 1]


## No doubled letters and no three vowels in a row: they read as typos.
static func _sounds_right(word: String) -> bool:
	var vowels := 0
	for i in word.length():
		if i > 0 and word[i] == word[i - 1]:
			return false
		vowels = vowels + 1 if "AEIOUY".contains(word[i]) else 0
		if vowels >= 3:
			return false
	return true


## Level 100: one vast open room and 25 waves, every one with a boss at
## full strength. One boss alone, then two at once, then three with heavies.
## Concurrency stays low enough for a phone; the length is the test.
static func _finale() -> Dictionary:
	var waves: Array[Dictionary] = []
	for w in 25:
		var bosses := 1 if w < 8 else (2 if w < 17 else 3)
		var spec := {"b": bosses, "r": 3 + floori(w / 3.0), "s": 2 + floori(w / 5.0), "shield": 1, "support": 1}
		if w >= 4:
			spec["h"] = 1 + floori(w / 8.0)
		spec["cap"] = mini(bosses + 3 + floori(w / 5.0), 9)
		waves.append(spec)
	return {"n": FINALE, "rooms": [_open_room(waves)], "boss": true,
		"theme": theme_for(FINALE), "modifier": &""}


## Level 101: one wave to begin; the director writes the rest as it goes.
static func _endless() -> Dictionary:
	var waves: Array[Dictionary] = [endless_wave(1)]
	return {"n": ENDLESS, "rooms": [_open_room(waves)], "boss": false,
		"theme": theme_for(ENDLESS), "modifier": &"", "endless": true}


## Wave w of the endless level: more bodies every wave, a boss every fifth.
static func endless_wave(w: int) -> Dictionary:
	var bodies := 6 + w
	var spec := {"r": maxi(2, floori(bodies / 2.0)), "s": floori(bodies / 4.0), "h": floori(w / 4.0), "cap": clampi(4 + floori(w / 3.0), 4, 10)}
	if w >= 3:
		spec["shield"] = 1 + floori(w / 8.0)
	if w >= 5:
		spec["support"] = 1 + floori(w / 10.0)
	if w % 5 == 0:
		spec["b"] = floori(w / 10.0) + 1
	return spec


static func _open_room(waves: Array[Dictionary]) -> Dictionary:
	return {"width": 36.0, "length": 64.0, "gates": 8, "layout": &"open", "cover": [], "waves": waves}


## No modifier while the game is teaching; then about two levels in five.
## Boss levels stay plain so the boss is the twist.
static func _modifier(n: int, rng: RandomNumberGenerator) -> StringName:
	var roll := rng.randf()
	if n < 6 or is_boss_level(n) or roll > 0.4:
		return &""
	var pool: Array[StringName] = [&"swarm", &"blackout", &"overdrive"]
	if n >= 12:
		pool.append(&"crossfire")
	if n >= 32:
		pool.append(&"juggernaut")
	return pool[rng.randi_range(0, pool.size() - 1)]


static func _room(n: int, rng: RandomNumberGenerator, boss_room: bool, modifier: StringName, last_layout: StringName) -> Dictionary:
	# Three shapes inside §3's 16–24 by 30–46: the hall is long and narrow,
	# the arena wide and short, the standard room in between.
	var width: float
	var length: float
	match rng.randi_range(0, 2):
		0:
			width = rng.randf_range(16.0, 18.0)
			length = rng.randf_range(40.0, 46.0)
		1:
			width = rng.randf_range(22.0, 24.0)
			length = rng.randf_range(30.0, 34.0)
		_:
			width = rng.randf_range(18.0, 22.0)
			length = rng.randf_range(34.0, 40.0)
	var layout: StringName
	if boss_room:
		width = 24.0 # the boss gets space to circle it
		length = 44.0
		layout = &"arena"
	else:
		var options: Array[StringName] = []
		for l: StringName in LAYOUTS:
			if l != last_layout:
				options.append(l)
		layout = options[rng.randi_range(0, options.size() - 1)]
	var gates := 3 if width < 19.0 else rng.randi_range(4, 5)
	var waves: Array[Dictionary] = []
	if boss_room:
		waves.append(_boss_wave(n))
	else:
		for _w in _waves_per_room(n, rng):
			waves.append(_wave(n, rng, modifier))
	return {
		"width": width,
		"length": length,
		"gates": gates,
		"layout": layout,
		"cover": _cover(layout, width, length, rng),
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
## are, and the modifier reweights them. Counts are per wave, so a long
## level is long because of its rooms, never because one wave is padded (§2).
static func _wave(n: int, rng: RandomNumberGenerator, modifier: StringName) -> Dictionary:
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
	var cap := clampi(3 + floori(n / 9.0), 3, 12)
	match modifier:
		&"swarm":
			bodies = roundi(bodies * 1.5)
			shooters = floori(shooters / 2.0)
			heavies = 0
			cap = mini(cap + 3, 14)
		&"crossfire":
			shooters = maxi(shooters, roundi(bodies * 0.55))
		&"juggernaut":
			heavies += 2
			bodies = maxi(bodies - 2, heavies + 2)
	spec["r"] = maxi(2, bodies - shooters - heavies)
	if shooters > 0:
		spec["s"] = shooters
	if heavies > 0:
		spec["h"] = heavies
	# Replace existing bodies rather than increasing the wave or concurrency.
	if n >= 15 and int(spec["r"]) > 2:
		spec["r"] -= 1
		spec["shield"] = 1
	if n >= 25 and int(spec["r"]) > 2:
		spec["r"] -= 1
		spec["support"] = 1
	spec["cap"] = cap
	return spec


## The boss, alone at first (§7's floor), with a rusher escort from level 30.
static func _boss_wave(n: int) -> Dictionary:
	var escort := maxi(0, (floori(n / 10.0) - 2) * 2)
	var spec := {"b": 1, "cap": 1 + mini(escort, 4)}
	if escort > 0:
		spec["r"] = escort
	return spec


## Cover in the middle band only (§3), as [size, position, rotation].
## Positions are room-local, origin at the floor's center, the entry wall at
## +z and the far wall at -z. Free-standing pieces keep 3.5 m from the side
## walls and gaps of at least 3 m between them, so nothing traps a walker;
## pieces against a wall leave no gap at all.
static func _cover(layout: StringName, width: float, length: float, rng: RandomNumberGenerator) -> Array:
	var band := length / 2.0 - 8.0 # cover lives in -band..band along z
	var hw := width / 2.0
	match layout:
		&"pillars":
			return _pillars(hw, band, rng)
		&"lanes":
			return _lanes(hw, band, rng)
		&"deck":
			return _deck(hw, band, rng)
		&"bunkers":
			return _bunkers(hw, band, rng)
		&"spine":
			return _spine(hw, band, rng)
		&"catwalks":
			return _catwalks(hw, band, rng)
		&"arena":
			return _arena(hw, band)
	return _scatter(hw, band, rng)


## The v2 room: low walls and tall blocks dropped at random.
static func _scatter(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
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
		var x := rng.randf_range(-hw + 3.5 + size.x / 2.0, hw - 3.5 - size.x / 2.0)
		var z := rng.randf_range(-band + size.z / 2.0, band - size.z / 2.0)
		if _clear(pieces, size, x, z, 3.0):
			pieces.append([size, Vector3(x, size.y / 2.0, z), Vector3.ZERO])
	return pieces


## A hall of columns: tall, thin, in a staggered grid. Sightlines open and
## close as you move, and nothing is low enough to crouch behind.
static func _pillars(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var spacing := rng.randf_range(5.0, 6.5)
	var thick := rng.randf_range(1.0, 1.6)
	var row := 0
	var z := -band
	while z <= band + 0.01:
		var offset := spacing / 2.0 if row % 2 == 1 else 0.0
		var x := -hw + 3.5 + thick / 2.0 + offset
		while x <= hw - 3.5 - thick / 2.0:
			pieces.append([Vector3(thick, 3.6, thick), Vector3(x, 1.8, z), Vector3.ZERO])
			x += spacing
		z += spacing
		row += 1
	return pieces


## Long low walls running the room's length: lanes to slide down and
## crouch along, with breaks to cut across.
static func _lanes(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var count := 2 if hw < 10.0 else 3
	for i in count:
		var x := lerpf(-hw + 4.0, hw - 4.0, float(i) / float(count - 1))
		# Each lane is two or three segments with a gap between them.
		# Neighbouring lanes break in different places.
		var segments := 2 + (i + rng.randi_range(0, 1)) % 2
		var seg_len := (band * 2.0 - 3.5 * float(segments - 1)) / float(segments)
		for s in segments:
			var z := -band + seg_len / 2.0 + float(s) * (seg_len + 3.5)
			pieces.append([Vector3(1.0, 1.2, seg_len), Vector3(x, 0.6, z), Vector3.ZERO])
	return pieces


## A raised deck in the middle with a full-width ramp at each end (§3's
## level change to slide off), and blocks either side of it.
static func _deck(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var height := rng.randf_range(1.2, 1.8)
	var deck_w := minf(10.0, hw * 2.0 - 9.0)
	var deck_len := rng.randf_range(5.0, 8.0)
	var run := clampf((band * 2.0 - deck_len) / 2.0, 3.0, 6.0)
	pieces.append([Vector3(deck_w, height, deck_len), Vector3(0.0, height / 2.0, 0.0), Vector3.ZERO])
	for dir: float in [1.0, -1.0]:
		var tilt := atan(height / run) * dir
		var ramp_len := sqrt(run * run + height * height)
		var top_z := dir * deck_len / 2.0
		# Ramps span the deck's full width: a narrower ramp leaves concave
		# corners that trap enemies who walk straight at the player (§6).
		pieces.append([Vector3(deck_w, 0.3, ramp_len), Vector3(0.0, height / 2.0 - 0.1, top_z + dir * run / 2.0), Vector3(tilt, 0.0, 0.0)])
	var side_x := deck_w / 2.0 + (hw - deck_w / 2.0) / 2.0
	if hw - deck_w / 2.0 > 7.0:
		for sx: float in [-1.0, 1.0]:
			pieces.append([Vector3(1.0, 1.2, 3.0), Vector3(sx * side_x, 0.6, rng.randf_range(-band, band)), Vector3.ZERO])
	return pieces


## Bunkers: a tall block with a low wall in front and one to the side,
## each a few metres off so you can move between the pieces. Each bunker
## faces its own way.
static func _bunkers(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var centers: Array = []
	var count := rng.randi_range(2, 3)
	var tries := 0
	while centers.size() < count and tries < 40:
		tries += 1
		var sx := 1.0 if rng.randf() < 0.5 else -1.0
		# The bunker spans 5 m to one side of its block and 3 m to the other.
		var lo := -hw + 8.5 if sx > 0.0 else -hw + 6.5
		var hi := hw - 6.5 if sx > 0.0 else hw - 8.5
		var x := rng.randf_range(lo, hi)
		var z := rng.randf_range(-band + 1.5, band - 5.0)
		var ok := true
		for c: Vector3 in centers:
			if Vector2(c.x, c.y).distance_to(Vector2(x, z)) < 11.0:
				ok = false
		if ok:
			centers.append(Vector3(x, z, sx))
	for c: Vector3 in centers:
		var sx := c.z
		var sz := 1.0 if rng.randf() < 0.5 else -1.0
		pieces.append([Vector3(2.0, 2.6, 2.0), Vector3(c.x, 1.3, c.y), Vector3.ZERO])
		pieces.append([Vector3(3.0, 1.2, 1.0), Vector3(c.x + sx * 1.5, 0.6, c.y + 4.5), Vector3.ZERO])
		pieces.append([Vector3(1.0, 1.2, 3.0), Vector3(c.x - sx * 4.5, 0.6, c.y + sz), Vector3.ZERO])
	return pieces


## A spine of tall blocks down the middle with gaps: the room becomes two
## lanes that see each other only through the gaps.
static func _spine(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var block := rng.randf_range(3.5, 5.0)
	var gap := 3.5
	var z := -band + block / 2.0
	while z + block / 2.0 <= band + 0.01:
		pieces.append([Vector3(1.4, 3.0, block), Vector3(0.0, 1.5, z), Vector3.ZERO])
		z += block + gap
	# Low walls in each lane to crouch behind.
	if hw > 8.5:
		for sx: float in [-1.0, 1.0]:
			pieces.append([Vector3(1.0, 1.2, 3.0), Vector3(sx * (hw + 0.7) / 2.0, 0.6, rng.randf_range(-band + 1.5, band - 1.5)), Vector3.ZERO])
	return pieces


## Raised walkways along both side walls, ramped at each end along the
## wall, over an open floor with a few blocks. High ground to fight from,
## and edges to slide off.
static func _catwalks(hw: float, band: float, rng: RandomNumberGenerator) -> Array:
	var pieces: Array = []
	var height := 1.4
	var walk_w := 2.5
	var run := 4.0
	var walk_len := maxf(band * 2.0 - run * 2.0, 4.0)
	for sx: float in [-1.0, 1.0]:
		var x := sx * (hw - walk_w / 2.0) # flush against the wall: no gap to trap a walker
		pieces.append([Vector3(walk_w, height, walk_len), Vector3(x, height / 2.0, 0.0), Vector3.ZERO])
		for dir: float in [1.0, -1.0]:
			var tilt := atan(height / run) * dir
			var ramp_len := sqrt(run * run + height * height)
			pieces.append([Vector3(walk_w, 0.3, ramp_len), Vector3(x, height / 2.0 - 0.1, dir * (walk_len / 2.0 + run / 2.0)), Vector3(tilt, 0.0, 0.0)])
	var inner := hw - walk_w - 4.0
	for i in rng.randi_range(2, 3):
		var x := rng.randf_range(-inner, inner) if inner > 0.0 else 0.0
		var z := lerpf(-band * 0.8, band * 0.8, float(i) / 2.0)
		pieces.append([Vector3(2.0, 2.6, 2.0), Vector3(x, 1.3, z), Vector3.ZERO])
	return pieces


## The boss room: four big pillars around an open middle, wide apart so
## the boss can circle them.
static func _arena(hw: float, band: float) -> Array:
	var pieces: Array = []
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			pieces.append([Vector3(2.4, 3.6, 2.4), Vector3(sx * (hw - 6.0), 1.8, sz * band * 0.6), Vector3.ZERO])
	return pieces


## True when a piece of this size at (x, z) leaves at least `gap` metres,
## edge to edge, to every piece already placed.
static func _clear(pieces: Array, size: Vector3, x: float, z: float, gap: float) -> bool:
	for p: Array in pieces:
		var o_size: Vector3 = p[0]
		var o_pos: Vector3 = p[1]
		var dx := absf(o_pos.x - x) - (o_size.x + size.x) / 2.0
		var dz := absf(o_pos.z - z) - (o_size.z + size.z) / 2.0
		if Vector2(maxf(dx, 0.0), maxf(dz, 0.0)).length() < gap:
			return false
	return true
