extends RefCounted
class_name SimulationBot

static var TurnManager = Engine.get_main_loop().root.get_node_or_null("/root/TurnManager") if Engine.get_main_loop() is SceneTree else null
static var MagicSystem = Engine.get_main_loop().root.get_node_or_null("/root/MagicSystem") if Engine.get_main_loop() is SceneTree else null
static var SpellRegistry = Engine.get_main_loop().root.get_node_or_null("/root/SpellRegistry") if Engine.get_main_loop() is SceneTree else null

static func take_turn(game, class_id: String) -> void:
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

static func _visible_monsters(game) -> Array:
	var out: Array = []
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if n is Monster and game.map.visible_tiles.has(n.grid_pos):
			out.append(n)
	return out

static func _try_use_survival_item(game, class_id: String) -> bool:
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
	if class_id == "rogue" and hp_ratio <= 0.45 and _try_use_named_item(player, "potion_invisible"):
		TurnManager.end_player_turn()
		return true
	return false

static func _try_use_named_item(player, item_id: String) -> bool:
	for i in range(player.items.size()):
		if String(player.items[i].get("id", "")) == item_id:
			player.use_item(i)
			return true
	return false

static func _try_cast_spell(game, visible: Array) -> bool:
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
		if player.get_skill_level("spellcasting") < spell.spell_level:
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

static func _score_spell(spell: SpellData, visible_count: int, low_hp: bool) -> float:
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
