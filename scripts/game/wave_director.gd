class_name WaveDirector
extends Node
## Runs the twenty waves and the boss (§2, §7). A wave is a budget (a fixed
## composition) plus a cap on how many may be alive at once. Spawns are
## distance-gated and telegraphed. A wave ends when its last enemy dies —
## never on a timer, and nothing about it changes mid-fight.

signal wave_started(wave: int, total: int)
signal wave_cleared(wave: int)
signal interval_tick(seconds_left: float)
signal enemy_killed(enemy: Enemy)
signal all_waves_cleared

## Escalation from composition before count (§7). r = rusher, s = shooter,
## h = heavy, b = boss.
const WAVES := [
	# Open: rushers only.
	{"r": 6, "cap": 3},
	{"r": 9, "cap": 4},
	{"r": 12, "cap": 5},
	{"r": 15, "cap": 6},
	# Pressure: shooters join.
	{"r": 10, "s": 2, "cap": 6},
	{"r": 12, "s": 3, "cap": 6},
	{"r": 12, "s": 4, "cap": 7},
	{"r": 14, "s": 4, "cap": 7},
	{"r": 16, "s": 5, "cap": 8},
	# Punishment: heavies join. Fewer bodies, more variety.
	{"r": 8, "s": 3, "h": 1, "cap": 7},
	{"r": 10, "s": 4, "h": 1, "cap": 8},
	{"r": 10, "s": 5, "h": 1, "cap": 8},
	{"r": 12, "s": 5, "h": 2, "cap": 9},
	{"r": 12, "s": 6, "h": 2, "cap": 9},
	{"r": 14, "s": 6, "h": 2, "cap": 10},
	# Breakdown: dense mixes, multiple heavies.
	{"r": 14, "s": 7, "h": 3, "cap": 10},
	{"r": 16, "s": 7, "h": 3, "cap": 11},
	{"r": 16, "s": 8, "h": 4, "cap": 11},
	{"r": 18, "s": 8, "h": 4, "cap": 12},
	# Boss: a single entity (§7's floor).
	{"b": 1, "cap": 1},
]

enum State { IDLE, INTERVAL, WAVE, DONE }

var player: Player
var spawn_points: Array[Vector3] = []
var enemy_parent: Node3D
## Debug/practice: the first wave to run.
var start_wave := 1

var wave := 0
var state := State.IDLE
var _queue: Array[StringName] = []
var _alive := 0
var _cap := 0
var _interval_left := 0.0
var _walk_in_left := 0.0


func start() -> void:
	wave = start_wave - 1
	state = State.INTERVAL
	_interval_left = Tuning.first_wave_delay


func total_waves() -> int:
	return WAVES.size()


func is_boss_wave() -> bool:
	return wave == WAVES.size()


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
	var spec: Dictionary = WAVES[n - 1]
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
	wave_started.emit(wave, WAVES.size())


func _clear_wave() -> void:
	wave_cleared.emit(wave)
	if wave >= WAVES.size():
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
	enemy.target = player
	enemy.position = candidates.pick_random()
	enemy.died.connect(_on_enemy_died)
	enemy_parent.add_child(enemy)
	_alive += 1
	return true


func _free_points() -> Array[Vector3]:
	var free: Array[Vector3] = []
	for p in spawn_points:
		if p.distance_to(player.global_position) < Tuning.min_spawn_distance:
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
		var pos := (e as Enemy).global_position
		if pos.y > 12.0 or pos.y < -5.0 or absf(pos.x) > 24.0 or absf(pos.z) > 24.0:
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
