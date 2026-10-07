class_name WaveDirector
extends Node
## Runs waves per §2 and §7. A wave is a budget (total count) plus a cap on
## how many are alive at once. Spawns are distance-gated and telegraphed.
## A wave ends when its last enemy dies — never on a timer.

signal wave_started(wave: int, total: int)
signal wave_cleared(wave: int)
signal interval_tick(seconds_left: float)
signal enemy_killed(enemy: Rusher)
signal all_waves_cleared

## First slice: the "Open" phase only (waves 1–4, rushers only).
const WAVES := [
	{"rushers": 6, "cap": 3},
	{"rushers": 9, "cap": 4},
	{"rushers": 12, "cap": 5},
	{"rushers": 15, "cap": 6},
]

enum State { IDLE, INTERVAL, WAVE, DONE }

var player: Player
var spawn_points: Array[Vector3] = []
var enemy_parent: Node3D

var wave := 0
var state := State.IDLE
var _reserve := 0
var _alive := 0
var _cap := 0
var _interval_left := 0.0
var _walk_in_left := 0.0


func start() -> void:
	state = State.INTERVAL
	_interval_left = Tuning.first_wave_delay


func total_waves() -> int:
	return WAVES.size()


func _physics_process(delta: float) -> void:
	match state:
		State.INTERVAL:
			_interval_left -= delta
			interval_tick.emit(maxf(0.0, _interval_left))
			if _interval_left <= 0.0:
				_begin_wave(wave + 1)
		State.WAVE:
			_walk_in_left -= delta
			if _reserve > 0 and _alive < _cap and _walk_in_left <= 0.0:
				if _spawn_one():
					_walk_in_left = Tuning.walk_in_delay
			if _reserve == 0 and _alive == 0:
				_clear_wave()


func _begin_wave(n: int) -> void:
	wave = n
	var spec: Dictionary = WAVES[n - 1]
	_reserve = spec["rushers"]
	_cap = spec["cap"]
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


## Nothing spawns near the player (§2). If every point is too close, wait.
func _spawn_one() -> bool:
	var candidates: Array[Vector3] = []
	for p in spawn_points:
		if p.distance_to(player.global_position) >= Tuning.min_spawn_distance:
			candidates.append(p)
	if candidates.is_empty():
		return false
	var rusher := Rusher.new()
	rusher.target = player
	rusher.position = candidates.pick_random()
	rusher.died.connect(_on_enemy_died)
	enemy_parent.add_child(rusher)
	_reserve -= 1
	_alive += 1
	return true


func _on_enemy_died(enemy: Rusher) -> void:
	_alive -= 1
	enemy_killed.emit(enemy)
