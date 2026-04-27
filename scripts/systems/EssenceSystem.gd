class_name EssenceSystem extends RefCounted

## Essence progression system.
## Each essence grants a strong identity, a conditional passive,
## and a drawback. Some pairings also unlock resonance bonuses.

static var TurnManager = Engine.get_main_loop().root.get_node_or_null("/root/TurnManager") if Engine.get_main_loop() is SceneTree else null

const SLOT_COUNT: int = 3
const SLOT_UNLOCK_LEVELS: Array = [1, 8, 16]
const INVENTORY_CAP: int = 4
const ESSENCE_ICON_DIR := "res://assets/tiles/individual/item/essence/"

const UNIQUE_MONSTER_ESSENCE_IDS: Array = [
	"essence_gloam", "essence_cinder", "essence_serpent", "essence_bastion",
	"essence_dread", "essence_bloodwake", "essence_tempest", "essence_pale_star",
	"essence_plague", "essence_glacial", "essence_infernal", "essence_acid",
]

const RUNE_COSTS: Dictionary = {
	"essence_fire": 10,
	"essence_cold": 10,
	"essence_swiftness": 10,
	"essence_regeneration": 10,
	"essence_venom": 10,
	"essence_vitality": 20,
	"essence_stone": 20,
	"essence_warding": 20,
	"essence_might": 20,
	"essence_arcana": 35,
	"essence_fury": 35,
	"essence_drain": 35,
	"essence_cinder": 35,
	"essence_serpent": 35,
	"essence_gloam": 35,
	"essence_dread": 60,
	"essence_bloodwake": 60,
	"essence_tempest": 60,
	"essence_bastion": 60,
	"essence_pale_star": 60,
	"essence_plague": 60,
	"essence_glacial": 60,
	"essence_infernal": 60,
	"essence_acid": 60,
}

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
	"essence_gloam": "unique",
	"essence_cinder": "unique",
	"essence_serpent": "unique",
	"essence_bastion": "unique",
	"essence_dread": "unique",
	"essence_bloodwake": "unique",
	"essence_tempest": "unique",
	"essence_pale_star": "unique",
	"essence_plague": "unique",
	"essence_glacial": "unique",
	"essence_infernal": "unique",
	"essence_acid": "unique",
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
	# ── Branch Boss Essences ──────────────────────────────────────────────────
	"essence_plague": {
		"name": "Plague Essence",
		"desc": "Poison-immune. Attacks against poisoned enemies deal +20% damage.",
		"passive_desc": "+20% damage vs. poisoned targets. Poison immunity.",
		"penalty_desc": "WL -1.",
		"passive_effect": "plague_bonus",
		"color": Color(0.35, 0.85, 0.35),
		"effect": "wl_down",
		"penalty_effect": "wl_down",
		"penalty_value": 1,
	},
	"essence_glacial": {
		"name": "Glacial Essence",
		"desc": "Cold resistant. 20% chance to freeze attacker when hit.",
		"passive_desc": "Reflect freeze on attackers. Cold resistance.",
		"penalty_desc": "DEX -1.",
		"passive_effect": "glacial_retaliate",
		"color": Color(0.5, 0.85, 1.0),
		"effect": "resist_cold",
		"penalty_effect": "dex_down",
		"penalty_value": 1,
	},
	"essence_infernal": {
		"name": "Infernal Essence",
		"desc": "Fire resistant. Fire attacks and spells deal +25% damage.",
		"passive_desc": "+25% fire damage output. Fire resistance.",
		"penalty_desc": "Cold vulnerable.",
		"passive_effect": "infernal_fire",
		"color": Color(1.0, 0.4, 0.1),
		"effect": "resist_fire",
		"penalty_effect": "vuln_cold",
	},
	"essence_acid": {
		"name": "Acid Essence",
		"desc": "Corrosion resistant. Attacks corrode enemies, reducing their AC.",
		"passive_desc": "Melee hits apply corroded (AC -2, 3 turns). Corrosion immunity.",
		"penalty_desc": "HP max -4.",
		"passive_effect": "acid_touch",
		"color": Color(0.6, 0.85, 0.3),
		"effect": "resist_corr",
		"penalty_effect": "hp_down",
		"penalty_value": 4,
	},
	# ── Unique Monster Essences ────────────────────────────────────────────────
	"essence_gloam": {
		"name": "Gloam Essence",
		"desc": "First hit on unaware targets deals +35% damage. WILL +1.",
		"passive_desc": "+35% first-hit damage vs. unaware enemies. Stealth bonus.",
		"penalty_desc": "HP max -3.",
		"passive_effect": "gloam_unaware",
		"color": Color(0.35, 0.3, 0.55),
		"effect": "wl_bonus",
		"value": 1,
		"penalty_effect": "hp_down",
		"penalty_value": 3,
	},
	"essence_cinder": {
		"name": "Cinder Essence",
		"desc": "Melee and fire spells deal +2 fire damage. Fire resistant. INT +1.",
		"passive_desc": "+2 fire damage on melee and fire spells.",
		"penalty_desc": "Cold vulnerable.",
		"passive_effect": "cinder_fire",
		"color": Color(1.0, 0.5, 0.15),
		"effect": "resist_fire",
		"penalty_effect": "vuln_cold",
	},
	"essence_serpent": {
		"name": "Serpent Essence",
		"desc": "First unaware hit poisons 5 turns. All hits 25% to poison 3 turns. DEX +1.",
		"passive_desc": "Poison on hit. Unaware opener poisons for 5 turns.",
		"penalty_desc": "WILL -1.",
		"passive_effect": "serpent_poison",
		"color": Color(0.3, 0.85, 0.3),
		"effect": "stat_dex",
		"value": 1,
		"penalty_effect": "wl_down",
		"penalty_value": 1,
	},
	"essence_bastion": {
		"name": "Bastion Essence",
		"desc": "Incoming damage -2. AC +2. WILL +1.",
		"passive_desc": "Constant damage reduction and bonus armor.",
		"penalty_desc": "EV -2.",
		"passive_effect": "",
		"color": Color(0.7, 0.75, 0.65),
		"effect": "wl_bonus",
		"value": 1,
		"penalty_effect": "ev_down",
		"penalty_value": 2,
	},
	"essence_dread": {
		"name": "Dread Essence",
		"desc": "Attacks have 20% chance to inflict fear for 2 turns. WILL +1.",
		"passive_desc": "20% fear on hit. Bonus will vs. control effects.",
		"penalty_desc": "STR -1.",
		"passive_effect": "dread_fear",
		"color": Color(0.5, 0.3, 0.65),
		"effect": "wl_bonus",
		"value": 1,
		"penalty_effect": "str_down",
		"penalty_value": 1,
	},
	"essence_bloodwake": {
		"name": "Bloodwake Essence",
		"desc": "On kill: heal 5 HP and gain +20% damage for 2 turns. HP max +5.",
		"passive_desc": "5 HP and damage surge on each kill.",
		"penalty_desc": "Potion healing -20%.",
		"passive_effect": "bloodwake_kill",
		"color": Color(0.85, 0.2, 0.25),
		"effect": "hp_max",
		"value": 5,
		"penalty_effect": "",
	},
	"essence_tempest": {
		"name": "Tempest Essence",
		"desc": "Ranged attacks and spells deal +15% damage. INT +1, DEX +1.",
		"passive_desc": "+15% damage on ranged attacks and spells.",
		"penalty_desc": "AC -1.",
		"passive_effect": "tempest_ranged",
		"color": Color(0.4, 0.65, 1.0),
		"effect": "",
		"penalty_effect": "ac_down",
		"penalty_value": 1,
	},
	"essence_pale_star": {
		"name": "Pale Star Essence",
		"desc": "Control effects +1 turn. Spell INT req -2. INT +2, WILL +1.",
		"passive_desc": "Extended control durations and spell study discount.",
		"penalty_desc": "HP max -6. Fire vulnerable.",
		"passive_effect": "pale_star_control",
		"color": Color(0.75, 0.85, 1.0),
		"effect": "",
		"penalty_effect": "",
	},
}

static func rune_cost(id: String) -> int:
	return int(RUNE_COSTS.get(id, 20))

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
	var keys: Array = []
	for k in ESSENCES.keys():
		if not UNIQUE_MONSTER_ESSENCE_IDS.has(k):
			keys.append(k)
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
		"resist_corr":
			if not player.resists.has("corr+"):
				player.resists.append("corr+")
		"stat_str":
			player.strength += value
		"stat_int":
			player.intelligence += value
		"stat_dex":
			player.dexterity += value
		"hp_max":
			player.hp_max += value
			player.hp = mini(player.hp + value, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch", "plague_bonus", "glacial_retaliate", "infernal_fire", "acid_touch":
			pass
	if effect == "wl_bonus":
		player.wl += value
	_apply_penalty(player, penalty_effect, penalty_value, true)
	_apply_unique_stats(player, essence_id, true)
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
		"resist_corr":
			player.resists.erase("corr+")
		"stat_str":
			player.strength = maxi(1, player.strength - value)
		"stat_int":
			player.intelligence = maxi(1, player.intelligence - value)
		"stat_dex":
			player.dexterity = maxi(1, player.dexterity - value)
		"hp_max":
			player.hp_max = maxi(1, player.hp_max - value)
			player.hp = mini(player.hp, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch", "plague_bonus", "glacial_retaliate", "infernal_fire", "acid_touch":
			pass
	if effect == "wl_bonus":
		player.wl = maxi(0, player.wl - value)
	_apply_penalty(player, penalty_effect, penalty_value, false)
	_apply_unique_stats(player, essence_id, false)
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
		"str_down":
			player.strength = maxi(1, player.strength - penalty_value * mult)
		"hp_down":
			player.hp_max = maxi(1, player.hp_max - penalty_value * mult)
			player.hp = mini(player.hp, player.hp_max)
		"mp_down":
			player.mp_max = maxi(0, player.mp_max - penalty_value * mult)
			player.mp = mini(player.mp, player.mp_max)
		"wl_down":
			player.wl = maxi(0, player.wl - penalty_value * mult)

static func _apply_unique_stats(player: Player, essence_id: String, applying: bool) -> void:
	var mult: int = 1 if applying else -1
	match essence_id:
		"essence_cinder":
			player.intelligence = maxi(1, player.intelligence + mult)
		"essence_serpent":
			if applying:
				if not player.resists.has("poison+"):
					player.resists.append("poison+")
			else:
				player.resists.erase("poison+")
		"essence_tempest":
			player.intelligence = maxi(1, player.intelligence + mult)
			player.dexterity = maxi(1, player.dexterity + mult)
		"essence_pale_star":
			player.intelligence = maxi(1, player.intelligence + 2 * mult)
			player.wl = maxi(0, player.wl + mult)
			player.hp_max = maxi(1, player.hp_max - 6 * mult)
			player.hp = mini(player.hp, player.hp_max)
			if applying:
				if not player.resists.has("fire-"):
					player.resists.append("fire-")
			else:
				player.resists.erase("fire-")

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
	if has_synergy(player, "essence_gloam", "essence_swiftness"):
		out.append("Gloam + Swiftness: first unaware hit also weakens for 2 turns.")
	if has_synergy(player, "essence_cinder", "essence_arcana"):
		out.append("Cinder + Arcana: fire spells gain +4 bonus power.")
	if has_synergy(player, "essence_serpent", "essence_swiftness"):
		out.append("Serpent + Swiftness: unaware opener gains +25% damage.")
	if has_synergy(player, "essence_bastion", "essence_vitality"):
		out.append("Bastion + Vitality: potion healing +3 HP.")
	if has_synergy(player, "essence_dread", "essence_warding"):
		out.append("Dread + Warding: feared enemies deal -2 damage.")
	if has_synergy(player, "essence_bloodwake", "essence_fury"):
		out.append("Bloodwake + Fury: on-kill surge lasts 3 turns.")
	if has_synergy(player, "essence_tempest", "essence_arcana"):
		out.append("Tempest + Arcana: spell study INT -3 total.")
	if has_synergy(player, "essence_pale_star", "essence_arcana"):
		out.append("Pale Star + Arcana: spell study INT -4 total.")
	return out

static func has_venom_touch(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_venom")

static func has_acid_touch(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_acid")

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
	if player.essence_slots.has("essence_gloam"):
		bonus += 2
	if has_synergy(player, "essence_swiftness", "essence_venom"):
		bonus += 2
	return bonus

static func spell_int_discount(player: Player) -> int:
	if player == null:
		return 0
	var discount: int = 0
	if player.essence_slots.has("essence_arcana"):
		discount += 2
	if player.essence_slots.has("essence_pale_star"):
		discount += 2
	if has_synergy(player, "essence_tempest", "essence_arcana"):
		discount = maxi(discount, 3)
	if has_synergy(player, "essence_pale_star", "essence_arcana"):
		discount = maxi(discount, 4)
	if has_synergy(player, "essence_arcana", "essence_warding"):
		discount = maxi(discount, 3)
	return discount

static func spell_power_bonus(player: Player, spell: SpellData) -> int:
	if player == null or spell == null:
		return 0
	var bonus: int = 0
	if has_synergy(player, "essence_fire", "essence_arcana") and spell.element == "fire":
		bonus += 4
	if has_synergy(player, "essence_cold", "essence_arcana") and spell.element == "cold":
		bonus += 4
	if has_synergy(player, "essence_cinder", "essence_arcana") and spell.element == "fire":
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
	if player.essence_slots.has("essence_bastion"):
		reduction += 2
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
	if player.essence_slots.has("essence_bastion"):
		total += 2
	if player.essence_slots.has("essence_swiftness"):
		total -= 1
	if player.essence_slots.has("essence_fury"):
		total -= 1
	if player.essence_slots.has("essence_tempest"):
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
	if player.essence_slots.has("essence_bastion"):
		total -= 2
	return total

static func potion_heal_bonus(player: Player) -> int:
	if player == null:
		return 0
	var bonus: int = 0
	if has_synergy(player, "essence_bastion", "essence_vitality"):
		bonus += 3
	return bonus

static func potion_heal_mult(player: Player) -> float:
	if player == null:
		return 1.0
	if player.essence_slots.has("essence_bloodwake"):
		return 0.8
	return 1.0

static func ranged_damage_mult(player: Player) -> float:
	if player == null:
		return 1.0
	if player.essence_slots.has("essence_tempest"):
		return 1.15
	return 1.0

static func fire_damage_mult(player: Player) -> float:
	if player == null:
		return 1.0
	if player.essence_slots.has("essence_infernal"):
		return 1.25
	return 1.0

static func unaware_damage_mult(player: Player) -> float:
	if player == null:
		return 1.0
	var mult: float = 1.0
	if player.essence_slots.has("essence_gloam"):
		mult *= 1.35
	if has_synergy(player, "essence_serpent", "essence_swiftness"):
		mult *= 1.25
	return mult

static func apply_melee_hit_effects(player: Player, monster: Monster) -> void:
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "melee_fire":
			var fire_dmg: int = Status.resist_scale(3, monster.data.resists, "fire")
			if fire_dmg > 0:
				monster.take_damage(fire_dmg)
				if randf() < 0.35 and monster.hp > 0:
					Status.apply(monster, "burning", 2)
		elif effect_id == "cinder_fire":
			var fire_dmg: int = Status.resist_scale(2, monster.data.resists, "fire")
			if fire_dmg > 0:
				monster.take_damage(fire_dmg)
		elif effect_id == "melee_chill":
			if randf() < 0.4:
				Status.apply(monster, "frozen", 1)
		elif effect_id == "venom_touch":
			var venom_dmg: int = Status.resist_scale(1, monster.data.resists, "poison")
			if venom_dmg > 0:
				monster.take_damage(venom_dmg)
			if not monster.is_aware and has_synergy(player, "essence_swiftness", "essence_venom"):
				Status.apply(monster, "poison", 5)
		elif effect_id == "serpent_poison":
			if not monster.is_aware:
				Status.apply(monster, "poison", 5)
			elif randf() < 0.25:
				Status.apply(monster, "poison", 3)
		elif effect_id == "dread_fear":
			if randf() < 0.20 and monster.hp > 0:
				Status.apply(monster, "feared", 2)
	# Gloam + Swiftness resonance: first unaware hit also weakens
	if not monster.is_aware and has_synergy(player, "essence_gloam", "essence_swiftness"):
		Status.apply(monster, "weak", 2)

static func apply_on_kill_effects(player: Player) -> void:
	var has_bloodwake_fury: bool = has_synergy(player, "essence_bloodwake", "essence_fury")
	for slot in player.essence_slots:
		var effect_id: String = passive_effect(slot)
		if effect_id == "on_kill_heal":
			player.heal(3)
		elif effect_id == "on_kill_fury":
			var fury_dur: int = 3 if has_bloodwake_fury else 2
			Status.apply(player, "damage_boost", fury_dur)
		elif effect_id == "on_kill_drain":
			player.heal(4)
			player.heal_injury(1)
		elif effect_id == "bloodwake_kill":
			player.heal(5)
			var wake_dur: int = 3 if has_bloodwake_fury else 2
			Status.apply(player, "damage_boost", wake_dur)
	if has_synergy(player, "essence_fury", "essence_drain"):
		player.heal(2)
