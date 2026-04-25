class_name EssenceSystem extends RefCounted

## Passive essence system. Essences can grant flat bonuses, recurring effects,
## or conditional passives such as on-hit / on-kill triggers.

const SLOT_COUNT: int = 3

const ESSENCES: Dictionary = {
	"essence_fire": {
		"name": "Fire Essence",
		"desc": "Fire resistance.",
		"passive_desc": "Melee attacks deal +2 fire damage.",
		"passive_effect": "melee_fire",
		"color": Color(1.0, 0.55, 0.25),
		"effect": "resist_fire",
	},
	"essence_cold": {
		"name": "Ice Essence",
		"desc": "Cold resistance.",
		"passive_desc": "Melee hits have a 30% chance to freeze for 1 turn.",
		"passive_effect": "melee_chill",
		"color": Color(0.5, 0.85, 1.0),
		"effect": "resist_cold",
	},
	"essence_might": {
		"name": "War Essence",
		"desc": "+3 Strength.",
		"passive_desc": "Flat strength bonus.",
		"passive_effect": "",
		"color": Color(1.0, 0.45, 0.3),
		"effect": "stat_str",
		"value": 3,
	},
	"essence_arcana": {
		"name": "Arcane Essence",
		"desc": "+3 Intelligence.",
		"passive_desc": "Flat intelligence bonus.",
		"passive_effect": "",
		"color": Color(0.5, 0.7, 1.0),
		"effect": "stat_int",
		"value": 3,
	},
	"essence_swiftness": {
		"name": "Swift Essence",
		"desc": "+2 Dexterity, +1 Evasion.",
		"passive_desc": "Flat agility bonus.",
		"passive_effect": "",
		"color": Color(0.4, 1.0, 0.65),
		"effect": "stat_dex",
		"value": 2,
	},
	"essence_vitality": {
		"name": "Life Essence",
		"desc": "+20 maximum HP.",
		"passive_desc": "Restore 3 HP on kill.",
		"passive_effect": "on_kill_heal",
		"color": Color(0.5, 1.0, 0.55),
		"effect": "hp_max",
		"value": 20,
	},
	"essence_stone": {
		"name": "Stone Essence",
		"desc": "+5 Armor Class.",
		"passive_desc": "Flat armor bonus.",
		"passive_effect": "",
		"color": Color(0.8, 0.8, 0.65),
		"effect": "ac_bonus",
		"value": 5,
	},
	"essence_warding": {
		"name": "Ward Essence",
		"desc": "+8 Will.",
		"passive_desc": "Flat will bonus.",
		"passive_effect": "",
		"color": Color(0.75, 0.5, 1.0),
		"effect": "wl_bonus",
		"value": 8,
	},
	"essence_regeneration": {
		"name": "Regen Essence",
		"desc": "Recover 1 HP per turn.",
		"passive_desc": "Regenerate 1 HP each turn.",
		"passive_effect": "regen",
		"color": Color(0.6, 1.0, 0.7),
		"effect": "regen",
	},
	"essence_venom": {
		"name": "Venom Essence",
		"desc": "Melee attacks poison enemies.",
		"passive_desc": "Melee attacks inflict poison for 3 turns.",
		"passive_effect": "venom_touch",
		"color": Color(0.45, 1.0, 0.4),
		"effect": "venom_touch",
	},
	"essence_fury": {
		"name": "Fury Essence",
		"desc": "On kill, your next melee hit deals +4 damage.",
		"passive_desc": "On kill, gain a brief melee damage boost.",
		"passive_effect": "on_kill_fury",
		"color": Color(1.0, 0.3, 0.2),
		"effect": "fury",
	},
	"essence_drain": {
		"name": "Drain Essence",
		"desc": "On kill, absorb 5 HP.",
		"passive_desc": "On kill, heal for 5 HP.",
		"passive_effect": "on_kill_drain",
		"color": Color(0.7, 0.3, 1.0),
		"effect": "drain",
	},
}

static func all_ids() -> Array:
	return ESSENCES.keys()

static func display_name(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("name", id))

static func description(id: String) -> String:
	var info: Dictionary = ESSENCES.get(id, {})
	var base: String = String(info.get("desc", ""))
	var extra: String = String(info.get("passive_desc", ""))
	if extra == "":
		return base
	if base == "":
		return extra
	return "%s %s" % [base, extra]

static func color_of(id: String) -> Color:
	return ESSENCES.get(id, {}).get("color", Color(0.8, 0.8, 0.85))

static func random_id() -> String:
	var keys: Array = ESSENCES.keys()
	return keys[randi() % keys.size()]

static func apply(player: Player, essence_id: String) -> void:
	var info: Dictionary = ESSENCES.get(essence_id, {})
	var effect: String = String(info.get("effect", ""))
	var value: int = int(info.get("value", 0))
	match effect:
		"resist_fire":
			if not player.resists.has("fire+"):
				player.resists.append("fire+")
		"resist_cold":
			if not player.resists.has("cold+"):
				player.resists.append("cold+")
		"stat_str":
			player.strength += value
		"stat_int":
			player.intelligence += value
		"stat_dex":
			player.dexterity += value
			player.ev += 1
		"hp_max":
			player.hp_max += value
			player.hp = mini(player.hp + value, player.hp_max)
		"ac_bonus":
			player.ac += value
		"wl_bonus":
			player.wl += value
		"fury", "drain", "regen", "venom_touch":
			pass
	player.emit_signal("stats_changed")

static func remove(player: Player, essence_id: String) -> void:
	var info: Dictionary = ESSENCES.get(essence_id, {})
	var effect: String = String(info.get("effect", ""))
	var value: int = int(info.get("value", 0))
	match effect:
		"resist_fire":
			player.resists.erase("fire+")
		"resist_cold":
			player.resists.erase("cold+")
		"stat_str":
			player.strength = maxi(1, player.strength - value)
		"stat_int":
			player.intelligence = maxi(1, player.intelligence - value)
		"stat_dex":
			player.dexterity = maxi(1, player.dexterity - value)
			player.ev = maxi(0, player.ev - 1)
		"hp_max":
			player.hp_max = maxi(1, player.hp_max - value)
			player.hp = mini(player.hp, player.hp_max)
		"ac_bonus":
			player.ac = maxi(0, player.ac - value)
		"wl_bonus":
			player.wl = maxi(0, player.wl - value)
		"fury", "drain", "regen", "venom_touch":
			pass
	player.emit_signal("stats_changed")

static func tick(player: Player) -> void:
	for slot in player.essence_slots:
		if slot == "essence_regeneration" and player.hp < player.hp_max:
			player.heal(1)

static func has_venom_touch(player: Player) -> bool:
	return player.essence_slots.has("essence_venom")

static func passive_desc(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("passive_desc", ""))

static func passive_effect(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("passive_effect", ""))

static func apply_melee_hit_effects(player: Player, monster: Monster) -> void:
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "melee_fire":
			var dmg: int = Status.resist_scale(2, monster.data.resists, "fire")
			if dmg > 0:
				monster.take_damage(dmg)
		elif effect_id == "melee_chill":
			if randf() < 0.3:
				Status.apply(monster, "frozen", 1)

static func apply_on_kill_effects(player: Player) -> void:
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "on_kill_heal":
			player.heal(3)
		elif effect_id == "on_kill_fury":
			Status.apply(player, "damage_boost", 1)
		elif effect_id == "on_kill_drain":
			player.heal(5)
