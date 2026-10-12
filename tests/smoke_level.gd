extends Node
## Boots a level and lets it run unattended, to catch runtime errors:
##   godot --headless --path . res://tests/smoke_level.tscn --quit-after 2000 -- 10
## The number after -- is the level (default 1).


func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	Game.level = int(args[0]) if not args.is_empty() else 1
	Game.mode = Game.Mode.RUN
	get_tree().change_scene_to_file.call_deferred("res://scenes/main.tscn")
