extends Node
## Global game state singleton. Holds current run context.

signal run_started
signal run_ended(victory: bool)

var current_depth: int = 1
var current_seed: int = -1
var player: Node = null
var dungeon: Node = null
# Character-creation selections. Set by RaceSelect / JobSelect screens.
# "" means: use GameBootstrap defaults.
var selected_race_id: String = ""
var selected_job_id: String = ""

func start_new_run(job_id: String = "fighter", race_id: String = "human", run_seed: int = -1) -> void:
	current_depth = 1
	current_seed = run_seed if run_seed != -1 else randi()
	selected_race_id = race_id
	selected_job_id = job_id
	run_started.emit()

func end_run(victory: bool) -> void:
	run_ended.emit(victory)
