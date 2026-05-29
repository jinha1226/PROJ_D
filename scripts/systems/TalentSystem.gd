class_name TalentSystem
extends Node

# ──────────────────────────────────────────────────────────────────────────────
# T0: Jobs (선택: 게임 시작 전, 5개)
# ──────────────────────────────────────────────────────────────────────────────
const JOBS: Dictionary = {
	"fighter": {
		"name": "Fighter",
		"desc": "Stalwart front-liner. Bonus STR and HP. Starts with a sword and chain armor.",
		"color": Color(0.95, 0.7, 0.3, 1.0),
		"str": 2, "dex": 0, "int": 0, "hp": 6, "mp": 0,
		"kit": ["sword", "chain_armor"],
	},
	"rogue": {
		"name": "Rogue",
		"desc": "Quick and cunning. Bonus DEX. Starts with a dagger, leather armor, and poison darts.",
		"color": Color(0.48, 0.84, 0.64, 1.0),
		"str": 0, "dex": 2, "int": 0, "hp": 0, "mp": 0,
		"kit": ["dagger", "leather_armor", "poison_dart", "poison_dart", "poison_dart"],
	},
	"ranger": {
		"name": "Ranger",
		"desc": "Versatile hunter. Bonus DEX and INT. Starts with a bow, leather armor, and a dagger.",
		"color": Color(0.55, 0.82, 0.45, 1.0),
		"str": 0, "dex": 1, "int": 1, "hp": 0, "mp": 0,
		"kit": ["shortbow", "leather_armor", "dagger"],
	},
	"mage": {
		"name": "Mage",
		"desc": "Arcane scholar. Bonus INT and MP. Starts with a staff and two random spellbooks.",
		"color": Color(0.72, 0.56, 0.98, 1.0),
		"str": 0, "dex": 0, "int": 3, "hp": 0, "mp": 6,
		"kit": ["staff", "random_spellbook", "random_spellbook"],
	},
	"cleric": {
		"name": "Cleric",
		"desc": "Warrior-priest. Bonus STR, INT, and HP. Starts with a mace, chain armor, and healing potions.",
		"color": Color(0.85, 0.85, 0.55, 1.0),
		"str": 1, "dex": 0, "int": 1, "hp": 4, "mp": 0,
		"kit": ["mace", "chain_armor", "potion_healing", "potion_healing"],
	},
}

# ──────────────────────────────────────────────────────────────────────────────
# T1~T4: Talents (XL 5/10/15/20에서 각 1개 선택)
# tier: 1~4, concept: 카테고리 레이블
# ──────────────────────────────────────────────────────────────────────────────
const TALENTS: Dictionary = {
	# T1 (XL 5)
	"bloodlust": {
		"name": "Bloodlust",
		"desc": "On kill: recover 2 HP.",
		"tier": 1,
		"concept": "necro",
		"color": Color(0.8, 0.25, 0.35, 1.0),
	},
	"venom": {
		"name": "Venom",
		"desc": "Melee attacks have a 15% chance to apply Poison for 3 turns.",
		"tier": 1,
		"concept": "poison",
		"color": Color(0.38, 0.88, 0.38, 1.0),
	},
	"frost_touch": {
		"name": "Frost Touch",
		"desc": "Melee attacks have a 20% chance to apply Frozen for 1 turn.",
		"tier": 1,
		"concept": "cold",
		"color": Color(0.55, 0.85, 1.0, 1.0),
	},
	"iron_body": {
		"name": "Iron Body",
		"desc": "Immediately gain +8 maximum HP.",
		"tier": 1,
		"concept": "will",
		"color": Color(0.75, 0.75, 0.8, 1.0),
	},
	"arcane_flow": {
		"name": "Arcane Flow",
		"desc": "On kill: recover 1 MP.",
		"tier": 1,
		"concept": "magic",
		"color": Color(0.65, 0.45, 1.0, 1.0),
	},

	# T2 (XL 10)
	"momentum": {
		"name": "Momentum",
		"desc": "On kill: 40% chance your next melee attack costs no action.",
		"tier": 2,
		"concept": "lightning",
		"color": Color(1.0, 0.85, 0.25, 1.0),
	},
	"plague_vector": {
		"name": "Plague Vector",
		"desc": "When a poisoned enemy dies, Poison spreads to all adjacent enemies for 2 turns.",
		"tier": 2,
		"concept": "poison",
		"color": Color(0.3, 0.9, 0.3, 1.0),
	},
	"glacial": {
		"name": "Glacial",
		"desc": "When you are hit in melee, apply Slowed for 1 turn to the attacker.",
		"tier": 2,
		"concept": "cold",
		"color": Color(0.5, 0.8, 1.0, 1.0),
	},
	"soul_tap": {
		"name": "Soul Tap",
		"desc": "On spell critical hit: recover 1 MP.",
		"tier": 2,
		"concept": "necro",
		"color": Color(0.7, 0.3, 0.8, 1.0),
	},
	"chain_strike": {
		"name": "Chain Strike",
		"desc": "Ranged attacks chain to one adjacent enemy for 50% damage.",
		"tier": 2,
		"concept": "lightning",
		"color": Color(1.0, 0.95, 0.4, 1.0),
	},

	# T3 (XL 15)
	"cleave": {
		"name": "Cleave",
		"desc": "Melee attacks deal 40% damage to all adjacent enemies and apply Burning for 1 turn.",
		"tier": 3,
		"concept": "fire",
		"color": Color(1.0, 0.5, 0.15, 1.0),
	},
	"shadow_step": {
		"name": "Shadow Step",
		"desc": "When hit: 15% chance to teleport behind the attacker (passive dodge).",
		"tier": 3,
		"concept": "necro",
		"color": Color(0.5, 0.4, 0.65, 1.0),
	},
	"overload": {
		"name": "Overload",
		"desc": "Spell damage +30%, but MP cost +1 per cast.",
		"tier": 3,
		"concept": "fire",
		"color": Color(1.0, 0.55, 0.2, 1.0),
	},
	"multishot": {
		"name": "Multishot",
		"desc": "Ranged attacks pierce through up to 2 additional enemies in a straight line.",
		"tier": 3,
		"concept": "lightning",
		"color": Color(0.9, 0.9, 0.3, 1.0),
	},
	"purify": {
		"name": "Purify",
		"desc": "Every 20 turns: automatically remove one debuff and recover 3 HP.",
		"tier": 3,
		"concept": "will",
		"color": Color(0.9, 0.9, 0.65, 1.0),
	},

	# T4 (XL 20)
	"unstoppable": {
		"name": "Unstoppable",
		"desc": "Below 30% HP: take 25% less damage and deal 10% more damage.",
		"tier": 4,
		"concept": "will",
		"color": Color(0.85, 0.85, 0.9, 1.0),
	},
	"execute": {
		"name": "Execute",
		"desc": "Instantly kill poisoned or bleeding enemies at 35% HP or below.",
		"tier": 4,
		"concept": "poison",
		"color": Color(0.25, 1.0, 0.4, 1.0),
	},
	"volley": {
		"name": "Volley",
		"desc": "Ranged attacks simultaneously hit 1 additional adjacent enemy for reduced damage.",
		"tier": 4,
		"concept": "lightning",
		"color": Color(1.0, 1.0, 0.35, 1.0),
	},
	"arcane_surge": {
		"name": "Arcane Surge",
		"desc": "12% chance on cast: free (no MP cost) and double damage.",
		"tier": 4,
		"concept": "fire",
		"color": Color(1.0, 0.6, 0.1, 1.0),
	},
	"last_rites": {
		"name": "Last Rites",
		"desc": "Once per run: when you would die, revive with 25% HP instead.",
		"tier": 4,
		"concept": "necro",
		"color": Color(0.65, 0.25, 0.75, 1.0),
	},
}

const TIER_UNLOCK_XL: Dictionary = {1: 5, 2: 10, 3: 15, 4: 20}
const TALENT_IDS_IN_ORDER: Array = [
	"bloodlust", "venom", "frost_touch", "iron_body", "arcane_flow",
	"momentum", "plague_vector", "glacial", "soul_tap", "chain_strike",
	"cleave", "shadow_step", "overload", "multishot", "purify",
	"unstoppable", "execute", "volley", "arcane_surge", "last_rites",
]

# ──────────────────────────────────────────────────────────────────────────────
# Static helpers
# ──────────────────────────────────────────────────────────────────────────────

static func job_ids_in_order() -> Array:
	return ["fighter", "rogue", "ranger", "mage", "cleric"]

static func talent_ids_in_order() -> Array:
	return TALENT_IDS_IN_ORDER.duplicate()

## Returns all talent ids for the given tier (1-4).
static func talents_for_tier(tier: int) -> Array:
	var result: Array = []
	for id in TALENTS.keys():
		if int(TALENTS[id].get("tier", 0)) == tier:
			result.append(id)
	return result

static func get_job(job_id: String) -> Dictionary:
	return JOBS.get(job_id, {})

static func get_talent(talent_id: String) -> Dictionary:
	return TALENTS.get(talent_id, {})

static func job_display_name(job_id: String) -> String:
	return String(get_job(job_id).get("name", job_id.capitalize()))

static func talent_display_name(talent_id: String) -> String:
	return String(get_talent(talent_id).get("name", talent_id.capitalize()))

static func talent_description(talent_id: String) -> String:
	return String(get_talent(talent_id).get("desc", ""))

static func talent_color(talent_id: String) -> Color:
	return get_talent(talent_id).get("color", Color.WHITE)

static func talent_concept(talent_id: String) -> String:
	return String(get_talent(talent_id).get("concept", ""))

# ──────────────────────────────────────────────────────────────────────────────
# Job application (스탯 + 시작 장비)
# ──────────────────────────────────────────────────────────────────────────────

static func apply_job(player, job_id: String) -> void:
	if player == null or job_id == "":
		return
	var data: Dictionary = get_job(job_id)
	if data.is_empty():
		return
	player.job_id = job_id
	var str_bonus: int = int(data.get("str", 0))
	var dex_bonus: int = int(data.get("dex", 0))
	var int_bonus: int = int(data.get("int", 0))
	if str_bonus != 0:
		player.strength = max(1, player.strength + str_bonus)
	if dex_bonus != 0:
		player.dexterity = max(1, player.dexterity + dex_bonus)
	if int_bonus != 0:
		player.intelligence = max(1, player.intelligence + int_bonus)
	var hp_bonus: int = int(data.get("hp", 0))
	if hp_bonus != 0 and player.has_method("_apply_max_hp_gain"):
		player._apply_max_hp_gain(hp_bonus)
	var mp_bonus: int = int(data.get("mp", 0))
	if mp_bonus != 0 and player.has_method("_apply_max_mp_gain"):
		player._apply_max_mp_gain(mp_bonus)
	if player.has_method("refresh_ac_from_equipment"):
		player.refresh_ac_from_equipment()

# ──────────────────────────────────────────────────────────────────────────────
# Talent application (즉시 효과 - iron_body 등)
# ──────────────────────────────────────────────────────────────────────────────

static func apply_talent(player, talent_id: String) -> void:
	if player == null or talent_id == "":
		return
	match talent_id:
		"iron_body":
			if player.has_method("_apply_max_hp_gain"):
				player._apply_max_hp_gain(12)

# Legacy compatibility — old TalentSystem.apply(player, talent_id) calls
# remain functional during the transition period. These routed the old
# job-selection system; now they are no-ops (job_id is applied via apply_job).
static func apply(player, _talent_id: String) -> void:
	pass

# Legacy: ids_in_order was used by TalentSelect for the old 3-talent list.
# Returns job_ids_in_order now so any remaining callers don't crash.
static func ids_in_order() -> Array:
	return job_ids_in_order()

# Legacy display helpers used by TalentSelect scene.
static func display_name(id: String) -> String:
	if JOBS.has(id):
		return job_display_name(id)
	return talent_display_name(id)

static func short_text(id: String) -> String:
	if JOBS.has(id):
		return String(get_job(id).get("desc", ""))
	return String(get_talent(id).get("desc", ""))

static func description_text(id: String) -> String:
	return short_text(id)

static func color(id: String) -> Color:
	if JOBS.has(id):
		return get_job(id).get("color", Color.WHITE)
	return talent_color(id)

static func bonus_lines(_id: String) -> PackedStringArray:
	return PackedStringArray()
