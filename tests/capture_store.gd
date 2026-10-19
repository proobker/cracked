extends Node
## Takes store screenshots from real play: boots each level, keeps the
## player alive while the first wave walks in, and saves the screen to
## build/store/. Needs a window (not --headless):
##   godot --path . --resolution 1920x1080 res://tests/capture_store.tscn -- 3 10 27 45 63 99
## Restores the real progress file afterwards.

const WAIT := 13.0 # seconds into the level before the shot

var _levels: Array[int] = []
var _game: Node
var _clock := 0.0
var _saved := {}
var _out := ""


func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		_levels.append(int(a))
	if _levels.is_empty():
		_levels = [3, 10, 27, 45, 63, 99]
	_saved = Progress.to_dict()
	_out = ProjectSettings.globalize_path("res://build/store")
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
	Progress.unlocked = 1
	Progress.best.clear()
	Progress.merge(_saved)
	get_tree().quit()
