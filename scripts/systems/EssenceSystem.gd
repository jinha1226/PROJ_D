class_name EssenceSystem extends RefCounted

## Passive essence system. Players collect essences from slain monsters and
## equip up to 3 at a time in StatusDialog. Each essence grants a permanent
## passive bonus while equipped.

const SLOT_COUNT: int = 3

const ESSENCES: Dictionary = {
	"essence_fire": {
		"name": "Fire Essence",
		"desc": "Grants fire resistance.",
		"color": Color(1.0, 0.55, 0.25),
		"effect": "resist_fire",
	},
	"essence_cold": {
		"name": "Ice Essence",
		"desc": "Grants cold resistance.",
		"color": Color(0.5, 0.85, 1.0),
		"effect": "resist_cold",
	},
	"essence_might": {
		"name": "War Essence",
		"desc": "+3 Strength.",
		"color": Color(1.0, 0.45, 0.3),
		"effect": "stat_str",
		"value": 3,
	},
	"essence_arcana": {
		"name": "Arcane Essence",
		"desc": "+3 Intelligence — increases magic power.",
		"color": Color(0.5, 0.7, 1.0),
		"effect": "stat_int",
		"value": 3,
	},
	"essence_swiftness": {
		"name": "Swift Essence",
		"desc": "+2 Dexterity, +1 Evasion.",
		"color": Color(0.4, 1.0, 0.65),
		"effect": "stat_dex",
		"value": 2,
	},
	"essence_vitality": {
		"name": "Life Essence",
		"desc": "+20 maximum HP.",
		"color": Color(0.5, 1.0, 0.55),
		"effect": "hp_max",
		"value": 20,
	},
	"essence_stone": {
		"name": "Stone Essence",
		"desc": "+5 Armor Class.",
		"color": Color(0.8, 0.8, 0.65),
		"effect": "ac_bonus",
		"value": 5,
	},
	"essence_warding": {
		"name": "Ward Essence",
		"desc": "+8 Will — resists hostile magic.",
		"color": Color(0.75, 0.5, 1.0),
		"effect": "wl_bonus",
		"value": 8,
	},
	"essence_regeneration": {
		"name": "Regen Essence",
		"desc": "Recover 1 HP per turn.",
		"color": Color(0.6, 1.0, 0.7),
		"effect": "regen",
	},
	"essence_venom": {
		"name": "Venom Essence",
		"desc": "Melee attacks poison enemies.",
		"color": Color(0.45, 1.0, 0.4),
		"effect": "venom_touch",
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
	player.emit_signal("stats_changed")

# Called from Player.tick_statuses() each player turn.
static func tick(player: Player) -> void:
	for slot in player.essence_slots:
		if slot == "essence_regeneration" and player.hp < player.hp_max:
			player.heal(1)

# Called from CombatSystem after a successful melee hit.
static func has_venom_touch(player: Player) -> bool:
	return player.essence_slots.has("essence_venom")
