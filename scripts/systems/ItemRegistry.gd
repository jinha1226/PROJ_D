extends Node

const ITEM_DIR: String = "res://resources/items"

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	_scan()

func _scan() -> void:
	by_id.clear()
	all.clear()
	var dir := DirAccess.open(ITEM_DIR)
	if dir == null:
		push_warning("ItemRegistry: %s not found." % ITEM_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path: String = "%s/%s" % [ITEM_DIR, fname]
			var res = load(path)
			if res is ItemData and res.id != "":
				by_id[res.id] = res
				all.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

func get_by_id(id: String) -> ItemData:
	return by_id.get(id)

func pick_by_depth(depth: int, kind_filter: String = "") -> ItemData:
	var candidates: Array = []
	for it in all:
		if kind_filter != "" and it.kind != kind_filter:
			continue
		if depth >= it.tier:
			candidates.append(it)
	if candidates.is_empty():
		return null
	return candidates[randi() % candidates.size()]
