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

# Hand-tuned entries — DCSS itself supplies AC / EV values via
# `assets/dcss_items/armours.json` (see _ensure_loaded). Only a handful
# of magical-cloak variants and spelling-aliases live here; everything
# else falls through to DCSS's item-prop.cc data.
const DATA: Dictionary = {
	# Cloak ego variants (our mobile layer — no direct DCSS equivalent).
	"cloak_protection":  {"name": "Cloak of Protection","slot": "cloak", "ac": 2, "ev_penalty": 0, "ev_bonus": 1, "color": Color(0.55, 0.45, 0.85)},
	"cloak_stealth":     {"name": "Cloak of Stealth",   "slot": "cloak", "ac": 1, "ev_penalty": 0, "ev_bonus": 1, "stealth": 2, "color": Color(0.12, 0.14, 0.22)},
	"cloak_resistance":  {"name": "Cloak of Resistance","slot": "cloak", "ac": 1, "ev_penalty": 0, "ev_bonus": 1, "dmg_reduce": 1, "color": Color(0.7, 0.25, 0.25)},
	# Legacy spelling aliases that some save/LPC paths still use.
	"leather_armor": {"name": "Leather Armour", "slot": "chest", "ac": 3, "ev_penalty": -40, "color": Color(0.55, 0.35, 0.20)},
	"plate_armor":   {"name": "Plate Armour",   "slot": "chest", "ac": 10, "ev_penalty": -180, "color": Color(0.85, 0.85, 0.90)},
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


static func _lookup(id: String) -> Dictionary:
	_ensure_loaded()
	return _merged.get(id, {})


static func is_armor(id: String) -> bool:
	_ensure_loaded()
	return _merged.has(id)


static func get_info(id: String) -> Dictionary:
	var d: Dictionary = _lookup(id)
	if d.is_empty():
		return {}
	var out: Dictionary = d.duplicate()
	out["id"] = id
	return out


static func slot_for(id: String) -> String:
	return String(_lookup(id).get("slot", ""))


static func ac_for(id: String) -> int:
	return int(_lookup(id).get("ac", 0))


static func ev_penalty_for(id: String) -> int:
	return int(_lookup(id).get("ev_penalty", 0))


static func display_name_for(id: String) -> String:
	return String(_lookup(id).get("name", id.replace("_", " ").capitalize()))
