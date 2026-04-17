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
		"mp": 6, "min_dmg": 4, "max_dmg": 10, "difficulty": 5,
		"targeting": "area", "range": 8, "radius": 2, "effect": "damage",
		"color": Color(1.0, 0.6, 0.0),
		"desc": "Explosive fire damage in an area. High difficulty.",
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
		"mp": 3, "min_dmg": 3, "max_dmg": 7, "difficulty": 2,
		"targeting": "single", "range": 7, "effect": "damage",
		"color": Color(0.75, 0.65, 0.45),
		"desc": "A sharp shard of conjured stone.",
	},
	"lightning_bolt": {
		"name": "Lightning Bolt", "school": "air",
		"mp": 3, "min_dmg": 3, "max_dmg": 7, "difficulty": 2,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(1.0, 1.0, 0.4),
		"desc": "An arc of electricity to the target.",
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
		"mp": 3, "min_dmg": 0, "max_dmg": 0, "difficulty": 2,
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
}

const SCHOOL_SPELLS: Dictionary = {
	"conjurations": [{"id": "magic_dart", "min_level": 1}],
	"fire":         [{"id": "flame_tongue", "min_level": 1},
	                 {"id": "fireball", "min_level": 5}],
	"cold":         [{"id": "freeze", "min_level": 1}],
	"earth":        [{"id": "stone_arrow", "min_level": 2}],
	"air":          [{"id": "lightning_bolt", "min_level": 2}],
	"necromancy":   [{"id": "pain", "min_level": 1}],
	"hexes":        [{"id": "slow", "min_level": 2}],
	"translocations":[{"id": "blink", "min_level": 2}],
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


static func failure_chance(spell_id: String, school_level: int, spellcasting_level: int) -> float:
	var info: Dictionary = SPELLS.get(spell_id, {})
	var diff: int = int(info.get("difficulty", 1))
	var effective: int = school_level + spellcasting_level / 2
	if effective >= diff * 3:
		return 0.0
	if effective >= diff * 2:
		return 0.1
	if effective >= diff:
		return 0.25
	if effective >= 1:
		return 0.5
	return 0.75
