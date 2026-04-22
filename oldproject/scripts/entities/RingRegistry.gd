class_name RingRegistry
extends RefCounted
## Ring catalog. Each entry may carry:
##   str / dex / int_           → base stat bonus
##   ac / ev                    → defensive bonus
##   mp_max                     → max MP bonus
##   dmg_bonus                  → flat melee damage
##   spell_power                → flat spell-power add
##   regen                      → +N HP per turn
##   stealth                    → permanent stealth bonus
##   fire_apt / cold_apt        → school aptitude bump
##   resists: {element: level}  → folded into Player.get_resist()
##   flags: [flag_name]         → metas set as "_ring_<flag>" on equip
##
## All numeric values are integers; missing key = zero / empty.

const DATA: Dictionary = {
	# --- Single-stat classics ---
	"ring_str":          {"name": "Ring of Strength",        "str": 3,
						  "color": Color(0.95, 0.60, 0.30)},
	"ring_dex":          {"name": "Ring of Dexterity",       "dex": 3,
						  "color": Color(0.35, 0.85, 0.60)},
	"ring_int":          {"name": "Ring of Intelligence",    "int_": 3,
						  "color": Color(0.55, 0.55, 1.00)},
	"ring_protection":   {"name": "Ring of Protection",      "ac": 3,
						  "color": Color(0.85, 0.85, 0.90)},
	"ring_evasion":      {"name": "Ring of Evasion",         "ev": 3,
						  "color": Color(0.60, 1.00, 0.60)},
	"ring_magical_power":{"name": "Ring of Magical Power",   "mp_max": 9,
						  "color": Color(0.75, 0.30, 1.00)},
	"ring_regeneration": {"name": "Ring of Regeneration",    "regen": 1,
						  "color": Color(1.00, 0.55, 0.55)},
	"ring_stealth":      {"name": "Ring of Stealth",         "stealth": 3,
						  "color": Color(0.30, 0.30, 0.50)},
	# --- Multi-stat ---
	"ring_slaying":      {"name": "Ring of Slaying",         "dmg_bonus": 3, "str": 1,
						  "color": Color(1.00, 0.30, 0.20)},
	"ring_wizardry":     {"name": "Ring of Wizardry",        "spell_power": 4, "int_": 1,
						  "color": Color(0.40, 0.50, 1.00)},
	"ring_fire":         {"name": "Ring of Fire",            "fire_apt": 1, "dmg_bonus": 1,
						  "resists": {"fire": 1},
						  "color": Color(1.00, 0.40, 0.10)},
	"ring_ice":          {"name": "Ring of Ice",             "cold_apt": 1, "ac": 1,
						  "resists": {"cold": 1},
						  "color": Color(0.50, 0.85, 1.00)},
	"ring_the_mage":     {"name": "Ring of the Mage",        "int_": 3, "spell_power": 3,
						  "color": Color(0.65, 0.55, 1.00)},
	"ring_sustenance":   {"name": "Ring of Sustenance",      "regen": 1, "stealth": 1,
						  "color": Color(0.70, 0.90, 0.55)},
	# --- Resist rings ---
	"ring_life_protection": {"name": "Ring of Life Protection",
							 "resists": {"neg": 1},
							 "color": Color(0.55, 0.80, 0.55)},
	"ring_poison_resistance": {"name": "Ring of Poison Resistance",
							   "resists": {"poison": 1},
							   "color": Color(0.60, 0.85, 0.35)},
	"ring_lightning":    {"name": "Ring of Lightning",       "resists": {"elec": 1}, "ev": 1,
						  "color": Color(0.90, 0.95, 0.35)},
	# --- Flag rings ---
	"ring_see_invisible":{"name": "Ring of See Invisible",   "flags": ["see_invis"],
						  "color": Color(0.85, 0.95, 1.00)},
	"ring_flight":       {"name": "Ring of Flight",          "flags": ["flying"],
						  "color": Color(0.75, 0.85, 1.00)},
}


static func is_ring(id: String) -> bool:
	return DATA.has(id)


## Copy with id + slot/kind baked in.
static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate(true)
	d["id"]   = id
	d["slot"] = "ring"
	d["kind"] = "ring"
	return d


static func display_name_for(id: String) -> String:
	return String(DATA.get(id, {}).get("name", id.capitalize().replace("_", " ")))


static func all_ids() -> Array:
	return DATA.keys()
