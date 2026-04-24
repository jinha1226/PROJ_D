class_name EssenceSystem extends RefCounted

## Passive essence system. Players collect essences from slain monsters and
## equip up to 3 at a time in StatusDialog. Each essence grants a permanent
## passive bonus while equipped.

const SLOT_COUNT: int = 3

const ESSENCES: Dictionary = {
	"essence_fire": {
		"name": "Fire Essence",
		"desc": "Grants fire resistance.",
		"active_desc": "Melee attacks deal +2 fire damage.",
		"active_effect": "melee_fire",
		"color": Color(1.0, 0.55, 0.25),
		"effect": "resist_fire",
	},
	"essence_cold": {
		"name": "Ice Essence",
		"desc": "Grants cold resistance.",
		"active_desc": "On melee hit, 30% chance to slow enemy (frozen 1 turn).",
		"active_effect": "melee_chill",
		"color": Color(0.5, 0.85, 1.0),
		"effect": "resist_cold",
	},
	"essence_might": {
		"name": "War Essence",
		"desc": "+3 Strength.",
		"active_desc": "Passive STR boost only.",
		"active_effect": "",
		"color": Color(1.0, 0.45, 0.3),
		"effect": "stat_str",
		"value": 3,
	},
	"essence_arcana": {
		"name": "Arcane Essence",
		"desc": "+3 Intelligence — increases magic power.",
		"active_desc": "Passive INT boost only.",
		"active_effect": "",
		"color": Color(0.5, 0.7, 1.0),
		"effect": "stat_int",
		"value": 3,
	},
	"essence_swiftness": {
		"name": "Swift Essence",
		"desc": "+2 Dexterity, +1 Evasion.",
		"active_desc": "On dodge, gain +2 EV for 2 turns.",
		"active_effect": "on_dodge_boost",
		"color": Color(0.4, 1.0, 0.65),
		"effect": "stat_dex",
		"value": 2,
	},
	"essence_vitality": {
		"name": "Life Essence",
		"desc": "+20 maximum HP.",
		"active_desc": "On kill, restore 3 HP.",
		"active_effect": "on_kill_heal",
		"color": Color(0.5, 1.0, 0.55),
		"effect": "hp_max",
		"value": 20,
	},
	"essence_stone": {
		"name": "Stone Essence",
		"desc": "+5 Armor Class.",
		"active_desc": "Passive AC boost only.",
		"active_effect": "",
		"color": Color(0.8, 0.8, 0.65),
		"effect": "ac_bonus",
		"value": 5,
	},
	"essence_warding": {
		"name": "Ward Essence",
		"desc": "+8 Will — resists hostile magic.",
		"active_desc": "Passive Will boost only.",
		"active_effect": "",
		"color": Color(0.75, 0.5, 1.0),
		"effect": "wl_bonus",
		"value": 8,
	},
	"essence_regeneration": {
		"name": "Regen Essence",
		"desc": "Recover 1 HP per turn.",
		"active_desc": "Passive: heal 1 HP per turn.",
		"active_effect": "regen",
		"color": Color(0.6, 1.0, 0.7),
		"effect": "regen",
	},
	"essence_venom": {
		"name": "Venom Essence",
		"desc": "Melee attacks poison enemies.",
		"active_desc": "Melee attacks inflict poison (3 turns).",
		"active_effect": "venom_touch",
		"color": Color(0.45, 1.0, 0.4),
		"effect": "venom_touch",
	},
	"essence_fury": {
		"name": "Fury Essence",
		"desc": "On kill, +4 damage to next melee attack.",
		"active_desc": "On kill: next melee hit deals +4 bonus damage.",
		"active_effect": "on_kill_fury",
		"color": Color(1.0, 0.3, 0.2),
		"effect": "fury",
	},
	"essence_drain": {
		"name": "Drain Essence",
		"desc": "On kill, absorb 5 HP from slain enemy.",
		"active_desc": "On kill: drain 5 HP from enemy corpse.",
		"active_effect": "on_kill_drain",
		"color": Color(0.7, 0.3, 1.0),
		"effect": "drain",
	},
}

static func all_ids() -> Array:
	return ESSENCES.keys()

static func display_name(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("name", id))

static func description(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("desc", ""))

static func color_of(id: String) -> Color:
	return ESSENCES.get(id, {}).get("color", Color(0.8, 0.8, 0.85))

static func random_id() -> String:
	var keys: Array = ESSENCES.keys()
	return keys[randi() % keys.size()]

# ── Apply / Remove ────────────────────────────────────────────────────────────

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
		"fury", "drain":
			pass  # effects are triggered, not applied on equip
		# "regen" and "venom_touch" are handled in tick() / CombatSystem
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
		"fury", "drain":
			pass
	player.emit_signal("stats_changed")

# Called from Player.tick_statuses() each player turn.
static func tick(player: Player) -> void:
	for slot in player.essence_slots:
		if slot == "essence_regeneration" and player.hp < player.hp_max:
			player.heal(1)

# Called from CombatSystem after a successful melee hit.
static func has_venom_touch(player: Player) -> bool:
	return player.essence_slots.has("essence_venom")

static func active_desc(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("active_desc", ""))

static func active_effect(id: String) -> String:
	return String(ESSENCES.get(id, {}).get("active_effect", ""))

# Called from CombatSystem after a successful player melee hit.
static func apply_melee_hit_effects(player: Player, monster: Monster) -> void:
	for slot in player.essence_slots:
		var ae: String = active_effect(slot)
		if ae == "melee_fire":
			var dmg: int = 2
			dmg = Status.resist_scale(dmg, monster.data.resists, "fire")
			if dmg > 0:
				monster.take_damage(dmg)
		elif ae == "melee_chill":
			if randf() < 0.3:
				Status.apply(monster, "frozen", 1)

# Called from CombatSystem after player kills a monster.
static func apply_on_kill_effects(player: Player) -> void:
	for slot in player.essence_slots:
		var ae: String = active_effect(slot)
		if ae == "on_kill_heal":
			player.heal(3)
		elif ae == "on_kill_fury":
			Status.apply(player, "damage_boost", 1)
		elif ae == "on_kill_drain":
			player.heal(5)
