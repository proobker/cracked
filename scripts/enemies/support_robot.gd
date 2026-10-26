class_name SupportRobot
extends Shooter
## Repairs one visible wounded ally at a bounded tick rate; never resurrects.
var _repair_left := 0.0

func _configure() -> void:
	super()
	kind = &"support"
	display_name = "a support robot"
	max_health = 100.0
	points = 220
	color = Color(0.2, 1.0, 0.65)

func _act(delta: float, to: Vector3) -> Vector3:
	_repair_left -= delta
	if _repair_left <= 0.0:
		_repair_left = 0.3
		var nearest := 12.0
		var ally: Enemy
		var origin := global_position + Vector3.UP * 1.6
		for node in get_tree().get_nodes_in_group("enemy"):
			var candidate := node as Enemy
			if candidate == self or candidate.kind in [&"support", &"boss"] or not candidate.active or candidate._dead or candidate.health >= candidate.max_health:
				continue
			var distance := global_position.distance_to(candidate.global_position)
			if distance < nearest and Combat.visible(self, origin, candidate.global_position + Vector3.UP):
				nearest = distance
				ally = candidate
		if ally:
			ally.health = minf(ally.max_health, ally.health + 6.0)
			ShotFx.tracer(get_parent(), origin, ally.global_position + Vector3.UP, color, 0.05, 0.25)
	return super(delta, to)
