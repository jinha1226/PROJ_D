class_name EssenceSystem extends RefCounted

## Essence progression system.
## Each essence grants a strong identity, a conditional passive,
## and a drawback. Some pairings also unlock resonance bonuses.


const SLOT_COUNT: int = 3
# Slot unlock: 1 slot per XL, capped at SLOT_COUNT. XL1=1 slot, XL2=2, XL3+=3.
const INVENTORY_CAP: int = 4
const ESSENCE_ICON_DIR := "res://assets/tiles/individual/item/essence/"

const UNIQUE_MONSTER_ESSENCE_IDS: Array = [
	"essence_gloam", "essence_cinder", "essence_serpent", "essence_bastion",
	"essence_dread", "essence_bloodwake", "essence_tempest", "essence_pale_star",
	"essence_plague", "essence_glacial", "essence_infernal", "essence_undeath",
]


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
	"essence_undeath": "unique",
	# Normal tier additions
	"essence_nimble": "normal",
	"essence_fang": "normal",
	"essence_pack": "normal",
	"essence_marrow": "normal",
	# Rare tier additions
	"essence_shadow": "rare",
	"essence_tracker": "rare",
	"essence_blood": "rare",
	"essence_scales": "rare",
	"essence_iron_will": "rare",
	"essence_wither": "rare",
	"essence_constrict": "rare",
	# Unique tier additions
	"essence_titan": "unique",
	"essence_necromancer": "unique",
	"essence_abyssal": "unique",
	"essence_war_cry": "unique",
	"essence_hydra": "unique",
	"essence_golden": "unique",
}

const ESSENCE_TAGS_BY_ID := {
	"essence_fire": ["fire", "arcane"],
	"essence_cold": ["cold", "ward", "arcane"],
	"essence_might": ["might", "melee", "war"],
	"essence_arcana": ["arcane", "magic"],
	"essence_swiftness": ["speed", "storm", "stealth"],
	"essence_vitality": ["life", "blood", "fortify"],
	"essence_stone": ["stone", "fortify"],
	"essence_warding": ["ward", "will", "fortify"],
	"essence_regeneration": ["life", "restoration"],
	"essence_venom": ["poison", "nature"],
	"essence_fury": ["fury", "melee"],
	"essence_drain": ["death", "drain", "blood"],
	"essence_plague": ["poison", "plague", "death"],
	"essence_glacial": ["cold", "ward"],
	"essence_infernal": ["fire", "arcane", "fury"],
	"essence_undeath": ["death", "drain", "void"],
	"essence_nimble": ["speed", "stealth"],
	"essence_fang": ["poison", "nature", "beast"],
	"essence_pack": ["beast", "speed", "fury"],
	"essence_marrow": ["death", "stone", "fortify"],
	"essence_shadow": ["shadow", "void", "stealth"],
	"essence_tracker": ["stealth", "beast", "speed"],
	"essence_blood": ["blood", "life", "drain"],
	"essence_scales": ["stone", "ward", "dragon"],
	"essence_iron_will": ["will", "ward", "fortify"],
	"essence_wither": ["death", "poison", "decay"],
	"essence_constrict": ["nature", "poison", "control"],
	"essence_titan": ["stone", "fortify", "giant", "melee"],
	"essence_necromancer": ["death", "arcane", "necromancy"],
	"essence_abyssal": ["void", "death", "drain"],
	"essence_war_cry": ["war", "melee", "fury"],
	"essence_hydra": ["beast", "nature", "melee"],
	"essence_golden": ["holy", "ward", "dragon"],
	"essence_gloam": ["shadow", "void", "stealth"],
	"essence_cinder": ["fire", "arcane"],
	"essence_serpent": ["poison", "nature", "stealth"],
	"essence_bastion": ["fortify", "stone", "ward"],
	"essence_dread": ["shadow", "void", "fear"],
	"essence_bloodwake": ["blood", "fury", "life", "drain"],
	"essence_tempest": ["storm", "speed", "ranged", "arcane"],
	"essence_pale_star": ["arcane", "ward", "will", "cold"],
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
		"passive_desc": "Heal 4 HP on kill.",
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
	"essence_undeath": {
		"name": "Essence of Undeath",
		"desc": "Necromantic resistance. Melee hits drain 2 HP from enemies to you.",
		"passive_desc": "Melee hits drain 2 HP (vampiric). Necromantic resistance (necro+).",
		"penalty_desc": "HP max -4.",
		"passive_effect": "drain_touch",
		"color": Color(0.55, 0.35, 0.85),
		"effect": "resist_necro",
		"penalty_effect": "hp_down",
		"penalty_value": 4,
	},
	# ── Normal Tier Additions ─────────────────────────────────────────────────
	"essence_nimble": {
		"name": "Nimble Essence",
		"desc": "+1 Evasion. Stealth+2.",
		"passive_desc": "Agile and harder to detect.",
		"penalty_desc": "Will -1.",
		"passive_effect": "",
		"color": Color(0.55, 0.9, 0.55),
		"effect": "stat_dex",
		"value": 1,
		"penalty_effect": "wl_down",
		"penalty_value": 1,
	},
	"essence_fang": {
		"name": "Fang Essence",
		"desc": "+1 Dexterity. Melee hits deliver a venomous bite.",
		"passive_desc": "Melee hits deal 2 extra poison damage and apply poison for 4 turns.",
		"penalty_desc": "Fire vulnerable.",
		"passive_effect": "fang_poison",
		"color": Color(0.4, 0.85, 0.45),
		"effect": "stat_dex",
		"value": 1,
		"penalty_effect": "vuln_fire",
	},
	"essence_pack": {
		"name": "Pack Essence",
		"desc": "On kill, next melee attack gains a damage surge.",
		"passive_desc": "Killing an enemy grants a 1-turn damage boost.",
		"penalty_desc": "AC -1.",
		"passive_effect": "on_kill_pack",
		"color": Color(0.75, 0.55, 0.3),
		"effect": "on_kill_pack",
		"penalty_effect": "ac_down",
		"penalty_value": 1,
	},
	"essence_marrow": {
		"name": "Marrow Essence",
		"desc": "+4 max HP, +1 Armor Class.",
		"passive_desc": "Undead resilience thickens your body.",
		"penalty_desc": "Fire vulnerable.",
		"passive_effect": "",
		"color": Color(0.85, 0.85, 0.75),
		"effect": "hp_max",
		"value": 4,
		"penalty_effect": "vuln_fire",
	},
	# ── Rare Tier Additions ────────────────────────────────────────────────────
	"essence_shadow": {
		"name": "Shadow Essence",
		"desc": "+1 Evasion. Stealth+2. 20% chance to blind attacker when hit.",
		"passive_desc": "Shadow form evades and disorients attackers.",
		"penalty_desc": "Fire vulnerable.",
		"passive_effect": "shadow_blind",
		"color": Color(0.35, 0.3, 0.5),
		"effect": "shadow_blind",
		"penalty_effect": "vuln_fire",
	},
	"essence_tracker": {
		"name": "Tracker Essence",
		"desc": "Stealth+3. Read the dungeon like a predator.",
		"passive_desc": "Expert at remaining hidden.",
		"penalty_desc": "Will -1.",
		"passive_effect": "",
		"color": Color(0.6, 0.45, 0.25),
		"effect": "",
		"penalty_effect": "wl_down",
		"penalty_value": 1,
	},
	"essence_blood": {
		"name": "Blood Essence",
		"desc": "Melee hits heal 2 HP.",
		"passive_desc": "Drain vitality from each strike.",
		"penalty_desc": "Will -2.",
		"passive_effect": "blood_heal",
		"color": Color(0.85, 0.2, 0.3),
		"effect": "blood_heal",
		"penalty_effect": "wl_down",
		"penalty_value": 2,
	},
	"essence_scales": {
		"name": "Scale Essence",
		"desc": "+2 Armor Class. Fire and cold resistance.",
		"passive_desc": "Draconic scales deflect and resist.",
		"penalty_desc": "EV -1.",
		"passive_effect": "",
		"color": Color(0.6, 0.8, 0.45),
		"effect": "ac_bonus",
		"value": 2,
		"penalty_effect": "ev_down",
		"penalty_value": 1,
	},
	"essence_iron_will": {
		"name": "Iron Will Essence",
		"desc": "+3 Will.",
		"passive_desc": "Will-resisted effects are even less likely to land.",
		"penalty_desc": "STR -1.",
		"passive_effect": "",
		"color": Color(0.65, 0.65, 0.85),
		"effect": "wl_bonus",
		"value": 3,
		"penalty_effect": "str_down",
		"penalty_value": 1,
	},
	"essence_wither": {
		"name": "Wither Essence",
		"desc": "Melee hits corrode enemy armor for 3 turns.",
		"passive_desc": "Mummified touch erodes defenses.",
		"penalty_desc": "HP max -4.",
		"passive_effect": "wither_corrode",
		"color": Color(0.65, 0.5, 0.35),
		"effect": "wither_corrode",
		"penalty_effect": "hp_down",
		"penalty_value": 4,
	},
	"essence_constrict": {
		"name": "Constrict Essence",
		"desc": "25% chance to slow enemies on melee hit.",
		"passive_desc": "Crushing grip can immobilize foes.",
		"penalty_desc": "DEX -1.",
		"passive_effect": "constrict_slow",
		"color": Color(0.3, 0.55, 0.35),
		"effect": "constrict_slow",
		"penalty_effect": "dex_down",
		"penalty_value": 1,
	},
	# ── Unique Tier Additions ──────────────────────────────────────────────────
	"essence_titan": {
		"name": "Titan Essence",
		"desc": "+3 Strength, +8 max HP. Earthshatter skill.",
		"passive_desc": "Giant fortitude and devastating strikes.",
		"penalty_desc": "EV -2.",
		"passive_effect": "",
		"color": Color(0.75, 0.65, 0.45),
		"effect": "stat_str",
		"value": 3,
		"penalty_effect": "ev_down",
		"penalty_value": 2,
		"active_skill": {"id": "earthshatter", "name": "Earthshatter", "desc": "Deal damage to all adjacent enemies.", "cooldown": 12},
	},
	"essence_necromancer": {
		"name": "Necromancer Essence",
		"desc": "+2 Will. Necromancy spells gain +2 power. Raise Dead skill.",
		"passive_desc": "Dark mastery strengthens the mind against death.",
		"penalty_desc": "HP max -4. Fire vulnerable.",
		"passive_effect": "",
		"color": Color(0.5, 0.3, 0.7),
		"effect": "wl_bonus",
		"value": 2,
		"penalty_effect": "hp_down",
		"penalty_value": 4,
		"active_skill": {"id": "raise_dead", "name": "Raise Dead", "desc": "Summon a skeletal warrior ally for 8 turns.", "cooldown": 20},
	},
	"essence_abyssal": {
		"name": "Abyssal Essence",
		"desc": "+1 Intelligence. Melee hits deal +2 drain damage. Void Step skill.",
		"passive_desc": "Abyssal energies hunger for life force.",
		"penalty_desc": "Cold vulnerable.",
		"passive_effect": "abyssal_dark",
		"color": Color(0.3, 0.2, 0.5),
		"effect": "stat_int",
		"value": 1,
		"penalty_effect": "vuln_cold",
		"active_skill": {"id": "void_step", "name": "Void Step", "desc": "Teleport to a target tile.", "cooldown": 10},
	},
	"essence_war_cry": {
		"name": "War Cry Essence",
		"desc": "+2 Strength. Melee +2 flat damage. War Cry skill.",
		"passive_desc": "Bloodlust amplifies every strike.",
		"penalty_desc": "EV -1.",
		"passive_effect": "war_cry_bonus",
		"color": Color(1.0, 0.35, 0.15),
		"effect": "stat_str",
		"value": 2,
		"penalty_effect": "ev_down",
		"penalty_value": 1,
		"active_skill": {"id": "war_cry", "name": "War Cry", "desc": "Fear all adjacent enemies for 2 turns.", "cooldown": 10},
	},
	"essence_hydra": {
		"name": "Hydra Essence",
		"desc": "30% chance to strike twice on melee attack. Multihead Strike skill.",
		"passive_desc": "Multiple heads lash out in rapid succession.",
		"penalty_desc": "AC -1.",
		"passive_effect": "hydra_double",
		"color": Color(0.3, 0.7, 0.5),
		"effect": "hydra_double",
		"penalty_effect": "ac_down",
		"penalty_value": 1,
		"active_skill": {"id": "multihead", "name": "Multihead Strike", "desc": "Strike all adjacent enemies.", "cooldown": 8},
	},
	"essence_golden": {
		"name": "Golden Essence",
		"desc": "+2 Will. All resistances +1. Dragon Aura skill.",
		"passive_desc": "Draconic majesty radiates elemental resilience.",
		"penalty_desc": "EV -2.",
		"passive_effect": "",
		"color": Color(1.0, 0.85, 0.2),
		"effect": "wl_bonus",
		"value": 2,
		"penalty_effect": "ev_down",
		"penalty_value": 2,
		"active_skill": {"id": "dragon_aura", "name": "Dragon Aura", "desc": "Reflect 50% of incoming damage for 3 turns.", "cooldown": 15},
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

static func is_available(player) -> bool:
	return FaithSystem.allows_essence(player)

static func all_ids() -> Array:
	return ESSENCES.keys()

static func active_slot_count(player: Player) -> int:
	if player == null:
		return 1
	return clampi(player.xl, 1, SLOT_COUNT)

static func slot_is_unlocked(player: Player, slot_index: int) -> bool:
	return slot_index >= 0 and slot_index < active_slot_count(player)

static func inventory_capacity(player: Player) -> int:
	return INVENTORY_CAP + FaithSystem.essence_inventory_bonus(player)

static func inventory_is_full(player: Player) -> bool:
	return player != null and player.essence_inventory.size() >= inventory_capacity(player)

static func _tr_or(key: String, fallback: String) -> String:
	var t: String = TranslationServer.translate(key)
	return t if t != key else fallback

static func display_name(id: String) -> String:
	var fallback: String = String(ESSENCES.get(id, {}).get("name", id))
	return _tr_or("ESSENCE_NAME_" + id.to_upper(), fallback)

static func description(id: String) -> String:
	var info: Dictionary = ESSENCES.get(id, {})
	var parts: Array = []
	var base: String = _tr_or("ESSENCE_DESC_" + id.to_upper(), String(info.get("desc", "")))
	var passive: String = _tr_or("ESSENCE_PASSIVE_" + id.to_upper(), String(info.get("passive_desc", "")))
	var penalty: String = _tr_or("ESSENCE_PENALTY_" + id.to_upper(), String(info.get("penalty_desc", "")))
	if base != "":
		parts.append(base)
	if passive != "":
		parts.append(passive)
	if penalty != "":
		parts.append(TranslationServer.translate("ESSENCE_PENALTY_PREFIX") % penalty)
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
			player.add_resist("fire", 1)
		"resist_cold":
			player.add_resist("cold", 1)
		"resist_will":
			player.add_resist("will", 1)
		"resist_necro":
			player.add_resist("necro", 1)
		"stat_str":
			player.strength += value
		"stat_int":
			player.intelligence += value
		"stat_dex":
			player.dexterity += value
		"hp_max":
			player.hp_max += value
			player.hp = mini(player.hp + value, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch", "plague_bonus", "glacial_retaliate", "infernal_fire", "drain_touch", \
		"on_kill_pack", "shadow_blind", "blood_heal", "wither_corrode", "constrict_slow", "hydra_double", "war_cry_bonus", "abyssal_dark":
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
			player.add_resist("fire", -1)
		"resist_cold":
			player.add_resist("cold", -1)
		"resist_will":
			player.add_resist("will", -1)
		"resist_necro":
			player.add_resist("necro", -1)
		"stat_str":
			player.strength = maxi(1, player.strength - value)
		"stat_int":
			player.intelligence = maxi(1, player.intelligence - value)
		"stat_dex":
			player.dexterity = maxi(1, player.dexterity - value)
		"hp_max":
			player.hp_max = maxi(1, player.hp_max - value)
			player.hp = mini(player.hp, player.hp_max)
		"ac_bonus", "wl_bonus", "fury", "drain", "regen", "venom_touch", "plague_bonus", "glacial_retaliate", "infernal_fire", "drain_touch", \
		"on_kill_pack", "shadow_blind", "blood_heal", "wither_corrode", "constrict_slow", "hydra_double", "war_cry_bonus", "abyssal_dark":
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
			player.add_resist("fire", -1 if applying else 1)
		"vuln_cold":
			player.add_resist("cold", -1 if applying else 1)
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
			player.add_resist("poison", 1 if applying else -1)
		"essence_tempest":
			player.intelligence = maxi(1, player.intelligence + mult)
			player.dexterity = maxi(1, player.dexterity + mult)
		"essence_pale_star":
			player.intelligence = maxi(1, player.intelligence + 2 * mult)
			player.wl = maxi(0, player.wl + mult)
			player.hp_max = maxi(1, player.hp_max - 6 * mult)
			player.hp = mini(player.hp, player.hp_max)
			player.add_resist("fire", -1 if applying else 1)
		"essence_marrow":
			player.add_resist("fire", -1 if applying else 1)
		"essence_scales":
			player.add_resist("fire", 1 if applying else -1)
			player.add_resist("cold", 1 if applying else -1)
		"essence_necromancer":
			player.add_resist("fire", -1 if applying else 1)
		"essence_titan":
			player.hp_max = maxi(1, player.hp_max + 8 * mult)
			player.hp = mini(player.hp + (8 if applying else 0), player.hp_max)
		"essence_abyssal":
			player.add_resist("cold", -1 if applying else 1)
		"essence_golden":
			player.add_resist("fire", 1 if applying else -1)
			player.add_resist("cold", 1 if applying else -1)
			player.add_resist("poison", 1 if applying else -1)
			player.wl = maxi(0, player.wl + mult)

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

static func essence_tags_of(id: String) -> Array:
	return Array(ESSENCE_TAGS_BY_ID.get(id, []))

static func has_essence_tag(player: Player, tag: String) -> bool:
	if player == null or tag == "":
		return false
	for essence_id in player.essence_slots:
		if essence_tags_of(String(essence_id)).has(tag):
			return true
	return false

static func has_any_essence_tags(player: Player, tags: Array) -> bool:
	if player == null:
		return false
	for tag in tags:
		if has_essence_tag(player, String(tag)):
			return true
	return false

static func has_talent_tags(player: Player, talent_id: String, tags: Array) -> bool:
	return player != null and player.has_talent(talent_id) and has_any_essence_tags(player, tags)

static func active_synergies(player: Player) -> Array:
	var pairs: Array = [
		["essence_fire", "essence_arcana", "ESSENCE_SYN_BLAZECRAFT"],
		["essence_cold", "essence_arcana", "ESSENCE_SYN_FROSTCRAFT"],
		["essence_arcana", "essence_warding", "ESSENCE_SYN_FORBIDDEN_WARD"],
		["essence_swiftness", "essence_venom", "ESSENCE_SYN_GHOST_VENOM"],
		["essence_stone", "essence_vitality", "ESSENCE_SYN_BULWARK_HEART"],
		["essence_fury", "essence_drain", "ESSENCE_SYN_BLOODRUSH"],
		["essence_gloam", "essence_swiftness", "ESSENCE_SYN_GLOAM_SWIFT"],
		["essence_cinder", "essence_arcana", "ESSENCE_SYN_CINDER_ARCANA"],
		["essence_serpent", "essence_swiftness", "ESSENCE_SYN_SERPENT_SWIFT"],
		["essence_bastion", "essence_vitality", "ESSENCE_SYN_BASTION_VITAL"],
		["essence_dread", "essence_warding", "ESSENCE_SYN_DREAD_WARD"],
		["essence_bloodwake", "essence_fury", "ESSENCE_SYN_BLOODWAKE_FURY"],
		["essence_tempest", "essence_arcana", "ESSENCE_SYN_TEMPEST_ARCANA"],
		["essence_pale_star", "essence_arcana", "ESSENCE_SYN_PALE_STAR_ARCANA"],
		["essence_shadow", "essence_gloam", "ESSENCE_SYN_SHADOW_GLOAM"],
		["essence_blood", "essence_fury", "ESSENCE_SYN_BLOOD_FURY"],
		["essence_tracker", "essence_swiftness", "ESSENCE_SYN_TRACKER_SWIFT"],
	]
	var out: Array = []
	for p in pairs:
		if has_synergy(player, p[0], p[1]):
			out.append(TranslationServer.translate(p[2]))
	return out

static func has_essence(player: Player, essence_id: String) -> bool:
	return player != null and essence_id != "" and player.essence_slots.has(essence_id)

static func has_any_essence(player: Player, essence_ids: Array) -> bool:
	if player == null:
		return false
	for essence_id in essence_ids:
		if player.essence_slots.has(String(essence_id)):
			return true
	return false

static func has_talent_essence(player: Player, talent_id: String, essence_id: String) -> bool:
	return player != null and player.has_talent(talent_id) and has_essence(player, essence_id)

static func has_talent_any_essence(player: Player, talent_id: String, essence_ids: Array) -> bool:
	return player != null and player.has_talent(talent_id) and has_any_essence(player, essence_ids)

static func active_talent_synergies(player: Player) -> Array:
	var out: Array = []
	if has_talent_tags(player, "bloodlust", ["death", "blood", "drain"]):
		out.append("Bloodlust + Death/Blood essences: kill heals +1 HP.")
	if has_talent_tags(player, "arcane_flow", ["arcane", "death", "void"]):
		out.append("Arcane Flow + Arcane/Death/Void essences: kill restores more MP.")
	if has_talent_tags(player, "venom", ["poison", "nature"]):
		out.append("Venom + Poison essences: poison chance rises and lasts longer.")
	if has_talent_tags(player, "frost_touch", ["cold", "ward"]):
		out.append("Frost Touch + Cold/Ward essences: freeze lasts longer.")
	if has_talent_tags(player, "momentum", ["storm", "speed"]):
		out.append("Momentum + Storm/Speed essences: free follow-up chance rises.")
	if has_talent_tags(player, "soul_tap", ["arcane", "death", "void"]):
		out.append("Soul Tap + Arcane/Death/Void essences: spell crits restore more MP.")
	if has_talent_tags(player, "cleave", ["fire", "fury"]):
		out.append("Cleave + Fire/Fury essences: splash burns harder and longer.")
	if has_talent_tags(player, "shadow_step", ["shadow", "void"]):
		out.append("Shadow Step + Shadow/Void essences: dodge blink becomes more reliable.")
	if has_talent_tags(player, "purify", ["ward", "will", "fortify"]):
		out.append("Purify + Ward/Will essences: cleanse comes faster and heals more.")
	if has_talent_tags(player, "unstoppable", ["stone", "fortify", "giant"]):
		out.append("Unstoppable + Stone/Fortify/Giant essences: low-HP threshold becomes sturdier.")
	if has_talent_tags(player, "execute", ["poison", "plague", "death"]):
		out.append("Execute + Poison/Plague essences: finishers trigger sooner.")
	if has_talent_tags(player, "volley", ["storm", "speed", "ranged"]):
		out.append("Volley + Storm/Speed essences: secondary shots spread wider.")
	if has_talent_tags(player, "multishot", ["storm", "speed", "ranged"]):
		out.append("Multishot + Storm/Speed essences: straight-line pierce extends further.")
	if has_talent_tags(player, "arcane_surge", ["arcane", "fire"]):
		out.append("Arcane Surge + Arcane/Fire essences: free-cast surge procs more often.")
	if has_talent_tags(player, "last_rites", ["death", "void"]):
		out.append("Last Rites + Death/Void essences: revival returns with more life.")
	return out

static func has_venom_touch(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_venom")

static func has_drain_touch(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_undeath")

static func has_blood_heal(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_blood")

static func has_hydra_double(player: Player) -> bool:
	return player != null and player.essence_slots.has("essence_hydra")

static func melee_flat_bonus(player: Player) -> int:
	if player == null:
		return 0
	var bonus: int = 0
	if player.essence_slots.has("essence_war_cry"):
		bonus += 2
	return bonus

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
	if player.essence_slots.has("essence_nimble"):
		bonus += 2
	if player.essence_slots.has("essence_shadow"):
		bonus += 2
	if player.essence_slots.has("essence_tracker"):
		bonus += 3
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

static func bonus_ac(player: Player) -> int:
	if player == null:
		return 0
	var total: int = 0
	if player.essence_slots.has("essence_stone"):
		total += 2
	if player.essence_slots.has("essence_bastion"):
		total += 2
	if player.essence_slots.has("essence_marrow"):
		total += 1
	if player.essence_slots.has("essence_scales"):
		total += 2
	if player.essence_slots.has("essence_swiftness"):
		total -= 1
	if player.essence_slots.has("essence_fury"):
		total -= 1
	if player.essence_slots.has("essence_tempest"):
		total -= 1
	if player.essence_slots.has("essence_pack"):
		total -= 1
	if player.essence_slots.has("essence_hydra"):
		total -= 1
	return total

static func bonus_ev(player: Player) -> int:
	if player == null:
		return 0
	var total: int = 0
	if player.essence_slots.has("essence_swiftness"):
		total += 1
	if player.essence_slots.has("essence_nimble"):
		total += 1
	if player.essence_slots.has("essence_shadow"):
		total += 1
	if player.essence_slots.has("essence_vitality"):
		total -= 1
	if player.essence_slots.has("essence_bastion"):
		total -= 2
	if player.essence_slots.has("essence_scales"):
		total -= 1
	if player.essence_slots.has("essence_war_cry"):
		total -= 1
	if player.essence_slots.has("essence_titan"):
		total -= 2
	if player.essence_slots.has("essence_golden"):
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
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_MELEE_FIRE") % [monster.data.loc_name(), fire_dmg])
				if randf() < 0.35 and monster.hp > 0:
					Status.apply(monster, "burning", 2)
		elif effect_id == "cinder_fire":
			var fire_dmg: int = Status.resist_scale(2, monster.data.resists, "fire")
			if fire_dmg > 0:
				monster.take_damage(fire_dmg)
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_CINDER_FIRE") % [monster.data.loc_name(), fire_dmg])
		elif effect_id == "melee_chill":
			if randf() < 0.4:
				Status.apply(monster, "frozen", 1)
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_MELEE_CHILL") % monster.data.loc_name())
		elif effect_id == "venom_touch":
			var venom_dmg: int = Status.resist_scale(1, monster.data.resists, "poison")
			if venom_dmg > 0:
				monster.take_damage(venom_dmg)
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_VENOM_TOUCH") % [monster.data.loc_name(), venom_dmg])
			if not monster.is_aware and has_synergy(player, "essence_swiftness", "essence_venom"):
				Status.apply(monster, "poison", int(5 * FaithSystem.resonance_mult(player)))
		elif effect_id == "serpent_poison":
			if not monster.is_aware:
				Status.apply(monster, "poison", int(5 * FaithSystem.resonance_mult(player)))
			elif randf() < 0.25:
				Status.apply(monster, "poison", int(3 * FaithSystem.resonance_mult(player)))
		elif effect_id == "dread_fear":
			if randf() < 0.20 and monster.hp > 0:
				Status.apply(monster, "feared", int(2 * FaithSystem.resonance_mult(player)))
		elif effect_id == "fang_poison":
			var fang_dmg: int = Status.resist_scale(2, monster.data.resists, "poison")
			if fang_dmg > 0:
				monster.take_damage(fang_dmg)
			Status.apply(monster, "poison", int(4 * FaithSystem.resonance_mult(player)))
			CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_FANG_POISON") % monster.data.loc_name())
		elif effect_id == "shadow_blind":
			if randf() < 0.20 and monster.hp > 0:
				Status.apply(monster, "blind", 2)
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_SHADOW_BLIND") % monster.data.loc_name())
		elif effect_id == "blood_heal":
			player.heal(2)
		elif effect_id == "wither_corrode":
			Status.apply(monster, "corroded", 3)
			CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_WITHER_CORRODE") % monster.data.loc_name())
		elif effect_id == "constrict_slow":
			if randf() < 0.25 and monster.hp > 0:
				Status.apply(monster, "slow", 3)
				CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_CONSTRICT_SLOW") % monster.data.loc_name())
		elif effect_id == "abyssal_dark":
			monster.take_damage(2)
			CombatLog.hit(TranslationServer.translate("ESSENCE_LOG_ABYSSAL_DARK") % [monster.data.loc_name(), 2])
	# Gloam + Swiftness resonance: first unaware hit also weakens
	if not monster.is_aware and has_synergy(player, "essence_gloam", "essence_swiftness"):
		Status.apply(monster, "weak", int(2 * FaithSystem.resonance_mult(player)))

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
		elif effect_id == "bloodwake_kill":
			player.heal(5)
			var wake_dur: int = 3 if has_bloodwake_fury else 2
			Status.apply(player, "damage_boost", wake_dur)
		elif effect_id == "on_kill_pack":
			Status.apply(player, "damage_boost", 1)
	if has_synergy(player, "essence_fury", "essence_drain"):
		player.heal(2)
