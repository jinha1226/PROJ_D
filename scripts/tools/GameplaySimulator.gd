extends SceneTree

const GAME_SCENE: PackedScene = preload("res://scenes/main/Game.tscn")
const CLASS_IDS: Array[String] = ["warrior", "rogue", "mage"]
const DEFAULT_RACE: String = "human"

var _runs_per_class: int = 10
var _max_turns: int = 2500
var _depth_goal: int = 8

func _init() -> void:
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
			_take_bot_turn(game, class_id)
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

func _take_bot_turn(game, class_id: String) -> void:
	var player = game.player
	if player == null or player.hp <= 0:
		return
	if not game._auto_path.is_empty():
		game._advance_auto_walk()
		return
	if _try_use_survival_item(game, class_id):
		return
	var visible: Array = _visible_monsters(game)
	if not visible.is_empty():
		if class_id == "rogue" and _try_use_named_item(player, "scroll_shrouding"):
			TurnManager.end_player_turn()
			return
		if _try_cast_spell(game, visible):
			return
		game._on_act_pressed()
		return
	if player.grid_pos == game.map.stairs_down_pos:
		game._on_stairs_down()
		return
	var stairs_known: bool = game.map.explored.has(game.map.stairs_down_pos) \
		or game.map.visible_tiles.has(game.map.stairs_down_pos)
	var explore_target: Vector2i = game._find_explore_target()
	if explore_target != Vector2i(-1, -1):
		var path: Array = game._bfs_path(player.grid_pos, explore_target)
		if not path.is_empty():
			player.try_step(path[0] - player.grid_pos)
			return
	if stairs_known:
		var stairs_path: Array = game._bfs_path(player.grid_pos, game.map.stairs_down_pos)
		if not stairs_path.is_empty():
			player.try_step(stairs_path[0] - player.grid_pos)
			return
	game._on_rest_pressed()

func _visible_monsters(game) -> Array:
	var out: Array = []
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if n is Monster and game.map.visible_tiles.has(n.grid_pos):
			out.append(n)
	return out

func _try_use_survival_item(game, class_id: String) -> bool:
	var player = game.player
	var hp_ratio: float = float(player.hp) / float(max(1, player.hp_max))
	if hp_ratio <= 0.35 and _try_use_named_item(player, "potion_healing"):
		TurnManager.end_player_turn()
		return true
	if player.statuses.has("poison") and _try_use_named_item(player, "potion_cure_poison"):
		TurnManager.end_player_turn()
		return true
	if class_id == "mage" and player.mp <= 1 and _try_use_named_item(player, "potion_magic"):
		TurnManager.end_player_turn()
		return true
	if class_id == "rogue" and hp_ratio <= 0.45 and _try_use_named_item(player, "scroll_blinking"):
		TurnManager.end_player_turn()
		return true
	return false

func _try_use_named_item(player, item_id: String) -> bool:
	for i in range(player.items.size()):
		if String(player.items[i].get("id", "")) == item_id:
			player.use_item(i)
			return true
	return false

func _try_cast_spell(game, visible: Array) -> bool:
	var player = game.player
	if player == null or player.known_spells.is_empty():
		return false
	var low_hp: bool = float(player.hp) / float(max(1, player.hp_max)) <= 0.5
	var best_spell: SpellData = null
	var best_score: float = -999999.0
	for sid in player.known_spells:
		var spell: SpellData = SpellRegistry.get_by_id(String(sid))
		if spell == null:
			continue
		if player.get_skill_level("magic") < spell.spell_level:
			continue
		if player.intelligence < player.int_required_for_spell(spell):
			continue
		if player.mp < spell.mp_cost:
			continue
		var score: float = _score_spell(spell, visible.size(), low_hp)
		if score > best_score:
			best_score = score
			best_spell = spell
	if best_spell == null:
		return false
	if MagicSystem.cast(best_spell.id, player, game):
		TurnManager.end_player_turn()
		return true
	return false

func _score_spell(spell: SpellData, visible_count: int, low_hp: bool) -> float:
	var score: float = float(spell.spell_level * 10 - spell.mp_cost)
	match spell.effect:
		"heal":
			score += 50.0 if low_hp else -20.0
		"aoe_damage", "chain_damage", "aoe_status":
			score += 12.0 + float(visible_count) * 4.0
		"damage", "multi_damage", "drain":
			score += 10.0
		"hold", "sleep", "fear", "confusion", "stun":
			score += 8.0
		_:
			score += 2.0
	return score

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
