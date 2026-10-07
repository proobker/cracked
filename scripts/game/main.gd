extends Node3D
## Boots a run: builds the plaza, player, systems, and UI, and wires them
## together. Owns pausing, death, and instant restart (§8).

var _world: Node3D
var _player: Player
var _score: Score
var _director: WaveDirector
var _hud: Hud
var _touch: TouchControls
var _over := false
var _over_at_ms := 0


func _ready() -> void:
	# Main keeps running while paused so it can resume and restart; the
	# world and gameplay systems are explicitly pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS

	_world = Node3D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var plaza := Plaza.new()
	_world.add_child(plaza)
	var enemies := Node3D.new()
	_world.add_child(enemies)
	_player = Player.new()
	_player.position = Vector3(0.0, 0.2, 17.0)
	_world.add_child(_player)

	_score = Score.new()
	_score.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_score)

	_director = WaveDirector.new()
	_director.process_mode = Node.PROCESS_MODE_PAUSABLE
	_director.player = _player
	_director.spawn_points = plaza.spawn_points()
	_director.enemy_parent = enemies
	add_child(_director)

	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Hud.new()
	_hud.score_source = _score
	ui.add_child(_hud)
	_touch = TouchControls.new()
	_touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	ui.add_child(_touch)

	_player.health_changed.connect(_hud.set_health)
	_player.damaged.connect(_score.on_player_hit)
	_player.died.connect(_on_player_died)
	_player.weapon.ammo_changed.connect(_hud.set_ammo)
	_player.weapon.hit.connect(_hud.show_marker)
	# The weapon announced its ammo before the HUD was listening.
	_hud.set_ammo(_player.weapon.mag, _player.weapon.reserve, false)
	_score.changed.connect(func(s: int, m: int, _best: int) -> void: _hud.set_score(s, m))
	_score.combo_lost.connect(_hud.flash_combo)
	_director.wave_started.connect(_on_wave_started)
	_director.wave_cleared.connect(_on_wave_cleared)
	_director.interval_tick.connect(_on_interval_tick)
	_director.enemy_killed.connect(_on_enemy_killed)
	_director.all_waves_cleared.connect(_on_all_waves_cleared)

	_hud.set_wave(0, _director.total_waves())
	_capture_mouse(true)
	_director.start()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _over:
		_set_paused(not get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if not get_tree().paused:
		var click := event as InputEventMouseButton
		if click and click.pressed:
			_capture_mouse(true)
		return
	if event.is_action("pause") or not _is_tap(event):
		return
	if _over:
		# A short guard so the shot that was being fired doesn't skip the screen.
		if Time.get_ticks_msec() - _over_at_ms > 600:
			get_tree().paused = false
			get_tree().reload_current_scene()
	else:
		_set_paused(false)


## Any loss of focus pauses the run; it is never lost to an interruption (§13).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if is_inside_tree() and not _over and not get_tree().paused:
				_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_touch.reset()
	_capture_mouse(not paused)
	if paused:
		_hud.show_overlay("PAUSED\n\ntap to resume")
	else:
		_hud.hide_overlay()


func _end_run(text: String) -> void:
	_over = true
	_over_at_ms = Time.get_ticks_msec()
	get_tree().paused = true
	_touch.reset()
	_capture_mouse(false)
	_hud.show_overlay(text)


func _on_player_died(cause: String) -> void:
	_end_run("DEAD\n\nWave %d   ·   %d score   ·   x%d best combo\n%s\n\ntap to restart" % [
		_director.wave, _score.score, _score.best, cause,
	])


func _on_all_waves_cleared() -> void:
	_end_run("END OF SLICE\n\nAll %d waves cleared   ·   %d score   ·   x%d best combo\nWaves 5–20 and the boss aren't built yet.\n\ntap to restart" % [
		_director.total_waves(), _score.score, _score.best,
	])


func _on_wave_started(wave: int, total: int) -> void:
	_hud.set_wave(wave, total)
	_hud.banner("WAVE %d" % wave)


func _on_wave_cleared(_wave: int) -> void:
	_hud.banner("WAVE CLEARED", 2.0)


func _on_interval_tick(seconds_left: float) -> void:
	if seconds_left > 0.0 and seconds_left < 5.0:
		_hud.banner("NEXT WAVE IN %d" % ceili(seconds_left), 0.2)


func _on_enemy_killed(enemy: Rusher) -> void:
	_score.on_kill(enemy.points)
	var pickup := AmmoPickup.new()
	pickup.position = Vector3(enemy.global_position.x, 0.5, enemy.global_position.z)
	_world.add_child(pickup)


func _is_tap(event: InputEvent) -> bool:
	if event is InputEventScreenTouch:
		return (event as InputEventScreenTouch).pressed
	if event is InputEventMouseButton:
		return (event as InputEventMouseButton).pressed
	if event is InputEventKey:
		var key := event as InputEventKey
		return key.pressed and not key.echo
	if event is InputEventJoypadButton:
		return (event as InputEventJoypadButton).pressed
	return false


## Mouse capture is for testing in the editor; phones have no pointer.
func _capture_mouse(capture: bool) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
