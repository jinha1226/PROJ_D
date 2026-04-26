extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main/Game.tscn")
const SimulationBotRef = preload("res://scripts/tools/SimulationBot.gd")
const CLASS_IDS: Array[String] = ["warrior", "rogue", "mage"]
const DEFAULT_RACE: String = "human"

var _runs_per_class: int = 10
var _max_turns: int = 2500
var _depth_goal: int = 8

var GameManager = null
var TurnManager = null
var CombatLog = null

func _init() -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null:
		GameManager = tree.root.get_node_or_null("/root/GameManager")
		TurnManager = tree.root.get_node_or_null("/root/TurnManager")
		CombatLog = tree.root.get_node_or_null("/root/CombatLog")
	call_deferred("_run")

func _run() -> void:
	_parse_args()
	await process_frame
	print("== PocketCrawl Gameplay Simulator ==")
	print("runs/class=%d max_turns=%d depth_goal=%d" % [_runs_per_class, _max_turns, _depth_goal])
	for class_id in CLASS_IDS:
		var summary := await _simulate_class(class_id, DEFAULT_RACE, _runs_per_class)
		print(JSON.stringify(summary))
	GameManager.simulation_mode = false
	quit()

func _simulate_class(class_id: String, race_id: String, runs: int) -> Dictionary:
	var depths: Array[int] = []
	var kills: Array[int] = []
	var turns: Array[int] = []
	var wins: int = 0
	for run_idx in range(runs):
		var seed: int = 1000 + run_idx
		var result := await _simulate_run(class_id, race_id, seed)
		depths.append(int(result.depth))
		kills.append(int(result.kills))
		turns.append(int(result.turns))
		if bool(result.reached_goal):
			wins += 1
	return {
		"class_id": class_id,
		"race_id": race_id,
		"runs": runs,
		"avg_depth": _avg(depths),
		"max_depth": depths.max() if not depths.is_empty() else 0,
		"avg_kills": _avg(kills),
		"avg_turns": _avg(turns),
		"goal_clear_rate": float(wins) / float(max(1, runs)),
	}

func _simulate_run(class_id: String, race_id: String, seed: int) -> Dictionary:
	_reset_globals()
	GameManager.simulation_mode = true
	GameManager.selected_class_id = class_id
	GameManager.selected_race_id = race_id
	GameManager.selected_starting_weapon_id = "short_sword" if class_id == "warrior" else ""
	GameManager.start_new_run(seed)
	var game: Node = GAME_SCENE.instantiate()
	root.add_child(game)
	await process_frame
	var reached_goal: bool = false
	for _step in range(_max_turns):
		await process_frame
		if not is_instance_valid(game):
			break
		if game.player == null:
			continue
		if game.player.hp <= 0 or not GameManager.run_in_progress:
			break
		if GameManager.depth >= _depth_goal:
			reached_goal = true
			break
		if TurnManager.is_player_turn:
			SimulationBotRef.take_turn(game, class_id)
	var final_kills: int = game.player.kills if is_instance_valid(game) and game.player != null else 0
	var final_depth: int = GameManager.depth
	var final_turns: int = TurnManager.turn_number
	if is_instance_valid(game):
		game.queue_free()
	await process_frame
	var result := {
		"class_id": class_id,
		"depth": final_depth,
		"kills": final_kills,
		"turns": final_turns,
		"reached_goal": reached_goal,
	}
	GameManager.simulation_mode = false
	GameManager.run_in_progress = false
	return result

func _reset_globals() -> void:
	TurnManager.actors.clear()
	TurnManager.turn_number = 0
	TurnManager.is_player_turn = true
	CombatLog.clear()
	GameManager.floor_cache.clear()
	GameManager.pending_player_state.clear()

func _avg(values: Array[int]) -> float:
	if values.is_empty():
		return 0.0
	var total: int = 0
	for value in values:
		total += value
	return float(total) / float(values.size())

func _parse_args() -> void:
	var args: Array = OS.get_cmdline_user_args()
	for i in range(args.size()):
		match String(args[i]):
			"--runs":
				if i + 1 < args.size():
					_runs_per_class = max(1, int(args[i + 1]))
			"--turns":
				if i + 1 < args.size():
					_max_turns = max(100, int(args[i + 1]))
			"--goal":
				if i + 1 < args.size():
					_depth_goal = max(2, int(args[i + 1]))
