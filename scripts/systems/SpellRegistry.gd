extends Node

const _DART: Resource = preload("res://resources/spells/magic_dart.tres")
const _HEAL: Resource = preload("res://resources/spells/heal_wounds.tres")
const _BLINK: Resource = preload("res://resources/spells/blink.tres")
const _ICE_BOLT: Resource = preload("res://resources/spells/ice_bolt.tres")

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in [_DART, _HEAL, _BLINK, _ICE_BOLT]:
		_register(res)
	if all.is_empty():
		push_warning("SpellRegistry: 0 spells registered.")

func _register(res) -> void:
	if res == null:
		return
	if not ("id" in res):
		return
	if String(res.id) == "":
		return
	by_id[String(res.id)] = res
	all.append(res)

func get_by_id(id: String) -> SpellData:
	return by_id.get(id)
