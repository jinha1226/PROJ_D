extends Node
## Touch/click input handler for dungeon map.
## Converts screen → world → grid, dispatches to player. Handles auto-move along A* paths,
## longpress auto-explore, and monster-sight interruption.

signal stairs_tapped(pos: Vector2i)
signal stairs_up_tapped(pos: Vector2i)

const TILE_SIZE: int = 32
const LONGPRESS_TIME: float = 0.5
# Chebyshev distance within which an enemy halts auto-move. Small so that
# just "seeing an enemy on screen" (no fog-of-war yet) doesn't cancel travel.
const SIGHT_RANGE: int = 3

@export var generator: DungeonGenerator
@export var player: Player
@export var camera: Camera2D
@export var dmap: DungeonMap  # optional — used for path overlay

var _press_pos_screen: Vector2 = Vector2.ZERO
var _press_grid: Vector2i = Vector2i.ZERO
var _pressing: bool = false
var _longpress_timer: float = 0.0
var _longpress_fired: bool = false

var _auto_move_path: Array[Vector2i] = []
var _is_auto_moving: bool = false
# Hard cap on consecutive auto-move steps to defend against a runaway loop
# (e.g. monster-sight check missing a monster, or a path that re-fills).
const MAX_AUTO_STEPS: int = 200
var _auto_steps: int = 0


func _ready() -> void:
	if TurnManager and not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)


func _process(delta: float) -> void:
	if _pressing and not _longpress_fired:
		_longpress_timer += delta
		if _longpress_timer >= LONGPRESS_TIME:
			_longpress_fired = true
			_on_longpress(_press_grid)


func _unhandled_input(event: InputEvent) -> void:
	if player == null or generator == null:
		return
	if event is InputEventMouseButton:
		var mb: InputEventMouseButton = event
		if mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed:
				_begin_press(mb.position)
			else:
				_end_press(mb.position)
	elif event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_begin_press(st.position)
		else:
			_end_press(st.position)


func _begin_press(screen_pos: Vector2) -> void:
	# Cancel in-progress auto-move on any tap.
	if _is_auto_moving:
		_cancel_auto_move()
		return
	_press_pos_screen = screen_pos
	_press_grid = _screen_to_grid(screen_pos)
	_pressing = true
	_longpress_timer = 0.0
	_longpress_fired = false


func _end_press(screen_pos: Vector2) -> void:
	if not _pressing:
		return
	_pressing = false
	if _longpress_fired:
		return
	var grid: Vector2i = _screen_to_grid(screen_pos)
	_on_tap(grid)


func _screen_to_grid(screen_pos: Vector2) -> Vector2i:
	var world: Vector2
	if camera != null:
		# Account for camera position and zoom; viewport center == camera.position.
		var viewport_size: Vector2 = get_viewport().get_visible_rect().size
		var offset: Vector2 = (screen_pos - viewport_size * 0.5) / camera.zoom
		world = camera.get_screen_center_position() + offset
	else:
		world = screen_pos
	return Vector2i(int(floor(world.x / TILE_SIZE)), int(floor(world.y / TILE_SIZE)))


func _on_tap(grid: Vector2i) -> void:
	if not player.is_alive:
		return
	var delta: Vector2i = grid - player.grid_pos
	var cheb: int = max(abs(delta.x), abs(delta.y))
	# Tap on self → if on stairs, emit.
	if cheb == 0:
		var tile_here: int = generator.get_tile(grid)
		if tile_here == DungeonGenerator.TileType.STAIRS_DOWN:
			stairs_tapped.emit(grid)
		elif tile_here == DungeonGenerator.TileType.STAIRS_UP:
			stairs_up_tapped.emit(grid)
		return
	if cheb == 1:
		# Adjacent: move (or attack if monster there — handled in try_move).
		player.try_move(delta)
		return
	# Distant tap: attempt A* auto-move.
	if generator.get_tile(grid) == DungeonGenerator.TileType.STAIRS_DOWN and grid == player.grid_pos:
		stairs_tapped.emit(grid)
		return
	var path: Array[Vector2i] = Pathfinding.find_path(generator, player.grid_pos, grid)
	if path.is_empty():
		return
	_auto_move_path = path
	_is_auto_moving = true
	_auto_steps = 0
	_update_path_overlay()
	_step_auto_move()


## External entrypoint — used by the minimap popup to route a tap on a
## distant tile through the same A* auto-move path logic as an in-world tap.
func begin_auto_move_to(target: Vector2i) -> bool:
	if player == null or generator == null or not player.is_alive:
		return false
	if target == player.grid_pos:
		return false
	var path: Array[Vector2i] = Pathfinding.find_path(generator, player.grid_pos, target)
	if path.is_empty():
		return false
	_auto_move_path = path
	_is_auto_moving = true
	_auto_steps = 0
	_update_path_overlay()
	_step_auto_move()
	return true


func _on_longpress(grid: Vector2i) -> void:
	if not player.is_alive:
		return
	# Simplified auto-explore: BFS-walk toward the farthest reachable FLOOR tile.
	var goal: Vector2i = _farthest_floor_from(player.grid_pos)
	if goal == player.grid_pos:
		return
	var path: Array[Vector2i] = Pathfinding.find_path(generator, player.grid_pos, goal)
	if path.is_empty():
		return
	_auto_move_path = path
	_is_auto_moving = true
	_auto_steps = 0
	_update_path_overlay()
	_step_auto_move()


func _farthest_floor_from(start: Vector2i) -> Vector2i:
	# BFS over 4-connected walkable tiles.
	# Priority 1: nearest unexplored tile (reveals new map area).
	# Priority 2: farthest reachable explored tile (keep moving when fully explored).
	var visited: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var nearest_unexplored: Vector2i = start
	var nearest_unexplored_d: int = 999999
	var farthest: Vector2i = start
	var farthest_d: int = 0
	var dirs: Array[Vector2i] = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = visited[cur]
		if d > farthest_d:
			farthest_d = d
			farthest = cur
		# Track nearest unexplored tile (uses dmap fog-of-war if available).
		if dmap != null and not dmap.is_explored(cur) and d < nearest_unexplored_d:
			nearest_unexplored_d = d
			nearest_unexplored = cur
		for nd in dirs:
			var nb: Vector2i = cur + nd
			if visited.has(nb):
				continue
			if not generator.is_walkable(nb):
				continue
			visited[nb] = d + 1
			queue.append(nb)
	return nearest_unexplored if nearest_unexplored_d < 999999 else farthest


func _on_player_turn_started() -> void:
	if _is_auto_moving:
		# 150 ms delay so each step is visually distinct.
		get_tree().create_timer(0.15).timeout.connect(_step_auto_move, CONNECT_ONE_SHOT)


func _step_auto_move() -> void:
	if not _is_auto_moving:
		return
	if _auto_move_path.is_empty():
		_cancel_auto_move()
		return
	if _monster_in_sight():
		_cancel_auto_move()
		return
	_auto_steps += 1
	if _auto_steps > MAX_AUTO_STEPS:
		push_warning("TouchInput: auto-move exceeded MAX_AUTO_STEPS; cancelling")
		_cancel_auto_move()
		return
	var next_tile: Vector2i = _auto_move_path[0]
	_auto_move_path.remove_at(0)
	_update_path_overlay()
	var delta: Vector2i = next_tile - player.grid_pos
	var moved_ok: bool = player.try_move(delta)
	if not moved_ok:
		_cancel_auto_move()


func _cancel_auto_move() -> void:
	_is_auto_moving = false
	_auto_move_path.clear()
	_auto_steps = 0
	if dmap != null:
		dmap.clear_path()


func _update_path_overlay() -> void:
	if dmap == null:
		return
	dmap.show_path(_auto_move_path)


func _monster_in_sight() -> bool:
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if "grid_pos" in m:
			var d: int = max(abs(m.grid_pos.x - player.grid_pos.x), abs(m.grid_pos.y - player.grid_pos.y))
			if d <= SIGHT_RANGE:
				return true
	return false
