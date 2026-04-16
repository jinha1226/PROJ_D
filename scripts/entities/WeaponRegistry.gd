class_name WeaponRegistry
extends RefCounted
## Static weapon catalog for M1. Maps weapon id → damage / skill / delay.
## Skill mapping is also surfaced on SkillSystem.WEAPON_SKILL; this class keeps
## numeric combat data.

const DATA: Dictionary = {
	# Axes
	"axe": {"dmg": 9, "skill": "axe", "delay": 1.0},
	"axe_medium": {"dmg": 9, "skill": "axe", "delay": 1.0},
	"waraxe": {"dmg": 10, "skill": "axe", "delay": 1.1},
	# Maces / clubs / flails
	"club": {"dmg": 5, "skill": "mace", "delay": 0.9},
	"mace": {"dmg": 8, "skill": "mace", "delay": 1.0},
	"flail": {"dmg": 9, "skill": "mace", "delay": 1.1},
	# Short blades
	"dagger": {"dmg": 5, "skill": "short_blade", "delay": 0.8},
	"short_sword": {"dmg": 6, "skill": "short_blade", "delay": 0.9},
	"rapier": {"dmg": 7, "skill": "short_blade", "delay": 0.9},
	"saber": {"dmg": 7, "skill": "short_blade", "delay": 0.9},
	# Long blades
	"arming_sword": {"dmg": 8, "skill": "long_blade", "delay": 1.0},
	"longsword": {"dmg": 8, "skill": "long_blade", "delay": 1.0},
	"katana": {"dmg": 9, "skill": "long_blade", "delay": 1.0},
	"scimitar": {"dmg": 8, "skill": "long_blade", "delay": 1.0},
	"greatsword": {"dmg": 12, "skill": "long_blade", "delay": 1.3},
	# Polearms
	"spear": {"dmg": 7, "skill": "polearm", "delay": 1.0},
	"longspear": {"dmg": 9, "skill": "polearm", "delay": 1.1},
	"halberd": {"dmg": 11, "skill": "polearm", "delay": 1.2},
	"scythe": {"dmg": 10, "skill": "polearm", "delay": 1.2},
	"trident": {"dmg": 9, "skill": "polearm", "delay": 1.1},
	# Ranged
	"short_bow": {"dmg": 6, "skill": "bow", "delay": 1.0},
	"long_bow": {"dmg": 9, "skill": "bow", "delay": 1.2},
	"bow": {"dmg": 7, "skill": "bow", "delay": 1.0},
	"crossbow": {"dmg": 10, "skill": "crossbow", "delay": 1.3},
	"slingshot": {"dmg": 4, "skill": "sling", "delay": 0.9},
	"boomerang": {"dmg": 5, "skill": "throwing", "delay": 1.0},
	# Staves
	"fire_staff": {"dmg": 6, "skill": "staff", "delay": 1.1},
	"ice_staff": {"dmg": 6, "skill": "staff", "delay": 1.1},
	"lightning_staff": {"dmg": 6, "skill": "staff", "delay": 1.1},
	"gnarled_staff": {"dmg": 7, "skill": "staff", "delay": 1.1},
	"crystal_staff": {"dmg": 7, "skill": "staff", "delay": 1.1},
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
