class_name DungeonGenerator extends Node

const MAP_WIDTH: int = 50
const MAP_HEIGHT: int = 72
const MIN_ROOM_SIZE: int = 5
const MAX_ROOM_SIZE: int = 16
# BSP depth 4 → at most 16 leaf rooms; typically 8–12 after min-size culling.
const BSP_MAX_DEPTH: int = 4

enum TileType { WALL, FLOOR, DOOR_OPEN, DOOR_CLOSED, STAIRS_DOWN, STAIRS_UP, WATER, LAVA, TRAP, BRANCH_ENTRANCE, SHOP, ALTAR }

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
	_bsp_split(Rect2i(1, 1, MAP_WIDTH - 2, MAP_HEIGHT - 2), BSP_MAX_DEPTH)
	_connect_rooms()
	_ensure_reachability()
	_place_stairs()

func _init_map() -> void:
	map = []
	map.resize(MAP_WIDTH)
	for x in MAP_WIDTH:
		var col: Array = []
		col.resize(MAP_HEIGHT)
		for y in MAP_HEIGHT:
			col[y] = TileType.WALL
		map[x] = col

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
## connected neighbour rather than the next-by-index room. Cuts long
## diagonal corridors that the old sequential pairing produced.
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

func _ensure_reachability() -> void:
	if rooms.is_empty():
		return
	spawn_pos = _room_center(rooms[0])
	var reachable: Dictionary = _bfs_reachable(spawn_pos)
	for i in range(1, rooms.size()):
		var c: Vector2i = _room_center(rooms[i])
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

func _place_stairs() -> void:
	if rooms.is_empty():
		spawn_pos = Vector2i(MAP_WIDTH / 2, MAP_HEIGHT / 2)
		stairs_down_pos = spawn_pos
		stairs_down_pos2 = spawn_pos
		spawn_pos2 = spawn_pos
		return
	# Sort rooms by distance from room[0] center.
	spawn_pos = _room_center(rooms[0])
	var dists: Array = []
	for i in range(rooms.size()):
		var c: Vector2i = _room_center(rooms[i])
		dists.append({"idx": i, "d": abs(c.x - spawn_pos.x) + abs(c.y - spawn_pos.y)})
	dists.sort_custom(func(a, b): return a["d"] > b["d"])
	# Farthest room → stairs_down #1
	var far1_idx: int = dists[0]["idx"]
	stairs_down_pos = _room_center(rooms[far1_idx])
	map[stairs_down_pos.x][stairs_down_pos.y] = TileType.STAIRS_DOWN
	# Second farthest → stairs_down #2
	if dists.size() >= 3:
		var far2_idx: int = dists[1]["idx"]
		if far2_idx == 0:
			far2_idx = dists[2]["idx"] if dists.size() > 2 else far1_idx
		stairs_down_pos2 = _room_center(rooms[far2_idx])
		map[stairs_down_pos2.x][stairs_down_pos2.y] = TileType.STAIRS_DOWN
	else:
		stairs_down_pos2 = stairs_down_pos
	# Stairs up #1 at spawn
	map[spawn_pos.x][spawn_pos.y] = TileType.STAIRS_UP
	# Stairs up #2 in a different room (second closest to spawn)
	if rooms.size() >= 3:
		var near2_idx: int = dists[dists.size() - 2]["idx"]
		if near2_idx == 0:
			near2_idx = dists[dists.size() - 3]["idx"] if dists.size() > 2 else 0
		spawn_pos2 = _room_center(rooms[near2_idx])
		map[spawn_pos2.x][spawn_pos2.y] = TileType.STAIRS_UP
	else:
		spawn_pos2 = spawn_pos

func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < MAP_WIDTH and p.y >= 0 and p.y < MAP_HEIGHT

func get_tile(p: Vector2i) -> int:
	if not _in_bounds(p):
		return TileType.WALL
	return map[p.x][p.y]

func is_walkable(p: Vector2i) -> bool:
	var t: int = get_tile(p)
	return t == TileType.FLOOR or t == TileType.STAIRS_DOWN or t == TileType.STAIRS_UP or t == TileType.DOOR_OPEN
