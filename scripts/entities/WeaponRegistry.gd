class_name WeaponRegistry
extends RefCounted
## Static weapon catalog. Two-layer lookup:
##   1. DATA const — hand-tuned / aliased weapons (our custom ids).
##   2. DCSS JSON — 48 weapons from item-prop.cc (loaded lazily).
## Custom entries win when ids overlap.

const _DCSS_JSON := "res://assets/dcss_items/weapons.json"

# Hand-tuned / alias entries (our internal ids).
const DATA: Dictionary = {
	# Axes
	"axe":        {"dmg": 7,  "skill": "axe",         "delay": 1.3},
	"axe_medium": {"dmg": 11, "skill": "axe",         "delay": 1.5},
	"waraxe":     {"dmg": 11, "skill": "axe",         "delay": 1.5},
	# Maces
	"club":       {"dmg": 5,  "skill": "mace",        "delay": 1.3},
	"mace":       {"dmg": 9,  "skill": "mace",        "delay": 1.4},
	"flail":      {"dmg": 11, "skill": "mace",        "delay": 1.4},
	# Short blades
	"dagger":     {"dmg": 4,  "skill": "short_blade", "delay": 1.0},
	"short_sword":{"dmg": 6,  "skill": "short_blade", "delay": 1.1},
	"rapier":     {"dmg": 7,  "skill": "short_blade", "delay": 1.2},
	"saber":      {"dmg": 7,  "skill": "short_blade", "delay": 1.2},
	# Long blades
	"arming_sword":{"dmg": 7,  "skill": "long_blade", "delay": 1.3},
	"longsword":   {"dmg": 10, "skill": "long_blade", "delay": 1.4},
	"katana":      {"dmg": 10, "skill": "long_blade", "delay": 1.4},
	"scimitar":    {"dmg": 11, "skill": "long_blade", "delay": 1.5},
	"greatsword":  {"dmg": 17, "skill": "long_blade", "delay": 1.7},
	# Polearms
	"spear":      {"dmg": 7,  "skill": "polearm",     "delay": 1.2},
	"longspear":  {"dmg": 9,  "skill": "polearm",     "delay": 1.3},
	"trident":    {"dmg": 9,  "skill": "polearm",     "delay": 1.3},
	"halberd":    {"dmg": 13, "skill": "polearm",     "delay": 1.5},
	"scythe":     {"dmg": 14, "skill": "polearm",     "delay": 1.8},
	# Ranged
	"short_bow":  {"dmg": 9,  "skill": "bow",         "delay": 1.3},
	"long_bow":   {"dmg": 15, "skill": "bow",         "delay": 1.6},
	"bow":        {"dmg": 9,  "skill": "bow",         "delay": 1.3},
	"crossbow":   {"dmg": 18, "skill": "crossbow",    "delay": 1.9},
	"slingshot":  {"dmg": 5,  "skill": "sling",       "delay": 1.1},
	"boomerang":  {"dmg": 5,  "skill": "throwing",    "delay": 1.0},
	"throwing_axe":{"dmg": 8, "skill": "throwing",    "delay": 1.1},
	# Staves
	"gnarled_staff":  {"dmg": 10, "skill": "staff", "delay": 1.3, "spell_school": "",      "spell_bonus": 2},
	"fire_staff":     {"dmg": 8,  "skill": "staff", "delay": 1.3, "spell_school": "fire",  "spell_bonus": 3},
	"ice_staff":      {"dmg": 8,  "skill": "staff", "delay": 1.3, "spell_school": "cold",  "spell_bonus": 3},
	"lightning_staff":{"dmg": 8,  "skill": "staff", "delay": 1.3, "spell_school": "air",   "spell_bonus": 3},
	"crystal_staff":  {"dmg": 8,  "skill": "staff", "delay": 1.3, "spell_school": "earth", "spell_bonus": 3},
	# Evocable
	"wand_simple": {"dmg": 3, "skill": "evocations", "delay": 1.0},
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


static func _get(id: String) -> Dictionary:
	_ensure_loaded()
	return _merged.get(id, {})


static func is_weapon(id: String) -> bool:
	_ensure_loaded()
	return _merged.has(id)


static func weapon_damage_for(id: String) -> int:
	return int(_get(id).get("dmg", 0))


static func weapon_skill_for(id: String) -> String:
	return String(_get(id).get("skill", ""))


static func weapon_delay_for(id: String) -> float:
	var d = _get(id).get("delay", 1.0)
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
	return String(_get(weapon_id).get("spell_school", ""))


static func staff_spell_bonus(weapon_id: String) -> int:
	return int(_get(weapon_id).get("spell_bonus", 0))
