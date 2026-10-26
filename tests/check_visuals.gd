extends Node
## Visual progression contract (docs/visual-progression-plan.md): the galaxy
## level map, skill names/icons, and the campaign-only normal build.
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
	AudioServer.set_bus_mute(0, true)
	_test_galaxy()
	await _test_level_select()
	await _test_reveal()
	_test_identity()
	await _test_tree_text()
	await _test_practice_lock()
	await _test_menu_overlap()
	Progress.restore({})
	Audio.stop_all()
	await get_tree().process_frame
	print("VISUALS: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _test_galaxy() -> void:
	var stars := LevelMap.star_positions()
	check(stars.size() == Levels.COUNT, "one star per level")
	var seen := {}
	var closest := INF
	for i in stars.size():
		seen[stars[i]] = true
		var inside := absf(stars[i].x) <= LevelMap.WORLD.x / 2.0 and absf(stars[i].y) <= LevelMap.WORLD.y / 2.0
		check(inside, "star %d sits inside the galaxy" % (i + 1))
		for j in range(i + 1, stars.size()):
			closest = minf(closest, stars[i].distance_to(stars[j]))
	check(seen.size() == Levels.COUNT, "every level owns its own star")
	check(closest >= LevelMap.MIN_GAP - 0.01, "stars keep their spacing (%.0f)" % closest)
	check(LevelMap.star(Levels.FINALE) == Vector2.ZERO, "the finale burns at the core")
	check(LevelMap.star(Levels.ENDLESS).length() > LevelMap.star(Levels.CAMPAIGN).length(), "the abyss lies past the rim")
	check(LevelMap.star_positions() == stars, "layout is stable")

func _test_level_select() -> void:
	Progress.restore({})
	var select := LevelSelect.new()
	add_child(select)
	select.open()
	await get_tree().process_frame
	await get_tree().process_frame
	var map := select._map
	check(map.is_open(1) and not map.is_open(2), "new save opens only the first star")
	check(map.is_visible_star(3) and not map.is_visible_star(4), "two stars glint ahead, the rest stay dark")
	check(not map.is_visible_star(Levels.ENDLESS), "the abyss hides until it is unlocked")
	map.skip()
	map.look_at_star(1)
	check(map.pick(map.size / 2.0) == 1, "tapping the centred star picks it")
	map.look_at_star(2)
	check(map.pick(map.size / 2.0) == 0, "a locked star cannot be picked")
	var chosen: Array = []
	select.chosen.connect(func(n: int) -> void: chosen.append(n))
	select._choose(5)
	select._choose(1)
	check(chosen == [1], "locked stars never start; unlocked ones do")
	# No number anywhere a player reads it.
	var digits := RegEx.create_from_string("[0-9]")
	select._show_card(1)
	check(not digits.search(select._name.text), "the card names the star, never numbers it")
	for b in select.find_children("*", "Button", true, false):
		check(not digits.search((b as Button).text), "button text has no level number")
	Progress.merge({"unlocked": Levels.COUNT, "best": {}}, false)
	select._refresh()
	check(map.is_open(Levels.ENDLESS) and map.is_visible_star(Levels.ENDLESS), "clearing the crown reveals the abyss")
	map.travel_to(Levels.ENDLESS)
	check(map.is_travelling(), "changing stars flies")
	map.skip()
	check(not map.is_travelling() and map.selected == Levels.ENDLESS, "skipping lands on the star")
	select.queue_free()
	Progress.restore({})
	await get_tree().process_frame

func _test_reveal() -> void:
	Progress.restore({})
	var armory := Armory.new()
	add_child(armory)
	armory.open()
	check(armory._tree._positions.size() == 3, "zero coins still reveals all foundations")
	check(armory._buy.disabled, "visible foundation still requires coins to purchase")
	check(not SkillCatalog.is_revealed("moving_accuracy", {}, 30), "level alone cannot reveal a child")
	check(not SkillCatalog.is_revealed("moving_accuracy", {"swap_speed": 1}, 4), "owned parent cannot bypass level gate")
	check(SkillCatalog.is_revealed("moving_accuracy", {"swap_speed": 1}, 5), "level and owned prerequisite reveal the node")
	check(SkillCatalog.is_revealed("reload_speed", {"moving_reload": 1}, 15), "any valid alternate owned parent reveals a node")
	Progress.award("reveal-fixture", 20, SkillCatalog.xp_for_level(5))
	check(Progress.purchase("swap_speed"), "fixture purchases the foundation")
	check(Progress.ledger.coins == 0, "purchase emptied wallet")
	check(armory._tree._positions.has("moving_accuracy") and armory._tree._positions.has("dash_cooldown"), "new children appear immediately despite zero coins")
	check(not armory._tree._positions.has("slide_distance"), "grandchildren remain hidden until parent is purchased")
	check(not armory._tree._positions.has("sprint_recovery"), "higher tiers stay hidden")
	armory._tree.focus_node("moving_accuracy")
	check(not armory._buy.visible or armory._buy.disabled, "revealed child cannot be bought without coins")
	var before := armory._tree._positions.duplicate()
	Progress.award("more-coins", 1000, 0)
	check(armory._tree._positions == before, "coins never alter discovery")
	check(not armory._buy.disabled, "earning enough coins enables purchase")
	armory.open(true)
	check(armory._tree._positions.size() == 405, "practice reveals entire graph")
	armory._tree.focus_node("evasion_circuit_1_3")
	_hover(armory._tree, armory._tree.size / 2)
	armory.open(false)
	check(armory._tree._positions == before, "campaign rebuild removes unrevealed practice nodes")
	check(not armory._tree._card.visible and armory._selected == "swap_speed", "hidden selection and hover reset on mode switch")
	var hidden_at: Vector2 = SkillCatalog.nodes()["evasion_circuit_1_3"].position * armory._tree._zoom + armory._tree._pan
	check(armory._tree._pick(hidden_at) != "evasion_circuit_1_3", "hidden nodes cannot be inspected")
	armory.queue_free()
	Progress.restore({})
	await get_tree().process_frame

func _test_identity() -> void:
	var base: Array = SkillCatalog.ROOTS.duplicate()
	for path: String in SkillCatalog.PATHS:
		base.append_array(SkillCatalog.PATHS[path])
	check(base.size() == 39 and SkillIdentity.DATA.size() == 39 and SkillIdentity.ICONS.size() == 39, "39 effects, 39 identities")
	var names := {}
	var art := {}
	for id: String in base:
		check(SkillIdentity.DATA.has(id) and SkillIdentity.ICONS.has(id), "%s has a name and icon" % id)
		if not SkillIdentity.DATA.has(id):
			continue
		var texture: Texture2D = SkillIdentity.ICONS[id]
		check(texture != null and texture.get_width() >= 64, "%s icon loads at full size" % id)
		var meaning: String = SkillIdentity.DATA[id][1]
		check(not meaning.is_empty() and not meaning.contains("%"), "%s meaning is plain language" % id)
		names[SkillIdentity.DATA[id][0]] = id
		# Rendered pixels, not the .svg source: an exported APK ships only the
		# imported texture, and distinct pixels are what the player sees.
		if texture:
			art[Marshalls.raw_to_base64(texture.get_image().get_data()).sha256_text()] = id
	check(names.size() == 39, "every skill name is unique")
	check(art.size() == 39, "every icon is distinct artwork")
	# Save IDs and graph shape are untouched by the visual layer.
	var graph := SkillCatalog.nodes()
	check(graph.size() == 405, "405 nodes")
	var circuits := 0
	var bridges := 0
	var shape := []
	for id: String in graph:
		circuits += 1 if id.contains("_circuit_") else 0
		bridges += 1 if id.ends_with("_bridge") else 0
		shape.append("%s<%s" % [id, ",".join(graph[id].parents)])
		var effect := SkillCatalog.effect_of(id)
		check(SkillIdentity.DATA.has(effect), "%s resolves to a skill identity" % id)
		var title := SkillCatalog.title(id)
		check(not title.is_empty() and not title.contains("_") and not title.to_lower().contains("circuit"), "%s has a player-facing name" % id)
		check(SkillCatalog.icon(id) == SkillIdentity.ICONS[effect], "%s reuses its effect's icon" % id)
		check(not SkillCatalog.requirements(id).contains("_"), "%s prerequisites use names" % id)
	check(base.all(func(id: String) -> bool: return graph.has(id)), "original save IDs remain")
	check(circuits == 360 and bridges == 6, "circuit and bridge counts unchanged")
	shape.sort()
	check("\n".join(shape).sha256_text() == GRAPH_SHAPE, "graph IDs and edges unchanged: " + "\n".join(shape).sha256_text())
	var echo := "momentum_circuit_1_3"
	check(SkillCatalog.title(echo) == SkillIdentity.DATA[SkillCatalog.effect_of(echo)][0] + " Echo", "minor nodes are named echoes")
	check(SkillCatalog.title("momentum_bridge") == "Quickdraw Crossing", "bridges are named crossings")
	check(SkillCatalog.title("near_miss") == "Thread the Needle", "core skills keep their own name")
	check(SkillCatalog.description(echo).contains("0.25"), "exact tuning stays available")

## sha256 of the sorted "id<parents" list; update only on purpose.
const GRAPH_SHAPE := "958dba9b0ac792fd17cd32a8871d7c76af64f2d1cd0f8e3a3fcd4ac7e1931d79"

func _test_tree_text() -> void:
	var armory := Armory.new()
	add_child(armory)
	armory.open(true) # Inspect the full practice catalog, not hidden campaign nodes.
	await get_tree().process_frame
	var id := "evasion_circuit_1_3"
	armory._tree.focus_node(id)
	var tree := armory._tree
	_hover(tree, tree.size / 2)
	check(tree._card.visible and tree._card_title.text == SkillCatalog.title(id) and tree._card_meaning.text == SkillCatalog.meaning(id), "hover leads with name and meaning")
	check(tree._card_icon.texture == SkillCatalog.icon(id), "hover card shows the skill icon")
	check(not (tree._card_title.text + tree._card_meaning.text + tree._card_stats.text).contains("_"), "hover never shows save IDs")
	# Moving to another node must update the card (native tooltips went stale).
	var other := ""
	for candidate: String in tree._positions:
		var at: Vector2 = tree._positions[candidate] * tree._zoom + tree._pan
		if Rect2(Vector2(60, 60), tree.size - Vector2(120, 120)).has_point(at) and SkillCatalog.title(candidate) != SkillCatalog.title(id) and tree._pick(at) == candidate:
			other = candidate
			break
	check(not other.is_empty(), "a second visible node to hover")
	if not other.is_empty():
		_hover(tree, Vector2(tree._positions[other]) * tree._zoom + tree._pan)
		check(tree._card_title.text == SkillCatalog.title(other), "hover card follows the pointer to the next node")
		var card := Rect2(tree._card.position, tree._card.get_combined_minimum_size())
		check(Rect2(Vector2.ZERO, tree.size).encloses(card), "hover card stays inside the canvas")
	var empty := Vector2(-1, -1)
	for y in range(4, int(tree.size.y), 12):
		if tree._pick(Vector2(4, y)).is_empty():
			empty = Vector2(4, y)
			break
	check(empty.x >= 0, "an empty spot to hover")
	_hover(tree, empty)
	check(not tree._card.visible, "hover card hides over empty space")
	# Height is fixed at 720 and width follows the window (stretch "expand"),
	# so a 4:3 window is 960 wide. Any row needing more pushes the layout past
	# the edge and clips the inspector, as an unwrapped help line once did.
	var layout: Control = armory.get_child(1)
	check(layout.get_combined_minimum_size().x <= 960 - 48, "Armory fits a 4:3 window (needs %d px)" % layout.get_combined_minimum_size().x)
	check(armory._title.text == SkillCatalog.title(id) and armory._detail.text == SkillCatalog.meaning(id), "inspector leads with name and meaning")
	check(armory._icon.texture == SkillCatalog.icon(id), "inspector shows the skill icon")
	check(not (armory._title.text + armory._detail.text + armory._stats.text).contains("_"), "inspector shows no save IDs")
	armory.queue_free()
	await get_tree().process_frame

## On phones Play Games is available, so the menu's sign-in button exists.
## It shares the panels' layer and drew over the Armory header (seen on the
## emulator); it must show only on the title menu.
func _test_menu_overlap() -> void:
	var was_available := PlayGames.available
	PlayGames.available = true
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await get_tree().process_frame
	check(menu._gamer.visible, "sign-in button shows on the title menu")
	menu._open_armory(false)
	check(menu._armory.visible and not menu._gamer.visible, "sign-in button hides under the Armory")
	menu._armory.close()
	check(menu._gamer.visible, "sign-in button returns with the title menu")
	menu._open_levels()
	check(not menu._gamer.visible, "sign-in button hides under the level map")
	menu._levels.close()
	menu._open_settings()
	check(not menu._gamer.visible, "sign-in button hides under settings")
	menu.queue_free()
	PlayGames.available = was_available
	await get_tree().process_frame

func _hover(tree: SkillTree, at: Vector2) -> void:
	var motion := InputEventMouseMotion.new()
	motion.position = at
	tree._gui_input(motion)

func _test_practice_lock() -> void:
	Progress.restore({})
	Progress.select_build([], ["railgun", "arc", "plasma"], "emp", true)
	var armory := Armory.new()
	add_child(armory)
	armory.open()
	armory._preview.button_pressed = true
	check(not armory.practice and not armory._preview.button_pressed, "campaign Armory refuses the practice build")
	check(armory._practice_warning.visible, "turning practice on outside the range shows the notice")
	var notice := armory._practice_warning.get_child(0) as Label
	check(notice.text.begins_with("PRACTICE BUILD IS TURNED OFF"), "notice says practice build is turned off")
	check(armory._practice_warning.mouse_filter == Control.MOUSE_FILTER_IGNORE, "notice never blocks input")
	check(armory._tree.owned == Progress.ledger.owned and armory._tree.active == Progress.active, "the normal build stays on screen")
	armory.open(true)
	check(armory.practice and armory._enter_range.visible, "practice build works from Practice Range")
	armory._practice_warning.visible = false
	armory.open()
	check(not armory.practice and armory._practice_warning.visible, "leaving the range turns practice off with the notice")
	armory.open(true)
	Game.notice = ""
	armory.prepare_campaign()
	check(not armory.practice and Game.notice == Armory.PRACTICE_OFF, "campaign launch discards practice and queues the notice")
	Game.mode = Game.Mode.RUN
	Game.level = 1
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	await get_tree().physics_frame
	check(game._player.build.guns == Progress.guns and not game._player.build.guns.has("railgun"), "campaign runs the normal build")
	for i in 60:
		await get_tree().physics_frame
	check(game._hud._notice.text.begins_with(Armory.PRACTICE_OFF), "the notice survives wave banners")
	check(Game.notice.is_empty(), "the notice shows once")
	get_tree().paused = false
	game.queue_free()
	await get_tree().process_frame
	armory.prepare_campaign()
	check(Game.notice.is_empty(), "no notice when practice was off")
	Game.mode = Game.Mode.PRACTICE
	game = load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	await get_tree().physics_frame
	check(game._player.build.guns == Progress.practice_guns, "Practice Range runs the practice build")
	get_tree().paused = false
	game.queue_free()
	Game.mode = Game.Mode.RUN
	armory.queue_free()
	await get_tree().process_frame
