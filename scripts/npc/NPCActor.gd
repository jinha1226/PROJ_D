class_name NPCActor extends Actor

## Intelligent NPC actor with full stats/skills/equipment (via Actor base),
## TurnManager integration, GOAP-driven AI, and a social relations system.
##
## Lifecycle:
##   1. Create instance and add to scene tree.
##   2. Call setup(map, pos) to bind map and register with TurnManager.
##   3. Optionally set relations, loadout, and goal_selector before first turn.

var TurnManager = null
var pending_energy: float = 0.0

var npc_name: String = "Explorer"

## Social relations keyed by Node.get_instance_id().
## Each entry: {trust: float[-1..1], threat: float[0..1], loot_value: float[0..1]}
##   trust > 0  → ally;  trust < -0.3 → enemy;  0 = neutral
##   threat     → how dangerous we perceive them (drives ally-seeking)
##   loot_value → incentive to betray an ally when they die
var relations: Dictionary = {}

## Current alliance members (Array of NPCActor refs).
var alliance_members: Array = []

## Emitted when this NPC picks up a floor item. Game.gd connects this to
## remove the FloorItem node from the scene (same pattern as Player.item_dropped).
signal item_picked_up(entry: Dictionary, at_pos: Vector2i)

## Swap in a custom subclass of NPCGoalSelector to change personality.
var goal_selector: NPCGoalSelector = null

## Set to true after a failed recruit attempt. Hides the Recruit button for
## the rest of this floor (resets automatically when the NPC is cleared on descent).
var recruit_attempted: bool = false

# ── internal AI state ─────────────────────────────────────────────────────────

var _current_plan: Array = []   # Array of NPCAction
var _current_goal: Dictionary = {}

## Last perceived enemy reference (Actor or Monster duck-typed).
var _known_enemy = null

## Last perceived loot tile in FOV.
var _known_loot_tile: Vector2i = Vector2i(-1, -1)

## Exploration target: frontier tile adjacent to unexplored area.
## Picked when idle; cleared when reached or invalidated.
var _explore_target: Vector2i = Vector2i(-1, -1)

# ── lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	TurnManager  = get_node_or_null("/root/TurnManager")
	CombatLog    = get_node_or_null("/root/CombatLog")
	GameManager  = get_node_or_null("/root/GameManager")
	ItemRegistry = get_node_or_null("/root/ItemRegistry")
	add_to_group("npcs")
	if goal_selector == null:
		goal_selector = NPCGoalSelector.new()
		goal_selector.actor = self
	init_skills()

func setup(map: DungeonMap, pos: Vector2i) -> void:
	_map = map
	grid_pos = pos
	position = map.grid_to_world(pos)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		if TurnManager != null:
			TurnManager.unregister_actor(self)

# ── TurnManager actor interface ───────────────────────────────────────────────

func take_turn() -> void:
	if _dead or _map == null:
		return
	tick_statuses()
	_update_perception()
	var world_state := _build_world_state()
	var goal := goal_selector.select_goal(world_state)
	if goal.is_empty():
		_wander()
		return
	# Replan when goal shifts or current plan is exhausted / invalidated
	if _current_plan.is_empty() or goal != _current_goal:
		_current_plan = GOAPPlanner.plan(world_state, goal, _get_actions())
		_current_goal = goal
	if _current_plan.is_empty():
		return
	var action: NPCAction = _current_plan[0]
	if action.is_applicable(world_state):
		action.execute(self)
		_current_plan.remove_at(0)
	else:
		_current_plan = []   # stale plan — replan next turn

# ── perception ────────────────────────────────────────────────────────────────

func _update_perception() -> void:
	if _map == null:
		return
	var fov := compute_fov()
	_known_enemy = null
	_known_loot_tile = Vector2i(-1, -1)

	# Nearest hostile monster in FOV
	for node in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(node):
			continue
		if node.get("is_ally") == true:
			continue
		if not fov.has(node.grid_pos):
			continue
		if _known_enemy == null or _chebyshev(node.grid_pos, grid_pos) < _chebyshev(_known_enemy.grid_pos, grid_pos):
			_known_enemy = node

	# Player — always overrides monster target when trust is sufficiently negative.
	# Ensures counter-attack fires even when monsters are in FOV.
	for node in get_tree().get_nodes_in_group("player"):
		if not is_instance_valid(node) or not fov.has(node.grid_pos):
			continue
		if _relation_trust(node) < -0.3:
			_known_enemy = node

	# Nearest floor item in FOV (duck-typed: needs grid_pos)
	for node in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(node):
			continue
		var item_pos: Vector2i = node.grid_pos
		if fov.has(item_pos):
			_known_loot_tile = item_pos
			break

# ── world state ───────────────────────────────────────────────────────────────

func _build_world_state() -> Dictionary:
	var hp_ratio := float(hp) / float(max(hp_max, 1))
	var enemy_adjacent := false
	var enemy_dead := false
	var enemy_strong := false
	if _known_enemy != null:
		enemy_adjacent = _chebyshev(_known_enemy.grid_pos, grid_pos) <= 1
		enemy_dead = _known_enemy.hp <= 0
		enemy_strong = _known_enemy.hp > hp
	return {
		has_enemy_in_sight  = _known_enemy != null and not enemy_dead,
		adjacent_to_enemy   = enemy_adjacent,
		enemy_is_dead       = enemy_dead,
		hp_critical         = hp_ratio < 0.3,
		has_loot_nearby     = _known_loot_tile != Vector2i(-1, -1),
		at_loot_pos         = grid_pos == _known_loot_tile,
		loot_collected      = false,
		has_potential_ally  = _has_potential_ally(),
		ally_proposed       = false,
		enemy_is_strong     = enemy_strong,
	}

# ── actions pool ──────────────────────────────────────────────────────────────

func _get_actions() -> Array:
	return [
		NpcActionMoveToward.new(),
		NpcActionAttack.new(),
		NpcActionFlee.new(),
		NpcActionMoveToLoot.new(),
		NpcActionPickupItem.new(),
		NpcActionProposePeace.new(),
		NpcActionWait.new(),
	]

# ── relations helpers ─────────────────────────────────────────────────────────

func set_relation(other: Node, trust: float, threat: float = 0.0, loot_value: float = 0.0) -> void:
	relations[other.get_instance_id()] = {trust = trust, threat = threat, loot_value = loot_value}

func _relation_trust(other: Node) -> float:
	return relations.get(other.get_instance_id(), {}).get("trust", 0.0)

func _relation_threat(other: Node) -> float:
	return relations.get(other.get_instance_id(), {}).get("threat", 0.0)

func _has_potential_ally() -> bool:
	for node in get_tree().get_nodes_in_group("npcs"):
		if node == self or not is_instance_valid(node):
			continue
		if node is NPCActor and _relation_trust(node) >= 0.0:
			return true
	return false

## Build a CompanionData snapshot from this NPC's current stats and equipment.
## Used when the player successfully recruits this NPC as a companion.
func to_companion_data() -> CompanionData:
	var c := CompanionData.new()
	c.id = "npc_" + str(get_instance_id())
	c.display_name = npc_name
	c.race_id = get("race_id") if "race_id" in self else "human"
	c.job_id = "fighter"
	c.hp_max = hp_max
	c.mp_max = mp_max
	c.strength = strength
	c.dexterity = dexterity
	c.intelligence = intelligence
	c.ac = ac
	c.ev = ev
	c.xl = xl
	c.xp = xp
	c.skills = skills.duplicate(true)
	c.equipped_weapon_id = equipped_weapon_id
	c.equipped_armor_id = equipped_armor_id
	c.equipped_shield_id = equipped_shield_id
	c.equipped_helmet_id = equipped_helmet_id
	c.equipped_gloves_id = equipped_gloves_id
	c.equipped_boots_id = equipped_boots_id
	c.equipped_ring_id = equipped_ring_id
	c.equipped_amulet_id = equipped_amulet_id
	return c

## Exploration and wandering when idle (no GOAP goal).
## Actively seeks frontier tiles (explored tiles adjacent to unexplored floor).
func _wander() -> void:
	# 25% chance to skip entirely — prevents mechanical-looking constant movement.
	if randi() % 4 == 0:
		return

	# Validate or clear stale explore target.
	if _explore_target != Vector2i(-1, -1):
		if not _map.in_bounds(_explore_target) or not _map.is_walkable(_explore_target):
			_explore_target = Vector2i(-1, -1)
		elif _map.explored.has(_explore_target):
			_explore_target = Vector2i(-1, -1)  # already explored, pick new one

	# Pick a new frontier target when we don't have one.
	if _explore_target == Vector2i(-1, -1):
		_explore_target = _find_explore_frontier()

	# Move toward explore target.
	if _explore_target != Vector2i(-1, -1):
		var step := _greedy_step_toward(_explore_target)
		if step != Vector2i.ZERO:
			_do_move(step)
			return
		# Blocked — abandon target and fall through to random wander.
		_explore_target = Vector2i(-1, -1)

	# Fallback: random adjacent step.
	var dirs := [Vector2i(0, 1), Vector2i(0, -1), Vector2i(1, 0), Vector2i(-1, 0),
				 Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	dirs.shuffle()
	for d: Vector2i in dirs:
		var p: Vector2i = grid_pos + d
		if _map.in_bounds(p) and _map.is_walkable(p) and not _is_pos_occupied(p):
			_do_move(d)
			return

## Move one step in direction d and emit signal.
func _do_move(d: Vector2i) -> void:
	var p: Vector2i = grid_pos + d
	grid_pos = p
	position = _map.grid_to_world(p)
	facing = d
	emit_signal("moved", p)

## Greedy single step toward target (diagonal preferred).
func _greedy_step_toward(target: Vector2i) -> Vector2i:
	var dx: int = sign(target.x - grid_pos.x)
	var dy: int = sign(target.y - grid_pos.y)
	for step: Vector2i in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if step == Vector2i.ZERO:
			continue
		var pos: Vector2i = grid_pos + step
		if _map.in_bounds(pos) and _map.is_walkable(pos) and not _is_pos_occupied(pos):
			return step
	return Vector2i.ZERO

## Find a frontier tile: a walkable explored tile adjacent to an unexplored floor tile.
## Returns the farthest candidate to spread NPC exploration.
func _find_explore_frontier() -> Vector2i:
	if _map == null:
		return Vector2i(-1, -1)
	var best: Vector2i = Vector2i(-1, -1)
	var best_dist: int = -1
	const DIRS := [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	for pos: Vector2i in _map.explored.keys():
		if not _map.is_walkable(pos):
			continue
		var is_frontier: bool = false
		for d: Vector2i in DIRS:
			var n: Vector2i = pos + d
			if _map.in_bounds(n) and not _map.explored.has(n) \
					and _map.tile_at(n) != DungeonMap.Tile.WALL:
				is_frontier = true
				break
		if not is_frontier:
			continue
		var dist: int = _chebyshev(pos, grid_pos)
		if dist > best_dist:
			best_dist = dist
			best = pos
	return best

## Returns true if pos is occupied by any actor (monster, player, or NPC).
## Used by movement actions to prevent overlap.
func _is_pos_occupied(pos: Vector2i) -> bool:
	for node in get_tree().get_nodes_in_group("monsters"):
		if is_instance_valid(node) and node.grid_pos == pos:
			return true
	for node in get_tree().get_nodes_in_group("player"):
		if is_instance_valid(node) and node.grid_pos == pos:
			return true
	for node in get_tree().get_nodes_in_group("npcs"):
		if node != self and is_instance_valid(node) and node.grid_pos == pos:
			return true
	return false

# ── Actor hook overrides ──────────────────────────────────────────────────────

func _on_take_damage_visual() -> void:
	pass  # override in concrete subclass for flash/shake

func _on_equipment_changed() -> void:
	pass  # recalculate AC/EV when equipment is set
