extends Node

const MONSTER_DIR: String = "res://resources/monsters"

var by_id: Dictionary = {}
var all: Array = []

func _ready() -> void:
	_scan()

func _scan() -> void:
	by_id.clear()
	all.clear()
	var dir := DirAccess.open(MONSTER_DIR)
	if dir == null:
		push_warning("MonsterRegistry: %s not found; run with empty roster." % MONSTER_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var path: String = "%s/%s" % [MONSTER_DIR, fname]
			var res = load(path)
			if res is MonsterData and res.id != "":
				by_id[res.id] = res
				all.append(res)
		fname = dir.get_next()
	dir.list_dir_end()

func get_by_id(id: String) -> MonsterData:
	return by_id.get(id)

func pick_by_depth(depth: int) -> MonsterData:
	var candidates: Array = []
	var total_weight: int = 0
	for m in all:
		if depth >= m.min_depth and depth <= m.max_depth:
			candidates.append(m)
			total_weight += max(1, m.weight)
	if candidates.is_empty():
		return null
	var roll: int = randi_range(1, total_weight)
	var accum: int = 0
	for m in candidates:
		accum += max(1, m.weight)
		if roll <= accum:
			return m
	return candidates[0]
