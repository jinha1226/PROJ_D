class_name ArmorRegistry
extends RefCounted
## Static armour catalog. Two-layer lookup:
##   1. DATA const — hand-tuned entries with slot assignments (our ids).
##   2. DCSS JSON — 22 armours from item-prop.cc (loaded lazily).
## Custom entries win when ids overlap.

const _DCSS_JSON := "res://assets/dcss_items/armours.json"

# Slot mapping for DCSS armour ids.
const _SLOT_MAP: Dictionary = {
	"robe": "chest", "animal_skin": "chest",
	"leather_armour": "chest", "ring_mail": "chest", "scale_mail": "chest",
	"chain_mail": "chest", "plate_armour": "chest", "crystal_plate_armour": "chest",
	"troll_leather_armour": "chest",
	"cloak": "cloak", "scarf": "cloak",
	"gloves": "gloves",
	"helmet": "helm", "cap": "helm", "hat": "helm",
	"boots": "boots",
	"buckler": "shield", "kite_shield": "shield", "tower_shield": "shield",
	"centaur_barding": "boots", "barding": "boots",
	"orb": "offhand",
}

# Hand-tuned entries (our custom/aliased ids). These win over DCSS.
const DATA: Dictionary = {
	"robe":          {"name": "Robe",          "slot": "chest", "ac": 2,  "color": Color(0.55, 0.40, 0.85)},
	"leather_chest": {"name": "Leather Chest", "slot": "chest", "ac": 3,  "color": Color(0.55, 0.35, 0.20)},
	"chain_chest":   {"name": "Chain Chest",   "slot": "chest", "ac": 6,  "color": Color(0.70, 0.72, 0.78)},
	"plate_chest":   {"name": "Plate Chest",   "slot": "chest", "ac": 10, "color": Color(0.85, 0.85, 0.90)},
	"leather_legs":  {"name": "Leather Legs",  "slot": "legs",  "ac": 1,  "color": Color(0.55, 0.35, 0.20)},
	"chain_legs":    {"name": "Chain Legs",    "slot": "legs",  "ac": 2,  "color": Color(0.70, 0.72, 0.78)},
	"plate_legs":    {"name": "Plate Legs",    "slot": "legs",  "ac": 3,  "color": Color(0.85, 0.85, 0.90)},
	"leather_boots": {"name": "Leather Boots", "slot": "boots", "ac": 1,  "color": Color(0.55, 0.35, 0.20)},
	"plate_boots":   {"name": "Plate Boots",   "slot": "boots", "ac": 2,  "color": Color(0.85, 0.85, 0.90)},
	"leather_helm":  {"name": "Leather Helm",  "slot": "helm",  "ac": 1,  "color": Color(0.55, 0.35, 0.20)},
	"plate_helm":    {"name": "Plate Helm",    "slot": "helm",  "ac": 2,  "color": Color(0.85, 0.85, 0.90)},
	"leather_gloves":{"name": "Leather Gloves","slot": "gloves","ac": 1,  "color": Color(0.55, 0.35, 0.20)},
	"plate_gloves":  {"name": "Plate Gloves",  "slot": "gloves","ac": 2,  "color": Color(0.85, 0.85, 0.90)},
	"cloak":             {"name": "Cloak",              "slot": "cloak", "ac": 1, "ev_bonus": 1, "color": Color(0.35, 0.22, 0.55)},
	"cloak_protection":  {"name": "Cloak of Protection","slot": "cloak", "ac": 2, "ev_bonus": 1, "color": Color(0.55, 0.45, 0.85)},
	"cloak_stealth":     {"name": "Cloak of Stealth",   "slot": "cloak", "ac": 1, "ev_bonus": 1, "stealth": 2, "color": Color(0.12, 0.14, 0.22)},
	"cloak_resistance":  {"name": "Cloak of Resistance","slot": "cloak", "ac": 1, "ev_bonus": 1, "dmg_reduce": 1, "color": Color(0.7, 0.25, 0.25)},
	# Legacy aliases
	"leather_armor": {"name": "Leather Chest", "slot": "chest", "ac": 3,  "color": Color(0.55, 0.35, 0.20)},
	"chain_mail":    {"name": "Chain Mail",    "slot": "chest", "ac": 8,  "color": Color(0.70, 0.72, 0.78)},
	"plate_armor":   {"name": "Plate Armour",  "slot": "chest", "ac": 10, "color": Color(0.85, 0.85, 0.90)},
}

static var _dcss: Dictionary = {}
static var _merged: Dictionary = {}
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_DCSS_JSON, FileAccess.READ)
	if f == null:
		_merged = DATA.duplicate()
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if not (parsed is Array):
		_merged = DATA.duplicate()
		return
	for entry in parsed:
		var aid: String = String(entry.get("id", ""))
		if aid == "":
			continue
		var ev_pen: int = int(entry.get("ev_penalty", 0))
		_dcss[aid] = {
			"name":       String(entry.get("name", "")),
			"ac":         int(entry.get("ac", 0)),
			"ev_penalty": ev_pen,
			"slot":       _SLOT_MAP.get(aid, "chest"),
		}
	_merged = _dcss.duplicate()
	for k in DATA:
		_merged[k] = DATA[k]


static func _get(id: String) -> Dictionary:
	_ensure_loaded()
	return _merged.get(id, {})


static func is_armor(id: String) -> bool:
	_ensure_loaded()
	return _merged.has(id)


static func get_info(id: String) -> Dictionary:
	var d: Dictionary = _get(id)
	if d.is_empty():
		return {}
	var out: Dictionary = d.duplicate()
	out["id"] = id
	return out


static func slot_for(id: String) -> String:
	return String(_get(id).get("slot", ""))


static func ac_for(id: String) -> int:
	return int(_get(id).get("ac", 0))


static func ev_penalty_for(id: String) -> int:
	return int(_get(id).get("ev_penalty", 0))


static func display_name_for(id: String) -> String:
	return String(_get(id).get("name", id.replace("_", " ").capitalize()))
