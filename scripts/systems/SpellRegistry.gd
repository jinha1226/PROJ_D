class_name SpellRegistry
extends Object

const SPELLS: Dictionary = {
	"magic_dart": {
		"name": "Magic Dart", "school": "conjurations",
		"mp": 1, "min_dmg": 1, "max_dmg": 3, "difficulty": 1,
		"targeting": "single", "range": 9, "effect": "damage",
		"color": Color(0.75, 0.75, 1.0),
		"desc": "A conjured dart. Never misses.",
	},
	"flame_tongue": {
		"name": "Flame Tongue", "school": "fire",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 5, "effect": "damage",
		"color": Color(1.0, 0.4, 0.0),
		"desc": "A short-range gout of flame.",
	},
	"fireball": {
		"name": "Fireball", "school": "fire",
		"mp": 6, "min_dmg": 3, "max_dmg": 30, "difficulty": 5,
		"targeting": "area", "range": 5, "radius": 2, "effect": "damage",
		"color": Color(1.0, 0.6, 0.0),
		"desc": "Explosive fire. Lv5, high power + high failure.",
	},
	"freeze": {
		"name": "Freeze", "school": "cold",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.5, 0.85, 1.0),
		"desc": "Crystallises moisture around the target.",
	},
	"stone_arrow": {
		"name": "Stone Arrow", "school": "earth",
		"mp": 3, "min_dmg": 3, "max_dmg": 21, "difficulty": 3,
		"targeting": "single", "range": 4, "effect": "damage",
		"color": Color(0.75, 0.65, 0.45),
		"desc": "A sharp shard of stone. Lv3, physical damage.",
	},
	"lightning_bolt": {
		"name": "Lightning Bolt", "school": "air",
		"mp": 5, "min_dmg": 1, "max_dmg": 33, "difficulty": 5,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(1.0, 1.0, 0.4),
		"desc": "A bolt of lightning. Lv5, ignores half AC.",
	},
	"pain": {
		"name": "Pain", "school": "necromancy",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.55, 0.0, 0.75),
		"desc": "Channels death-energy into raw agony.",
	},
	"slow": {
		"name": "Slow", "school": "hexes",
		"mp": 2, "min_dmg": 0, "max_dmg": 0, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "slow",
		"color": Color(0.4, 0.9, 0.5),
		"desc": "Halves target speed for 4 turns.",
	},
	"blink": {
		"name": "Blink", "school": "translocations",
		"mp": 2, "min_dmg": 0, "max_dmg": 0, "difficulty": 2,
		"targeting": "self", "range": 0, "effect": "teleport",
		"color": Color(0.8, 0.55, 1.0),
		"desc": "Randomly teleports you a short distance.",
	},
	# --- Lv1 multi-school ---
	"shock": {
		"name": "Shock", "school": "air", "school2": "conjurations",
		"mp": 1, "min_dmg": 1, "max_dmg": 4, "difficulty": 1,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(0.9, 0.95, 1.0),
		"desc": "A jolt of electricity. Pierces armor slightly.",
	},
	# --- Lv2 ---
	"scorch": {
		"name": "Scorch", "school": "fire", "school2": "conjurations",
		"mp": 2, "min_dmg": 2, "max_dmg": 8, "difficulty": 2,
		"targeting": "single", "range": 5, "effect": "damage",
		"color": Color(1.0, 0.5, 0.1),
		"desc": "Intense heat that weakens fire resistance.",
	},
	"static_discharge": {
		"name": "Static Discharge", "school": "air", "school2": "conjurations",
		"mp": 2, "min_dmg": 1, "max_dmg": 6, "difficulty": 2,
		"targeting": "area", "range": 0, "radius": 1, "effect": "damage",
		"color": Color(0.8, 0.9, 1.0),
		"desc": "Electric burst hitting all adjacent enemies.",
	},
	# --- Lv3 ---
	"vampiric_drain": {
		"name": "Vampiric Draining", "school": "necromancy",
		"mp": 3, "min_dmg": 2, "max_dmg": 10, "difficulty": 3,
		"targeting": "single", "range": 1, "effect": "vampiric",
		"color": Color(0.7, 0.0, 0.2),
		"desc": "Drain life from adjacent target. Heals you for damage dealt.",
	},
	"hailstorm": {
		"name": "Hailstorm", "school": "cold", "school2": "conjurations",
		"mp": 4, "min_dmg": 3, "max_dmg": 15, "difficulty": 3,
		"targeting": "area", "range": 6, "radius": 2, "effect": "damage",
		"color": Color(0.6, 0.85, 1.0),
		"desc": "A ring of ice shards around the target.",
	},
	"confuse": {
		"name": "Confuse", "school": "hexes",
		"mp": 3, "min_dmg": 0, "max_dmg": 0, "difficulty": 3,
		"targeting": "single", "range": 6, "effect": "confuse",
		"color": Color(0.9, 0.5, 0.9),
		"desc": "Target moves randomly for 4 turns.",
	},
	"dazzling_flash": {
		"name": "Dazzling Flash", "school": "conjurations", "school2": "hexes",
		"mp": 3, "min_dmg": 1, "max_dmg": 5, "difficulty": 3,
		"targeting": "area", "range": 0, "radius": 2, "effect": "damage",
		"color": Color(1.0, 1.0, 0.8),
		"desc": "Blinding flash hitting nearby enemies.",
	},
	# --- Lv4 ---
	"sticky_flame": {
		"name": "Sticky Flame", "school": "fire", "school2": "conjurations",
		"mp": 4, "min_dmg": 2, "max_dmg": 8, "difficulty": 4,
		"targeting": "single", "range": 5, "effect": "dot_fire",
		"color": Color(1.0, 0.7, 0.0),
		"desc": "Burning gel. Deals fire damage over 4 turns.",
	},
	"airstrike": {
		"name": "Airstrike", "school": "air", "school2": "conjurations",
		"mp": 4, "min_dmg": 3, "max_dmg": 20, "difficulty": 4,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.7, 0.85, 1.0),
		"desc": "Smash with compressed air. Ignores armor.",
	},
	"petrify": {
		"name": "Petrify", "school": "hexes", "school2": "earth",
		"mp": 4, "min_dmg": 0, "max_dmg": 0, "difficulty": 4,
		"targeting": "single", "range": 5, "effect": "petrify",
		"color": Color(0.6, 0.55, 0.45),
		"desc": "Gradually turns target to stone. Immobilized 5 turns.",
	},
	"passage": {
		"name": "Passage of Golubria", "school": "translocations",
		"mp": 4, "min_dmg": 0, "max_dmg": 0, "difficulty": 4,
		"targeting": "self", "range": 0, "effect": "teleport",
		"color": Color(0.7, 0.4, 1.0),
		"desc": "Controlled blink to a specific explored tile.",
	},
	# --- Lv5 ---
	"agony": {
		"name": "Agony", "school": "necromancy", "school2": "hexes",
		"mp": 5, "min_dmg": 0, "max_dmg": 0, "difficulty": 5,
		"targeting": "single", "range": 1, "effect": "agony",
		"color": Color(0.4, 0.0, 0.5),
		"desc": "Halves the target's current HP. Melee range.",
	},
	"metabolic_englaciation": {
		"name": "Metabolic Englaciation", "school": "cold", "school2": "hexes",
		"mp": 5, "min_dmg": 0, "max_dmg": 0, "difficulty": 5,
		"targeting": "area", "range": 0, "radius": 4, "effect": "slow",
		"color": Color(0.5, 0.7, 1.0),
		"desc": "Slows all visible enemies for 4 turns.",
	},
	# --- Lv6 ---
	"iron_shot": {
		"name": "Iron Shot", "school": "conjurations", "school2": "earth",
		"mp": 6, "min_dmg": 5, "max_dmg": 40, "difficulty": 6,
		"targeting": "single", "range": 3, "effect": "damage",
		"color": Color(0.5, 0.5, 0.55),
		"desc": "Massive iron projectile. Short range, huge damage.",
	},
	"chain_lightning": {
		"name": "Chain Lightning", "school": "air", "school2": "conjurations",
		"mp": 8, "min_dmg": 3, "max_dmg": 35, "difficulty": 7,
		"targeting": "area", "range": 8, "radius": 3, "effect": "damage",
		"color": Color(1.0, 1.0, 0.5),
		"desc": "Lightning arcing between all visible enemies.",
	},
	# --- Lv7 ---
	"orb_of_destruction": {
		"name": "Orb of Destruction", "school": "conjurations",
		"mp": 7, "min_dmg": 8, "max_dmg": 50, "difficulty": 7,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(0.9, 0.3, 1.0),
		"desc": "A devastating orb of pure magical energy.",
	},
	"fire_storm": {
		"name": "Fire Storm", "school": "fire", "school2": "conjurations",
		"mp": 9, "min_dmg": 5, "max_dmg": 55, "difficulty": 8,
		"targeting": "area", "range": 6, "radius": 3, "effect": "damage",
		"color": Color(1.0, 0.3, 0.0),
		"desc": "Apocalyptic firestorm. Massive area, massive damage.",
	},
}

const SCHOOL_SPELLS: Dictionary = {
	"conjurations": [
		{"id": "magic_dart", "min_level": 1},
		{"id": "dazzling_flash", "min_level": 3},
		{"id": "orb_of_destruction", "min_level": 7},
	],
	"fire": [
		{"id": "flame_tongue", "min_level": 1},
		{"id": "scorch", "min_level": 2},
		{"id": "sticky_flame", "min_level": 4},
		{"id": "fireball", "min_level": 5},
		{"id": "fire_storm", "min_level": 8},
	],
	"cold": [
		{"id": "freeze", "min_level": 1},
		{"id": "hailstorm", "min_level": 3},
		{"id": "metabolic_englaciation", "min_level": 5},
	],
	"earth": [
		{"id": "stone_arrow", "min_level": 3},
		{"id": "iron_shot", "min_level": 6},
	],
	"air": [
		{"id": "shock", "min_level": 1},
		{"id": "static_discharge", "min_level": 2},
		{"id": "airstrike", "min_level": 4},
		{"id": "lightning_bolt", "min_level": 5},
		{"id": "chain_lightning", "min_level": 7},
	],
	"necromancy": [
		{"id": "pain", "min_level": 1},
		{"id": "vampiric_drain", "min_level": 3},
		{"id": "agony", "min_level": 5},
	],
	"hexes": [
		{"id": "slow", "min_level": 1},
		{"id": "confuse", "min_level": 3},
		{"id": "petrify", "min_level": 4},
	],
	"translocations": [
		{"id": "blink", "min_level": 2},
		{"id": "passage", "min_level": 4},
	],
}


static func get_spell(id: String) -> Dictionary:
	return SPELLS.get(id, {})


static func get_known_for_player(player: Node, skill_sys: Node) -> Array[String]:
	var known: Array[String] = []
	if player == null:
		return known
	if "learned_spells" in player:
		for sid in player.learned_spells:
			var sp: String = String(sid)
			if sp != "" and not known.has(sp):
				known.append(sp)
		return known
	if skill_sys == null:
		return known
	for school in SCHOOL_SPELLS:
		var level: int = skill_sys.get_level(player, school)
		if level <= 0:
			continue
		for entry in SCHOOL_SPELLS[school]:
			var sid2: String = String(entry.get("id", ""))
			var min_lv: int = int(entry.get("min_level", 1))
			if level >= min_lv and not known.has(sid2):
				known.append(sid2)
	return known


static func failure_chance(spell_id: String, school_level: int, spellcasting_level: int, school2_level: int = -1) -> float:
	var info: Dictionary = SPELLS.get(spell_id, {})
	var diff: int = int(info.get("difficulty", 1))
	var eff_school: int = school_level
	if school2_level >= 0:
		eff_school = min(school_level, school2_level)
	var effective: float = float(eff_school) + float(spellcasting_level) * 0.5
	var gap: float = effective - float(diff)
	if gap >= 10:
		return 0.0
	if gap >= 7:
		return 0.05
	if gap >= 4:
		return 0.15
	if gap >= 2:
		return 0.3
	if gap >= 0:
		return 0.5
	if gap >= -2:
		return 0.75
	if gap >= -4:
		return 0.9
	return 0.99
