extends Node

const _HUMAN: Resource = preload("res://resources/races/human.tres")
const _ELF: Resource = preload("res://resources/races/elf.tres")
const _DWARF: Resource = preload("res://resources/races/dwarf.tres")

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in [_HUMAN, _ELF, _DWARF]:
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
	var known: Array = ["human", "elf", "dwarf"]
	var result: Array = []
	for id in known:
		if by_id.has(id):
			result.append(id)
	for id in by_id.keys():
		if not result.has(id):
			result.append(id)
	return result

func is_unlocked(id: String) -> bool:
	var r: RaceData = get_by_id(id)
	if r == null:
		return false
	return r.unlocked
