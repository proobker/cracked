class_name WaveDirector
extends Node
## Runs one room's waves (§2, §7). A wave is a budget (a fixed composition)
## plus a cap on how many may be alive at once; the specs come from Levels.
## Spawns are distance-gated and telegraphed. A wave ends when its last enemy
## dies — never on a timer, and nothing about it changes mid-fight.

signal wave_started(wave: int, total: int)
signal wave_cleared(wave: int)
signal interval_tick(seconds_left: float)
signal enemy_killed(enemy: Enemy)
signal all_waves_cleared

enum State { IDLE, INTERVAL, WAVE, DONE }

var player: Player
## Wave specs: r = rusher, s = shooter, h = heavy, b = boss, cap = alive at once.
var waves: Array[Dictionary] = []
var spawn_points: Array[Vector3] = []
var enemy_parent: Node3D
## Where enemies belong; one found outside is put back on a spawn point.
var bounds := AABB(Vector3(-24.0, -5.0, -24.0), Vector3(48.0, 17.0, 48.0))
var min_spawn_distance := Tuning.min_spawn_distance
var first_delay := Tuning.first_wave_delay
## Boss health multiplier, from the level.
var boss_scale := 1.0
## Enemy speed multiplier, from the level's modifier.
var speed_scale := 1.0

var wave := 0
var state := State.IDLE
var _queue: Array[StringName] = []
var _alive := 0
var _cap := 0
var _interval_left := 0.0
var _walk_in_left := 0.0


func start() -> void:
	wave = 0
	state = State.INTERVAL
	_interval_left = first_delay


func total_waves() -> int:
	return waves.size()


func is_boss_wave() -> bool:
	return wave >= 1 and waves[wave - 1].has("b")


func next_is_boss() -> bool:
	return wave < waves.size() and waves[wave].has("b")


func _physics_process(delta: float) -> void:
	match state:
		State.INTERVAL:
			_interval_left -= delta
			interval_tick.emit(maxf(0.0, _interval_left))
			if _interval_left <= 0.0:
				_begin_wave(wave + 1)
		State.WAVE:
			_walk_in_left -= delta
			if not _queue.is_empty() and _alive < _cap and _walk_in_left <= 0.0:
				if _spawn_one():
					_walk_in_left = Tuning.walk_in_delay
			if _queue.is_empty() and _alive == 0:
				_clear_wave()
			_rescue_strays()


func _begin_wave(n: int) -> void:
	wave = n
	var spec: Dictionary = waves[n - 1]
	_queue.clear()
	for i in int(spec.get("r", 0)):
		_queue.append(&"rusher")
	for i in int(spec.get("s", 0)):
		_queue.append(&"shooter")
	_queue.shuffle()
	# Heavies walk in after the opening bodies, as the wave's punctuation.
	var heavies := int(spec.get("h", 0))
	for i in heavies:
		var at := int(float(_queue.size()) * float(i + 1) / float(heavies + 1))
		_queue.insert(at, &"heavy")
	for i in int(spec.get("b", 0)):
		_queue.append(&"boss")
	_cap = int(spec["cap"])
	_alive = 0
	_walk_in_left = 0.0
	state = State.WAVE
	wave_started.emit(wave, waves.size())


func _clear_wave() -> void:
	wave_cleared.emit(wave)
	if wave >= waves.size():
		state = State.DONE
		all_waves_cleared.emit()
	else:
		state = State.INTERVAL
		_interval_left = Tuning.interval_seconds


## Nothing spawns near the player (§2), or on top of another enemy. If every
## point is blocked, wait.
func _spawn_one() -> bool:
	var candidates := _free_points()
	if candidates.is_empty():
		return false
	var enemy := make_enemy(_queue.pop_front())
	if enemy is Boss:
		(enemy as Boss).health_scale = boss_scale
	enemy.target = player
	enemy.speed_scale = speed_scale
	enemy.position = candidates.pick_random()
	enemy.died.connect(_on_enemy_died)
	enemy_parent.add_child(enemy)
	_alive += 1
	return true


func _free_points() -> Array[Vector3]:
	var free: Array[Vector3] = []
	for p in spawn_points:
		if p.distance_to(player.global_position) < min_spawn_distance:
			continue
		var taken := false
		for e in enemy_parent.get_children():
			if e is Enemy and Vector2(e.global_position.x - p.x, e.global_position.z - p.z).length() < (e as Enemy).radius + 1.6:
				taken = true
				break
		if not taken:
			free.append(p)
	return free


## Insurance against a soft-locked wave: an enemy that has somehow left the
## arena (physics overlap, falling) is put back on a free spawn point.
func _rescue_strays() -> void:
	for e in enemy_parent.get_children():
		if not e is Enemy:
			continue
		if not bounds.has_point((e as Enemy).global_position):
			var free := _free_points()
			if not free.is_empty():
				(e as Enemy).global_position = free.pick_random()
				(e as Enemy).velocity = Vector3.ZERO


static func make_enemy(kind: StringName) -> Enemy:
	match kind:
		&"shooter":
			return Shooter.new()
		&"heavy":
			return Heavy.new()
		&"boss":
			return Boss.new()
	return Rusher.new()


func _on_enemy_died(enemy: Enemy) -> void:
	_alive -= 1
	enemy_killed.emit(enemy)
