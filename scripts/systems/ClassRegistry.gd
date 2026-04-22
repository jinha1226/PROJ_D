extends Node

const CLASS_DIR: String = "res://resources/classes"

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	_scan()

func _scan() -> void:
	by_id.clear()
	all.clear()
	var dir := DirAccess.open(CLASS_DIR)
	if dir == null:
		push_warning("ClassRegistry: %s not found." % CLASS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path: String = "%s/%s" % [CLASS_DIR, fname]
			var res = load(path)
			# Duck-typed check — `is ClassData` can fail when the
			# global class registry isn't yet populated (e.g. first
			# run after a git pull without a fresh editor import).
			if res != null and "id" in res and "starting_hp" in res \
					and String(res.id) != "":
				by_id[String(res.id)] = res
				all.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

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
