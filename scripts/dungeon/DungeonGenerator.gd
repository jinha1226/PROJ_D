class_name DungeonGenerator extends Node
## Dispatches to per-branch builders so each stretch of the run feels
## structurally different, not just re-themed:
##   main    — BSP rooms + L-corridors (classic DCSS D)
##   mine    — cellular-automata caverns (Orc/Lair flavour)
##   forest  — caves + tree clusters
##   swamp   — caves + water pools
##   volcano — caves + lava pools
## Every branch places one random minivault from VaultRegistry for flavour.

const MAP_WIDTH: int = 50
const MAP_HEIGHT: int = 72
const MIN_ROOM_SIZE: int = 5
const MAX_ROOM_SIZE: int = 16
# BSP depth 4 → at most 16 leaf rooms; typically 8–12 after min-size culling.
const BSP_MAX_DEPTH: int = 4
# Cellular-automata parameters.
const CAVE_INITIAL_FILL: float = 0.45   # starting wall probability
const CAVE_SMOOTH_STEPS: int = 5
const CAVE_MIN_FLOOR_TILES: int = 600   # fallback threshold

enum TileType { WALL, FLOOR, DOOR_OPEN, DOOR_CLOSED, STAIRS_DOWN, STAIRS_UP, WATER, LAVA, TRAP, BRANCH_ENTRANCE, SHOP, ALTAR, TREE }

var map: Array = []
var rooms: Array[Rect2i] = []
var stairs_down_pos: Vector2i = Vector2i.ZERO
var stairs_down_pos2: Vector2i = Vector2i.ZERO
var spawn_pos: Vector2i = Vector2i.ZERO
var spawn_pos2: Vector2i = Vector2i.ZERO

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

func generate(depth: int, run_seed: int = -1) -> void:
	if run_seed == -1:
		_rng.randomize()
	else:
		_rng.seed = run_seed + depth * 1000
	rooms.clear()
	_init_map()
	HyperLayout.set_seed(_rng.seed + depth)
	var branch: String = _current_branch()
	match branch:
		"main":    _build_hyper_main()
		"mine":    _build_caves(); _decorate_rock_debris(8)
		"forest":  _build_caves(); _decorate_trees(22)
		"swamp":   _build_caves(); _decorate_trees(10); _place_pools(TileType.WATER, 4, 4, 9)
		"volcano": _build_caves(); _place_pools(TileType.LAVA, 3, 3, 7)
		_:         _build_hyper_main()
	_place_vault(branch)
	_ensure_reachability()
	_place_stairs()


# ---- Builder: DCSS hyper engine ------------------------------------------

## Drive the ported DCSS 0.34 hyper layout engine to produce the main
## branch (and any "basic rooms" branch). Produces a usage_grid which we
## then translate back into our TileType enum map.
func _build_hyper_main() -> void:
	var paint_cb: Callable = Callable(HyperLayout, "_default_floor_paint")
	var options: Dictionary = {
		"name": "Main Dungeon",
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"min_room_size": 4,
		"max_room_size": 10,
		"max_rooms": 16,
		"max_room_tries": 40,
		"max_place_tries": 80,
		"layout_wall_type": "rock_wall",
		"layout_floor_type": "floor",
		"grid_initialiser": Callable(self, "_hyper_init_cell"),
		"skip_analyse": false,
		# One varied "code" generator — floor rectangle + added walls +
		# buffer so adjacent rooms don't touch. A second generator with
		# bigger min_size handles larger rooms (25%).
		"room_type_weights": [
			{
				"generator": "code",
				"paint_callback": paint_cb,
				"room_transform": Callable(HyperRooms, "add_buffer_walls"),
				"weight": 3,
				"min_size": 4,
				"max_size": 8,
			},
			{
				"generator": "code",
				"paint_callback": paint_cb,
				"room_transform": Callable(HyperRooms, "add_buffer_walls"),
				"weight": 1,
				"min_size": 7,
				"max_size": 11,
			},
		],
		"build_fixture": [
			# First pass: seed the level with a primary room.
			{
				"type": "build",
				"max_rooms": 1,
				"strategy": HyperStrategy.strategy_primary(),
			},
			# Main pass: attach rooms off existing walls.
			{
				"type": "build",
				"max_rooms": 14,
				"strategy": HyperStrategy.strategy_default(),
			},
		],
	}
	var state: Dictionary = HyperLayout.build(options)
	_apply_usage_grid(state["usage_grid"])


## Seed each usage cell as solid rock so the engine has walls to carve.
func _hyper_init_cell(x: int, y: int) -> Dictionary:
	return {
		"feature": "rock_wall",
		"solid": true,
		"wall": true,
		"carvable": true,
		"space": false,
		"vault": false,
		"anchors": [],
	}


## Translate the finished usage_grid back into our TileType enum map +
## rooms array (needed for stair placement / reachability).
func _apply_usage_grid(usage_grid: Dictionary) -> void:
	for x in MAP_WIDTH:
		for y in MAP_HEIGHT:
			var cell: Dictionary = HyperUsage.get_usage(usage_grid, x, y)
			map[x][y] = _feature_to_tile(String(cell.get("feature", "rock_wall")))
	# Derive rooms from per-room anchors — simplest: collect bounding rect
	# per unique room ref. Used by _place_stairs and _ensure_reachability.
	var by_room: Dictionary = {}
	for x in MAP_WIDTH:
		for y in MAP_HEIGHT:
			var cell: Dictionary = HyperUsage.get_usage(usage_grid, x, y)
			var r = cell.get("room", null)
			if r == null:
				continue
			if bool(cell.get("solid", true)) and not String(cell.get("feature", "")) == "open_door":
				continue
			var key: int = r.get_instance_id() if r is Object else hash(r)
			if not by_room.has(key):
				by_room[key] = {"min_x": x, "min_y": y, "max_x": x, "max_y": y}
			else:
				var rec: Dictionary = by_room[key]
				rec["min_x"] = min(rec["min_x"], x)
				rec["min_y"] = min(rec["min_y"], y)
				rec["max_x"] = max(rec["max_x"], x)
				rec["max_y"] = max(rec["max_y"], y)
	rooms.clear()
	for rec_v in by_room.values():
		var rec: Dictionary = rec_v
		rooms.append(Rect2i(
				rec["min_x"], rec["min_y"],
				rec["max_x"] - rec["min_x"] + 1,
				rec["max_y"] - rec["min_y"] + 1))


## Feature-string → TileType enum lookup. Unknown → wall.
func _feature_to_tile(feature: String) -> int:
	match feature:
		"floor":             return TileType.FLOOR
		"rock_wall":         return TileType.WALL
		"stone_wall":        return TileType.WALL
		"open_door":         return TileType.DOOR_OPEN
		"closed_door":       return TileType.DOOR_CLOSED
		"stone_stairs_up":   return TileType.STAIRS_UP
		"stone_stairs_down": return TileType.STAIRS_DOWN
		"shallow_water":     return TileType.WATER
		"deep_water":        return TileType.WATER
		"lava":              return TileType.LAVA
		"tree":              return TileType.TREE
		"space":             return TileType.WALL
		_:                   return TileType.WALL


func _current_branch() -> String:
	var mgr: Node = null
	if Engine.get_main_loop() != null:
		mgr = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if mgr == null:
		return "main"
	return String(mgr.get("current_branch") or "main")


func _init_map() -> void:
	map = []
	map.resize(MAP_WIDTH)
	for x in MAP_WIDTH:
		var col: Array = []
		col.resize(MAP_HEIGHT)
		for y in MAP_HEIGHT:
			col[y] = TileType.WALL
		map[x] = col


# ---- Builder: rooms + corridors (classic BSP) -----------------------------

func _build_rooms_and_corridors() -> void:
	_bsp_split(Rect2i(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2), BSP_MAX_DEPTH)
	_connect_rooms()


func _bsp_split(region: Rect2i, depth: int) -> void:
	var can_split_h: bool = region.size.y >= MIN_ROOM_SIZE * 2 + 2
	var can_split_v: bool = region.size.x >= MIN_ROOM_SIZE * 2 + 2
	if depth <= 0 or (not can_split_h and not can_split_v):
		_place_room(region)
		return
	var split_horizontal: bool
	var aspect: float = float(region.size.x) / float(region.size.y)
	if aspect > 1.25:
		split_horizontal = false
	elif aspect < 0.8:
		split_horizontal = true
	else:
		split_horizontal = _rng.randf() > 0.5
	if split_horizontal and not can_split_h:
		split_horizontal = false
	elif not split_horizontal and not can_split_v:
		split_horizontal = true
	if split_horizontal:
		var min_y: int = MIN_ROOM_SIZE + 1
		var max_y: int = region.size.y - MIN_ROOM_SIZE - 1
		var split: int = _rng.randi_range(min_y, max_y)
		_bsp_split(Rect2i(region.position.x, region.position.y, region.size.x, split), depth - 1)
		_bsp_split(Rect2i(region.position.x, region.position.y + split, region.size.x, region.size.y - split), depth - 1)
	else:
		var min_x: int = MIN_ROOM_SIZE + 1
		var max_x: int = region.size.x - MIN_ROOM_SIZE - 1
		var split2: int = _rng.randi_range(min_x, max_x)
		_bsp_split(Rect2i(region.position.x, region.position.y, split2, region.size.y), depth - 1)
		_bsp_split(Rect2i(region.position.x + split2, region.position.y, region.size.x - split2, region.size.y), depth - 1)


func _place_room(region: Rect2i) -> void:
	var max_w: int = min(region.size.x - 2, MAX_ROOM_SIZE)
	var max_h: int = min(region.size.y - 2, MAX_ROOM_SIZE)
	if max_w < MIN_ROOM_SIZE or max_h < MIN_ROOM_SIZE:
		return
	var w: int = _rng.randi_range(MIN_ROOM_SIZE, max_w)
	var h: int = _rng.randi_range(MIN_ROOM_SIZE, max_h)
	var x: int = region.position.x + _rng.randi_range(1, region.size.x - w - 1)
	var y: int = region.position.y + _rng.randi_range(1, region.size.y - h - 1)
	var room: Rect2i = Rect2i(x, y, w, h)
	for rx in range(room.position.x, room.position.x + room.size.x):
		for ry in range(room.position.y, room.position.y + room.size.y):
			map[rx][ry] = TileType.FLOOR
	rooms.append(room)


## Minimum-spanning-tree style: each new room joins to its nearest already-
## connected neighbour rather than the next-by-index room.
func _connect_rooms() -> void:
	if rooms.size() < 2:
		return
	var connected: Array[int] = [0]
	while connected.size() < rooms.size():
		var best_pair: Array[int] = [0, 0]
		var best_d: int = 0x3fffffff
		for i in connected:
			var ca: Vector2i = _room_center(rooms[i])
			for j in range(rooms.size()):
				if connected.has(j):
					continue
				var cb: Vector2i = _room_center(rooms[j])
				var d: int = abs(ca.x - cb.x) + abs(ca.y - cb.y)
				if d < best_d:
					best_d = d
					best_pair = [i, j]
		var ia: int = best_pair[0]
		var ib: int = best_pair[1]
		_carve_corridor(_room_center(rooms[ia]), _room_center(rooms[ib]))
		connected.append(ib)


func _room_center(r: Rect2i) -> Vector2i:
	return Vector2i(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2)


func _carve_corridor(a: Vector2i, b: Vector2i) -> void:
	if _rng.randf() > 0.5:
		_carve_h(a.x, b.x, a.y)
		_carve_v(a.y, b.y, b.x)
	else:
		_carve_v(a.y, b.y, a.x)
		_carve_h(a.x, b.x, b.y)


func _carve_h(x1: int, x2: int, y: int) -> void:
	var lo: int = min(x1, x2)
	var hi: int = max(x1, x2)
	for x in range(lo, hi + 1):
		if _in_bounds(Vector2i(x, y)) and map[x][y] == TileType.WALL:
			map[x][y] = TileType.FLOOR


func _carve_v(y1: int, y2: int, x: int) -> void:
	var lo: int = min(y1, y2)
	var hi: int = max(y1, y2)
	for y in range(lo, hi + 1):
		if _in_bounds(Vector2i(x, y)) and map[x][y] == TileType.WALL:
			map[x][y] = TileType.FLOOR


# ---- Builder: cellular-automata caves -------------------------------------

func _build_caves() -> void:
	# Seed random walls, keeping a 1-tile border solid.
	for x in range(1, MAP_WIDTH - 1):
		for y in range(1, MAP_HEIGHT - 1):
			map[x][y] = (TileType.WALL if _rng.randf() < CAVE_INITIAL_FILL
					else TileType.FLOOR)
	# Smooth: standard 4/5 rule.
	for _i in CAVE_SMOOTH_STEPS:
		_cave_smooth_step()
	# Keep only the largest connected floor region — everything else becomes
	# wall. Fallback to rooms+corridors if caves came out too sparse.
	var largest: Dictionary = _largest_floor_region()
	if largest.size() < CAVE_MIN_FLOOR_TILES:
		rooms.clear()
		_init_map()
		_build_rooms_and_corridors()
		return
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			if map[x][y] == TileType.FLOOR and not largest.has(Vector2i(x, y)):
				map[x][y] = TileType.WALL
	# Register a single "room" covering the cavern bounding box so item /
	# monster spawners that iterate `rooms` still have somewhere to place.
	rooms.append(_bounding_rect(largest))


func _cave_smooth_step() -> void:
	var next_map: Array = []
	next_map.resize(MAP_WIDTH)
	for x in MAP_WIDTH:
		var col: Array = []
		col.resize(MAP_HEIGHT)
		for y in MAP_HEIGHT:
			if x == 0 or y == 0 or x == MAP_WIDTH - 1 or y == MAP_HEIGHT - 1:
				col[y] = TileType.WALL
				continue
			var n_wall: int = _count_wall_neighbors(x, y)
			var was_wall: bool = (map[x][y] == TileType.WALL)
			if was_wall:
				col[y] = TileType.WALL if n_wall >= 4 else TileType.FLOOR
			else:
				col[y] = TileType.WALL if n_wall >= 5 else TileType.FLOOR
		next_map[x] = col
	map = next_map


func _count_wall_neighbors(cx: int, cy: int) -> int:
	var n: int = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var nx: int = cx + dx
			var ny: int = cy + dy
			if nx < 0 or nx >= MAP_WIDTH or ny < 0 or ny >= MAP_HEIGHT:
				n += 1
			elif map[nx][ny] == TileType.WALL:
				n += 1
	return n


## Flood-fill: pick the largest contiguous FLOOR region. Returns the set of
## tiles in it as a dict keyed by Vector2i.
func _largest_floor_region() -> Dictionary:
	var visited: Dictionary = {}
	var largest: Dictionary = {}
	for x in range(MAP_WIDTH):
		for y in range(MAP_HEIGHT):
			if map[x][y] != TileType.FLOOR:
				continue
			var p: Vector2i = Vector2i(x, y)
			if visited.has(p):
				continue
			var region: Dictionary = _flood_floor(p, visited)
			if region.size() > largest.size():
				largest = region
	return largest


func _flood_floor(start: Vector2i, visited: Dictionary) -> Dictionary:
	var region: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	while not queue.is_empty():
		var p: Vector2i = queue.pop_front()
		if visited.has(p):
			continue
		visited[p] = true
		if map[p.x][p.y] != TileType.FLOOR:
			continue
		region[p] = true
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if _in_bounds(n) and not visited.has(n) and map[n.x][n.y] == TileType.FLOOR:
				queue.append(n)
	return region


func _bounding_rect(tiles: Dictionary) -> Rect2i:
	if tiles.is_empty():
		return Rect2i(0, 0, 1, 1)
	var min_x: int = MAP_WIDTH
	var min_y: int = MAP_HEIGHT
	var max_x: int = 0
	var max_y: int = 0
	for k in tiles.keys():
		var p: Vector2i = k
		min_x = min(min_x, p.x)
		min_y = min(min_y, p.y)
		max_x = max(max_x, p.x)
		max_y = max(max_y, p.y)
	return Rect2i(min_x, min_y, max_x - min_x + 1, max_y - min_y + 1)


# ---- Decorators -----------------------------------------------------------

## Convert `count` random interior floor tiles into trees. Avoids stairs
## and tiles that would cut off movement.
func _decorate_trees(count: int) -> void:
	_scatter_blocker(TileType.TREE, count)


func _decorate_rock_debris(count: int) -> void:
	_scatter_blocker(TileType.WALL, count)


func _scatter_blocker(tile: int, count: int) -> void:
	var placed: int = 0
	var tries: int = count * 8
	while placed < count and tries > 0:
		tries -= 1
		var x: int = _rng.randi_range(2, MAP_WIDTH - 3)
		var y: int = _rng.randi_range(2, MAP_HEIGHT - 3)
		if map[x][y] != TileType.FLOOR:
			continue
		# Skip tiles whose removal would disconnect a narrow corridor —
		# simple heuristic: only allow tiles with ≥5 floor neighbours in
		# the 3×3 area (i.e. in an open region).
		if _floor_neighbours_3x3(x, y) < 5:
			continue
		map[x][y] = tile
		placed += 1


func _floor_neighbours_3x3(cx: int, cy: int) -> int:
	var n: int = 0
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			var nx: int = cx + dx
			var ny: int = cy + dy
			if _in_bounds(Vector2i(nx, ny)) and map[nx][ny] == TileType.FLOOR:
				n += 1
	return n


## Seed `count` hazard pools of the given tile type. Each pool is a BFS
## expansion from a random floor tile, 3–`max_size` tiles large.
func _place_pools(tile: int, count: int, min_size: int, max_size: int) -> void:
	var placed: int = 0
	var tries: int = count * 10
	while placed < count and tries > 0:
		tries -= 1
		var x: int = _rng.randi_range(3, MAP_WIDTH - 4)
		var y: int = _rng.randi_range(3, MAP_HEIGHT - 4)
		if map[x][y] != TileType.FLOOR:
			continue
		if _floor_neighbours_3x3(x, y) < 7:
			continue
		var target_size: int = _rng.randi_range(min_size, max_size)
		_grow_pool(Vector2i(x, y), tile, target_size)
		placed += 1


func _grow_pool(start: Vector2i, tile: int, target: int) -> void:
	var grown: Dictionary = {start: true}
	map[start.x][start.y] = tile
	var frontier: Array[Vector2i] = [start]
	while grown.size() < target and not frontier.is_empty():
		var idx: int = _rng.randi_range(0, frontier.size() - 1)
		var p: Vector2i = frontier[idx]
		frontier.remove_at(idx)
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + d
			if not _in_bounds(n) or grown.has(n):
				continue
			if map[n.x][n.y] != TileType.FLOOR:
				continue
			grown[n] = true
			map[n.x][n.y] = tile
			frontier.append(n)
			if grown.size() >= target:
				return


# ---- Vault placement ------------------------------------------------------

func _place_vault(branch: String) -> void:
	var pool: Array = VaultRegistry.for_branch(branch)
	if pool.is_empty():
		return
	var template: Array = pool[_rng.randi_range(0, pool.size() - 1)]
	if template.is_empty():
		return
	var h: int = template.size()
	var w: int = String(template[0]).length()
	# 20 attempts to find a fit; silently skip if none.
	for _i in 20:
		var ox: int = _rng.randi_range(2, MAP_WIDTH - w - 2)
		var oy: int = _rng.randi_range(2, MAP_HEIGHT - h - 2)
		if _vault_fits(template, ox, oy):
			_stamp_vault(template, ox, oy)
			return


func _vault_fits(template: Array, ox: int, oy: int) -> bool:
	# Require at least 25% of the vault's solid tiles to fall on existing
	# walls (so we're not carving into open space disruptively) but also at
	# least one tile overlapping existing floor (so the vault is reachable).
	var wall_overlap: int = 0
	var floor_overlap: int = 0
	var total_solid: int = 0
	for ry in template.size():
		var row: String = String(template[ry])
		for rx in row.length():
			var ch: String = row.substr(rx, 1)
			var tx: int = ox + rx
			var ty: int = oy + ry
			if not _in_bounds(Vector2i(tx, ty)):
				return false
			var t: int = VaultRegistry.char_to_tile(ch)
			if t == -1:
				continue
			if t == TileType.WALL or t == TileType.TREE:
				total_solid += 1
				if map[tx][ty] == TileType.WALL:
					wall_overlap += 1
			elif t == TileType.FLOOR and map[tx][ty] == TileType.FLOOR:
				floor_overlap += 1
	if total_solid > 0 and float(wall_overlap) / float(total_solid) < 0.25:
		return false
	return floor_overlap > 0


func _stamp_vault(template: Array, ox: int, oy: int) -> void:
	for ry in template.size():
		var row: String = String(template[ry])
		for rx in row.length():
			var ch: String = row.substr(rx, 1)
			var t: int = VaultRegistry.char_to_tile(ch)
			if t == -1:
				continue
			map[ox + rx][oy + ry] = t


# ---- Reachability + stair placement ---------------------------------------

func _ensure_reachability() -> void:
	if rooms.is_empty():
		# Caves can still produce a playable region even without registered
		# rooms — fall back to picking the largest floor blob.
		var largest: Dictionary = _largest_floor_region()
		if largest.is_empty():
			spawn_pos = Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
			map[spawn_pos.x][spawn_pos.y] = TileType.FLOOR
			return
		rooms.append(_bounding_rect(largest))
	spawn_pos = _room_center(rooms[0])
	# Ensure the chosen spawn cell is floor.
	if map[spawn_pos.x][spawn_pos.y] != TileType.FLOOR:
		var any: Dictionary = _largest_floor_region()
		if not any.is_empty():
			spawn_pos = any.keys()[0]
	var reachable: Dictionary = _bfs_reachable(spawn_pos)
	for i in range(1, rooms.size()):
		var c: Vector2i = _room_center(rooms[i])
		if map[c.x][c.y] != TileType.FLOOR:
			continue
		if not reachable.has(c):
			var nearest: Vector2i = _nearest_reachable(c, reachable)
			_carve_corridor(c, nearest)
			reachable = _bfs_reachable(spawn_pos)


func _bfs_reachable(start: Vector2i) -> Dictionary:
	var visited: Dictionary = {}
	var queue: Array[Vector2i] = [start]
	visited[start] = true
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + d
			if visited.has(n):
				continue
			if _in_bounds(n) and is_walkable(n):
				visited[n] = true
				queue.append(n)
	return visited


func _nearest_reachable(from: Vector2i, reachable: Dictionary) -> Vector2i:
	var best: Vector2i = spawn_pos
	var best_d: int = 0x3fffffff
	for k in reachable.keys():
		var p: Vector2i = k
		var d: int = abs(p.x - from.x) + abs(p.y - from.y)
		if d < best_d:
			best_d = d
			best = p
	return best


## Farthest reachable floor tile from `from` by BFS (step count). Used by
## cave stair placement where `rooms` has nothing useful.
func _bfs_farthest(from: Vector2i) -> Vector2i:
	var visited: Dictionary = {from: 0}
	var queue: Array[Vector2i] = [from]
	var farthest: Vector2i = from
	var farthest_d: int = 0
	while not queue.is_empty():
		var cur: Vector2i = queue.pop_front()
		var d: int = int(visited[cur])
		if d > farthest_d:
			farthest_d = d
			farthest = cur
		for dir in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = cur + dir
			if visited.has(n):
				continue
			if _in_bounds(n) and is_walkable(n):
				visited[n] = d + 1
				queue.append(n)
	return farthest


func _place_stairs() -> void:
	if rooms.is_empty():
		spawn_pos = Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
		stairs_down_pos = spawn_pos
		stairs_down_pos2 = spawn_pos
		spawn_pos2 = spawn_pos
		return
	# If the first "room" is a cavern bounding box, room-centre stair
	# placement doesn't work — use BFS-farthest instead.
	var first_c: Vector2i = _room_center(rooms[0])
	var single_cave: bool = rooms.size() == 1
	if single_cave or map[first_c.x][first_c.y] != TileType.FLOOR:
		spawn_pos = _pick_floor_tile_near(first_c)
		stairs_down_pos = _bfs_farthest(spawn_pos)
		stairs_down_pos2 = stairs_down_pos
		spawn_pos2 = spawn_pos
		map[spawn_pos.x][spawn_pos.y] = TileType.STAIRS_UP
		map[stairs_down_pos.x][stairs_down_pos.y] = TileType.STAIRS_DOWN
		return
	spawn_pos = _room_center(rooms[0])
	var dists: Array = []
	for i in range(rooms.size()):
		var c: Vector2i = _room_center(rooms[i])
		dists.append({"idx": i, "d": abs(c.x - spawn_pos.x) + abs(c.y - spawn_pos.y)})
	dists.sort_custom(func(a, b): return a["d"] > b["d"])
	var far1_idx: int = dists[0]["idx"]
	stairs_down_pos = _room_center(rooms[far1_idx])
	map[stairs_down_pos.x][stairs_down_pos.y] = TileType.STAIRS_DOWN
	if dists.size() >= 3:
		var far2_idx: int = dists[1]["idx"]
		if far2_idx == 0:
			far2_idx = dists[2]["idx"] if dists.size() > 2 else far1_idx
		stairs_down_pos2 = _room_center(rooms[far2_idx])
		map[stairs_down_pos2.x][stairs_down_pos2.y] = TileType.STAIRS_DOWN
	else:
		stairs_down_pos2 = stairs_down_pos
	map[spawn_pos.x][spawn_pos.y] = TileType.STAIRS_UP
	if rooms.size() >= 3:
		var near2_idx: int = dists[dists.size() - 2]["idx"]
		if near2_idx == 0:
			near2_idx = dists[dists.size() - 3]["idx"] if dists.size() > 2 else 0
		spawn_pos2 = _room_center(rooms[near2_idx])
		map[spawn_pos2.x][spawn_pos2.y] = TileType.STAIRS_UP
	else:
		spawn_pos2 = spawn_pos


## Find a floor tile within a small radius of `hint`; expands the search
## outward if the hint itself is wall.
func _pick_floor_tile_near(hint: Vector2i) -> Vector2i:
	if _in_bounds(hint) and map[hint.x][hint.y] == TileType.FLOOR:
		return hint
	for r in range(1, max(MAP_WIDTH, MAP_HEIGHT)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				var p: Vector2i = hint + Vector2i(dx, dy)
				if _in_bounds(p) and map[p.x][p.y] == TileType.FLOOR:
					return p
	return Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)


func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < MAP_WIDTH and p.y >= 0 and p.y < MAP_HEIGHT


func get_tile(p: Vector2i) -> int:
	if not _in_bounds(p):
		return TileType.WALL
	return map[p.x][p.y]


func is_walkable(p: Vector2i) -> bool:
	var t: int = get_tile(p)
	return t == TileType.FLOOR or t == TileType.STAIRS_DOWN or t == TileType.STAIRS_UP or t == TileType.DOOR_OPEN
