extends Node

# ── Z1 Dungeon ────────────────────────────────────────────────────────────────
const _GOBLIN: Resource          = preload("res://resources/monsters/goblin.tres")
const _HOBGOBLIN: Resource       = preload("res://resources/monsters/hobgoblin.tres")
const _KOBOLD: Resource          = preload("res://resources/monsters/kobold.tres")
const _ZOMBIE: Resource          = preload("res://resources/monsters/zombie.tres")
const _SKELETAL_WARRIOR: Resource = preload("res://resources/monsters/skeletal_warrior.tres")
const _ADDER: Resource           = preload("res://resources/monsters/adder.tres")

# ── Z2 Lair ───────────────────────────────────────────────────────────────────
const _WOLF: Resource            = preload("res://resources/monsters/wolf.tres")
const _BLACK_BEAR: Resource      = preload("res://resources/monsters/black_bear.tres")
const _GIANT_WOLF_SPIDER: Resource = preload("res://resources/monsters/giant_wolf_spider.tres")
const _SCORPION: Resource        = preload("res://resources/monsters/scorpion.tres")
const _VIPER: Resource           = preload("res://resources/monsters/viper.tres")
const _ANACONDA: Resource        = preload("res://resources/monsters/anaconda.tres")
const _TROLL: Resource           = preload("res://resources/monsters/troll.tres")

# ── Z3 Orc Mines ──────────────────────────────────────────────────────────────
const _ORC: Resource             = preload("res://resources/monsters/orc.tres")
const _ORC_WARRIOR: Resource     = preload("res://resources/monsters/orc_warrior.tres")
const _ORC_WIZARD: Resource      = preload("res://resources/monsters/orc_wizard.tres")
const _ORC_PRIEST: Resource      = preload("res://resources/monsters/orc_priest.tres")
const _GNOLL: Resource           = preload("res://resources/monsters/gnoll.tres")
const _GNOLL_SERGEANT: Resource  = preload("res://resources/monsters/gnoll_sergeant.tres")
const _GNOLL_SHAMAN: Resource    = preload("res://resources/monsters/gnoll_shaman.tres")
const _OGRE: Resource            = preload("res://resources/monsters/ogre.tres")

# ── Z4 Elven Halls ────────────────────────────────────────────────────────────
const _DEEP_ELF_ARCHER: Resource     = preload("res://resources/monsters/deep_elf_archer.tres")
const _DEEP_ELF_DEATH_MAGE: Resource = preload("res://resources/monsters/deep_elf_death_mage.tres")
const _OGRE_MAGE: Resource       = preload("res://resources/monsters/ogre_mage.tres")
const _VAMPIRE: Resource         = preload("res://resources/monsters/vampire.tres")
const _VAMPIRE_KNIGHT: Resource  = preload("res://resources/monsters/vampire_knight.tres")
const _GARGOYLE: Resource        = preload("res://resources/monsters/gargoyle.tres")
const _STONE_WARDEN: Resource    = preload("res://resources/monsters/stone_warden.tres")

# ── Z5 Crypt ──────────────────────────────────────────────────────────────────
const _WRAITH: Resource          = preload("res://resources/monsters/wraith.tres")
const _SHADOW_WRAITH: Resource   = preload("res://resources/monsters/shadow_wraith.tres")
const _GHOUL: Resource           = preload("res://resources/monsters/ghoul.tres")
const _MUMMY: Resource           = preload("res://resources/monsters/mummy.tres")
const _LICH: Resource            = preload("res://resources/monsters/lich.tres")
const _ANCIENT_LICH: Resource    = preload("res://resources/monsters/ancient_lich.tres")

# ── Z6 Abyss ──────────────────────────────────────────────────────────────────
const _CRIMSON_IMP: Resource     = preload("res://resources/monsters/crimson_imp.tres")
const _RED_DEVIL: Resource       = preload("res://resources/monsters/red_devil.tres")
const _BALRUG: Resource          = preload("res://resources/monsters/balrug.tres")
const _EXECUTIONER: Resource     = preload("res://resources/monsters/executioner.tres")
const _STONE_GIANT: Resource     = preload("res://resources/monsters/stone_giant.tres")
const _TITAN: Resource           = preload("res://resources/monsters/titan.tres")
const _BONE_DRAGON: Resource     = preload("res://resources/monsters/bone_dragon.tres")

# ── Branch regulars ───────────────────────────────────────────────────────────
const _VAMPIRE_BAT: Resource     = preload("res://resources/monsters/vampire_bat.tres")
const _SWAMP_DRAGON: Resource    = preload("res://resources/monsters/swamp_dragon.tres")
const _ICE_DRAGON: Resource      = preload("res://resources/monsters/ice_dragon.tres")
const _FIRE_DRAGON: Resource     = preload("res://resources/monsters/fire_dragon.tres")
const _CYCLOPS: Resource         = preload("res://resources/monsters/cyclops.tres")

# ── Branch bosses (unique) ─────────────────────────────────────────────────────
const _BOG_SERPENT: Resource       = preload("res://resources/monsters/bog_serpent.tres")
const _GLACIAL_SOVEREIGN: Resource = preload("res://resources/monsters/glacial_sovereign.tres")
const _EMBER_TYRANT: Resource      = preload("res://resources/monsters/ember_tyrant.tres")
const _GOLDEN_DRAGON: Resource     = preload("res://resources/monsters/golden_dragon.tres")

const _UNIQUE_MONSTERS: Array = [
	_BOG_SERPENT, _GLACIAL_SOVEREIGN, _EMBER_TYRANT, _GOLDEN_DRAGON,
]

const _ALL_MONSTERS: Array = [
	# Z1 Dungeon
	_GOBLIN, _HOBGOBLIN, _KOBOLD, _ZOMBIE, _SKELETAL_WARRIOR, _ADDER,
	# Z2 Lair
	_WOLF, _BLACK_BEAR, _GIANT_WOLF_SPIDER, _SCORPION, _VIPER, _ANACONDA, _TROLL,
	# Z3 Orc Mines
	_ORC, _ORC_WARRIOR, _ORC_WIZARD, _ORC_PRIEST, _GNOLL, _GNOLL_SERGEANT, _GNOLL_SHAMAN, _OGRE,
	# Z4 Elven Halls
	_DEEP_ELF_ARCHER, _DEEP_ELF_DEATH_MAGE, _OGRE_MAGE, _VAMPIRE, _VAMPIRE_KNIGHT, _GARGOYLE, _STONE_WARDEN,
	# Z5 Crypt
	_WRAITH, _SHADOW_WRAITH, _GHOUL, _MUMMY, _LICH, _ANCIENT_LICH,
	# Z6 Abyss
	_CRIMSON_IMP, _RED_DEVIL, _BALRUG, _EXECUTIONER, _STONE_GIANT, _TITAN, _BONE_DRAGON,
	# Branch regulars
	_VAMPIRE_BAT, _SWAMP_DRAGON, _ICE_DRAGON, _FIRE_DRAGON, _CYCLOPS,
]

var by_id: Dictionary = {}
var all: Array = []
var unique_by_id: Dictionary = {}

func _ready() -> void:
	for res in _ALL_MONSTERS:
		_register(res)
	for res in _UNIQUE_MONSTERS:
		_register(res)
		if res != null and "id" in res and String(res.id) != "":
			unique_by_id[String(res.id)] = res
	if all.is_empty():
		push_warning("MonsterRegistry: 0 monsters registered.")

func _register(res) -> void:
	if res == null:
		return
	if not ("id" in res):
		return
	if String(res.id) == "":
		return
	by_id[String(res.id)] = res
	all.append(res)

func get_by_id(id: String) -> MonsterData:
	return by_id.get(id)

func pick_by_branch(branch_id: String, depth: int) -> MonsterData:
	var pool: Array = ZoneManager.BRANCH_MONSTER_POOLS.get(branch_id, [])
	if pool.is_empty():
		return pick_by_depth(depth)
	var candidates: Array = []
	var total_weight: int = 0
	for m in all:
		if m.is_unique or not pool.has(m.id):
			continue
		# Weight by position in pool — earlier = lighter, later = heavier
		var pool_idx: int = pool.find(m.id)
		var base_w: int = max(1, pool_idx + 1)
		# Bias toward stronger monsters at higher effective depths
		var depth_factor: int = clamp(depth - m.min_depth, 0, 4)
		var eff_w: int = max(1, base_w + depth_factor)
		candidates.append({"data": m, "weight": eff_w})
		total_weight += eff_w
	if candidates.is_empty():
		return pick_by_depth(depth)
	var roll: int = randi_range(1, total_weight)
	var accum: int = 0
	for entry in candidates:
		accum += int(entry["weight"])
		if roll <= accum:
			return entry["data"]
	return candidates[0]["data"]

func pick_by_depth(depth: int) -> MonsterData:
	var candidates: Array = []
	var total_weight: int = 0
	for m in all:
		if m.is_unique:
			continue
		if depth >= m.min_depth and depth <= m.max_depth:
			var eff_weight: int = max(1, m.weight)
			if depth <= 3 and m.xp_value <= 2:
				eff_weight = max(1, int(eff_weight / 4))
			elif depth <= 5 and m.xp_value <= 4:
				eff_weight = max(1, int(eff_weight / 2))
			if depth >= 2 and m.tier >= 2:
				eff_weight += 2
			if depth >= 4 and m.tier >= 3:
				eff_weight += 3
			candidates.append({"data": m, "weight": eff_weight})
			total_weight += eff_weight
	if candidates.is_empty():
		return null
	var roll: int = randi_range(1, total_weight)
	var accum: int = 0
	for entry in candidates:
		accum += int(entry["weight"])
		if roll <= accum:
			return entry["data"]
	return candidates[0]["data"]

func unique_for_depth(depth: int) -> MonsterData:
	for res in _UNIQUE_MONSTERS:
		if res != null and depth >= res.min_depth and depth <= res.max_depth:
			return res as MonsterData
	return null
