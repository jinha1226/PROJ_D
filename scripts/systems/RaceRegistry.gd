extends Node

const ACTIVE_RACE_IDS: Array = ["human", "hill_orc", "elf", "kobold", "troll", "dwarf", "minotaur", "spriggan", "vampire", "gargoyle"]

const _HUMAN: Resource = preload("res://resources/races/human.tres")
const _KOBOLD: Resource = preload("res://resources/races/kobold.tres")
const _ORC: Resource = preload("res://resources/races/orc.tres")
const _TROLL: Resource = preload("res://resources/races/troll.tres")
const _MINOTAUR: Resource = preload("res://resources/races/minotaur.tres")
const _ELF: Resource = preload("res://resources/races/elf.tres")
const _DWARF: Resource = preload("res://resources/races/dwarf.tres")
const _SPRIGGAN: Resource = preload("res://resources/races/spriggan.tres")
const _VAMPIRE: Resource = preload("res://resources/races/vampire.tres")
const _GARGOYLE: Resource = preload("res://resources/races/gargoyle.tres")

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in [_HUMAN, _KOBOLD, _ORC, _TROLL, _MINOTAUR, _ELF,
			_DWARF, _SPRIGGAN, _VAMPIRE, _GARGOYLE]:
		_register(res)
	if all.is_empty():
		push_warning("RaceRegistry: 0 races registered.")

func _register(res) -> void:
	if res == null:
		return
	if not ("id" in res):
		return
	if String(res.id) == "":
		return
	by_id[String(res.id)] = res
	all.append(res)

func get_by_id(id: String) -> RaceData:
	return by_id.get(id)

func ids_in_order() -> Array:
	var known: Array = ACTIVE_RACE_IDS.duplicate()
	var result: Array = []
	for id in known:
		if by_id.has(id):
			result.append(id)
	return result

func active_race_ids() -> Array:
	return ACTIVE_RACE_IDS.duplicate()

func is_unlocked(id: String) -> bool:
	var r: RaceData = get_by_id(id)
	if r == null:
		return false
	if r.unlocked:
		return true
	return GameManager.is_unlocked(id)
