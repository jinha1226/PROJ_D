class_name ArmorRegistry
extends RefCounted
## Static armor catalog. Each entry has a slot id so Player can track
## chest/legs/boots/helm/gloves independently and sum AC across them.

# AC values follow DCSS body-armour table:
#   leather armour 3, chain mail 6, plate armour 10
#   helmet 1, boots 1, gloves 1, (greaves/pants 3)
const DATA: Dictionary = {
	# --- Chest ---
	"robe":          {"name": "Robe",          "slot": "chest", "ac": 2,  "color": Color(0.55, 0.40, 0.85)},
	"leather_chest": {"name": "Leather Chest", "slot": "chest", "ac": 3,  "color": Color(0.55, 0.35, 0.20)},
	"chain_chest":   {"name": "Chain Chest",   "slot": "chest", "ac": 6,  "color": Color(0.70, 0.72, 0.78)},
	"plate_chest":   {"name": "Plate Chest",   "slot": "chest", "ac": 10, "color": Color(0.85, 0.85, 0.90)},
	# --- Legs ---
	"leather_legs": {"name": "Leather Legs", "slot": "legs", "ac": 1, "color": Color(0.55, 0.35, 0.20)},
	"chain_legs":   {"name": "Chain Legs",   "slot": "legs", "ac": 2, "color": Color(0.70, 0.72, 0.78)},
	"plate_legs":   {"name": "Plate Legs",   "slot": "legs", "ac": 3, "color": Color(0.85, 0.85, 0.90)},
	# --- Boots ---
	"leather_boots": {"name": "Leather Boots", "slot": "boots", "ac": 1, "color": Color(0.55, 0.35, 0.20)},
	"plate_boots":   {"name": "Plate Boots",   "slot": "boots", "ac": 2, "color": Color(0.85, 0.85, 0.90)},
	# --- Helm ---
	"leather_helm": {"name": "Leather Helm", "slot": "helm", "ac": 1, "color": Color(0.55, 0.35, 0.20)},
	"plate_helm":   {"name": "Plate Helm",   "slot": "helm", "ac": 2, "color": Color(0.85, 0.85, 0.90)},
	# --- Gloves ---
	"leather_gloves": {"name": "Leather Gloves", "slot": "gloves", "ac": 1, "color": Color(0.55, 0.35, 0.20)},
	"plate_gloves":   {"name": "Plate Gloves",   "slot": "gloves", "ac": 2, "color": Color(0.85, 0.85, 0.90)},
	# --- Legacy aliases (kept so old job/spawn data still loads) ---
	"leather_armor": {"name": "Leather Chest", "slot": "chest", "ac": 3,  "color": Color(0.55, 0.35, 0.20)},
	"chain_mail":    {"name": "Chain Chest",   "slot": "chest", "ac": 6,  "color": Color(0.70, 0.72, 0.78)},
	"plate_armor":   {"name": "Plate Chest",   "slot": "chest", "ac": 10, "color": Color(0.85, 0.85, 0.90)},
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


static func slot_for(id: String) -> String:
	return String(DATA.get(id, {}).get("slot", ""))


static func display_name_for(id: String) -> String:
	return String(DATA.get(id, {}).get("name", id.capitalize().replace("_", " ")))
