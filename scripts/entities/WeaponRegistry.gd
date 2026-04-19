class_name WeaponRegistry
extends RefCounted
## Static weapon catalog for M1. Maps weapon id → damage / skill / delay.
## Skill mapping is also surfaced on SkillSystem.WEAPON_SKILL; this class keeps
## numeric combat data.

# Damage / delay calibrated to DCSS base values so combat pacing
# roughly matches the source game. dmg = max roll of the weapon die.
const DATA: Dictionary = {
	# Axes
	"axe":        {"dmg": 7,  "skill": "melee", "delay": 1.3},
	"axe_medium": {"dmg": 11, "skill": "melee", "delay": 1.5},
	"waraxe":     {"dmg": 11, "skill": "melee", "delay": 1.5},
	# Maces / clubs / flails
	"club":  {"dmg": 5,  "skill": "melee", "delay": 1.3},
	"mace":  {"dmg": 9,  "skill": "melee", "delay": 1.4},
	"flail": {"dmg": 11, "skill": "melee", "delay": 1.4},
	# Short blades
	"dagger":      {"dmg": 4, "skill": "melee", "delay": 1.0},
	"short_sword": {"dmg": 6, "skill": "melee", "delay": 1.1},
	"rapier":      {"dmg": 7, "skill": "melee", "delay": 1.2},
	"saber":       {"dmg": 7, "skill": "melee", "delay": 1.2},
	# Long blades
	"arming_sword": {"dmg": 7,  "skill": "melee", "delay": 1.3},
	"longsword":    {"dmg": 10, "skill": "melee", "delay": 1.4},
	"katana":       {"dmg": 10, "skill": "melee", "delay": 1.4},
	"scimitar":     {"dmg": 11, "skill": "melee", "delay": 1.5},
	"greatsword":   {"dmg": 17, "skill": "melee", "delay": 1.7},
	# Polearms
	"spear":     {"dmg": 7,  "skill": "melee", "delay": 1.2},
	"longspear": {"dmg": 9,  "skill": "melee", "delay": 1.3},
	"trident":   {"dmg": 9,  "skill": "melee", "delay": 1.3},
	"halberd":   {"dmg": 13, "skill": "melee", "delay": 1.5},
	"scythe":    {"dmg": 14, "skill": "melee", "delay": 1.8},
	# Ranged
	"short_bow": {"dmg": 9,  "skill": "ranged", "delay": 1.3},
	"long_bow":  {"dmg": 15, "skill": "ranged", "delay": 1.6},
	"bow":       {"dmg": 9,  "skill": "ranged", "delay": 1.3},
	"crossbow":  {"dmg": 18, "skill": "ranged", "delay": 1.9},
	"slingshot": {"dmg": 5,  "skill": "ranged", "delay": 1.1},
	"boomerang":    {"dmg": 5,  "skill": "ranged", "delay": 1.0},
	"throwing_axe": {"dmg": 8,  "skill": "ranged", "delay": 1.1},
	# Staves (melee + spell bonus)
	"gnarled_staff":   {"dmg": 10, "skill": "melee", "delay": 1.3, "spell_bonus": 2},
	"fire_staff":      {"dmg": 8,  "skill": "melee", "delay": 1.3, "spell_bonus": 3},
	"ice_staff":       {"dmg": 8,  "skill": "melee", "delay": 1.3, "spell_bonus": 3},
	"lightning_staff": {"dmg": 8,  "skill": "melee", "delay": 1.3, "spell_bonus": 3},
	"crystal_staff":   {"dmg": 8,  "skill": "melee", "delay": 1.3, "spell_bonus": 3},
	# Evocables
	"wand_simple": {"dmg": 3, "skill": "evocations", "delay": 1.0},
}


static func is_weapon(id: String) -> bool:
	return DATA.has(id)


static func weapon_damage_for(id: String) -> int:
	if id == "" or not DATA.has(id):
		return 0
	return int(DATA[id].get("dmg", 0))


static func weapon_skill_for(id: String) -> String:
	if id == "" or not DATA.has(id):
		return ""
	return String(DATA[id].get("skill", ""))


static func weapon_delay_for(id: String) -> float:
	if id == "" or not DATA.has(id):
		return 1.0
	return float(DATA[id].get("delay", 1.0))


static func all_weapon_ids() -> Array:
	return DATA.keys()


## Human-readable name. Falls back to id.capitalize() if missing.
const DISPLAY_NAMES: Dictionary = {
	"axe":        "Axe",
	"axe_medium": "Battle Axe",
	"waraxe":     "War Axe",
	"club":       "Club",
	"mace":       "Mace",
	"flail":      "Flail",
	"dagger":     "Dagger",
	"short_sword":"Short Sword",
	"rapier":     "Rapier",
	"saber":      "Saber",
	"arming_sword": "Arming Sword",
	"longsword":  "Longsword",
	"katana":     "Katana",
	"scimitar":   "Scimitar",
	"greatsword": "Greatsword",
	"spear":      "Spear",
	"longspear":  "Longspear",
	"halberd":    "Halberd",
	"scythe":     "Scythe",
	"trident":    "Trident",
	"short_bow":  "Short Bow",
	"long_bow":   "Long Bow",
	"bow":        "Bow",
	"crossbow":   "Crossbow",
	"slingshot":  "Slingshot",
	"boomerang":    "Boomerang",
	"throwing_axe": "Throwing Axe",
	"fire_staff": "Fire Staff",
	"ice_staff":  "Ice Staff",
	"lightning_staff": "Lightning Staff",
	"gnarled_staff":   "Gnarled Staff",
	"crystal_staff":   "Crystal Staff",
	"wand_simple":     "Simple Wand",
}


static func display_name_for(id: String) -> String:
	return DISPLAY_NAMES.get(id, id.capitalize().replace("_", " "))


static func staff_spell_bonus(weapon_id: String) -> int:
	var info: Dictionary = DATA.get(weapon_id, {})
	return int(info.get("spell_bonus", 0))
