extends Node

const SPELL_DIR: String = "res://resources/spells"

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	_scan()

func _scan() -> void:
	by_id.clear()
	all.clear()
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		push_warning("SpellRegistry: %s not found." % SPELL_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path: String = "%s/%s" % [SPELL_DIR, fname]
			var res = load(path)
			if res != null and "id" in res and "mp_cost" in res \
					and String(res.id) != "":
				by_id[String(res.id)] = res
				all.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

func get_by_id(id: String) -> SpellData:
	return by_id.get(id)
