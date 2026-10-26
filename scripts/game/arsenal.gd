class_name Arsenal
extends RefCounted
## Unlock levels are campaign clears, independent of player XP and currency.
const GUNS := {"rifle": 0, "shotgun": 0, "marksman": 0, "smg": 3, "burst": 8, "lmg": 15, "plasma": 25, "railgun": 35, "arc": 45}
const GRENADES := {"frag": 1, "emp": 10, "incendiary": 20}
const DEFAULT := ["rifle", "shotgun", "marksman"]

static func available(id: String, clears: Dictionary) -> bool:
	var required := int(GUNS.get(id, GRENADES.get(id, -1)))
	return required == 0 or (required > 0 and clears.has(str(required)))

static func loadout(ids: Array, clears: Dictionary, practice := false) -> Array:
	var result: Array = []
	for id: Variant in ids + DEFAULT:
		if id is String and GUNS.has(id) and not result.has(id) and (practice or available(id, clears)):
			result.append(id)
		if result.size() == 3:
			break
	return result

static func make(id: String) -> Weapon:
	match id:
		"rifle": return Rifle.new()
		"shotgun": return Shotgun.new()
		"marksman": return Marksman.new()
	return ExpansionWeapon.new(id)
