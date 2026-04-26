extends Node

const _SHORT_SWORD: Resource = preload("res://resources/items/short_sword.tres")
const _DAGGER: Resource = preload("res://resources/items/dagger.tres")
const _MACE: Resource = preload("res://resources/items/mace.tres")
const _LONG_SWORD: Resource = preload("res://resources/items/long_sword.tres")
const _LEATHER_ARMOR: Resource = preload("res://resources/items/leather_armor.tres")
const _ROBE: Resource = preload("res://resources/items/robe.tres")
const _CHAIN_MAIL: Resource = preload("res://resources/items/chain_mail.tres")
const _POTION_HEALING: Resource = preload("res://resources/items/potion_healing.tres")
const _POTION_MIGHT: Resource = preload("res://resources/items/potion_might.tres")
const _POTION_CURE_POISON: Resource = preload("res://resources/items/potion_cure_poison.tres")
const _POTION_MAGIC: Resource = preload("res://resources/items/potion_magic.tres")
const _SCROLL_BLINKING: Resource = preload("res://resources/items/scroll_blinking.tres")
const _SCROLL_MAGIC_MAPPING: Resource = preload("res://resources/items/scroll_magic_mapping.tres")
const _SCROLL_TELEPORT: Resource = preload("res://resources/items/scroll_teleport.tres")
const _SCROLL_ENCHANT_WEAPON: Resource = preload("res://resources/items/scroll_enchant_weapon.tres")
const _SCROLL_ENCHANT_ARMOR: Resource = preload("res://resources/items/scroll_enchant_armor.tres")
const _GOLD_PILE: Resource = preload("res://resources/items/gold_pile.tres")
const _BATTLE_AXE: Resource = preload("res://resources/items/battle_axe.tres")
const _FLAMING_SWORD: Resource = preload("res://resources/items/flaming_sword.tres")
const _FROST_DAGGER: Resource = preload("res://resources/items/frost_dagger.tres")
const _VENOM_DAGGER: Resource = preload("res://resources/items/venom_dagger.tres")
const _SHOCK_MACE: Resource = preload("res://resources/items/shock_mace.tres")
const _POTION_BERSERK: Resource = preload("res://resources/items/potion_berserk.tres")
const _SCROLL_IDENTIFY: Resource = preload("res://resources/items/scroll_identify.tres")
const _SCROLL_SHROUDING: Resource = preload("res://resources/items/scroll_shrouding.tres")
const _BOOK_EVOCATION: Resource = preload("res://resources/items/book_evocation.tres")
const _BOOK_CONJURATION: Resource = preload("res://resources/items/book_conjuration.tres")
const _BOOK_TRANSMUTATION: Resource = preload("res://resources/items/book_transmutation.tres")
const _BOOK_NECROMANCY: Resource = preload("res://resources/items/book_necromancy.tres")
const _BOOK_ABJURATION: Resource = preload("res://resources/items/book_abjuration.tres")
const _BOOK_ENCHANTMENT: Resource = preload("res://resources/items/book_enchantment.tres")
const _SPEAR: Resource = preload("res://resources/items/spear.tres")
const _RING_STR: Resource = preload("res://resources/items/ring_str.tres")
const _RING_INT: Resource = preload("res://resources/items/ring_int.tres")
const _RING_DEX: Resource = preload("res://resources/items/ring_dex.tres")
const _RING_PROTECTION: Resource = preload("res://resources/items/ring_protection.tres")
const _AMULET_LIFE: Resource = preload("res://resources/items/amulet_life.tres")
const _AMULET_MAGIC: Resource = preload("res://resources/items/amulet_magic.tres")
const _AMULET_STR: Resource = preload("res://resources/items/amulet_str.tres")
const _STILETTO: Resource = preload("res://resources/items/stiletto.tres")
const _DIRK: Resource = preload("res://resources/items/dirk.tres")
const _ASSASSIN_BLADE: Resource = preload("res://resources/items/assassin_blade.tres")
const _QUICK_BLADE: Resource = preload("res://resources/items/quick_blade.tres")
const _ARMING_SWORD: Resource = preload("res://resources/items/arming_sword.tres")
const _BASTARD_SWORD: Resource = preload("res://resources/items/bastard_sword.tres")
const _GREAT_BLADE: Resource = preload("res://resources/items/great_blade.tres")
const _BUCKLER: Resource = preload("res://resources/items/buckler.tres")
const _ROUND_SHIELD: Resource = preload("res://resources/items/round_shield.tres")
const _KITE_SHIELD: Resource = preload("res://resources/items/kite_shield.tres")
const _TOWER_SHIELD: Resource = preload("res://resources/items/tower_shield.tres")
const _SHORTBOW: Resource = preload("res://resources/items/shortbow.tres")
const _LONGBOW: Resource = preload("res://resources/items/longbow.tres")
const _CROSSBOW: Resource = preload("res://resources/items/crossbow.tres")
const _BANDAGE: Resource = preload("res://resources/items/bandage.tres")
const _STAFF: Resource = preload("res://resources/items/staff.tres")
# Potions (new)
const _POTION_HASTE: Resource = preload("res://resources/items/potion_haste.tres")
const _POTION_INVISIBLE: Resource = preload("res://resources/items/potion_invisible.tres")
const _POTION_AGILITY: Resource = preload("res://resources/items/potion_agility.tres")
const _POTION_BRILLIANCE: Resource = preload("res://resources/items/potion_brilliance.tres")
const _POTION_EXPERIENCE: Resource = preload("res://resources/items/potion_experience.tres")
# Scrolls (new)
const _SCROLL_FEAR: Resource = preload("res://resources/items/scroll_fear.tres")
const _SCROLL_UPGRADE: Resource = preload("res://resources/items/scroll_upgrade.tres")
const _SCROLL_FOG: Resource = preload("res://resources/items/scroll_fog.tres")
const _SCROLL_BRAND: Resource = preload("res://resources/items/scroll_brand.tres")
const _SCROLL_SILENCE: Resource = preload("res://resources/items/scroll_silence.tres")
# Wands
const _WAND_FIRE: Resource = preload("res://resources/items/wand_fire.tres")
const _WAND_FROST: Resource = preload("res://resources/items/wand_frost.tres")
const _WAND_LIGHTNING: Resource = preload("res://resources/items/wand_lightning.tres")
const _WAND_TELEPORT: Resource = preload("res://resources/items/wand_teleport.tres")
const _WAND_FEAR: Resource = preload("res://resources/items/wand_fear.tres")
const _WAND_HASTE: Resource = preload("res://resources/items/wand_haste.tres")
const _WAND_DIGGING: Resource = preload("res://resources/items/wand_digging.tres")
# Throwing
const _THROWING_KNIFE: Resource = preload("res://resources/items/throwing_knife.tres")
const _JAVELIN: Resource = preload("res://resources/items/javelin.tres")
const _BOMB: Resource = preload("res://resources/items/bomb.tres")
const _POISON_FLASK: Resource = preload("res://resources/items/poison_flask.tres")
const _SMOKE_BOMB: Resource = preload("res://resources/items/smoke_bomb.tres")

const _ALL_ITEMS: Array = [
	_SHORT_SWORD, _DAGGER, _MACE, _LONG_SWORD, _BATTLE_AXE, _SPEAR,
	_STILETTO, _DIRK, _ASSASSIN_BLADE, _QUICK_BLADE,
	_ARMING_SWORD, _BASTARD_SWORD, _GREAT_BLADE,
	_RING_STR, _RING_INT, _RING_DEX, _RING_PROTECTION,
	_AMULET_LIFE, _AMULET_MAGIC, _AMULET_STR,
	_BUCKLER, _ROUND_SHIELD, _KITE_SHIELD, _TOWER_SHIELD,
	_SHORTBOW, _LONGBOW, _CROSSBOW,
	_FLAMING_SWORD, _FROST_DAGGER, _VENOM_DAGGER, _SHOCK_MACE,
	_LEATHER_ARMOR, _ROBE, _CHAIN_MAIL,
	_POTION_HEALING, _POTION_MIGHT, _POTION_CURE_POISON, _POTION_MAGIC,
	_POTION_BERSERK, _BANDAGE, _STAFF,
	_POTION_HASTE, _POTION_INVISIBLE, _POTION_AGILITY,
	_POTION_BRILLIANCE, _POTION_EXPERIENCE,
	_SCROLL_BLINKING, _SCROLL_MAGIC_MAPPING, _SCROLL_TELEPORT,
	_SCROLL_ENCHANT_WEAPON, _SCROLL_ENCHANT_ARMOR, _SCROLL_IDENTIFY,
	_SCROLL_SHROUDING,
	_SCROLL_FEAR, _SCROLL_UPGRADE, _SCROLL_FOG, _SCROLL_BRAND, _SCROLL_SILENCE,
	_BOOK_EVOCATION, _BOOK_CONJURATION, _BOOK_TRANSMUTATION,
	_BOOK_NECROMANCY, _BOOK_ABJURATION, _BOOK_ENCHANTMENT,
	_GOLD_PILE,
	_WAND_FIRE, _WAND_FROST, _WAND_LIGHTNING, _WAND_TELEPORT,
	_WAND_FEAR, _WAND_HASTE, _WAND_DIGGING,
	_THROWING_KNIFE, _JAVELIN, _BOMB, _POISON_FLASK, _SMOKE_BOMB,
]

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in _ALL_ITEMS:
		_register(res)
	if all.is_empty():
		push_warning("ItemRegistry: 0 items registered.")

func _register(res) -> void:
	if res == null:
		return
	if not ("id" in res):
		return
	if String(res.id) == "":
		return
	by_id[String(res.id)] = res
	all.append(res)

func get_by_id(id: String) -> ItemData:
	return by_id.get(id)

func pick_by_depth(depth: int, kind_filter: String = "") -> ItemData:
	var candidates: Array = []
	for it in all:
		if kind_filter != "" and it.kind != kind_filter:
			continue
		if depth >= it.tier:
			candidates.append(it)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]

func pick_floor_loot(depth: int) -> ItemData:
	var roll: float = randf()
	if roll < 0.38:
		return _pick_weighted(depth, ["potion"])
	if roll < 0.68:
		return _pick_weighted(depth, ["scroll"])
	if roll < 0.74:
		return _pick_weighted(depth, ["book"])
	if roll < 0.82:
		return _pick_weighted(depth, ["wand", "throwing"])
	if roll < 0.88:
		return _pick_weighted(depth, ["gold"])
	return _pick_weighted(depth, ["weapon", "armor", "ring", "amulet", "shield"])

func _pick_weighted(depth: int, kinds: Array[String]) -> ItemData:
	var candidates: Array = []
	for it in all:
		if depth < it.tier:
			continue
		if not kinds.has(String(it.kind)):
			continue
		candidates.append(it)
	if candidates.is_empty():
		return pick_by_depth(depth)
	return candidates[randi() % candidates.size()]
