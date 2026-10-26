class_name LevelRun
extends Node3D
## One level (§2, §3): builds its rooms in a chain along -z and runs them in
## order. A room starts when the player is through its entry door, which
## locks behind them; its waves come from the far wall; clearing the last
## wave opens the exit. Clearing the last room clears the level.

signal room_started(index: int, total: int)
signal room_cleared(index: int, total: int)
signal level_complete

var level: Dictionary
## Set by Game before this enters the tree.
var director: WaveDirector

var rooms: Array[Room] = []
var room_index := -1


func _init(number: int) -> void:
	level = Levels.get_level(number)


func _ready() -> void:
	var theme: Dictionary = level["theme"]
	Blockout.environment(self, theme, level["modifier"] == &"blackout")
	var specs: Array = level["rooms"]
	var z := 0.0
	for i in specs.size():
		var spec: Dictionary = specs[i]
		if i > 0:
			z -= (specs[i - 1]["length"] as float) / 2.0 + Room.CORRIDOR + 2.0 + (spec["length"] as float) / 2.0
		var room := Room.new(spec, i > 0, i < specs.size() - 1, theme)
		room.position.z = z
		add_child(room)
		rooms.append(room)
		if i > 0:
			room.entered.connect(_start_room.bind(i))
	Blockout.skyline(self, Vector3(0.0, 0.0, z / 2.0), -z / 2.0, theme, 2077 + number())
	director.all_waves_cleared.connect(_on_room_cleared)


func _exit_tree() -> void:
	Blockout.clear_materials()


func number() -> int:
	return level["n"]


func room_count() -> int:
	return rooms.size()


func start_position() -> Vector3:
	return rooms[0].start_position()


func start() -> void:
	_start_room(0)


func _start_room(i: int) -> void:
	room_index = i
	_show_near(i)
	var room := rooms[i]
	room.close_entry()
	director.waves.assign(room.spec["waves"])
	director.spawn_points = room.spawn_points()
	director.bounds = room.bounds()
	director.min_spawn_distance = Tuning.room_spawn_distance
	director.boss_scale = Levels.boss_scale(number())
	director.speed_scale = Levels.speed_scale(level["modifier"])
	director.endless = level.get("endless", false)
	if director.endless:
		director.boss_scale = 0.8
	director.start()
	room_started.emit(i, rooms.size())


func _on_room_cleared() -> void:
	room_cleared.emit(room_index, rooms.size())
	if room_index >= rooms.size() - 1:
		level_complete.emit()
		return
	rooms[room_index].open_exit()


## Draws only this room and its neighbours, lights included: the doors lock,
## so nothing further can be seen anyway.
func _show_near(i: int) -> void:
	for j in rooms.size():
		rooms[j].visible = absi(j - i) <= 1
