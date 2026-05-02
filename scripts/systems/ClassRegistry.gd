extends Node

const ACTIVE_BASE_IDS: Array = ["warrior", "rogue", "elementalist"]

## Preload baked at script parse time — survives any filesystem / import
## quirk Godot's autoload phase might have. Adding a new class means
## adding a line here and a .tres file under resources/classes/.

const _WARRIOR: Resource = preload("res://resources/classes/warrior.tres")
const _BERSERKER: Resource = preload("res://resources/classes/berserker.tres")
const _CRUSHER: Resource = preload("res://resources/classes/crusher.tres")
const _SPEARMAN: Resource = preload("res://resources/classes/spearman.tres")
const _ROGUE: Resource = preload("res://resources/classes/rogue.tres")
const _RANGER: Resource = preload("res://resources/classes/ranger.tres")
const _ELEMENTALIST: Resource = preload("res://resources/classes/elementalist.tres")
const _CONJURER: Resource = preload("res://resources/classes/conjurer.tres")
const _ENCHANTER: Resource = preload("res://resources/classes/enchanter.tres")
const _NECROMANCER: Resource = preload("res://resources/classes/necromancer.tres")
const _SUMMONER: Resource = preload("res://resources/classes/summoner.tres")
const _ARCHMAGE: Resource = preload("res://resources/classes/archmage.tres")

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in [_WARRIOR, _BERSERKER, _CRUSHER, _SPEARMAN,
			_ROGUE, _RANGER,
			_ELEMENTALIST, _CONJURER, _ENCHANTER, _NECROMANCER, _SUMMONER,
			_ARCHMAGE]:
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
	var known_order: Array = ACTIVE_BASE_IDS.duplicate()
	var result: Array = []
	for id in known_order:
		if by_id.has(id):
			result.append(id)
	for id in by_id.keys():
		if not result.has(id):
			result.append(id)
	return result

func active_base_ids() -> Array:
	return ACTIVE_BASE_IDS.duplicate()

func is_unlocked(id: String) -> bool:
	var c: ClassData = get_by_id(id)
	if c == null:
		return false
	if c.unlocked:
		return true
	return GameManager.is_unlocked(id)

# Legacy rescan path kept for JobSelect defensive call.
func _scan() -> void:
	if all.is_empty():
		for res in [_WARRIOR, _BERSERKER, _CRUSHER, _SPEARMAN,
				_ROGUE, _RANGER,
				_ELEMENTALIST, _CONJURER, _ENCHANTER, _NECROMANCER, _SUMMONER,
				_ARCHMAGE]:
			_register(res)
