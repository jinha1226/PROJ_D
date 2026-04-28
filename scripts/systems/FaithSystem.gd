class_name FaithSystem extends RefCounted

const FAITHS: Dictionary = {
	"war": {
		"name": "War",
		"short": "Strength through steel and discipline.",
		"desc": "War favors melee, defense, and steady conquest.\nIt grants stronger front-line combat and steadier survival.\nMagic grows more slowly under its banner.",
		"color": Color(0.9, 0.35, 0.3),
		"allows_essence": false,
		"melee_damage_mult": 1.10,
		"defense_effectiveness_mult": 1.20,
		"shield_block_bonus": 0.08,
		"magic_xp_mult": 0.75,
		"spell_cost_mult": 1.20,
	},
	"arcana": {
		"name": "Arcana",
		"short": "Strength through memory, power, and spellcraft.",
		"desc": "Arcana favors magic, mana, and learning.\nIt grants stronger spells and smoother magical progression.\nIt offers little comfort in close combat.",
		"color": Color(0.4, 0.6, 1.0),
		"allows_essence": false,
		"spell_damage_mult": 1.12,
		"max_mp_bonus": 4,
		"magic_xp_mult": 1.20,
		"melee_damage_mult": 0.90,
		"defense_xp_mult": 0.85,
	},
	"trickery": {
		"name": "Trickery",
		"short": "Strength through speed, deceit, and precise tools.",
		"desc": "Trickery favors agility, tools, ranged combat, and ambushes.\nIt rewards clever positioning and flexible resources.\nIt offers little help in a straight brawl.",
		"color": Color(0.4, 0.85, 0.5),
		"allows_essence": false,
		"agility_effectiveness_mult": 1.20,
		"tool_effectiveness_mult": 1.25,
		"ranged_damage_mult": 1.10,
		"wand_charge_save_chance": 0.20,
		"detect_range_mod": -1,
		"shield_block_bonus": -0.06,
	},
	"death": {
		"name": "Death",
		"short": "Strength through ruin, hunger, and the fall of others.",
		"desc": "Death favors kill-chains, draining power, and dangerous momentum.\nIt rewards aggression and turns victory into sustenance.\nOrdinary comfort and healing lose some of their safety.",
		"color": Color(0.55, 0.35, 0.85),
		"allows_essence": false,
		"on_kill_hp": 3,
		"on_kill_mp": 1,
		"necrotic_damage_mult": 1.15,
		"undead_damage_mult": 1.10,
		"will_bonus": 1,
		"potion_heal_mult": 0.80,
	},
	"essence": {
		"name": "Essence",
		"short": "Strength through stolen remnants and unstable transformation.",
		"desc": "Essence is a special path that replaces normal divine power.\nIt allows the use of essences, stronger resonance, and highly flexible builds.\nIts strength depends on what the dungeon gives you.",
		"color": Color(0.85, 0.72, 1.0),
		"allows_essence": true,
		"essence_inventory_bonus": 1,
		"resonance_mult": 1.25,
		"essence_penalty_reduction": 0.20,
		"unique_essence_drop_bonus": 0.15,
	},
}

static func get_faith(id: String) -> Dictionary:
	return FAITHS.get(id, {})

static func display_name(id: String) -> String:
	return String(get_faith(id).get("name", id))

static func color_of(id: String) -> Color:
	return get_faith(id).get("color", Color.WHITE)

static func allows_essence(player) -> bool:
	if player == null:
		return false
	# Empty faith_id = legacy save; treat as essence path so old runs still work
	return player.faith_id == "essence" or player.faith_id == ""

static func melee_damage_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("melee_damage_mult", 1.0))

static func spell_damage_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("spell_damage_mult", 1.0))

static func ranged_damage_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("ranged_damage_mult", 1.0))

static func necrotic_damage_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("necrotic_damage_mult", 1.0))

static func spell_cost_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("spell_cost_mult", 1.0))

static func potion_heal_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("potion_heal_mult", 1.0))

static func shield_block_bonus(player) -> float:
	if player == null:
		return 0.0
	return float(get_faith(player.faith_id).get("shield_block_bonus", 0.0))

static func wand_charge_save_chance(player) -> float:
	if player == null:
		return 0.0
	return float(get_faith(player.faith_id).get("wand_charge_save_chance", 0.0))

static func on_kill_hp(player) -> int:
	if player == null:
		return 0
	return int(get_faith(player.faith_id).get("on_kill_hp", 0))

static func on_kill_mp(player) -> int:
	if player == null:
		return 0
	return int(get_faith(player.faith_id).get("on_kill_mp", 0))

static func max_mp_bonus(player) -> int:
	if player == null:
		return 0
	return int(get_faith(player.faith_id).get("max_mp_bonus", 0))

static func essence_inventory_bonus(player) -> int:
	if player == null:
		return 0
	return int(get_faith(player.faith_id).get("essence_inventory_bonus", 0))

static func resonance_mult(player) -> float:
	if player == null:
		return 1.0
	return float(get_faith(player.faith_id).get("resonance_mult", 1.0))
