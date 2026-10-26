extends Node
## Frame cost of real levels: boots each one, keeps the player alive and
## firing, lets the waves pile up, and prints frame time and render counts. Needs a real
## renderer (not --headless) and vsync off to mean anything:
##   godot --rendering-method mobile --disable-vsync --path . res://tests/bench_level.tscn -- --isolated 3 27 63
## Performance numbers, not a pass/fail check.

const WARMUP := 3.0
const SAMPLE := 8.0

var _levels: Array[int] = []
var _game: Game
var _clock := 0.0
var _last_us := 0
var _frames: Array[float] = []
var _draws := 0.0
var _objects := 0.0
var _prims := 0.0
var _saved := {}


func _ready() -> void:
	if not Progress.isolated:
		printerr("bench_level requires --isolated to protect player progress")
		get_tree().quit(1)
		return
	for a in DeviceTest.user_args():
		if a.is_valid_int():
			_levels.append(int(a))
	if _levels.is_empty():
		_levels = [3, 27, 63]
	_saved = Progress.to_dict()
	_next()


func _next() -> void:
	if _game:
		_game.queue_free()
		_game = null
		await get_tree().process_frame
	if _levels.is_empty():
		Progress.restore(_saved)
		Audio.stop_all()
		get_tree().quit(0)
		return
	var n: int = _levels.pop_front()
	Progress.unlocked = n
	Game.level = n
	Game.mode = Game.Mode.RUN
	_game = (load("res://scenes/main.tscn") as PackedScene).instantiate()
	_clock = 0.0
	_frames.clear()
	_draws = 0.0
	_objects = 0.0
	_prims = 0.0
	add_child(_game)
	_last_us = Time.get_ticks_usec()


func _process(delta: float) -> void:
	if _game == null:
		return
	var now := Time.get_ticks_usec()
	var frame_ms := (now - _last_us) / 1000.0
	_last_us = now
	_clock += delta
	get_tree().paused = false
	var player: Player = _game.get("_player")
	player.health = Tuning.max_health
	# Hold the trigger with a full magazine, so tracers and impacts are counted.
	Input.action_press("fire")
	player.weapon.mag = maxi(player.weapon.mag, 5)
	if _clock < WARMUP:
		return
	_frames.append(frame_ms)
	_draws += Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)
	_objects += Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)
	_prims += Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME)
	if _clock < WARMUP + SAMPLE:
		return
	var count := float(_frames.size())
	var sorted := _frames.duplicate()
	sorted.sort()
	var total := 0.0
	for f: float in _frames:
		total += f
	var enemies := (_game.get("_enemies") as Node3D).get_child_count()
	print("BENCH level %d: avg %.2f ms (%.0f fps)  p95 %.2f ms  max %.2f ms  draws %.0f  objects %.0f  prims %.0f  enemies %d  nodes %d" % [
		Game.level, total / count, 1000.0 * count / total, sorted[int(count * 0.95)], sorted[-1],
		_draws / count, _objects / count, _prims / count, enemies,
		Performance.get_monitor(Performance.OBJECT_NODE_COUNT)])
	Input.action_release("fire")
	_game.set_process(false)
	var finished := _game
	_game = null
	finished.queue_free()
	_next.call_deferred()
