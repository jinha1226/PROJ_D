extends Node

const SPELL_DIR := "res://resources/spells/"

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	var dir := DirAccess.open(SPELL_DIR)
	if dir == null:
		push_warning("SpellRegistry: cannot open %s" % SPELL_DIR)
		return
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".tres"):
			var res = load(SPELL_DIR + fname)
			if res is SpellData:
				_register(res)
		fname = dir.get_next()
	dir.list_dir_end()
	all.sort_custom(func(a, b):
		if a.school != b.school:
			return a.school < b.school
		return a.spell_level < b.spell_level)
	if all.is_empty():
		push_warning("SpellRegistry: 0 spells registered.")

func _register(res: SpellData) -> void:
	if res.id == "":
		return
	by_id[res.id] = res
	all.append(res)

func get_by_id(id: String) -> SpellData:
	return by_id.get(id)

func get_by_school(school: String) -> Array:
	return all.filter(func(s): return s.school == school)

func get_available_for_xl(xl: int) -> Array:
	return all.filter(func(s): return s.xl_required <= xl)
