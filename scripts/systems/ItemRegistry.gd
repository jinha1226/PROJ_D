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
const _POTION_BERSERK: Resource = preload("res://resources/items/potion_berserk.tres")
const _BOOK_ICE_MAGIC: Resource = preload("res://resources/items/book_ice_magic.tres")

const _ALL_ITEMS: Array = [
	_SHORT_SWORD, _DAGGER, _MACE, _LONG_SWORD, _BATTLE_AXE,
	_LEATHER_ARMOR, _ROBE, _CHAIN_MAIL,
	_POTION_HEALING, _POTION_MIGHT, _POTION_CURE_POISON, _POTION_MAGIC,
	_POTION_BERSERK,
	_SCROLL_BLINKING, _SCROLL_MAGIC_MAPPING, _SCROLL_TELEPORT,
	_SCROLL_ENCHANT_WEAPON, _SCROLL_ENCHANT_ARMOR,
	_BOOK_ICE_MAGIC,
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
