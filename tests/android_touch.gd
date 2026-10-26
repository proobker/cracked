extends Node
## Real-touch tour for a phone or emulator, driven by tools/check_android.py.
## The scene names a target in screen pixels ("TAP name x y" / "SWIPE name
## x1 y1 x2 y2 ms"); the harness performs it with `adb shell input`, so the
## whole Android touch path is exercised, then the scene checks the result.
## "SHOT name" asks the harness for a real device screenshot.
## Menu actions that would change scene (starting a level, entering the range)
## are not tapped; gameplay is instantiated here instead.
var failures: Array[String] = []
const WAIT := 10.0

func check(ok: bool, message: String) -> void:
	print("CHECK %s %s" % ["ok" if ok else "FAIL", message])
	if not ok:
		failures.append(message)

func _ready() -> void:
	if not Progress.isolated:
		printerr("Run through tools/check_android.py")
		get_tree().quit(1)
		return
	check(DisplayServer.is_touchscreen_available(), "touchscreen detected")
	var screen := DisplayServer.screen_get_size()
	print("SCREEN %d %d viewport %s" % [screen.x, screen.y, get_viewport().get_visible_rect().size])
	check(screen.x > screen.y, "landscape orientation")
	await _menu_tour()
	await _game_tour()
	Audio.stop_all()
	print("ANDROID TOUCH: %d failures" % failures.size())
	get_tree().quit(0 if failures.is_empty() else 1)

func _menu_tour() -> void:
	var menu: Node = load("res://scenes/menu.tscn").instantiate()
	add_child(menu)
	await _frames(20)
	await _shot("menu")
	check(not menu._menu.get_children().any(func(c: Node) -> bool: return c is Button and c.text == "QUIT"), "no QUIT button on mobile")

	await _tap("play", menu._play_button)
	check(await _until(func() -> bool: return menu._levels.visible), "PLAY opens the galaxy map")
	var levels: LevelSelect = menu._levels
	await _wait(2.0) # the opening flight down onto the first star
	await _shot("levels")
	var map := levels._map
	var star := func(n: int) -> Vector2: return map.get_global_transform() * map.to_screen(LevelMap.star(n))
	var chosen: Array = []
	levels.chosen.connect(func(n: int) -> void: chosen.append(n))
	# Disconnect the menu's own handler so a stray start cannot leave the test.
	for connection: Dictionary in levels.chosen.get_connections():
		if connection.callable.get_object() == menu:
			levels.chosen.disconnect(connection.callable)
	await _tap_at("locked-star", star.call(2))
	await _frames(20)
	check(chosen.is_empty(), "tapping a locked star does nothing")
	await _tap_at("star-1", star.call(1))
	check(await _until(func() -> bool: return chosen == [1]), "tapping the current star starts it")
	var reach := LevelMap.PICK_RADIUS * 2.0 * get_viewport().get_screen_transform().get_scale()
	print("STAR TARGET %s" % reach)
	check(reach.x >= 40 and reach.y >= 40, "star tap targets are at least 40 px on screen")

	var armory_button: Button = _find_button(levels, "Armory")
	await _tap("levels-armory", armory_button)
	var armory: Armory = menu._armory
	check(await _until(func() -> bool: return armory.visible), "ARMORY opens from the level map")
	await _frames(10)
	await _shot("armory")
	var tree := armory._tree
	var target := _visible_node(tree, armory._selected)
	check(not target.is_empty(), "a tree node is on screen to tap")
	if not target.is_empty():
		await _tap_at("tree-node", tree.global_position + Vector2(tree._positions[target]) * tree._zoom + tree._pan)
		check(await _until(func() -> bool: return armory._selected == target), "tapping a node inspects it")
		check(armory._title.text == SkillCatalog.title(target), "inspector shows the tapped skill")
		await _shot("armory-inspect")
		var pan := tree._pan
		var from := tree.global_position + tree.size * Vector2(0.3, 0.5)
		await _swipe("tree-pan", from, from + Vector2(260, 60), 400)
		check(await _until(func() -> bool: return tree._pan.distance_to(pan) > 100), "dragging pans the tree")
		check(armory._selected == target, "panning never changes the selection")
	await _tap("practice-toggle", armory._preview)
	check(await _until(func() -> bool: return armory._practice_warning.visible), "practice toggle outside the range shows the notice")
	check(not armory.practice, "practice build stays off outside the range")
	await _shot("practice-warning")
	await _tap("armory-back", _find_button(armory, "Back"))
	check(await _until(func() -> bool: return levels.visible and not armory.visible), "Armory BACK returns to the level map")
	await _tap("levels-back", _find_button(levels, "Back"))
	check(await _until(func() -> bool: return menu._menu.visible and not levels.visible), "level map BACK returns to the menu")

	await _tap("practice-range", _find_button(menu._menu, "PRACTICE RANGE"))
	check(await _until(func() -> bool: return armory.visible and armory.practice), "PRACTICE RANGE opens the practice build")
	check(armory._enter_range.visible, "ENTER RANGE is offered")
	await _shot("practice-armory")
	await _tap("practice-back", _find_button(armory, "Back"))
	check(await _until(func() -> bool: return menu._menu.visible), "practice Armory BACK returns to the menu")

	await _tap("settings", _find_button(menu._menu, "SETTINGS"))
	check(await _until(func() -> bool: return menu._settings.visible), "SETTINGS opens")
	await _shot("settings")
	await _tap("settings-back", _find_button(menu._settings, "BACK"))
	check(await _until(func() -> bool: return menu._menu.visible and not menu._settings.visible), "settings BACK returns to the menu")
	menu.queue_free()
	await _frames(2)

func _game_tour() -> void:
	Progress.restore({})
	Game.mode = Game.Mode.RUN
	Game.level = 1
	var game := load("res://scenes/main.tscn").instantiate() as Game
	add_child(game)
	await _frames(30)
	var touch := game._touch
	check(touch.visible, "touch controls shown in a run")
	await _shot("game")
	var player := game._player
	var yaw := player.rotation.y
	var look_from := touch.get_global_rect().size * Vector2(0.62, 0.35)
	await _swipe("look", look_from, look_from + Vector2(240, 0), 300)
	check(await _until(func() -> bool: return absf(player.rotation.y - yaw) > 0.05), "swiping the right side turns the camera")
	var mag := player.weapon.mag
	await _swipe("fire", _touch_button(touch, &"fire"), _touch_button(touch, &"fire"), 600)
	check(await _until(func() -> bool: return player.weapon.mag < mag), "holding FIRE shoots")
	var start := player.global_position
	# The stick is fixed: grabbing it off-centre does not move its base.
	var home := touch.get_global_transform() * touch._stick_home()
	await _swipe("move", home + Vector2(30, 20), home + Vector2(30, -80), 1500)
	check(await _until(func() -> bool: return player.global_position.distance_to(start) > 0.5), "the left stick moves the player")
	check(touch._stick_origin.is_equal_approx(touch._stick_home()), "the stick stays where it lives")
	await _tap_at("pause", _touch_button(touch, &"pause"))
	check(await _until(func() -> bool: return get_tree().paused), "the II button pauses")
	check(not touch.visible, "touch controls hide under the pause overlay")
	await _shot("pause")
	get_tree().paused = false
	game.queue_free()
	await _frames(2)

## Screen position of a touch button, from TouchControls' own layout.
func _touch_button(touch: TouchControls, action: StringName) -> Vector2:
	for b: Dictionary in touch._buttons:
		if b.action == action:
			return touch.get_global_transform() * touch._center(b)
	return Vector2.ZERO

func _visible_node(tree: SkillTree, avoid: String) -> String:
	var area := Rect2(Vector2(60, 40), (tree.size - Vector2(120, 80)).max(Vector2.ZERO))
	for id: String in tree._positions:
		var at: Vector2 = tree._positions[id] * tree._zoom + tree._pan
		if id != avoid and area.has_point(at) and tree._pick(at) == id:
			return id
	return ""

## By label, or by tooltip for icon-only buttons.
func _find_button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		var b := node as Button
		if (b.text == text or b.tooltip_text == text) and b.is_visible_in_tree():
			return b
	return null

func _screen(at: Vector2) -> Vector2i:
	return Vector2i((get_viewport().get_screen_transform() * at).round())

func _tap(name: String, control: Control) -> void:
	check(control != null, "%s exists" % name)
	if control:
		await _tap_at(name, control.get_global_rect().get_center())

func _tap_at(name: String, at: Vector2) -> void:
	var p := _screen(at)
	print("TAP %s %d %d" % [name, p.x, p.y])
	await _wait(0.8)

func _swipe(name: String, from: Vector2, to: Vector2, ms: int) -> void:
	var a := _screen(from)
	var b := _screen(to)
	print("SWIPE %s %d %d %d %d %d" % [name, a.x, a.y, b.x, b.y, ms])
	await _wait(0.6 + ms / 1000.0)

## The game's own rendered frame. Emulators that draw Vulkan on the host GPU
## return blank `adb screencap` images, so the harness pulls these instead.
func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(DeviceTest.capture_path("touch-" + name))
	print("SHOT %s" % name)
	await _wait(0.3)

func _until(condition: Callable) -> bool:
	var left := WAIT
	while left > 0.0:
		if condition.call():
			return true
		await get_tree().process_frame
		left -= get_process_delta_time()
	return false

func _wait(seconds: float) -> void:
	await get_tree().create_timer(seconds, true, false, true).timeout

func _frames(count: int) -> void:
	for i in count:
		await get_tree().process_frame
