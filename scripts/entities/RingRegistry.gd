class_name RingRegistry
extends RefCounted
## Ring catalog — trinket-style items whose bonuses stack onto Player
## stats at equip time and unwind at unequip. Effects are flat bonuses
## keyed by Stats field name or a handful of named keys consumed elsewhere:
##   "str", "dex", "int_"   → base stats
##   "ac", "ev"             → defensive
##   "mp_max"               → max MP
##   "dmg_bonus"            → flat melee damage
##   "spell_power"          → flat spell-power add
##   "regen"                → +N HP per turn while below max
##   "stealth"              → permanent stealth skill bonus
##   "fire_apt" / "cold_apt" → skill-aptitude bump for the matching school
##
## All values are integers; a missing key means zero.

const DATA: Dictionary = {
	"ring_str":          {"name": "Ring of Strength",     "str": 3,         "color": Color(0.95, 0.60, 0.30)},
	"ring_dex":          {"name": "Ring of Dexterity",    "dex": 3,         "color": Color(0.35, 0.85, 0.60)},
	"ring_int":          {"name": "Ring of Intelligence", "int_": 3,        "color": Color(0.55, 0.55, 1.00)},
	"ring_protection":   {"name": "Ring of Protection",   "ac": 2,          "color": Color(0.85, 0.85, 0.90)},
	"ring_evasion":      {"name": "Ring of Evasion",      "ev": 3,          "color": Color(0.60, 1.00, 0.60)},
	"ring_slaying":      {"name": "Ring of Slaying",      "dmg_bonus": 2,   "color": Color(1.00, 0.30, 0.20)},
	"ring_magical_power":{"name": "Ring of Magical Power","mp_max": 8,      "color": Color(0.75, 0.30, 1.00)},
	"ring_wizardry":     {"name": "Ring of Wizardry",     "spell_power": 3, "color": Color(0.40, 0.50, 1.00)},
	"ring_regeneration": {"name": "Ring of Regeneration", "regen": 1,       "color": Color(1.00, 0.55, 0.55)},
	"ring_stealth":      {"name": "Ring of Stealth",      "stealth": 3,     "color": Color(0.30, 0.30, 0.50)},
	"ring_fire":         {"name": "Ring of Fire",         "fire_apt": 1,    "dmg_bonus": 1, "color": Color(1.00, 0.40, 0.10)},
	"ring_ice":          {"name": "Ring of Ice",          "cold_apt": 1,    "ac": 1,        "color": Color(0.50, 0.85, 1.00)},
}


static func is_ring(id: String) -> bool:
	return DATA.has(id)


## Copy with id baked in, same convention as ArmorRegistry.
static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate()
	d["id"] = id
	d["slot"] = "ring"
	d["kind"] = "ring"
	return d


static func display_name_for(id: String) -> String:
	return String(DATA.get(id, {}).get("name", id.capitalize().replace("_", " ")))


static func all_ids() -> Array:
	return DATA.keys()
