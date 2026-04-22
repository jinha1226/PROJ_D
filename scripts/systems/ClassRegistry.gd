extends Node

## Preload baked at script parse time — survives any filesystem / import
## quirk Godot's autoload phase might have. Adding a new class means
## adding a line here and a .tres file under resources/classes/.

const _WARRIOR: Resource = preload("res://resources/classes/warrior.tres")
const _MAGE: Resource = preload("res://resources/classes/mage.tres")
const _ROGUE: Resource = preload("res://resources/classes/rogue.tres")

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in [_WARRIOR, _MAGE, _ROGUE]:
		_register(res)
	if all.is_empty():
		push_warning("ClassRegistry: 0 classes registered.")

func _register(res) -> void:
	if res == null:
		return
	var id_val = null
	if "id" in res:
		id_val = res.id
	if id_val == null or String(id_val) == "":
		push_warning("ClassRegistry: resource has no id (%s)." % str(res))
		return
	by_id[String(id_val)] = res
	all.append(res)

func get_by_id(id: String) -> ClassData:
	return by_id.get(id)

func ids_in_order() -> Array:
	var known_order: Array = ["warrior", "mage", "rogue"]
	var result: Array = []
	for id in known_order:
		if by_id.has(id):
			result.append(id)
	for id in by_id.keys():
		if not result.has(id):
			result.append(id)
	return result

# Legacy rescan path kept for JobSelect defensive call.
func _scan() -> void:
	if all.is_empty():
		for res in [_WARRIOR, _MAGE, _ROGUE]:
			_register(res)
