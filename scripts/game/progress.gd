extends Node
## Persistent campaign and expansion state. All mutations are transactional:
## durable write first, then changed. Room/kill event IDs make retries harmless.
signal changed
signal problem(message: String)
const PATH := "user://progress.cfg"
const SCHEMA := 2
var unlocked := 1
var best := {} # expansion scores, integer campaign keys
var legacy_best := {}
var clears := {} # string level keys, compatible with JSON
## Furthest wave reached in the endless level.
var endless_wave := 0
var ledger := ProgressionState.new()
var active: Array = []
var guns: Array = Arsenal.DEFAULT.duplicate()
var grenade := ""
var practice_guns: Array = Arsenal.DEFAULT.duplicate()
var practice_active: Array = []
var practice_grenade := "frag"
var writable := true
var last_error := ""
var isolated := false

func _ready() -> void:
	isolated = DeviceTest.user_args().has("--isolated") or not DeviceTest.scene().is_empty()
	if isolated:
		return
	load_from_disk()

func load_from_disk() -> void:
	for path: String in [PATH, PATH + ".bak"]:
		var cfg := ConfigFile.new()
		if cfg.load(path) != OK:
			continue
		var data: Variant = cfg.get_value("progress", "data", null)
		if not cfg.has_section_key("progress", "data"):
			data = {"unlocked": cfg.get_value("progress", "unlocked", 1), "best": cfg.get_value("progress", "best", {})}
		if data is Dictionary and _valid_data(data):
			merge(data, false)
			if writable:
				_load_xp_journal()
			return
	if FileAccess.file_exists(PATH):
		writable = false
		_fail("No valid progress backup could be loaded. Existing files were preserved.")

func is_unlocked(level: int) -> bool:
	return level <= unlocked

func best_for(level: int) -> int:
	return int(best.get(level, 0))

func player_level() -> int:
	return SkillCatalog.player_level(ledger.xp)

func snapshot(practice := false) -> Dictionary:
	if practice:
		var all_ranks := {}
		for id: String in SkillCatalog.nodes():
			all_ranks[id] = SkillCatalog.nodes()[id].max
		return {"guns": Arsenal.loadout(practice_guns, clears, true), "grenade": practice_grenade,
			"effects": SkillCatalog.effects(SkillCatalog.valid_active(practice_active, all_ranks, 30), all_ranks)}
	return {"guns": guns.duplicate(), "grenade": grenade, "effects": SkillCatalog.effects(active, ledger.owned)}

func to_dict() -> Dictionary:
	return {"schema": SCHEMA, "unlocked": unlocked, "best": _string_scores(best),
		"legacy_best": _string_scores(legacy_best), "clears": clears.duplicate(),
		"records": ledger.records.duplicate(true), "conflicts": ledger.conflicts.duplicate(),
		"active": active.duplicate(), "guns": guns.duplicate(), "grenade": grenade,
		"endless_wave": endless_wave}

func _string_scores(scores: Dictionary) -> Dictionary:
	var result := {}
	for key: Variant in scores:
		result[str(key)] = scores[key]
	return result

## Used to roll back failed writes and by isolated test fixtures.
func restore(data: Dictionary) -> void:
	unlocked = int(data.get("unlocked", 1))
	best = {}
	legacy_best = {}
	_read_scores(data.get("best", {}), best)
	_read_scores(data.get("legacy_best", {}), legacy_best)
	clears = data.get("clears", {}).duplicate()
	endless_wave = int(data.get("endless_wave", 0))
	ledger = ProgressionState.new()
	ledger.merge(data.get("records", {}), data.get("conflicts", []))
	active = data.get("active", []).duplicate()
	guns = data.get("guns", Arsenal.DEFAULT).duplicate()
	grenade = String(data.get("grenade", ""))
	_validate_selection()

func _read_scores(source: Dictionary, target: Dictionary) -> void:
	for key: Variant in source:
		var n := int(key)
		if n >= 1 and n <= Levels.COUNT:
			target[n] = maxi(int(target.get(n, 0)), maxi(0, int(source[key])))

func merge(data: Dictionary, persist := true) -> void:
	if not _valid_data(data):
		_fail("Invalid progress data was ignored; the last valid save is unchanged.")
		return
	var version := int(data.get("schema", 1))
	if version > SCHEMA:
		writable = false
		_fail("This save requires a newer game version. It has not been overwritten.")
		return
	var previous := to_dict()
	unlocked = clampi(maxi(unlocked, int(data.get("unlocked", 1))), 1, Levels.COUNT)
	if version < 2:
		_read_scores(data.get("best", {}), legacy_best)
		for n in range(1, unlocked):
			clears[str(n)] = true
		for n: int in legacy_best:
			clears[str(n)] = true
		for key: String in clears:
			_add_clear_reward(int(key))
	else:
		_read_scores(data.get("best", {}), best)
		_read_scores(data.get("legacy_best", {}), legacy_best)
		for key: Variant in data.get("clears", {}):
			if int(key) >= 1 and int(key) <= Levels.COUNT:
				clears[str(int(key))] = true
		ledger.merge(data.get("records", {}), data.get("conflicts", []))
		endless_wave = maxi(endless_wave, int(data.get("endless_wave", 0)))
		# Disk load restores choices; cloud merges retain local choices.
		if not persist:
			active = data.get("active", []).duplicate()
			guns = data.get("guns", Arsenal.DEFAULT).duplicate()
			grenade = String(data.get("grenade", ""))
	_validate_selection()
	if persist:
		_commit(previous)
	else:
		changed.emit()
	if not ledger.rejected.is_empty():
		problem.emit("Some conflicting offline purchases were not accepted. Your balance and skills were reconciled.")

func _validate_selection() -> void:
	active = SkillCatalog.valid_active(active, ledger.owned, player_level())
	guns = Arsenal.loadout(guns, clears)
	if not Arsenal.GRENADES.has(grenade) or not Arsenal.available(grenade, clears):
		grenade = "frag" if Arsenal.available("frag", clears) else ""

func _add_clear_reward(level: int) -> void:
	var key := "clear/%d" % level
	if not ledger.records.has(key):
		ledger.records[key] = {"type": "earn", "coins": 30 + level * 2, "xp": 100 + level * 10}
	ledger.rebuild()

func complete(level: int, score: int) -> bool:
	var previous := to_dict()
	unlocked = clampi(maxi(unlocked, level + 1), 1, Levels.COUNT)
	best[level] = maxi(best_for(level), score)
	clears[str(level)] = true
	_add_clear_reward(level)
	_validate_selection()
	return _commit(previous)

## The endless level is never cleared; a run's end only raises its records.
func record_endless(wave: int, score: int) -> bool:
	if wave <= endless_wave and score <= best_for(Levels.ENDLESS):
		return true
	var previous := to_dict()
	endless_wave = maxi(endless_wave, wave)
	best[Levels.ENDLESS] = maxi(best_for(Levels.ENDLESS), score)
	return _commit(previous)

func award(id: String, coins: int, xp: int) -> bool:
	if not ProgressionState.integer(coins) or not ProgressionState.integer(xp):
		_fail("Invalid reward was ignored.")
		return false
	if ledger.records.has(id):
		return true
	if coins == 0:
		# Kills append a small durable record instead of rewriting the entire
		# campaign journal on the combat thread. Room banks checkpoint it.
		if not writable or (not isolated and not _append_xp(id, xp)):
			return false
		ledger.records[id] = {"type": "earn", "coins": 0, "xp": xp}
		ledger.xp += xp
		changed.emit()
		return true
	var previous := to_dict()
	ledger.records[id] = {"type": "earn", "coins": coins, "xp": xp}
	ledger.rebuild()
	return _commit(previous)

func purchase(id: String) -> bool:
	var record := ledger.purchase_record(id)
	if record.is_empty():
		_fail("Need more coins, the player level, or a prerequisite rank.")
		return false
	var previous := to_dict()
	ledger.records[ProgressionState.uid()] = record
	ledger.rebuild()
	return _commit(previous)

func select_build(nodes: Array, loadout: Array, selected_grenade: String, practice := false) -> bool:
	if practice:
		var ranks := {}
		for id: String in SkillCatalog.nodes():
			ranks[id] = SkillCatalog.nodes()[id].max
		practice_active = SkillCatalog.valid_active(nodes, ranks, 30)
		practice_guns = Arsenal.loadout(loadout, clears, true)
		practice_grenade = selected_grenade if Arsenal.GRENADES.has(selected_grenade) else "frag"
		changed.emit()
		return true
	var previous := to_dict()
	active = nodes.duplicate()
	guns = loadout.duplicate()
	grenade = selected_grenade
	_validate_selection()
	return _commit(previous)

func save() -> bool:
	return _commit(to_dict())

func _commit(previous: Dictionary) -> bool:
	if not writable:
		restore(previous)
		return false
	if not isolated:
		var cfg := ConfigFile.new()
		cfg.set_value("progress", "data", to_dict())
		var err := cfg.save(PATH + ".tmp")
		if err == OK:
			if FileAccess.file_exists(PATH + ".bak"):
				DirAccess.remove_absolute(PATH + ".bak")
			if FileAccess.file_exists(PATH):
				err = DirAccess.rename_absolute(PATH, PATH + ".bak")
			if err == OK:
				err = DirAccess.rename_absolute(PATH + ".tmp", PATH)
				if err != OK and FileAccess.file_exists(PATH + ".bak"):
					DirAccess.rename_absolute(PATH + ".bak", PATH)
		if err != OK:
			restore(previous)
			_fail("Progress could not be saved. Free storage and retry.")
			return false
		# A checkpoint includes every XP event. Old duplicate lines are safe
		# even if cleanup fails; load deduplicates by event ID.
		if FileAccess.file_exists(PATH + ".xp"):
			DirAccess.remove_absolute(PATH + ".xp")
	last_error = ""
	changed.emit()
	return true

func _append_xp(id: String, xp: int) -> bool:
	if not FileAccess.file_exists(PATH) and not _commit(to_dict()):
		return false
	var path := PATH + ".xp"
	var file := FileAccess.open(path, FileAccess.READ_WRITE if FileAccess.file_exists(path) else FileAccess.WRITE_READ)
	if file == null:
		_fail("XP could not be saved. Free storage and retry.")
		return false
	file.seek_end()
	file.store_string("\n") # Separate any interrupted, unacknowledged tail.
	file.store_line(JSON.stringify({"id": id, "xp": xp}))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		_fail("XP could not be saved. Free storage and retry.")
		return false
	last_error = ""
	return true

func _load_xp_journal() -> void:
	if not FileAccess.file_exists(PATH + ".xp"):
		return
	var file := FileAccess.open(PATH + ".xp", FileAccess.READ)
	if file == null:
		return
	var incoming := {}
	while not file.eof_reached():
		var line := file.get_line()
		if line.is_empty():
			continue
		var parser := JSON.new()
		if parser.parse(line) != OK or not parser.data is Dictionary:
			continue # An interrupted final write has not been acknowledged.
		var event: Dictionary = parser.data
		if event.get("id") is String and ProgressionState.integer(event.get("xp")):
			incoming[event.id] = {"type": "earn", "coins": 0, "xp": int(event.xp)}
	file.close()
	ledger.merge(incoming)
	_validate_selection()
	changed.emit()

func _fail(message: String) -> void:
	last_error = message
	problem.emit(message)

## Cloud JSON is untrusted input, including fields not used by this device.
func _valid_data(data: Dictionary) -> bool:
	if not ProgressionState.integer(data.get("schema", 1), 1000) or not ProgressionState.integer(data.get("unlocked", 1), Levels.COUNT):
		return false
	if not ProgressionState.integer(data.get("endless_wave", 0), 1000000):
		return false
	for key: String in ["best", "legacy_best", "clears", "records"]:
		if not data.get(key, {}) is Dictionary:
			return false
	for key: String in ["active", "guns", "conflicts"]:
		if not data.get(key, []) is Array:
			return false
		for value: Variant in data.get(key, []):
			if not value is String:
				return false
	if not data.get("grenade", "") is String:
		return false
	for group: String in ["best", "legacy_best"]:
		for key: Variant in data.get(group, {}):
			if not str(key).is_valid_int() or not ProgressionState.integer(data[group][key], 2147483647):
				return false
	for key: Variant in data.get("clears", {}):
		if not str(key).is_valid_int() or data.clears[key] != true:
			return false
	return true
