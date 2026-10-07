class_name Game
extends Node3D
## Boots a run or the practice range: builds the plaza, player, systems, and
## UI, and wires them together. Owns pausing, death, the win, and instant
## restart (§8).

enum Mode { RUN, PRACTICE }

## Set by the menu before loading this scene.
static var mode := Mode.RUN
## Testing aid: the wave a run starts at.
static var start_wave := 1

const PRACTICE_DUMMIES := [
	[&"rusher", Vector3(-5.0, 0.1, 7.0)],
	[&"shooter", Vector3(6.0, 0.1, -2.0)],
	[&"heavy", Vector3(8.0, 0.1, -17.0)],
]

var _world: Node3D
var _enemies: Node3D
var _player: Player
var _score: Score
var _director: WaveDirector
var _hud: Hud
var _touch: TouchControls
var _settings: SettingsPanel
var _over := false
var _restarting := false


func _ready() -> void:
	# Game keeps running while paused so it can resume and restart; the
	# world and gameplay systems are explicitly pausable.
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().paused = false

	_world = Node3D.new()
	_world.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(_world)
	var plaza := Plaza.new()
	_world.add_child(plaza)
	_enemies = Node3D.new()
	_world.add_child(_enemies)
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
	_director.enemy_parent = _enemies
	_director.start_wave = clampi(start_wave, 1, _director.total_waves())
	add_child(_director)

	var ui := CanvasLayer.new()
	add_child(ui)
	_hud = Hud.new()
	_hud.score_source = _score
	ui.add_child(_hud)
	_touch = TouchControls.new()
	_touch.process_mode = Node.PROCESS_MODE_PAUSABLE
	_touch.player = _player
	ui.add_child(_touch)
	_settings = SettingsPanel.new()
	_settings.visible = false
	_settings.closed.connect(_on_settings_closed)
	ui.add_child(_settings)

	_player.health_changed.connect(_hud.set_health)
	_player.damaged.connect(_on_player_damaged)
	_player.died.connect(_on_player_died)
	_player.weapon_changed.connect(func(w: Weapon) -> void: _hud.set_weapon(w, _player.weapons))
	_player.shot_result.connect(_on_shot_result)
	_hud.set_weapon(_player.weapon, _player.weapons)
	_hud.overlay_action.connect(_on_overlay_action)
	_score.changed.connect(func(s: int, m: int, _best: int) -> void: _hud.set_score(s, m))
	_score.combo_lost.connect(_on_combo_lost)

	_capture_mouse(true)
	if mode == Mode.PRACTICE:
		_start_practice()
	else:
		_director.wave_started.connect(_on_wave_started)
		_director.wave_cleared.connect(_on_wave_cleared)
		_director.interval_tick.connect(_on_interval_tick)
		_director.enemy_killed.connect(_on_enemy_killed)
		_director.all_waves_cleared.connect(_on_all_waves_cleared)
		_hud.set_wave_text("WAVE %d / %d" % [_director.start_wave - 1, _director.total_waves()])
		Audio.play_music(&"combat")
		Audio.set_intensity(0.0)
		_director.start()


func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("pause") and not _over and not _settings.visible:
		_set_paused(not get_tree().paused)


func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused:
		return
	var click := event as InputEventMouseButton
	if click and click.pressed:
		_capture_mouse(true)


## Any loss of focus pauses the run; it is never lost to an interruption (§13).
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT:
			if is_inside_tree() and not _over and not get_tree().paused:
				_set_paused(true)


func _set_paused(paused: bool) -> void:
	get_tree().paused = paused
	_touch.reset()
	_touch.set_shown(not paused)
	_capture_mouse(not paused)
	if paused:
		_hud.show_overlay("PAUSED", "", [
			[&"resume", "RESUME"], [&"settings", "SETTINGS"], [&"restart", "RESTART"], [&"menu", "MENU"],
		])
	else:
		_hud.hide_overlay()


func _end_run(title: String, body: String) -> void:
	_over = true
	get_tree().paused = true
	_touch.reset()
	_touch.set_shown(false)
	_capture_mouse(false)
	Audio.stop_music()
	_hud.show_overlay(title, body, [[&"restart", "RESTART"], [&"menu", "MENU"]])


func _on_overlay_action(id: StringName) -> void:
	match id:
		&"resume":
			_set_paused(false)
		&"settings":
			_hud.hide_overlay()
			_settings.open()
		&"restart":
			_change_scene("res://scenes/main.tscn")
		&"menu":
			_change_scene("res://scenes/menu.tscn")


func _on_settings_closed() -> void:
	_player.camera.fov = Tuning.fov
	_set_paused(true)


func _change_scene(path: String) -> void:
	if _restarting:
		return
	_restarting = true
	get_tree().paused = false
	get_tree().change_scene_to_file.call_deferred(path)


func _on_player_damaged() -> void:
	_score.on_player_hit()
	_hud.flash_hurt()


func _on_player_died(cause: String) -> void:
	Audio.play(&"lose")
	var wave_text := "the boss" if _director.is_boss_wave() else "wave %d" % _director.wave
	_end_run("DEAD", "Reached %s   ·   %d score   ·   x%d best combo\n%s" % [
		wave_text, _score.score, _score.best, cause,
	])


func _on_all_waves_cleared() -> void:
	Audio.play(&"win")
	_end_run("YOU WIN", "All %d waves cleared, boss included\n%d score   ·   x%d best combo" % [
		_director.total_waves(), _score.score, _score.best,
	])


func _on_shot_result(result: String) -> void:
	if result == "miss":
		return
	_hud.show_marker(result)
	Audio.play(StringName(result), 0.0)


func _on_combo_lost(full: bool) -> void:
	_hud.flash_combo(full)
	Audio.play(&"combo_break" if full else &"combo_step")


func _on_wave_started(wave: int, total: int) -> void:
	if _director.is_boss_wave():
		_hud.set_wave_text("WAVE %d  ·  BOSS" % wave)
		_hud.banner("THE BOSS", 2.5)
		Audio.play_music(&"boss")
		Audio.set_intensity(1.0)
	else:
		_hud.set_wave_text("WAVE %d / %d" % [wave, total])
		_hud.banner("WAVE %d" % wave)
		Audio.set_intensity(float(wave - 1) / float(total - 2))
	Audio.play(&"wave_start", 0.0)


func _on_wave_cleared(_wave: int) -> void:
	_hud.banner("WAVE CLEARED", 2.0)
	Audio.play(&"wave_clear", 0.0)


func _on_interval_tick(seconds_left: float) -> void:
	if seconds_left > 0.0 and seconds_left < 5.0:
		var next := "THE BOSS" if _director.wave + 1 == _director.total_waves() else "NEXT WAVE"
		_hud.banner("%s IN %d" % [next, ceili(seconds_left)], 0.2)


## Score is weighted by enemy and weapon (§8). Ammo drops for the weapon
## that made the kill, and sometimes for another (§5).
func _on_enemy_killed(enemy: Enemy) -> void:
	var weapon := _player.weapon_by_kind(enemy.last_hit_by)
	_score.on_kill(roundi(enemy.points * weapon.score_mult))
	_drop_ammo(weapon, enemy.global_position)
	if randf() < 0.25:
		var others := _player.weapons.filter(func(w: Weapon) -> bool: return w != weapon)
		_drop_ammo(others.pick_random(), enemy.global_position + Vector3(0.8, 0.0, 0.0))


func _drop_ammo(weapon: Weapon, at: Vector3) -> void:
	var pickup := AmmoPickup.new()
	pickup.kind = weapon.kind
	pickup.amount = weapon.pickup_amount
	pickup.color = weapon.color
	pickup.position = Vector3(at.x, 0.5, at.z)
	_world.add_child(pickup)


## Practice range (§11): no waves, stationary dummies at three ranges that
## come back after dying, and ammo that never runs out.
func _start_practice() -> void:
	_hud.set_wave_text("PRACTICE RANGE")
	_hud.banner("PRACTICE  ·  PAUSE TO LEAVE", 3.0)
	Audio.play_music(&"menu")
	Audio.set_intensity(0.6)
	for spec: Array in PRACTICE_DUMMIES:
		_spawn_dummy(spec[0], spec[1])
	var refill := Timer.new()
	refill.wait_time = 1.0
	refill.autostart = true
	refill.timeout.connect(func() -> void:
		for w in _player.weapons:
			if w.reserve < w.reserve_max:
				w.add_ammo(w.reserve_max))
	_world.add_child(refill)


func _spawn_dummy(kind: StringName, at: Vector3) -> void:
	var dummy := WaveDirector.make_enemy(kind)
	dummy.dummy = true
	dummy.target = _player
	dummy.position = at
	dummy.died.connect(func(e: Enemy) -> void:
		_score.on_kill(e.points)
		get_tree().create_timer(2.0, false).timeout.connect(_spawn_dummy.bind(kind, at)))
	_enemies.add_child(dummy)


## Mouse capture is for testing on desktop; phones have no pointer.
func _capture_mouse(capture: bool) -> void:
	if DisplayServer.is_touchscreen_available():
		return
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if capture else Input.MOUSE_MODE_VISIBLE
