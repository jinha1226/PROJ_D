extends Node

signal depth_changed(new_depth: int)
signal run_ended(result: String)

var depth: int = 1
var seed: int = 0
var gold: int = 0
var identified: Dictionary = {}
var run_in_progress: bool = false

# Character selection — set by menus before start_new_run().
var selected_class_id: String = ""

func start_new_run(random_seed: int = -1) -> void:
	if random_seed < 0:
		seed = randi()
	else:
		seed = random_seed
	depth = 1
	gold = 0
	identified.clear()
	run_in_progress = true
	emit_signal("depth_changed", depth)

func descend() -> void:
	depth += 1
	emit_signal("depth_changed", depth)

func end_run(result: String) -> void:
	run_in_progress = false
	emit_signal("run_ended", result)

func is_identified(item_id: String) -> bool:
	return identified.get(item_id, false)

func identify(item_id: String) -> void:
	identified[item_id] = true
