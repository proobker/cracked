class_name ProgressionState
extends RefCounted
## Deterministic offline ledger. Earnings create outputs; purchases consume
## whole outputs and create change. Conflict losers confer neither rank nor cost.
var records := {}
var conflicts: Array = []
var xp := 0
var coins := 0
var owned := {}
var outputs := {}
var rejected: Array = []

static func integer(value: Variant, maximum := 100000) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and float(value) >= 0 and float(value) <= maximum and float(value) == floorf(float(value))


static func uid() -> String:
	return Crypto.new().generate_random_bytes(16).hex_encode()

func merge(incoming: Dictionary, tombstones: Array = []) -> void:
	for id: Variant in tombstones:
		if id is String and not conflicts.has(id):
			conflicts.append(id)
	for id: Variant in incoming:
		if not id is String or not incoming[id] is Dictionary:
			continue
		if records.has(id) and JSON.stringify(records[id], "", true) != JSON.stringify(incoming[id], "", true):
			if not conflicts.has(id):
				conflicts.append(id)
		else:
			records[id] = incoming[id].duplicate(true)
	rebuild()

func rebuild() -> void:
	xp = 0
	coins = 0
	owned = {}
	outputs = {}
	rejected = []
	var pending: Array = []
	var ids: Array = records.keys()
	ids.sort()
	for id: String in ids:
		if conflicts.has(id):
			rejected.append(id)
			continue
		var r: Dictionary = records[id]
		if r.get("type") == "earn":
			if not integer(r.get("coins")) or not integer(r.get("xp")):
				rejected.append(id)
				continue
			var money := int(r.coins)
			var experience := int(r.xp)
			if money < 0 or experience < 0:
				rejected.append(id)
				continue
			xp += experience
			if money > 0:
				outputs[id] = money
		elif r.get("type") == "buy":
			pending.append(id)
		else:
			rejected.append(id)
	var graph := SkillCatalog.nodes()
	# Sorted topological passes make snapshot merge order irrelevant.
	while not pending.is_empty():
		var progressed := false
		for id: String in pending.duplicate():
			var r: Dictionary = records[id]
			if not r.get("node") is String or not integer(r.get("rank"), 3) or not integer(r.get("cost")):
				rejected.append(id)
				pending.erase(id)
				progressed = true
				continue
			var node_id := String(r.node)
			var rank := int(r.rank)
			var inputs: Variant = r.get("inputs", [])
			if not graph.has(node_id) or not inputs is Array or inputs.is_empty():
				rejected.append(id)
				pending.erase(id)
				progressed = true
				continue
			var node: Dictionary = graph[node_id]
			if rank <= int(owned.get(node_id, 0)) or rank < 1 or rank > int(node.max):
				rejected.append(id)
				pending.erase(id)
				progressed = true
				continue
			if rank != int(owned.get(node_id, 0)) + 1 or not SkillCatalog.parent_owned(node, owned):
				continue
			if SkillCatalog.player_level(xp) < int(node.tier):
				continue
			var total := 0
			var seen := {}
			var ready := true
			for input: Variant in inputs:
				if not input is String or seen.has(input) or not outputs.has(input):
					ready = false
					break
				seen[input] = true
				total += int(outputs[input])
			var price := SkillCatalog.cost(node_id, rank)
			if not ready or total < price or int(r.get("cost", -1)) != price:
				continue
			for input: String in inputs:
				outputs.erase(input)
			if total > price:
				outputs[id + "/change"] = total - price
			owned[node_id] = rank
			pending.erase(id)
			progressed = true
		if not progressed:
			rejected.append_array(pending)
			break
	for amount: int in outputs.values():
		coins += amount

func purchase_record(node_id: String) -> Dictionary:
	var graph := SkillCatalog.nodes()
	if not graph.has(node_id):
		return {}
	var node: Dictionary = graph[node_id]
	var rank := int(owned.get(node_id, 0)) + 1
	if rank > int(node.max) or SkillCatalog.player_level(xp) < int(node.tier) or not SkillCatalog.parent_owned(node, owned):
		return {}
	var price := SkillCatalog.cost(node_id, rank)
	var inputs: Array = []
	var total := 0
	var ids: Array = outputs.keys()
	ids.sort()
	for id: String in ids:
		inputs.append(id)
		total += int(outputs[id])
		if total >= price:
			break
	if total < price:
		return {}
	return {"type": "buy", "node": node_id, "rank": rank, "cost": price, "inputs": inputs}
