class_name SkillCatalog
extends RefCounted
## Stable IDs are save-format identifiers. The graph has alternative-parent
## routes; validation uses a fixed point, never array/display order.

const PATHS := {
	"momentum": ["moving_accuracy", "slide_distance", "moving_reload", "sprint_recovery", "slide_guard", "slide_stagger"],
	"evasion": ["dash_cooldown", "air_control", "dash_handling", "dash_reload", "dash_guard", "near_miss"],
	"precision": ["scoped_handling", "first_shot", "weak_damage", "scope_speed", "weak_stagger", "precision_feed"],
	"suppression": ["bloom_control", "reserves", "sustained_handling", "reload_speed", "sustained_stagger", "focus_fire"],
	"ordnance": ["blast_radius", "blast_guard", "blast_stagger", "grenade_capacity", "plasma_reload", "blast_reload"],
	"disruption": ["emp_duration", "burn_duration", "throw_accuracy", "shield_break", "burn_slow", "disrupt_damage"],
}
const ROOTS := ["swap_speed", "recoil_recovery", "throw_recovery"]
const DESCRIPTIONS := {
	"swap_speed": "Weapon raise speed +20% per rank", "recoil_recovery": "Recoil recovery +20% per rank", "throw_recovery": "Throw recovery -12% per rank",
	"moving_accuracy": "Movement spread -15% per rank", "slide_distance": "Slide friction -10% per rank", "moving_reload": "Moving reload speed +12% per rank",
	"sprint_recovery": "Weapon ready after sprint +25% per rank", "slide_guard": "Sliding damage taken -10% per rank", "slide_stagger": "Slide primes next shot: 0.6s stagger (consumed on miss)",
	"dash_cooldown": "Dash cooldown -10% per rank", "air_control": "Air acceleration +20% per rank", "dash_handling": "After dash: spread/recoil -12% per rank for 2s",
	"dash_reload": "After dash: reload speed +15% per rank for 2s", "dash_guard": "After dash: damage taken -8% per rank for 2s", "near_miss": "Dodge a bolt during dash: +20% speed for 2s (4s cooldown)",
	"scoped_handling": "Scoped spread and kick -15% per rank", "first_shot": "Bloom decay +20% per rank", "weak_damage": "Weak-point damage +8% per rank",
	"scope_speed": "Scope transition +25% per rank", "weak_stagger": "Weak-point hits stagger 0.1s per rank", "precision_feed": "Weak-point kill transfers 2 reserve rounds into magazine",
	"bloom_control": "Bloom growth -12% per rank", "reserves": "Ammo reserve capacity +20% per rank", "sustained_handling": "Held-fire movement spread -12% per rank",
	"reload_speed": "Reload speed +10% per rank", "sustained_stagger": "Every fourth hit staggers 0.1s per rank", "focus_fire": "Four hits on one target: -25% spread for 2s",
	"blast_radius": "Explosion/EMP radius +8% per rank", "blast_guard": "Own explosive damage -20% per rank", "blast_stagger": "Explosions stagger 0.1s per rank",
	"grenade_capacity": "Grenade capacity +1 (starting count stays 2)", "plasma_reload": "Plasma reload speed +15% per rank", "blast_reload": "Grenade kill: +30% reload speed for 3s",
	"emp_duration": "EMP duration +20% per rank", "burn_duration": "Burn field duration +20% per rank", "throw_accuracy": "Moving throw deviation -25% per rank",
	"shield_break": "EMP shield disruption +1s per rank", "burn_slow": "Burn field slows enemies 8% per rank", "disrupt_damage": "Guns deal +15% to grenade-affected enemies",
}

static var _catalog: Dictionary = {}

static func nodes() -> Dictionary:
	if not _catalog.is_empty():
		return _catalog
	var result := {}
	var paths: Array = PATHS.keys()
	for i in ROOTS.size():
		result[ROOTS[i]] = {"tier": 1, "max": 3, "parents": [], "branch": i, "path": "foundation", "cap": false}
	for i in paths.size():
		var path: String = paths[i]
		var ids: Array = PATHS[path]
		for j in ids.size():
			var parents: Array = [ROOTS[i / 2]] if j == 0 else [ids[j - 1]]
			if j == 4:
				parents = [ids[2]]
			if j == 5:
				parents = [ids[3], ids[4]]
			if j in [3, 4] and path == "suppression":
				parents.append("moving_reload")
			if j in [3, 4] and path == "disruption":
				parents.append("weak_damage")
			result[ids[j]] = {"tier": 5 if j < 3 else (15 if j < 5 else 25), "max": 1 if j == 5 or ids[j] == "grenade_capacity" else 3, "parents": parents, "branch": i / 2, "path": path, "cap": j == 5}
	# Preserve the original 39 save IDs. Each discipline gains six branching
	# ten-node circuits and one bridge: 39 + 6 * 61 = 405 purchasable nodes.
	for i in paths.size():
		var path: String = paths[i]
		var ids: Array = PATHS[path]
		var angle := TAU * i / 6.0 - PI / 2.0
		for j in 6:
			result[ids[j]]["position"] = Vector2.from_angle(angle) * (350 + j * 360)
			for k in 10:
				var id := "%s_circuit_%d_%d" % [path, j + 1, k + 1]
				var row := k / 2
				var lane := k % 2
				var parents: Array = [ids[j]] if row == 0 else ["%s_circuit_%d_%d" % [path, j + 1, k - 1]]
				# Rejoining diamonds and alternate paths make each circuit traversable.
				if row > 0 and row % 2 == 0:
					parents.append("%s_circuit_%d_%d" % [path, j + 1, k if lane == 0 else k - 2])
				var effect: String = ids[(j + k) % 5]
				if effect == "grenade_capacity":
					effect = "throw_recovery"
				result[id] = {"tier": [5, 5, 10, 15, 20, 25][j], "max": 1, "parents": parents, "branch": i / 2, "path": path, "cap": false, "effect": effect, "weight": 0.25, "position": Vector2.from_angle(angle + (-1 if lane == 0 else 1) * (0.12 + row * 0.075)) * (430 + j * 360 + row * 38)}
		var bridge := path + "_bridge"
		result[bridge] = {"tier": 15, "max": 1, "parents": [ids[2], PATHS[paths[(i + 1) % 6]][2]], "branch": i / 2, "path": path, "cap": false, "effect": ROOTS[i / 2], "weight": 0.5, "position": Vector2.from_angle(angle + PI / 6) * 1150}
		for advanced in [3, 4]:
			result[ids[advanced]].parents.append(bridge)
			result[PATHS[paths[(i + 1) % 6]][advanced]].parents.append(bridge)
	for i in ROOTS.size():
		result[ROOTS[i]]["position"] = Vector2.from_angle(TAU * (i * 2 + 0.5) / 6.0 - PI / 2) * 140
	_catalog = result
	return _catalog

## Exact tuning; secondary to title()/meaning() in every player-facing view.
static func description(id: String) -> String:
	var node: Dictionary = nodes()[id]
	var effect := effect_of(id)
	if node.has("weight"):
		var name: String = SkillIdentity.DATA[effect][0]
		return "%s. Adds %.2f rank of %s; all %s sources cap at 3 ranks." % [DESCRIPTIONS[effect], float(node.weight), name, name]
	return DESCRIPTIONS[id]

## The effect a node grants: its own ID for the 39 core skills.
static func effect_of(id: String) -> String:
	return nodes()[id].get("effect", id)

## Player-facing name. Circuit/bridge IDs are save keys and never shown;
## minor nodes echo the skill they strengthen, bridges cross disciplines.
static func title(id: String) -> String:
	var name: String = SkillIdentity.DATA[effect_of(id)][0]
	if id.ends_with("_bridge"):
		return name + " Crossing"
	return name + (" Echo" if nodes()[id].has("weight") else "")

static func meaning(id: String) -> String:
	return SkillIdentity.DATA[effect_of(id)][1]

static func icon(id: String) -> Texture2D:
	return SkillIdentity.ICONS[effect_of(id)]

static func discipline(id: String) -> String:
	return String(nodes()[id].path).capitalize()

static func requirements(id: String) -> String:
	var parents: Array = nodes()[id].parents
	if parents.is_empty():
		return "Foundation skill"
	var names: Array = []
	for parent: String in parents:
		if not names.has(title(parent)):
			names.append(title(parent))
	return ("Requires " if names.size() == 1 else "Requires any of: ") + ", ".join(names)

static func xp_for_level(level: int) -> int:
	return 100 * (level - 1) * level

static func player_level(xp: int) -> int:
	var level := 1
	while level < 30 and xp >= xp_for_level(level + 1):
		level += 1
	return level

static func slots(level: int) -> int:
	return 4 + (4 if level >= 5 else 0) + (6 if level >= 15 else 0) + (10 if level >= 25 else 0)

static func cost(id: String, rank: int) -> int:
	var node: Dictionary = nodes().get(id, {})
	if node.has("weight"):
		return int(node.tier) * 5 * rank
	return int(node.get("tier", 1)) * 20 * rank

static func parent_owned(node: Dictionary, owned: Dictionary) -> bool:
	if node.parents.is_empty():
		return true
	for parent: String in node.parents:
		if int(owned.get(parent, 0)) > 0:
			return true
	return false

## Discovery excludes affordability: an earned route remains visible even
## with an empty wallet. Ownership, not activation, opens alternative paths.
static func is_revealed(id: String, owned: Dictionary, level: int) -> bool:
	var node: Dictionary = nodes().get(id, {})
	return not node.is_empty() and level >= int(node.tier) and parent_owned(node, owned)

static func valid_active(requested: Array, owned: Dictionary, level: int) -> Array:
	var graph := nodes()
	var result: Array = []
	var cap := false
	for _pass in graph.size():
		var previous_size := result.size()
		for id: Variant in requested:
			if not id is String or not graph.has(id) or result.has(id) or result.size() >= slots(level):
				continue
			var node: Dictionary = graph[id]
			if int(owned.get(id, 0)) < 1 or level < int(node.tier) or (node.cap and cap):
				continue
			var available := {}
			for active_id: String in result:
				available[active_id] = 1
			if parent_owned(node, available):
				result.append(id)
				cap = cap or node.cap
		if result.size() == previous_size:
			break
	return result

static func effects(active: Array, owned: Dictionary) -> Dictionary:
	var result := {}
	for id: String in active:
		if not nodes().has(id):
			continue
		var node: Dictionary = nodes()[id]
		var effect: String = node.get("effect", id)
		var limit := 1.0 if nodes()[effect].cap or effect == "grenade_capacity" else 3.0
		result[effect] = minf(limit, float(result.get(effect, 0)) + float(owned.get(id, 0)) * float(node.get("weight", 1.0)))
	return result
