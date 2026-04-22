extends Node

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
const _DEEP_ELF_ARCHER: Resource = preload(
	"res://resources/monsters/deep_elf_archer.tres")
const _GIANT_WOLF_SPIDER: Resource = preload(
	"res://resources/monsters/giant_wolf_spider.tres")
const _GNOLL_SHAMAN: Resource = preload(
	"res://resources/monsters/gnoll_shaman.tres")
const _WIGHT: Resource = preload("res://resources/monsters/wight.tres")
const _MUMMY: Resource = preload("res://resources/monsters/mummy.tres")
const _STONE_GIANT: Resource = preload(
	"res://resources/monsters/stone_giant.tres")

const _ALL_MONSTERS: Array = [
	_RAT, _BAT, _KOBOLD, _GOBLIN, _HOBGOBLIN, _ADDER, _GNOLL,
	_ORC, _OGRE, _ORC_WIZARD, _TROLL, _MINOTAUR, _DEEP_ELF_ARCHER,
	_GIANT_WOLF_SPIDER, _GNOLL_SHAMAN, _WIGHT, _MUMMY, _STONE_GIANT,
]

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in _ALL_MONSTERS:
		_register(res)
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
		if depth >= m.min_depth and depth <= m.max_depth:
			candidates.append(m)
			total_weight += max(1, m.weight)
	if candidates.is_empty():
		return null
	var roll: int = randi_range(1, total_weight)
	var accum: int = 0
	for m in candidates:
		accum += max(1, m.weight)
		if roll <= accum:
			return m
	return candidates[0]
