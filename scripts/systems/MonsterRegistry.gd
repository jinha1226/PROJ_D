extends Node

# ── Original 18 ───────────────────────────────────────────────────────────────
const _RAT: Resource = preload("res://resources/monsters/rat.tres")
const _BAT: Resource = preload("res://resources/monsters/bat.tres")
const _KOBOLD: Resource = preload("res://resources/monsters/kobold.tres")
const _GOBLIN: Resource = preload("res://resources/monsters/goblin.tres")
const _HOBGOBLIN: Resource = preload("res://resources/monsters/hobgoblin.tres")
const _ADDER: Resource = preload("res://resources/monsters/adder.tres")
const _GNOLL: Resource = preload("res://resources/monsters/gnoll.tres")
const _ORC: Resource = preload("res://resources/monsters/orc.tres")
const _OGRE: Resource = preload("res://resources/monsters/ogre.tres")
const _ORC_WIZARD: Resource = preload("res://resources/monsters/orc_wizard.tres")
const _TROLL: Resource = preload("res://resources/monsters/troll.tres")
const _MINOTAUR: Resource = preload("res://resources/monsters/minotaur.tres")
const _DEEP_ELF_ARCHER: Resource = preload("res://resources/monsters/deep_elf_archer.tres")
const _GIANT_WOLF_SPIDER: Resource = preload("res://resources/monsters/giant_wolf_spider.tres")
const _GNOLL_SHAMAN: Resource = preload("res://resources/monsters/gnoll_shaman.tres")
const _WIGHT: Resource = preload("res://resources/monsters/wight.tres")
const _MUMMY: Resource = preload("res://resources/monsters/mummy.tres")
const _STONE_GIANT: Resource = preload("res://resources/monsters/stone_giant.tres")

# ── Tier 1 ────────────────────────────────────────────────────────────────────
const _WOLF: Resource = preload("res://resources/monsters/wolf.tres")
const _HOUND: Resource = preload("res://resources/monsters/hound.tres")
const _JACKAL: Resource = preload("res://resources/monsters/jackal.tres")
const _GIANT_COCKROACH: Resource = preload("res://resources/monsters/giant_cockroach.tres")
const _HORNET: Resource = preload("res://resources/monsters/hornet.tres")

# ── Tier 2 ────────────────────────────────────────────────────────────────────
const _ORC_WARRIOR: Resource = preload("res://resources/monsters/orc_warrior.tres")
const _VAMPIRE_BAT: Resource = preload("res://resources/monsters/vampire_bat.tres")
const _ZOMBIE: Resource = preload("res://resources/monsters/zombie.tres")
const _SCORPION: Resource = preload("res://resources/monsters/scorpion.tres")
const _YAK: Resource = preload("res://resources/monsters/yak.tres")
const _WARG: Resource = preload("res://resources/monsters/warg.tres")
const _ORC_PRIEST: Resource = preload("res://resources/monsters/orc_priest.tres")

# ── Tier 3 ────────────────────────────────────────────────────────────────────
const _GNOLL_SERGEANT: Resource = preload("res://resources/monsters/gnoll_sergeant.tres")
const _BLACK_BEAR: Resource = preload("res://resources/monsters/black_bear.tres")
const _GHOUL: Resource = preload("res://resources/monsters/ghoul.tres")
const _CRIMSON_IMP: Resource = preload("res://resources/monsters/crimson_imp.tres")
const _SKELETAL_WARRIOR: Resource = preload("res://resources/monsters/skeletal_warrior.tres")
const _CENTAUR: Resource = preload("res://resources/monsters/centaur.tres")
const _GARGOYLE: Resource = preload("res://resources/monsters/gargoyle.tres")
const _EARTH_ELEMENTAL: Resource = preload("res://resources/monsters/earth_elemental.tres")
const _FIRE_ELEMENTAL: Resource = preload("res://resources/monsters/fire_elemental.tres")
const _PHANTOM: Resource = preload("res://resources/monsters/phantom.tres")
const _STEAM_DRAGON: Resource = preload("res://resources/monsters/steam_dragon.tres")
const _BASILISK: Resource = preload("res://resources/monsters/basilisk.tres")

# ── Tier 4 ────────────────────────────────────────────────────────────────────
const _TWO_HEADED_OGRE: Resource = preload("res://resources/monsters/two_headed_ogre.tres")
const _CYCLOPS: Resource = preload("res://resources/monsters/cyclops.tres")
const _WRAITH: Resource = preload("res://resources/monsters/wraith.tres")
const _VAMPIRE: Resource = preload("res://resources/monsters/vampire.tres")
const _MANTICORE: Resource = preload("res://resources/monsters/manticore.tres")
const _RED_DEVIL: Resource = preload("res://resources/monsters/red_devil.tres")
const _DEEP_TROLL: Resource = preload("res://resources/monsters/deep_troll.tres")
const _REVENANT: Resource = preload("res://resources/monsters/revenant.tres")
const _WYVERN: Resource = preload("res://resources/monsters/wyvern.tres")
const _SWAMP_DRAGON: Resource = preload("res://resources/monsters/swamp_dragon.tres")

# ── Tier 5 ────────────────────────────────────────────────────────────────────
const _OGRE_MAGE: Resource = preload("res://resources/monsters/ogre_mage.tres")
const _IRON_GOLEM: Resource = preload("res://resources/monsters/iron_golem.tres")
const _VAMPIRE_KNIGHT: Resource = preload("res://resources/monsters/vampire_knight.tres")
const _FIRE_DRAGON: Resource = preload("res://resources/monsters/fire_dragon.tres")
const _ICE_DRAGON: Resource = preload("res://resources/monsters/ice_dragon.tres")
const _LICH: Resource = preload("res://resources/monsters/lich.tres")
const _ICE_DEVIL: Resource = preload("res://resources/monsters/ice_devil.tres")
const _BALRUG: Resource = preload("res://resources/monsters/balrug.tres")
const _FROST_GIANT: Resource = preload("res://resources/monsters/frost_giant.tres")
const _FIRE_GIANT: Resource = preload("res://resources/monsters/fire_giant.tres")
const _BONE_DRAGON: Resource = preload("res://resources/monsters/bone_dragon.tres")
const _DEEP_ELF_DEATH_MAGE: Resource = preload("res://resources/monsters/deep_elf_death_mage.tres")

# ── Tier 6 ────────────────────────────────────────────────────────────────────
const _ANCIENT_LICH: Resource = preload("res://resources/monsters/ancient_lich.tres")
const _GOLDEN_DRAGON: Resource = preload("res://resources/monsters/golden_dragon.tres")
const _EXECUTIONER: Resource = preload("res://resources/monsters/executioner.tres")
const _TITAN: Resource = preload("res://resources/monsters/titan.tres")

# ── Unique sector monsters ─────────────────────────────────────────────────────
const _ASHEN_MAGPIE: Resource = preload("res://resources/monsters/ashen_magpie.tres")
const _SISTER_CINDER: Resource = preload("res://resources/monsters/sister_cinder.tres")
const _VIPER_SAINT: Resource = preload("res://resources/monsters/viper_saint.tres")
const _STONE_WARDEN: Resource = preload("res://resources/monsters/stone_warden.tres")
const _HARROW_KNIGHT: Resource = preload("res://resources/monsters/harrow_knight.tres")
const _BLOOD_DUKE: Resource = preload("res://resources/monsters/blood_duke.tres")
const _STORM_HIEROPHANT: Resource = preload("res://resources/monsters/storm_hierophant.tres")
const _PALE_SCHOLAR: Resource = preload("res://resources/monsters/pale_scholar.tres")

const _UNIQUE_MONSTERS: Array = [
	_ASHEN_MAGPIE, _SISTER_CINDER, _VIPER_SAINT, _STONE_WARDEN,
	_HARROW_KNIGHT, _BLOOD_DUKE, _STORM_HIEROPHANT, _PALE_SCHOLAR,
]

const _ALL_MONSTERS: Array = [
	# original 18
	_RAT, _BAT, _KOBOLD, _GOBLIN, _HOBGOBLIN, _ADDER, _GNOLL,
	_ORC, _OGRE, _ORC_WIZARD, _TROLL, _MINOTAUR, _DEEP_ELF_ARCHER,
	_GIANT_WOLF_SPIDER, _GNOLL_SHAMAN, _WIGHT, _MUMMY, _STONE_GIANT,
	# tier 1
	_WOLF, _HOUND, _JACKAL, _GIANT_COCKROACH, _HORNET,
	# tier 2
	_ORC_WARRIOR, _VAMPIRE_BAT, _ZOMBIE, _SCORPION, _YAK, _WARG, _ORC_PRIEST,
	# tier 3
	_GNOLL_SERGEANT, _BLACK_BEAR, _GHOUL, _CRIMSON_IMP, _SKELETAL_WARRIOR,
	_CENTAUR, _GARGOYLE, _EARTH_ELEMENTAL, _FIRE_ELEMENTAL, _PHANTOM,
	_STEAM_DRAGON, _BASILISK,
	# tier 4
	_TWO_HEADED_OGRE, _CYCLOPS, _WRAITH, _VAMPIRE, _MANTICORE, _RED_DEVIL,
	_DEEP_TROLL, _REVENANT, _WYVERN, _SWAMP_DRAGON,
	# tier 5
	_OGRE_MAGE, _IRON_GOLEM, _VAMPIRE_KNIGHT, _FIRE_DRAGON, _ICE_DRAGON,
	_LICH, _ICE_DEVIL, _BALRUG, _FROST_GIANT, _FIRE_GIANT, _BONE_DRAGON,
	_DEEP_ELF_DEATH_MAGE,
	# tier 6
	_ANCIENT_LICH, _GOLDEN_DRAGON, _EXECUTIONER, _TITAN,
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
