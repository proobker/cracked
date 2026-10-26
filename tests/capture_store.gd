extends Node
## Takes store screenshots from real play: boots each level, keeps the
## player alive while the first wave walks in, and saves the screen to
## store/screenshots/. Needs a window (not --headless):
##   godot --path . --resolution 1920x1080 res://tests/capture_store.tscn -- 3 10 27 45 63 100 --isolated
## Restores the real progress file afterwards.

const WAIT := 13.0 # seconds into the level before the shot

var _levels: Array[int] = []
var _game: Node
var _clock := 0.0
var _saved := {}
var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.is_valid_int():
			_levels.append(int(a))
	if _levels.is_empty():
		_levels = [3, 10, 27, 45, 63, 99]
	_saved = Progress.to_dict()
	_out = ProjectSettings.globalize_path("res://store/screenshots")
	DirAccess.make_dir_recursive_absolute(_out)
	_next()


func _next() -> void:
	if _game:
		_game.queue_free()
		_game = null
		await get_tree().process_frame
	if _levels.is_empty():
		_finish()
		return
	var n: int = _levels.pop_front()
	Progress.unlocked = n
	Game.level = n
	Game.mode = Game.Mode.RUN
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_game.set_meta("level", n)
	_clock = 0.0
	add_child(_game)


func _process(delta: float) -> void:
	if _game == null:
		return
	get_tree().paused = false
	var player: Player = _game.get("_player")
	player.health = Tuning.max_health
	_clock += delta
	if _clock < WAIT:
		return
	var n: int = _game.get_meta("level")
	var path := "%s/screenshot_level_%02d.png" % [_out, n]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
	_clock = -INF
	_next.call_deferred()


func _finish() -> void:
	await _menus()
	Progress.unlocked = 1
	Progress.best.clear()
	Progress.merge(_saved)
	get_tree().quit()


## The screens between fights: the galaxy mid-campaign, the Armory with a
## built-up tree, and the ending.
func _menus() -> void:
	var ui := CanvasLayer.new()
	add_child(ui)
	Progress.unlocked = 46
	for n in range(1, 46):
		Progress.clears[str(n)] = true
	var select := LevelSelect.new()
	ui.add_child(select)
	select.open()
	await get_tree().process_frame
	select._map.skip()
	select._map._camera(LevelMap.star(46) * 0.55, select._map.fit_zoom() * 1.7)
	await _save("screenshot_galaxy")
	select.queue_free()
	var armory := Armory.new()
	ui.add_child(armory)
	armory.open(true)
	await get_tree().process_frame
	armory._tree.focus_node("momentum_circuit_1_1")
	armory._tree.zoom_by(0.55)
	await _save("screenshot_armory")
	armory.queue_free()
	var ending := Conquered.new()
	ending.stats = "184320 score   ·   x31 best combo"
	ui.add_child(ending)
	await get_tree().create_timer(2.5).timeout
	await _save("screenshot_conquered")
	ending.queue_free()


func _save(name: String) -> void:
	await RenderingServer.frame_post_draw
	await RenderingServer.frame_post_draw
	var path := "%s/%s.png" % [_out, name]
	get_viewport().get_texture().get_image().save_png(path)
	print("saved ", path)
