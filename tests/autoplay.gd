extends Node
## Plays levels unattended to prove they can be finished: every enemy dies
## as soon as it is hittable, the player is kept alive, and walks through
## each exit door as it opens. Checks that only gates spawn enemies, that the
## doors lock and open, and that clearing unlocks the next level.
##   godot --headless --path . res://tests/autoplay.tscn -- 1 10 45
## Restores the real progress file afterwards. Exits 1 on any failure.

const TIMEOUT := 600.0 # simulated seconds per level

var _levels: Array[int] = []
var _game: Game
var _failures: Array[String] = []
var _done := false
var _clock := 0.0
var _saved := {}


func _ready() -> void:
	if not Progress.isolated:
		printerr("Autoplay requires --isolated to protect player progress")
		get_tree().quit(1)
		return
	for a in DeviceTest.user_args():
		if a.is_valid_int():
			_levels.append(int(a))
	if _levels.is_empty():
		_levels = [1, 10]
	_saved = Progress.to_dict()
	Engine.time_scale = 4.0
	Engine.physics_ticks_per_second = 60
	Engine.max_physics_steps_per_frame = 32
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
	_done = false
	_clock = 0.0
	add_child(_game)
	var run: LevelRun = _game.get("_run")
	run.level_complete.connect(func() -> void:
		_done = true
		print("level %d cleared in %.0f s" % [n, _clock])
		if not Progress.is_unlocked(mini(n + 1, Levels.COUNT)):
			_failures.append("level %d: clearing did not unlock the next" % n)
		_next.call_deferred(), CONNECT_ONE_SHOT)
	var director: WaveDirector = _game.get("_director")
	director.wave_started.connect(func(_w: int, _t: int) -> void:
		for e in (_game.get("_enemies") as Node3D).get_children():
			e.set_meta("seen", false))


func _physics_process(delta: float) -> void:
	if _game == null or _done:
		return
	_clock += delta
	var level := Game.level
	# The endless level never clears: it passes once it keeps writing waves.
	if Levels.is_endless(level) and (_game.get("_director") as WaveDirector).wave >= 4:
		print("level %d reached wave 4 in %.0f s" % [level, _clock])
		_done = true
		_next.call_deferred()
		return
	if _clock > (TIMEOUT * 2.0 if level == Levels.FINALE else TIMEOUT):
		var d: WaveDirector = _game.get("_director")
		var r: LevelRun = _game.get("_run")
		_failures.append("level %d: not cleared after %.0f s (room %d, wave %d/%d, state %d, %d alive, %d queued)" % [
			level, TIMEOUT, r.room_index + 1, d.wave, d.total_waves(), d.state, d.get("_alive"), (d.get("_queue") as Array).size()])
		_done = true
		_next.call_deferred()
		return
	get_tree().paused = false
	var player: Player = _game.get("_player")
	var run: LevelRun = _game.get("_run")
	var director: WaveDirector = _game.get("_director")
	player.health = Tuning.max_health
	var room := run.rooms[run.room_index]
	for e in (_game.get("_enemies") as Node3D).get_children():
		var enemy := e as Enemy
		if enemy == null:
			continue
		if not enemy.has_meta("spawn_checked"):
			enemy.set_meta("spawn_checked", true)
			if enemy.global_position.z > room.global_position.z - room.length / 2.0 - 1.0:
				_failures.append("level %d: enemy appeared in front of the far wall at %s" % [level, enemy.global_position])
		if enemy.active:
			enemy.take_hit(1e9, -1, &"rifle", 0.0)
	# Room cleared: walk through the exit into the next room's trigger.
	if director.state == WaveDirector.State.DONE and run.room_index < run.room_count() - 1:
		var next := run.rooms[run.room_index + 1]
		player.global_position = next.to_global(Vector3(0.0, 0.3, next.length / 2.0 - 5.0))
		player.velocity = Vector3.ZERO


func _finish() -> void:
	Progress.restore(_saved)
	Audio.stop_all()
	Engine.time_scale = 1.0
	for f in _failures:
		printerr(f)
	print("OK" if _failures.is_empty() else "%d FAILURES" % _failures.size())
	get_tree().quit(0 if _failures.is_empty() else 1)
