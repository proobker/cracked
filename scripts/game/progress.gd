extends Node
## Which levels are open and the best score on each, saved to
## user://progress.cfg. Autoloaded as `Progress`. Play Games keeps a copy
## in the cloud through to_dict() / merge().

signal changed

const PATH := "user://progress.cfg"

## The highest level that can be played. Clearing it opens the next.
var unlocked := 1
## Level number -> best score on a clear.
var best := {}


func _ready() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	merge({"unlocked": cfg.get_value("progress", "unlocked", 1), "best": cfg.get_value("progress", "best", {})}, false)


func is_unlocked(level: int) -> bool:
	return level <= unlocked


func best_for(level: int) -> int:
	return int(best.get(level, 0))


## A clear opens the next level and keeps the higher score.
func complete(level: int, score: int) -> void:
	unlocked = clampi(maxi(unlocked, level + 1), 1, Levels.COUNT)
	best[level] = maxi(best_for(level), score)
	save()


func save() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("progress", "unlocked", unlocked)
	cfg.set_value("progress", "best", best)
	cfg.save(PATH)
	changed.emit()


func to_dict() -> Dictionary:
	var scores := {}
	for level: int in best:
		scores[str(level)] = best[level]
	return {"unlocked": unlocked, "best": scores}


## Takes the further of the two: the higher unlock, and per level the
## higher score. Merging never loses progress, whichever side is newer.
func merge(data: Dictionary, persist := true) -> void:
	unlocked = clampi(maxi(unlocked, int(data.get("unlocked", 1))), 1, Levels.COUNT)
	var scores: Dictionary = data.get("best", {})
	for key: Variant in scores:
		var level := int(key)
		if level >= 1 and level <= Levels.COUNT:
			best[level] = maxi(best_for(level), int(scores[key]))
	if persist:
		save()
	else:
		changed.emit()
