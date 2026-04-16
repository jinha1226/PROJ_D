class_name ArmorRegistry
extends RefCounted
## Static armor catalog. Mirrors WeaponRegistry's API so Player.setup can
## auto-equip the first body-armor entry it finds in job.starting_equipment.

const DATA: Dictionary = {
	"leather_armor": {"name": "Leather Armor", "ac": 2, "color": Color(0.55, 0.35, 0.20)},
	"chain_mail":    {"name": "Chain Mail",    "ac": 4, "color": Color(0.70, 0.72, 0.78)},
	"plate_armor":   {"name": "Plate Armor",   "ac": 6, "color": Color(0.85, 0.85, 0.90)},
	# Aliases — some jobs and LPC defs use "leather_chest" / "plate_chest".
	"leather_chest": {"name": "Leather Chest", "ac": 2, "color": Color(0.55, 0.35, 0.20)},
	"chain_chest":   {"name": "Chain Chest",   "ac": 4, "color": Color(0.70, 0.72, 0.78)},
	"plate_chest":   {"name": "Plate Chest",   "ac": 6, "color": Color(0.85, 0.85, 0.90)},
}


static func is_armor(id: String) -> bool:
	return DATA.has(id)


## Returns a copy with id baked in; empty if unknown.
static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate()
	d["id"] = id
	return d
