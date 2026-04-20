class_name WeaponRegistry
extends RefCounted
## Static weapon catalog. Two-layer lookup:
##   1. DATA const — hand-tuned / aliased weapons (our custom ids).
##   2. DCSS JSON — 48 weapons from item-prop.cc (loaded lazily).
## Custom entries win when ids overlap.

const _DCSS_JSON := "res://assets/dcss_items/weapons.json"

# Hand-tuned / alias entries (our internal ids). Values match DCSS
# 0.34 item-prop.cc `Weapon_prop[]`. DCSS `speed` is the 1/10-second
# delay field; we divide by 10 to get the float delay.
#
# IDs prefixed with `weap_` would be cleaner but we keep our legacy
# short names so existing JobData starting_equipment / code paths
# don't shift. Aliases (longsword → long_sword, etc.) exist where
# DCSS renamed a weapon.
const DATA: Dictionary = {
	# --- Maces & flails ---
	"club":       {"dmg": 5,  "skill": "mace",        "delay": 1.3},
	"whip":       {"dmg": 6,  "skill": "mace",        "delay": 1.1},
	"mace":       {"dmg": 8,  "skill": "mace",        "delay": 1.4},
	"flail":      {"dmg": 10, "skill": "mace",        "delay": 1.4},
	"morningstar":{"dmg": 13, "skill": "mace",        "delay": 1.5},
	"great_mace": {"dmg": 17, "skill": "mace",        "delay": 1.7},
	# --- Short blades ---
	"dagger":     {"dmg": 4,  "skill": "short_blade", "delay": 1.0},
	"quick_blade":{"dmg": 4,  "skill": "short_blade", "delay": 1.5},
	"short_sword":{"dmg": 5,  "skill": "short_blade", "delay": 1.0},
	"rapier":     {"dmg": 7,  "skill": "short_blade", "delay": 1.2},
	# --- Long blades ---
	"falchion":   {"dmg": 8,  "skill": "long_blade",  "delay": 1.3},
	"long_sword": {"dmg": 10, "skill": "long_blade",  "delay": 1.4},
	"longsword":  {"dmg": 10, "skill": "long_blade",  "delay": 1.4},  # alias
	"scimitar":   {"dmg": 12, "skill": "long_blade",  "delay": 1.4},
	"great_sword":{"dmg": 17, "skill": "long_blade",  "delay": 1.7},
	"greatsword": {"dmg": 17, "skill": "long_blade",  "delay": 1.7},  # alias
	# --- Axes ---
	"hand_axe":   {"dmg": 7,  "skill": "axe",         "delay": 1.3},
	"axe":        {"dmg": 7,  "skill": "axe",         "delay": 1.3},  # alias → hand_axe
	"war_axe":    {"dmg": 11, "skill": "axe",         "delay": 1.5},
	"waraxe":     {"dmg": 11, "skill": "axe",         "delay": 1.5},  # alias
	"axe_medium": {"dmg": 11, "skill": "axe",         "delay": 1.5},  # alias → war_axe
	"broad_axe":  {"dmg": 13, "skill": "axe",         "delay": 1.6},
	"battleaxe":  {"dmg": 15, "skill": "axe",         "delay": 1.7},
	# --- Polearms ---
	"spear":      {"dmg": 6,  "skill": "polearm",     "delay": 1.1},
	"trident":    {"dmg": 9,  "skill": "polearm",     "delay": 1.3},
	"halberd":    {"dmg": 13, "skill": "polearm",     "delay": 1.5},
	"glaive":     {"dmg": 15, "skill": "polearm",     "delay": 1.7},
	"bardiche":   {"dmg": 18, "skill": "polearm",     "delay": 1.9},
	# --- Staves ---
	"staff":        {"dmg": 5,  "skill": "staff", "delay": 1.2},
	"quarterstaff": {"dmg": 10, "skill": "staff", "delay": 1.3},
	"gnarled_staff":{"dmg": 10, "skill": "staff", "delay": 1.3, "spell_school": "",      "spell_bonus": 2},  # magical quarterstaff
	"fire_staff":   {"dmg": 5,  "skill": "staff", "delay": 1.2, "spell_school": "fire",  "spell_bonus": 3},  # staff of fire
	"ice_staff":    {"dmg": 5,  "skill": "staff", "delay": 1.2, "spell_school": "cold",  "spell_bonus": 3},
	"lightning_staff":{"dmg": 5,"skill": "staff", "delay": 1.2, "spell_school": "air",   "spell_bonus": 3},
	"crystal_staff":{"dmg": 5,  "skill": "staff", "delay": 1.2, "spell_school": "earth", "spell_bonus": 3},
	# --- Ranged (DCSS 0.34 folds bow/sling/crossbow into SK_RANGED) ---
	"sling":      {"dmg": 7,  "skill": "bow",         "delay": 1.4},
	"slingshot":  {"dmg": 7,  "skill": "bow",         "delay": 1.4},  # alias
	"shortbow":   {"dmg": 8,  "skill": "bow",         "delay": 1.4},
	"short_bow":  {"dmg": 8,  "skill": "bow",         "delay": 1.4},  # alias
	"bow":        {"dmg": 8,  "skill": "bow",         "delay": 1.4},  # alias
	"orcbow":     {"dmg": 11, "skill": "bow",         "delay": 1.5},
	"longbow":    {"dmg": 14, "skill": "bow",         "delay": 1.7},
	"long_bow":   {"dmg": 14, "skill": "bow",         "delay": 1.7},  # alias
	"arbalest":   {"dmg": 16, "skill": "bow",         "delay": 1.9},
	"crossbow":   {"dmg": 16, "skill": "bow",         "delay": 1.9},  # alias
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
	# Build DCSS lookup keyed by id, converting speed→delay (DCSS speed=10 → 1.0 delay).
	for entry in parsed:
		var wid: String = String(entry.get("id", ""))
		if wid == "":
			continue
		_dcss[wid] = {
			"dmg":   int(entry.get("damage", 0)),
			"skill": String(entry.get("skill", "")),
			"delay": float(entry.get("speed", 10)) / 10.0,
			"name":  String(entry.get("name", "")),
		}
	# Merge: DATA takes priority.
	_merged = _dcss.duplicate()
	for k in DATA:
		_merged[k] = DATA[k]


static func _lookup(id: String) -> Dictionary:
	_ensure_loaded()
	return _merged.get(id, {})


static func is_weapon(id: String) -> bool:
	_ensure_loaded()
	return _merged.has(id)


static func weapon_damage_for(id: String) -> int:
	return int(_lookup(id).get("dmg", 0))


static func weapon_skill_for(id: String) -> String:
	return String(_lookup(id).get("skill", ""))


static func weapon_delay_for(id: String) -> float:
	var d = _lookup(id).get("delay", 1.0)
	return float(d)


static func all_weapon_ids() -> Array:
	_ensure_loaded()
	return _merged.keys()


static func display_name_for(id: String) -> String:
	_ensure_loaded()
	var dcss_name: String = String(_dcss.get(id, {}).get("name", ""))
	if dcss_name != "":
		return dcss_name
	const NAMES: Dictionary = {
		"axe": "Axe", "axe_medium": "Battle Axe", "waraxe": "War Axe",
		"club": "Club", "mace": "Mace", "flail": "Flail",
		"dagger": "Dagger", "short_sword": "Short Sword", "rapier": "Rapier",
		"saber": "Saber", "arming_sword": "Arming Sword", "longsword": "Longsword",
		"katana": "Katana", "scimitar": "Scimitar", "greatsword": "Greatsword",
		"spear": "Spear", "longspear": "Longspear", "halberd": "Halberd",
		"scythe": "Scythe", "trident": "Trident",
		"short_bow": "Short Bow", "long_bow": "Long Bow", "bow": "Bow",
		"crossbow": "Crossbow", "slingshot": "Slingshot",
		"boomerang": "Boomerang", "throwing_axe": "Throwing Axe",
		"fire_staff": "Fire Staff", "ice_staff": "Ice Staff",
		"lightning_staff": "Lightning Staff", "gnarled_staff": "Gnarled Staff",
		"crystal_staff": "Crystal Staff", "wand_simple": "Simple Wand",
	}
	return NAMES.get(id, id.replace("_", " ").capitalize())


static func staff_spell_school(weapon_id: String) -> String:
	return String(_lookup(weapon_id).get("spell_school", ""))


static func staff_spell_bonus(weapon_id: String) -> int:
	return int(_lookup(weapon_id).get("spell_bonus", 0))
