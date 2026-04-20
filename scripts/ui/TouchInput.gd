extends Node
## Touch/click input handler for dungeon map.
## Converts screen → world → grid, dispatches to player. Handles auto-move along A* paths,
## longpress auto-explore, and monster-sight interruption.

signal stairs_tapped(pos: Vector2i)
signal stairs_up_tapped(pos: Vector2i)
signal branch_entrance_tapped(pos: Vector2i)
signal target_selected(pos: Vector2i)
signal inspect_requested(pos: Vector2i)

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
var _auto_exploring: bool = false  # continuous explore until done / interrupted
const MAX_AUTO_STEPS: int = 400
var _auto_steps: int = 0
var _auto_move_grace: float = 0.0
# Monster instance IDs already spotted during the current auto-move session.
# DCSS-faithful: only *newly* visible monsters halt travel — ones you've
# already seen (and presumably chose to ignore) don't re-trigger the stop.
var _seen_monster_ids: Dictionary = {}
# Stair tiles seen at auto-move start. A stair that becomes visible mid-run
# that wasn't in this set halts travel so the player can decide whether to
# descend. Matches DCSS travel.cc's interesting-feature interrupt.
var _seen_stair_tiles: Dictionary = {}


func _ready() -> void:
	if TurnManager and not TurnManager.player_turn_started.is_connected(_on_player_turn_started):
		TurnManager.player_turn_started.connect(_on_player_turn_started)


func _process(delta: float) -> void:
	if _auto_move_grace > 0:
		_auto_move_grace -= delta
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
	if _is_auto_moving:
		if _auto_move_grace <= 0:
			_cancel_auto_move()
		return
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


var targeting_mode: bool = false

func _on_tap(grid: Vector2i) -> void:
	if not player.is_alive:
		return
	if targeting_mode:
		target_selected.emit(grid)
		targeting_mode = false
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
		elif tile_here == DungeonGenerator.TileType.BRANCH_ENTRANCE:
			branch_entrance_tapped.emit(grid)
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
	_auto_move_grace = 0.5
	_auto_steps = 0
	_snapshot_visible_monsters()
	_snapshot_visible_stairs()
	_update_path_overlay()
	_step_auto_move()


## Explore the dungeon automatically: move toward the nearest unexplored tile.
## Continuous — re-calculates a new target whenever the current path is done.
func begin_auto_explore() -> bool:
	if player == null or generator == null or not player.is_alive:
		return false
	# If already exploring, stop (toggle).
	if _auto_exploring:
		_cancel_auto_move()
		return false
	var target: Vector2i = _farthest_floor_from(player.grid_pos)
	if target == player.grid_pos:
		return false
	_auto_exploring = true
	return begin_auto_move_to(target)


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
	_auto_move_grace = 0.5
	_auto_steps = 0
	_snapshot_visible_monsters()
	_snapshot_visible_stairs()
	_update_path_overlay()
	_step_auto_move()
	return true


func _on_longpress(grid: Vector2i) -> void:
	if not player.is_alive:
		return
	inspect_requested.emit(grid)


func _farthest_floor_from(start: Vector2i) -> Vector2i:
	# BFS over 4-connected walkable tiles.
	# Priority 1: nearest visible floor item the player hasn't grabbed yet.
	# Priority 2: nearest unexplored tile (keep revealing map).
	# Priority 3: farthest reachable explored tile (keep moving when
	#            fully explored and everything's been picked up).
	var item_tiles: Dictionary = _visible_pickup_tiles()
	var visited: Dictionary = {start: 0}
	var queue: Array[Vector2i] = [start]
	var nearest_item: Vector2i = start
	var nearest_item_d: int = 999999
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
		# Visible-item priority comes first — a loot tile 3 squares away
		# beats an unexplored corridor 6 squares away.
		if cur != start and item_tiles.has(cur) and d < nearest_item_d:
			nearest_item_d = d
			nearest_item = cur
		if dmap != null and not dmap.is_explored(cur) and d < nearest_unexplored_d:
			nearest_unexplored_d = d
			nearest_unexplored = cur
		for nd in dirs:
			var nb: Vector2i = cur + nd
			if visited.has(nb):
				continue
			var nb_t: int = generator.get_tile(nb)
			var passable: bool = generator.is_walkable(nb) or nb_t == DungeonGenerator.TileType.DOOR_CLOSED
			if not passable:
				continue
			visited[nb] = d + 1
			queue.append(nb)
	# Priority order: visible item → unexplored tile → farthest explored.
	if nearest_item_d < 999999:
		return nearest_item
	if nearest_unexplored_d < 999999:
		return nearest_unexplored
	return farthest


## Tiles of every floor item currently in the player's FOV. Used so auto-
## explore can divert to loot before continuing to the next unexplored
## room.
func _visible_pickup_tiles() -> Dictionary:
	var out: Dictionary = {}
	for fi in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(fi) or not ("grid_pos" in fi):
			continue
		var p: Vector2i = fi.grid_pos
		if dmap != null and not dmap.is_tile_visible(p):
			continue
		out[p] = true
	return out


func _on_player_turn_started() -> void:
	if _is_auto_moving:
		# Roughly-2x faster auto-step cadence. Pair with Player's shorter
		# movement tween so each step still reads distinctly without
		# dragging on mobile.
		get_tree().create_timer(0.06).timeout.connect(_step_auto_move, CONNECT_ONE_SHOT)


func _step_auto_move() -> void:
	if not _is_auto_moving:
		return
	# Any monster currently visible halts travel — DCSS-style "you see
	# an enemy, freeze". The earlier "new monster only" variant slipped
	# past hostiles that were already in FOV at the moment auto-explore
	# started, which read as auto-move ignoring enemies.
	if _any_monster_in_sight():
		_cancel_auto_move()
		return
	if _newly_visible_stair() != Vector2i.ZERO:
		_cancel_auto_move()
		return
	if _auto_move_path.is_empty():
		# Path done — if exploring, try to continue to next unexplored tile.
		if _auto_exploring:
			_continue_auto_explore()
			# _continue_auto_explore just set a new path but doesn't end a
			# turn, so the next player_turn_started timer won't fire by
			# itself. Step into the new path immediately.
			if _auto_move_path.size() > 0:
				_step_auto_move()
		else:
			_cancel_auto_move()
		return
	_auto_steps += 1
	if _auto_steps > MAX_AUTO_STEPS:
		_cancel_auto_move()
		return
	var next_tile: Vector2i = _auto_move_path[0]
	_auto_move_path.remove_at(0)
	_update_path_overlay()
	var delta: Vector2i = next_tile - player.grid_pos
	# Flip the player's auto-step flag so try_move picks the fast tween
	# duration; restore right after so a manual tap reverts to normal.
	if player != null:
		player.is_auto_step = true
	var moved_ok: bool = player.try_move(delta)
	if player != null:
		player.is_auto_step = false
	if not moved_ok:
		# Blocked (door/wall changed); retry next target if exploring.
		if _auto_exploring:
			_auto_move_path.clear()
			_continue_auto_explore()
			if _auto_move_path.size() > 0:
				_step_auto_move()
		else:
			_cancel_auto_move()


## Pick up any floor item on the current tile, then find the next explore target.
func _continue_auto_explore() -> void:
	if player == null or generator == null or not player.is_alive:
		_cancel_auto_move()
		return
	# Pick up items on current tile automatically.
	for fi in get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(fi) or not ("grid_pos" in fi):
			continue
		if fi.grid_pos == player.grid_pos and player.has_method("pick_up_item"):
			player.pick_up_item(fi)
			break
	# Find next unexplored target.
	var target: Vector2i = _farthest_floor_from(player.grid_pos)
	if target == player.grid_pos:
		# Every reachable tile is already explored — nothing left to see.
		CombatLog.add("Dungeon fully explored.")
		_cancel_auto_move()
		return
	var path: Array[Vector2i] = Pathfinding.find_path(generator, player.grid_pos, target)
	if path.is_empty():
		CombatLog.add("Dungeon fully explored.")
		_cancel_auto_move()
		return
	_auto_move_path = path
	_auto_move_grace = 0.1
	_update_path_overlay()


func _cancel_auto_move() -> void:
	_is_auto_moving = false
	_auto_exploring = false
	_auto_move_path.clear()
	_auto_steps = 0
	_seen_monster_ids.clear()
	_seen_stair_tiles.clear()
	if dmap != null:
		dmap.clear_path()


## Snapshot monsters currently in FOV so they don't re-trigger a stop later
## in the same auto-move session. Called once when travel begins.
func _snapshot_visible_monsters() -> void:
	_seen_monster_ids.clear()
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not ("grid_pos" in m):
			continue
		if "is_alive" in m and not m.is_alive:
			continue
		if _monster_is_visible(m):
			_seen_monster_ids[m.get_instance_id()] = true


## Same idea as _snapshot_visible_monsters, but for stairs. Stairs the player
## already sees before starting travel don't trigger an interrupt; ones that
## come into view mid-run do, so the first sight of new stairs always halts.
func _snapshot_visible_stairs() -> void:
	_seen_stair_tiles.clear()
	for tile in _stair_tiles():
		if _tile_is_visible(tile):
			_seen_stair_tiles[tile] = true


## Return the first newly-visible stair tile this auto-move session, or
## Vector2i.ZERO if none. Players only get interrupted once per staircase
## because the tile is added to `_seen_stair_tiles` on the halt.
func _newly_visible_stair() -> Vector2i:
	for tile in _stair_tiles():
		if _seen_stair_tiles.has(tile):
			continue
		if _tile_is_visible(tile):
			_seen_stair_tiles[tile] = true
			return tile
	return Vector2i.ZERO


func _stair_tiles() -> Array:
	if generator == null:
		return []
	var out: Array = []
	if generator.stairs_down_pos != Vector2i.ZERO:
		out.append(generator.stairs_down_pos)
	if generator.stairs_down_pos2 != Vector2i.ZERO \
			and generator.stairs_down_pos2 != generator.stairs_down_pos:
		out.append(generator.stairs_down_pos2)
	if "spawn_pos" in generator and generator.spawn_pos != Vector2i.ZERO:
		out.append(generator.spawn_pos)  # this is the STAIRS_UP tile
	return out


func _tile_is_visible(tile: Vector2i) -> bool:
	if dmap != null:
		return dmap.is_tile_visible(tile)
	var d: int = max(abs(tile.x - player.grid_pos.x),
			abs(tile.y - player.grid_pos.y))
	return d <= SIGHT_RANGE


func _update_path_overlay() -> void:
	if dmap == null:
		return
	dmap.show_path(_auto_move_path)


## True iff a monster's tile is currently visible to the player.
func _monster_is_visible(m: Node) -> bool:
	if dmap != null:
		return dmap.is_tile_visible(m.grid_pos)
	var d: int = max(abs(m.grid_pos.x - player.grid_pos.x),
			abs(m.grid_pos.y - player.grid_pos.y))
	return d <= SIGHT_RANGE


## True iff any alive hostile monster is currently in FOV.
func _any_monster_in_sight() -> bool:
	for m in get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not ("grid_pos" in m):
			continue
		if "is_alive" in m and not m.is_alive:
			continue
		if _monster_is_visible(m):
			return true
	return false
