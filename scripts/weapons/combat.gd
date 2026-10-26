class_name Combat
extends RefCounted
## Shared world-space damage/visibility. Source IDs survive delayed attacks.
static func visible(world: Node3D, from: Vector3, to: Vector3) -> bool:
	return world.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(from, to, 1)).is_empty()

static func hit(enemy: Enemy, amount: float, shape: int, source: StringName, origin: Vector3, player: Player, effects: Dictionary, stagger := 0.0) -> String:
	var weak := shape >= 0 and shape == enemy._weak_shape_idx
	var gun := Arsenal.GUNS.has(String(source))
	if weak:
		amount *= 1.0 + 0.08 * float(effects.get("weak_damage", 0))
		stagger = maxf(stagger, 0.1 * float(effects.get("weak_stagger", 0)))
	if gun and enemy.affected_left > 0.0 and effects.has("disrupt_damage"):
		amount *= 1.15
	if is_instance_valid(player) and gun:
		stagger = maxf(stagger, player.hit_stagger(enemy))
	enemy.hit_origin = origin
	var result := enemy.take_hit(amount, shape, source, stagger)
	if is_instance_valid(player) and result != "none":
		player.combat_hit(enemy, result, weak, source)
	return result

static func explode(world: Node3D, at: Vector3, source: StringName, player: Player, effects: Dictionary, radius := 5.0, damage := 110.0) -> void:
	radius *= 1.0 + 0.08 * float(effects.get("blast_radius", 0))
	ShotFx.impact(world, at, Vector3.UP, Color(1.0, 0.5, 0.1), true)
	Audio.play_at(&"shot_shotgun", at)
	for node in world.get_tree().get_nodes_in_group("enemy"):
		var enemy := node as Enemy
		var center := enemy.global_position + Vector3.UP * enemy.height * 0.6
		var distance := at.distance_to(center)
		if distance > radius or not visible(world, at, center):
			continue
		enemy.affected_left = maxf(enemy.affected_left, 3.0) if source != &"plasma" else enemy.affected_left
		if source == &"emp":
			enemy.apply_emp(2.0 * (1.0 + 0.2 * float(effects.get("emp_duration", 0))), float(effects.get("shield_break", 0)))
		else:
			hit(enemy, damage * lerpf(1.0, 0.2, distance / radius), -1, source, at, player, effects, 0.1 * float(effects.get("blast_stagger", 0)))
	if source != &"emp" and is_instance_valid(player):
		var center := player.global_position + Vector3.UP
		var distance := at.distance_to(center)
		if distance < radius and visible(world, at, center):
			player.take_damage(damage * 0.45 * (1.0 - distance / radius) * (1.0 - 0.2 * float(effects.get("blast_guard", 0))), "your " + String(source))
