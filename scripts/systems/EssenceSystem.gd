class_name EssenceSystem extends RefCounted

## Essence progression system.
## Each essence grants a strong identity, a conditional passive,
## and a drawback. Some pairings also unlock resonance bonuses.

static var TurnManager = Engine.get_main_loop().root.get_node_or_null("/root/TurnManager") if Engine.get_main_loop() is SceneTree else null

const SLOT_COUNT: int = 3
const SLOT_UNLOCK_LEVELS: Array = [1, 8, 16]
const INVENTORY_CAP: int = 4
const ESSENCE_ICON_DIR := "res://assets/tiles/individual/item/essence/"
const ESSENCE_TIER_BY_ID := {
	"essence_fire": "normal",
	"essence_cold": "normal",
	"essence_swiftness": "normal",
	"essence_vitality": "normal",
	"essence_regeneration": "normal",
	"essence_venom": "normal",
	"essence_might": "rare",
	"essence_stone": "rare",
	"essence_warding": "rare",
	"essence_arcana": "unique",
	"essence_fury": "unique",
	"essence_drain": "unique",
}

const ESSENCES: Dictionary = {
	"essence_fire": {
		"name": "Fire Essence",
		"desc": "Fire resistance.",
		"passive_desc": "Melee attacks deal +3 fire damage and may ignite enemies.",
		"penalty_desc": "Cold vulnerable.",
		"passive_effect": "melee_fire",
		"color": Color(1.0, 0.55, 0.25),
		"effect": "resist_fire",
		"penalty_effect": "vuln_cold",
	},
	"essence_cold": {
		"name": "Ice Essence",
		"desc": "Cold resistance.",
		"passive_desc": "Melee hits have a 40% chance to freeze for 1 turn.",
		"penalty_desc": "Fire vulnerable.",
		"passive_effect": "melee_chill",
		"color": Color(0.5, 0.85, 1.0),
		"effect": "resist_cold",
		"penalty_effect": "vuln_fire",
	},
	"essence_might": {
		"name": "War Essence",
		"desc": "+2 Strength.",
		"passive_desc": "Greater kill momentum in direct combat.",
		"penalty_desc": "-1 Intelligence.",
		"passive_effect": "",
		"color": Color(1.0, 0.45, 0.3),
		"effect": "stat_str",
		"value": 2,
		"penalty_effect": "int_down",
		"penalty_value": 1,
	},
	"essence_arcana": {
		"name": "Arcane Essence",
		"desc": "+2 Intelligence.",
		"passive_desc": "-2 INT requirement for spell study.",
		"penalty_desc": "-4 maximum HP.",
		"passive_effect": "",
		"color": Color(0.5, 0.7, 1.0),
		"effect": "stat_int",
		"value": 2,
		"penalty_effect": "hp_down",
		"penalty_value": 4,
	},
	"essence_swiftness": {
		"name": "Swift Essence",
		"desc": "+1 Dexterity.",
		"passive_desc": "+1 EV and harder enemy detection.",
		"penalty_desc": "-1 Armor Class.",
		"passive_effect": "",
		"color": Color(0.4, 1.0, 0.65),
		"effect": "stat_dex",
		"value": 1,
		"penalty_effect": "ac_down",
		"penalty_value": 1,
	},
	"essence_vitality": {
		"name": "Life Essence",
		"desc": "+8 maximum HP.",
		"passive_desc": "Restore 3 HP on kill.",
		"penalty_desc": "-1 Evasion.",
		"passive_effect": "on_kill_heal",
		"color": Color(0.5, 1.0, 0.55),
		"effect": "hp_max",
		"value": 8,
		"penalty_effect": "ev_down",
		"penalty_value": 1,
	},
	"essence_stone": {
		"name": "Stone Essence",
		"desc": "+2 Armor Class.",
		"passive_desc": "Reduce incoming damage by 1.",
		"penalty_desc": "-1 Dexterity.",
		"passive_effect": "",
		"color": Color(0.8, 0.8, 0.65),
		"effect": "ac_bonus",
		"value": 2,
		"penalty_effect": "dex_down",
		"penalty_value": 1,
	},
	"essence_warding": {
		"name": "Ward Essence",
		"desc": "+5 Will.",
		"passive_desc": "Reduce incoming damage by 1.",
		"penalty_desc": "-1 maximum MP.",
		"passive_effect": "",
		"color": Color(0.75, 0.5, 1.0),
		"effect": "wl_bonus",
		"value": 5,
		"penalty_effect": "mp_down",
		"penalty_value": 1,
	},
	"essence_regeneration": {
		"name": "Regen Essence",
		"desc": "Recover 1 HP every 2 turns.",
		"passive_desc": "Reliable regeneration over time.",
		"penalty_desc": "Fire vulnerable.",
		"passive_effect": "regen",
		"color": Color(0.6, 1.0, 0.7),
		"effect": "regen",
		"penalty_effect": "vuln_fire",
	},
	"essence_venom": {
		"name": "Venom Essence",
		"desc": "Melee attacks poison enemies.",
		"passive_desc": "Adds a venom sting on hit.",
		"penalty_desc": "-2 Will.",
		"passive_effect": "venom_touch",
		"color": Color(0.45, 1.0, 0.4),
		"effect": "venom_touch",
		"penalty_effect": "wl_down",
		"penalty_value": 2,
	},
	"essence_fury": {
		"name": "Fury Essence",
		"desc": "On kill, your next strikes surge with power.",
		"passive_desc": "Gain a 2-turn melee damage boost on kill.",
		"penalty_desc": "-1 Armor Class.",
		"passive_effect": "on_kill_fury",
		"color": Color(1.0, 0.3, 0.2),
		"effect": "fury",
		"penalty_effect": "ac_down",
		"penalty_value": 1,
	},
	"essence_drain": {
		"name": "Drain Essence",
		"desc": "On kill, absorb life and recover slightly.",
		"passive_desc": "Heal 4 HP and clear 1 injury on kill.",
		"penalty_desc": "-2 maximum HP.",
		"passive_effect": "on_kill_drain",
		"color": Color(0.7, 0.3, 1.0),
		"effect": "drain",
		"penalty_effect": "hp_down",
		"penalty_value": 2,
	},
}

static func all_ids() -> Array:
	return ESSENCES.keys()

static func active_slot_count(player: Player) -> int:
	if player == null:
		return 1
	var count: int = 0
	for needed_xl in SLOT_UNLOCK_LEVELS:
		if player.xl >= int(needed_xl):
			count += 1
	return clampi(count, 1, SLOT_COUNT)

static func slot_is_unlocked(player: Player, slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < active_slot_count(player)

static func inventory_capacity(_player: Player) -> int:
	return INVENTORY_CAP

static func inventory_is_full(player: Player) -> bool:
	return player != null and player.essence_inventory.size() >= inventory_capacity(player)

static func display_name(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("name", id))

static func description(id: String) -> String:
	var info: Dictionary = ESSENCES.get(id, {})
	var parts: Array = []
	var base: String = String(info.get("desc", ""))
	var passive: String = String(info.get("passive_desc", ""))
	var penalty: String = String(info.get("penalty_desc", ""))
	if base != "":
		parts.append(base)
	if passive != "":
		parts.append(passive)
	if penalty != "":
		parts.append("Penalty: %s" % penalty)
	return " ".join(parts)

static func color_of(id: String) -> Color:
	return ESSENCES.get(id, {}).get("color", Color(0.8, 0.8, 0.85))

static func tier_of(id: String) -> String:
	return String(ESSENCE_TIER_BY_ID.get(id, "normal"))

static func icon_path_of(id: String) -> String:
	return ESSENCE_ICON_DIR + "essence_%s.png" % tier_of(id)

static func icon_texture_of(id: String) -> Texture2D:
	var path := icon_path_of(id)
	if ResourceLoader.exists(path):
		return load(path) as Texture2D
	return null

static func random_id() -> String:
	var keys: Array = ESSENCES.keys()
	return keys[randi() % keys.size()]

static func apply(player: Player, essence_id: String) -> void:
	var info: Dictionary = ESSENCES.get(essence_id, {})
	var effect: String = String(info.get("effect", ""))
	var value: int = int(info.get("value", 0))
	var penalty_effect: String = String(info.get("penalty_effect", ""))
	var penalty_value: int = int(info.get("penalty_value", 0))
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
		"hp_max":
			player.hp_max += value
			player.hp = mini(player.hp + value, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch":
			pass
	if effect == "wl_bonus":
		player.wl += value
	_apply_penalty(player, penalty_effect, penalty_value, true)
	player.refresh_ac_from_equipment()
	player.emit_signal("stats_changed")

static func remove(player: Player, essence_id: String) -> void:
	var info: Dictionary = ESSENCES.get(essence_id, {})
	var effect: String = String(info.get("effect", ""))
	var value: int = int(info.get("value", 0))
	var penalty_effect: String = String(info.get("penalty_effect", ""))
	var penalty_value: int = int(info.get("penalty_value", 0))
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
		"hp_max":
			player.hp_max = maxi(1, player.hp_max - value)
			player.hp = mini(player.hp, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch":
			pass
	if effect == "wl_bonus":
		player.wl = maxi(0, player.wl - value)
	_apply_penalty(player, penalty_effect, penalty_value, false)
	player.refresh_ac_from_equipment()
	player.emit_signal("stats_changed")

static func _apply_penalty(player: Player, penalty_effect: String, penalty_value: int, applying: bool) -> void:
	if penalty_effect == "":
		return
	var mult: int = 1 if applying else -1
	match penalty_effect:
		"vuln_fire":
			if applying:
				if not player.resists.has("fire-"):
					player.resists.append("fire-")
			else:
				player.resists.erase("fire-")
		"vuln_cold":
			if applying:
				if not player.resists.has("cold-"):
					player.resists.append("cold-")
			else:
				player.resists.erase("cold-")
		"int_down":
			player.intelligence = maxi(1, player.intelligence - penalty_value * mult)
		"dex_down":
			player.dexterity = maxi(1, player.dexterity - penalty_value * mult)
		"hp_down":
			player.hp_max = maxi(1, player.hp_max - penalty_value * mult)
			player.hp = mini(player.hp, player.hp_max)
		"mp_down":
			player.mp_max = maxi(0, player.mp_max - penalty_value * mult)
			player.mp = mini(player.mp, player.mp_max)
		"wl_down":
			player.wl = maxi(0, player.wl - penalty_value * mult)

static func tick(player: Player) -> void:
	var regen_count: int = 0
	for slot in player.essence_slots:
		if slot == "essence_regeneration":
			regen_count += 1
	if regen_count > 0 and player.hp < player.hp_max and TurnManager != null and TurnManager.turn_count % 2 == 0:
		player.heal(regen_count)

static func passive_desc(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("passive_desc", ""))

static func passive_effect(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("passive_effect", ""))

static func active_synergies(player: Player) -> Array:
	var out: Array = []
	if has_synergy(player, "essence_fire", "essence_arcana"):
		out.append("Blazecraft: fire spells gain +4 power.")
	if has_synergy(player, "essence_cold", "essence_arcana"):
		out.append("Frostcraft: cold spells gain +4 power.")
	if has_synergy(player, "essence_arcana", "essence_warding"):
		out.append("Forbidden Ward: spell study INT -3 total.")
	if has_synergy(player, "essence_swiftness", "essence_venom"):
		out.append("Ghost Venom: stronger stealth and unaware poison setup.")
	if has_synergy(player, "essence_stone", "essence_vitality"):
		out.append("Bulwark Heart: damage -3 total, injury gain reduced.")
	if has_synergy(player, "essence_fury", "essence_drain"):
		out.append("Bloodrush: extra healing on kill.")
	return out

static func has_venom_touch(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_venom")

static func has_synergy(player: Player, a: String, b: String) -> bool:
	return player != null and player.essence_slots.has(a) and player.essence_slots.has(b)

static func stealth_bonus(player: Player) -> int:
	if player == null:
		return 0
	var bonus: int = 0
	if player.essence_slots.has("essence_swiftness"):
		bonus += 2
	if player.essence_slots.has("essence_warding"):
		bonus += 1
	if has_synergy(player, "essence_swiftness", "essence_venom"):
		bonus += 2
	return bonus

static func spell_int_discount(player: Player) -> int:
	if player == null:
		return 0
	var discount: int = 0
	if player.essence_slots.has("essence_arcana"):
		discount += 2
	if has_synergy(player, "essence_arcana", "essence_warding"):
		discount += 1
	return discount

static func spell_power_bonus(player: Player, spell: SpellData) -> int:
	if player == null or spell == null:
		return 0
	var bonus: int = 0
	if has_synergy(player, "essence_fire", "essence_arcana") and spell.element == "fire":
		bonus += 4
	if has_synergy(player, "essence_cold", "essence_arcana") and spell.element == "cold":
		bonus += 4
	if has_synergy(player, "essence_arcana", "essence_warding") and spell.element == "necromancy":
		bonus += 2
	return bonus

static func incoming_damage_reduction(player: Player) -> int:
	if player == null:
		return 0
	var reduction: int = 0
	if player.essence_slots.has("essence_stone"):
		reduction += 1
	if player.essence_slots.has("essence_warding"):
		reduction += 1
	if has_synergy(player, "essence_stone", "essence_vitality"):
		reduction += 1
	return reduction

static func injury_reduction(player: Player) -> int:
	if has_synergy(player, "essence_stone", "essence_vitality"):
		return 1
	return 0

static func bonus_ac(player: Player) -> int:
	if player == null:
		return 0
	var total: int = 0
	if player.essence_slots.has("essence_stone"):
		total += 2
	if player.essence_slots.has("essence_swiftness"):
		total -= 1
	if player.essence_slots.has("essence_fury"):
		total -= 1
	return total

static func bonus_ev(player: Player) -> int:
	if player == null:
		return 0
	var total: int = 0
	if player.essence_slots.has("essence_swiftness"):
		total += 1
	if player.essence_slots.has("essence_vitality"):
		total -= 1
	return total

static func apply_melee_hit_effects(player: Player, monster: Monster) -> void:
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "melee_fire":
			var fire_dmg: int = Status.resist_scale(3, monster.data.resists, "fire")
			if fire_dmg > 0:
				monster.take_damage(fire_dmg)
				if randf() < 0.35 and monster.hp > 0:
					Status.apply(monster, "burning", 2)
		elif effect_id == "melee_chill":
			if randf() < 0.4:
				Status.apply(monster, "frozen", 1)
		elif effect_id == "venom_touch":
			var venom_dmg: int = Status.resist_scale(1, monster.data.resists, "poison")
			if venom_dmg > 0:
				monster.take_damage(venom_dmg)
			if not monster.is_aware and has_synergy(player, "essence_swiftness", "essence_venom"):
				Status.apply(monster, "poison", 5)

static func apply_on_kill_effects(player: Player) -> void:
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "on_kill_heal":
			player.heal(3)
		elif effect_id == "on_kill_fury":
			Status.apply(player, "damage_boost", 2)
		elif effect_id == "on_kill_drain":
			player.heal(4)
			player.heal_injury(1)
	if has_synergy(player, "essence_fury", "essence_drain"):
		player.heal(2)
