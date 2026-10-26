extends Node
## Pure progression checks plus real run/Armory integration, always isolated.
var failures: Array[String] = []

func check(ok: bool, message: String) -> void:
	if not ok:
		failures.append(message)
		printerr(message)

func _ready() -> void:
	if not Progress.isolated:
		printerr("Use tools/check_game.py; these checks require --isolated")
		get_tree().quit(1)
		return
	_test_tree()
	_test_ledger()
	_test_progress()
	_test_disk()
	await _test_game()
	await _test_combat()
	Audio.stop_all()
	await get_tree().process_frame
	print("EXPANSION: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_tree() -> void:
	var graph := SkillCatalog.nodes()
	check(graph.size() == 405, "tree must contain 405 purchasable nodes")
	var owned := {}
	for id: String in graph:
		owned[id] = graph[id].max
	check(SkillCatalog.player_level(0) == 1 and SkillCatalog.player_level(1000000) == 30, "XP cap")
	check(SkillCatalog.slots(1) == 4 and SkillCatalog.slots(25) == 24, "slot gates")
	var reachable := {}
	for pass_index in graph.size():
		var previous_size := reachable.size()
		for id: String in graph:
			if pass_index == 0:
				check(not SkillCatalog.description(id).is_empty(), "every node explains its effect")
				for parent: String in graph[id].parents:
					check(graph.has(parent), "parent exists: " + parent)
			if SkillCatalog.parent_owned(graph[id], reachable):
				reachable[id] = 1
		if previous_size == reachable.size():
			break
	check(reachable.size() == 405, "all nodes reachable from foundations")
	var all_effects := SkillCatalog.effects(graph.keys(), owned)
	for effect: String in all_effects:
		check(float(all_effects[effect]) <= 3.0, "aggregate effect bounded")
	var minor := SkillCatalog.effects(["momentum_circuit_1_1"], owned)
	check(is_equal_approx(float(minor.moving_accuracy), 0.25), "minor nodes affect combat")
	var route: Array = ["swap_speed", "moving_accuracy", "slide_distance", "moving_reload", "reload_speed", "focus_fire"]
	check(SkillCatalog.valid_active(route, owned, 25).size() == 6, "cross-link route")
	check(SkillCatalog.valid_active(route, owned, 5).size() == 4, "advanced tier locked")
	route.erase("moving_reload")
	check(SkillCatalog.valid_active(route, owned, 30).size() == 3, "dependents removed")
	var all := SkillCatalog.valid_active(graph.keys(), owned, 30)
	var capstones := 0
	for id: String in all:
		capstones += int(graph[id].cap)
	check(all.size() <= 24 and capstones <= 1, "slot/capstone limit")
	check(SkillCatalog.valid_active(["swap_speed", "swap_speed", "missing"], owned, 30) == ["swap_speed"], "duplicates and unknown IDs")
	check(SkillCatalog.nodes().grenade_capacity.max == 1, "capacity rank limit")
	var hybrid: Array = ["swap_speed", "moving_accuracy", "slide_distance", "moving_reload", "momentum_bridge", "dash_reload"]
	check(SkillCatalog.valid_active(hybrid, owned, 15) == hybrid, "bridge opens neighboring advanced route")
	# Every node must fit a valid activation route, not just be theoretically owned.
	var routes := {}
	for pass_index in 15:
		for id: String in graph:
			if routes.has(id):
				continue
			if graph[id].parents.is_empty():
				routes[id] = [id]
			for parent: String in graph[id].parents:
				if routes.has(parent):
					var candidate: Array = routes[parent].duplicate()
					candidate.append(id)
					if SkillCatalog.valid_active(candidate, owned, 30) == candidate:
						routes[id] = candidate
						break
	check(routes.size() == 405, "every node has an equippable route within slot/cap limits")

func _test_ledger() -> void:
	var seed := {"seed": {"type": "earn", "coins": 100, "xp": 100000}}
	var left := ProgressionState.new()
	left.merge(seed)
	var right := ProgressionState.new()
	right.merge(seed)
	left.records["a"] = left.purchase_record("swap_speed")
	right.records["b"] = right.purchase_record("recoil_recovery")
	left.rebuild()
	right.rebuild()
	var combined := ProgressionState.new()
	combined.merge(left.records)
	combined.merge(right.records)
	var reversed := ProgressionState.new()
	reversed.merge(right.records)
	reversed.merge(left.records)
	check(combined.coins == 80 and combined.owned == {"swap_speed": 1}, "concurrent spend accepts one purchase")
	check(combined.owned == reversed.owned and combined.coins == reversed.coins, "merge-order independence")
	combined.merge(left.records)
	check(combined.coins == 80 and combined.xp == 100000, "merge deduplicates rewards")
	combined.records["c"] = combined.purchase_record("swap_speed")
	combined.rebuild()
	check(combined.owned.swap_speed == 2 and combined.coins == 40, "change output and rank upgrade")
	combined.records["d"] = combined.purchase_record("moving_accuracy")
	combined.rebuild()
	check(not combined.owned.has("moving_accuracy"), "insufficient funds")
	var bad := ProgressionState.new()
	bad.merge({"x": {"type": "earn", "coins": -1, "xp": 2}})
	check(bad.coins == 0 and bad.xp == 0, "negative earning rejected")
	bad.merge(seed)
	bad.merge({"seed": {"type": "earn", "coins": 200, "xp": 100000}})
	check(bad.coins == 0, "conflicting payload tombstoned")

func _test_progress() -> void:
	Progress.restore({})
	Progress.merge({"unlocked": 10, "best": {"1": 0, "9": 20}}, false)
	check(Progress.clears.size() == 9 and Progress.clears.has("1"), "legacy zero-score clear and inferred clears")
	check(Progress.legacy_best.has(1) and Progress.best.is_empty(), "legacy score isolation")
	var coins := Progress.ledger.coins
	var xp := Progress.ledger.xp
	Progress.merge({"unlocked": 10, "best": {"1": 0, "9": 20}}, false)
	check(Progress.ledger.coins == coins and Progress.ledger.xp == xp, "migration is idempotent")
	Progress.merge({"unlocked": 99, "best": {}}, false)
	check(not Progress.clears.has("99"), "unlock 99 is not clear 99")
	Progress.complete(99, 0)
	check(Progress.clears.has("99"), "zero-score final clear recorded")
	check(Progress.award("kill-test", 0, 30), "XP commit")
	var before := Progress.ledger.xp
	Progress.award("kill-test", 0, 30)
	check(Progress.ledger.xp == before, "duplicate kill ignored")
	Progress.purchase("swap_speed")
	check(Progress.ledger.owned.get("swap_speed", 0) == 1, "purchase through Progress")
	Progress.select_build(["swap_speed"], ["smg", "plasma", "arc"], "emp")
	check(Progress.active == ["swap_speed"] and Progress.guns[0] == "smg", "persisted build selection")
	var snapshot := Progress.to_dict()
	Progress.restore(JSON.parse_string(JSON.stringify(snapshot)))
	check(Progress.active == ["swap_speed"] and Progress.clears.has("99"), "JSON roundtrip")
	Progress.writable = false
	var balance := Progress.ledger.coins
	check(not Progress.award("failed", 5, 0) and Progress.ledger.coins == balance, "failed write rolls back")
	Progress.writable = true
	var valid := Progress.to_dict()
	Progress.merge({"schema": 2, "guns": "bad", "records": []})
	check(Progress.to_dict() == valid, "malformed snapshot preserves state")
	check(not PlayGames._merge_bytes("not json".to_utf8_buffer()), "malformed cloud cannot trigger upload")
	Progress.restore({})

func _test_disk() -> void:
	# The runner redirects user:// into build/test-profile; never use real data.
	Progress.isolated = false
	check(Progress.award("disk/one", 30, 20), "durable write")
	check(Progress.award("disk/kill", 0, 40), "durable XP journal append")
	Progress.restore({})
	Progress.load_from_disk()
	check(Progress.ledger.coins == 30 and Progress.ledger.xp == 60, "XP journal recovers after process restart")
	check(Progress.award("disk/two", 40, 30), "second durable write creates backup")
	var cfg := ConfigFile.new()
	check(cfg.load(Progress.PATH) == OK and cfg.has_section_key("progress", "data"), "versioned save readable")
	var file := FileAccess.open(Progress.PATH, FileAccess.WRITE)
	file.store_string("[progress]\ndata=\"invalid\"")
	file.close()
	Progress.restore({})
	Progress.load_from_disk()
	check(Progress.ledger.coins == 30, "corrupt primary recovers last backup")
	Progress.isolated = true
	Progress.restore({})

func _test_game() -> void:
	Game.mode = Game.Mode.RUN
	Game.level = 1
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	await get_tree().physics_frame
	game._unbanked = 42
	game._on_room_cleared(0, 1)
	check(Progress.ledger.coins == 42 and game._unbanked == 0, "final-room bank")
	game._on_room_cleared(0, 1)
	check(Progress.ledger.coins == 42, "room bank idempotence")
	game._unbanked = 10
	game._on_player_died("test")
	check(Progress.ledger.coins == 42, "death retains bank, not room coins")
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	var armory := Armory.new()
	add_child(armory)
	armory.open()
	check(armory._tree._positions.size() == 3, "fresh campaign reveals only foundations")
	armory.open(true)
	check(armory._tree._positions.size() == 405, "practice graph fully rendered and pickable")
	armory._tree.focus_node("momentum_circuit_1_1")
	check(armory._tree._pick(armory._tree.size / 2) == "momentum_circuit_1_1", "zoomed node hit test")
	var hover := InputEventMouseMotion.new()
	hover.position = armory._tree.size / 2
	armory._tree._gui_input(hover)
	check(armory._tree._card.visible and armory._tree._card_stats.text.contains("0.25"), "hover explains minor effect")
	var anchor := Vector2(100, 100)
	var before: Vector2 = (anchor - armory._tree._pan) / armory._tree._zoom
	armory._tree.zoom_by(1.2, anchor)
	check(before.is_equal_approx((anchor - armory._tree._pan) / armory._tree._zoom), "zoom preserves pointer world position")
	armory._tree.focus_node("momentum_circuit_1_1")
	var inspected: Array = []
	armory._tree.selected.connect(func(id: String) -> void: inspected.append(id))
	var touch := InputEventScreenTouch.new()
	touch.position = armory._tree.size / 2
	touch.pressed = true
	armory._tree._gui_input(touch)
	touch.pressed = false
	armory._tree._gui_input(touch)
	check(inspected == ["momentum_circuit_1_1"], "touch tap inspects one node")
	inspected.clear()
	touch.pressed = true
	armory._tree._gui_input(touch)
	var drag := InputEventScreenDrag.new()
	drag.relative = Vector2(40, 20)
	drag.position = touch.position + drag.relative
	armory._tree._gui_input(drag)
	touch.pressed = false
	touch.position = drag.position
	armory._tree._gui_input(touch)
	check(inspected.is_empty(), "touch pan never selects or purchases")
	armory.practice = true
	armory._refresh()
	check(armory._buy.disabled, "practice cannot spend coins")
	var bank := Progress.ledger.coins
	Progress.select_build(["swap_speed"], ["railgun", "arc", "plasma"], "incendiary", true)
	check(Progress.ledger.coins == bank and Progress.guns == Arsenal.DEFAULT, "practice selection is separate")
	armory.queue_free()
	await get_tree().process_frame

func _test_combat() -> void:
	var world := Node3D.new()
	add_child(world)
	var player := Player.new()
	player.build = {"guns": ["rifle", "shotgun", "marksman"], "grenade": "frag", "effects": {"grenade_capacity": 1, "precision_feed": 1}}
	world.add_child(player)
	player.set_physics_process(false)
	check(player.grenade_cap == 3 and player.grenades == 2, "grenade capacity does not alter starting supply")
	for id: String in Arsenal.GUNS:
		var weapon := Arsenal.make(id)
		weapon.camera = player.camera
		weapon.fx_parent = world
		weapon.wielder = player
		player.camera.add_child(weapon)
		check(weapon.mag > 0 and weapon.kind == StringName(id), "weapon factory: " + id)
		weapon._raise = 0.0
		weapon._fire()
		check(weapon.mag == weapon.mag_size - 1, "ammo consumed: " + id)
		weapon.queue_free()
	var enemy := Heavy.new()
	enemy.target = player
	enemy.dummy = true
	enemy.position = Vector3(0, 0, -8)
	world.add_child(enemy)
	enemy._activate()
	var deaths := [0]
	enemy.died.connect(func(_e: Enemy) -> void: deaths[0] += 1)
	Combat.hit(enemy, 10000, -1, &"frag", player.global_position, player, {})
	Combat.hit(enemy, 10000, -1, &"incendiary", player.global_position, player, {})
	check(deaths[0] == 1 and enemy.last_hit_by == &"frag", "overlapping damage awards one death and preserves source")
	var wall := StaticBody3D.new()
	var collision := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(10, 10, 1)
	collision.shape = box
	wall.add_child(collision)
	wall.position = Vector3(0, 0, -4)
	world.add_child(wall)
	await get_tree().physics_frame
	check(not Combat.visible(world, Vector3(0, 1, 0), Vector3(0, 1, -8)), "cover blocks area/chain visibility")
	player._aim_velocity = Vector3(0, 3, -10)
	player.throw_grenade()
	check(player.grenades == 1, "throw consumes one charge")
	player.cancel_grenade()
	check(player.grenades == 1, "cancel consumes no charge")
	world.queue_free()
	await get_tree().process_frame
