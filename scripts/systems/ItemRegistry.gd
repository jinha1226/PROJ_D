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
const _TOWER_SHIELD: Resource = preload("res://resources/items/tower_shield.tres")
const _BANDAGE: Resource = preload("res://resources/items/bandage.tres")

const _ALL_ITEMS: Array = [
	_SHORT_SWORD, _DAGGER, _MACE, _LONG_SWORD, _BATTLE_AXE, _SPEAR,
	_STILETTO, _DIRK, _ASSASSIN_BLADE, _QUICK_BLADE,
	_ARMING_SWORD, _BASTARD_SWORD, _GREAT_BLADE,
	_RING_STR, _RING_INT, _RING_DEX, _RING_PROTECTION,
	_AMULET_LIFE, _AMULET_MAGIC, _AMULET_STR,
	_BUCKLER, _ROUND_SHIELD, _TOWER_SHIELD,
	_FLAMING_SWORD, _FROST_DAGGER, _VENOM_DAGGER, _SHOCK_MACE,
	_LEATHER_ARMOR, _ROBE, _CHAIN_MAIL,
	_POTION_HEALING, _POTION_MIGHT, _POTION_CURE_POISON, _POTION_MAGIC,
	_POTION_BERSERK, _BANDAGE,
	_SCROLL_BLINKING, _SCROLL_MAGIC_MAPPING, _SCROLL_TELEPORT,
	_SCROLL_ENCHANT_WEAPON, _SCROLL_ENCHANT_ARMOR, _SCROLL_IDENTIFY,
	_BOOK_EVOCATION, _BOOK_CONJURATION, _BOOK_TRANSMUTATION,
	_BOOK_NECROMANCY, _BOOK_ABJURATION, _BOOK_ENCHANTMENT,
	_GOLD_PILE,
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
