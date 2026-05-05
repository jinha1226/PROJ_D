extends Node

# Default selection list = 3 starter classes. Advanced classes appear in
# extended selection UI when their unlocked flag becomes true.
const ACTIVE_BASE_IDS: Array = ["melee", "magic", "ranged"]

## Preload baked at script parse time — survives any filesystem / import
## quirk Godot's autoload phase might have. Adding a new class means
## adding a line here and a .tres file under resources/classes/.

# Starter classes (visible by default)
const _MELEE: Resource = preload("res://resources/classes/melee.tres")
const _MAGIC: Resource = preload("res://resources/classes/magic.tres")
const _RANGED: Resource = preload("res://resources/classes/ranged.tres")

# Melee category advanced
const _FIGHTER: Resource = preload("res://resources/classes/fighter.tres")
const _BERSERKER: Resource = preload("res://resources/classes/berserker.tres")
const _MONK: Resource = preload("res://resources/classes/monk.tres")
const _GLADIATOR: Resource = preload("res://resources/classes/gladiator.tres")

# Ranged category advanced
const _HUNTER: Resource = preload("res://resources/classes/hunter.tres")
const _BRIGAND: Resource = preload("res://resources/classes/brigand.tres")

# Magic category advanced
const _WIZARD: Resource = preload("res://resources/classes/wizard.tres")
const _CONJURER: Resource = preload("res://resources/classes/conjurer.tres")
const _ENCHANTER: Resource = preload("res://resources/classes/enchanter.tres")
const _NECROMANCER: Resource = preload("res://resources/classes/necromancer.tres")
const _SUMMONER: Resource = preload("res://resources/classes/summoner.tres")
const _FIRE_ELEMENTALIST: Resource = preload("res://resources/classes/fire_elementalist.tres")
const _ICE_ELEMENTALIST: Resource = preload("res://resources/classes/ice_elementalist.tres")
const _AIR_ELEMENTALIST: Resource = preload("res://resources/classes/air_elementalist.tres")
const _EARTH_ELEMENTALIST: Resource = preload("res://resources/classes/earth_elementalist.tres")
const _ARCHMAGE: Resource = preload("res://resources/classes/archmage.tres")  # debug

# Other category
const _WANDERER: Resource = preload("res://resources/classes/wanderer.tres")
const _ARTIFICER: Resource = preload("res://resources/classes/artificer.tres")

const _ALL_CLASSES: Array = [
	_MELEE, _MAGIC, _RANGED,
	_FIGHTER, _BERSERKER, _MONK, _GLADIATOR,
	_HUNTER, _BRIGAND,
	_WIZARD, _CONJURER, _ENCHANTER, _NECROMANCER, _SUMMONER,
	_FIRE_ELEMENTALIST, _ICE_ELEMENTALIST, _AIR_ELEMENTALIST, _EARTH_ELEMENTALIST,
	_ARCHMAGE,
	_WANDERER, _ARTIFICER,
]

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	for res in _ALL_CLASSES:
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
		for res in _ALL_CLASSES:
			_register(res)
