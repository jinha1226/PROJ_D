class_name MapGen extends RefCounted

## BSP dungeon generator per guide §4.2a.
## Output keys: tiles (PackedByteArray), spawn (Vector2i),
## stairs_down (Vector2i), stairs_up (Vector2i), rooms (Array[Rect2i]).

const MIN_LEAF_AREA: int = 80
const MIN_ROOM_W: int = 4
const MIN_ROOM_H: int = 3
const MAX_ROOM_W: int = 8
const MAX_ROOM_H: int = 7
const MAX_SPLIT_DEPTH: int = 4

static func generate(width: int, height: int, map_seed: int = -1, style: String = "bsp") -> Dictionary:
	match style:
		"ca", "ca_open":
			return _generate_ca(width, height, map_seed, style)
		"ca_water", "ca_lava":
			return _generate_ca_scatter(width, height, map_seed, style)
		"bsp_tight":
			return _generate_bsp(width, height, map_seed, 5, 4, 6, 4)
		"bsp_long":
			return _generate_bsp(width, height, map_seed, 4, 3, 6, 4, 5)
		"bsp_large":
			return _generate_bsp(width, height, map_seed, 6, 5, 12, 10)
		"boss":
			return _generate_boss(width, height, map_seed)
		_:  # "bsp" default
			return _generate_bsp(width, height, map_seed)

static func _generate_bsp(width: int, height: int, map_seed: int = -1,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H,
		max_split_depth: int = MAX_SPLIT_DEPTH) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if map_seed >= 0:
		rng.seed = map_seed
	else:
		rng.randomize()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.WALL
	var rooms: Array[Rect2i] = []
	_split(Rect2i(1, 1, width - 2, height - 2), 0, rng, tiles, width, rooms,
		min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
	if rooms.is_empty():
		# Defensive: dig a single central room so the map is always playable.
		var fallback := Rect2i(width / 2 - 4, height / 2 - 3, 8, 6)
		rooms.append(fallback)
		for y in range(fallback.position.y, fallback.position.y + fallback.size.y):
			for x in range(fallback.position.x, fallback.position.x + fallback.size.x):
				tiles[y * width + x] = DungeonMap.Tile.FLOOR
	for i in range(rooms.size() - 1):
		_carve_corridor(rooms[i].get_center(), rooms[i + 1].get_center(),
			tiles, width, rng)
	var spawn: Vector2i = rooms[0].get_center()
	var stairs_down: Vector2i = _farthest_floor(spawn, tiles, width, height)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	return {
		"tiles": tiles,
		"spawn": spawn,
		"stairs_down": stairs_down,
		"stairs_up": spawn,
		"rooms": rooms,
	}

static func _generate_ca(width: int, height: int, map_seed: int, style: String) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	if map_seed >= 0:
		rng.seed = map_seed
	else:
		rng.randomize()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	# Initial random fill (45% FLOOR)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.FLOOR if rng.randf() < 0.45 else DungeonMap.Tile.WALL
	# Border always WALL
	for x in range(width):
		tiles[x] = DungeonMap.Tile.WALL
		tiles[(height - 1) * width + x] = DungeonMap.Tile.WALL
	for y in range(height):
		tiles[y * width] = DungeonMap.Tile.WALL
		tiles[y * width + width - 1] = DungeonMap.Tile.WALL
	# CA iterations
	var birth: int = 4 if style == "ca_open" else 5
	var death: int = 5 if style == "ca_open" else 4
	for _iter in range(4):
		var next := tiles.duplicate()
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var neighbors: int = _count_wall_neighbors(tiles, x, y, width, height)
				if tiles[y * width + x] == DungeonMap.Tile.WALL:
					next[y * width + x] = DungeonMap.Tile.WALL if neighbors >= death else DungeonMap.Tile.FLOOR
				else:
					next[y * width + x] = DungeonMap.Tile.WALL if neighbors >= birth else DungeonMap.Tile.FLOOR
		tiles = next
	# Keep largest connected region
	tiles = _keep_largest_region(tiles, width, height)
	var spawn: Vector2i = _find_floor_tile(tiles, width, height, rng)
	var stairs_down: Vector2i = _farthest_floor(spawn, tiles, width, height)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down, "stairs_up": spawn, "rooms": []}

static func _generate_ca_scatter(width: int, height: int, map_seed: int, style: String) -> Dictionary:
	var result: Dictionary = _generate_ca(width, height, map_seed, "ca")
	var tiles: PackedByteArray = result["tiles"]
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed ^ 0xDEADBEEF if map_seed >= 0 else rng.randi()
	var scatter_tile: int
	var density: float
	if style == "ca_water":
		scatter_tile = 6  # DungeonMap.Tile.WATER (added in Task 3)
		density = 0.15
	else:  # ca_lava
		scatter_tile = 7  # DungeonMap.Tile.LAVA (added in Task 3)
		density = 0.12
	var spawn: Vector2i = result["spawn"]
	var stairs: Vector2i = result["stairs_down"]
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if tiles[y * width + x] != DungeonMap.Tile.FLOOR:
				continue
			if p.distance_to(spawn) < 3.0 or p.distance_to(stairs) < 3.0:
				continue
			if rng.randf() < density:
				tiles[y * width + x] = scatter_tile
	result["tiles"] = tiles
	return result

static func _generate_boss(width: int, height: int, map_seed: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in range(tiles.size()):
		tiles[i] = DungeonMap.Tile.WALL
	var room_w: int = 20
	var room_h: int = 15
	var x0: int = (width - room_w) / 2
	var y0: int = (height - room_h) / 2
	for y in range(y0, y0 + room_h):
		for x in range(x0, x0 + room_w):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR
	var cx: int = width / 2
	for y in range(2, y0):
		tiles[y * width + cx] = DungeonMap.Tile.FLOOR
	var spawn := Vector2i(cx, y0 + room_h - 2)
	var stairs_up := Vector2i(cx, 3)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	var boss_room := Rect2i(x0, y0, room_w, room_h)
	return {"tiles": tiles, "spawn": spawn, "stairs_down": spawn,
		"stairs_up": stairs_up, "rooms": [boss_room]}

static func _split(rect: Rect2i, depth: int, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H,
		max_split_depth: int = MAX_SPLIT_DEPTH) -> void:
	var area: int = rect.size.x * rect.size.y
	if depth >= max_split_depth or area < MIN_LEAF_AREA \
			or rect.size.x < min_room_w + 2 or rect.size.y < min_room_h + 2:
		_carve_room(rect, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h)
		return
	var horizontal: bool
	if rect.size.x > int(rect.size.y * 1.25):
		horizontal = false
	elif rect.size.y > int(rect.size.x * 1.25):
		horizontal = true
	else:
		horizontal = rng.randf() < 0.5
	if horizontal:
		var split_at: int = int(rect.size.y * rng.randf_range(0.4, 0.6))
		if split_at < min_room_h + 1 or rect.size.y - split_at < min_room_h + 1:
			_carve_room(rect, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h)
			return
		_split(Rect2i(rect.position, Vector2i(rect.size.x, split_at)),
			depth + 1, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
		_split(Rect2i(rect.position + Vector2i(0, split_at),
				Vector2i(rect.size.x, rect.size.y - split_at)),
			depth + 1, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
	else:
		var split_at: int = int(rect.size.x * rng.randf_range(0.4, 0.6))
		if split_at < min_room_w + 1 or rect.size.x - split_at < min_room_w + 1:
			_carve_room(rect, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h)
			return
		_split(Rect2i(rect.position, Vector2i(split_at, rect.size.y)),
			depth + 1, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)
		_split(Rect2i(rect.position + Vector2i(split_at, 0),
				Vector2i(rect.size.x - split_at, rect.size.y)),
			depth + 1, rng, tiles, width, rooms, min_room_w, min_room_h, max_room_w, max_room_h, max_split_depth)

static func _carve_room(leaf: Rect2i, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array,
		min_room_w: int = MIN_ROOM_W, min_room_h: int = MIN_ROOM_H,
		max_room_w: int = MAX_ROOM_W, max_room_h: int = MAX_ROOM_H) -> void:
	var max_w: int = min(max_room_w, leaf.size.x - 2)
	var max_h: int = min(max_room_h, leaf.size.y - 2)
	if max_w < min_room_w or max_h < min_room_h:
		return
	var room_w: int = rng.randi_range(min_room_w, max_w)
	var room_h: int = rng.randi_range(min_room_h, max_h)
	var x0: int = leaf.position.x + rng.randi_range(1, leaf.size.x - room_w - 1)
	var y0: int = leaf.position.y + rng.randi_range(1, leaf.size.y - room_h - 1)
	var room := Rect2i(x0, y0, room_w, room_h)
	rooms.append(room)
	for y in range(y0, y0 + room_h):
		for x in range(x0, x0 + room_w):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

static func _carve_corridor(a: Vector2i, b: Vector2i,
		tiles: PackedByteArray, width: int, rng: RandomNumberGenerator) -> void:
	# L-corridor. Flip horizontal/vertical-first randomly for variety.
	var horizontal_first: bool = rng.randf() < 0.5
	if horizontal_first:
		_carve_h(a.y, a.x, b.x, tiles, width)
		_carve_v(b.x, a.y, b.y, tiles, width)
	else:
		_carve_v(a.x, a.y, b.y, tiles, width)
		_carve_h(b.y, a.x, b.x, tiles, width)

static func _carve_h(y: int, x0: int, x1: int, tiles: PackedByteArray, width: int) -> void:
	var lo: int = min(x0, x1)
	var hi: int = max(x0, x1)
	for x in range(lo, hi + 1):
		tiles[y * width + x] = DungeonMap.Tile.FLOOR

static func _carve_v(x: int, y0: int, y1: int, tiles: PackedByteArray, width: int) -> void:
	var lo: int = min(y0, y1)
	var hi: int = max(y0, y1)
	for y in range(lo, hi + 1):
		tiles[y * width + x] = DungeonMap.Tile.FLOOR

static func _count_wall_neighbors(tiles: PackedByteArray, x: int, y: int, width: int, height: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx
			var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				count += 1
				continue
			if tiles[ny * width + nx] == DungeonMap.Tile.WALL:
				count += 1
	return count

static func _keep_largest_region(tiles: PackedByteArray, width: int, height: int) -> PackedByteArray:
	var visited: Dictionary = {}
	var best_region: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if visited.has(p) or tiles[y * width + x] == DungeonMap.Tile.WALL:
				continue
			var region: Array[Vector2i] = []
			var frontier: Array[Vector2i] = [p]
			while not frontier.is_empty():
				var cur: Vector2i = frontier.pop_back()
				if visited.has(cur):
					continue
				visited[cur] = true
				region.append(cur)
				for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
					var n: Vector2i = cur + step
					if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
						continue
					if not visited.has(n) and tiles[n.y * width + n.x] == DungeonMap.Tile.FLOOR:
						frontier.append(n)
			if region.size() > best_region.size():
				best_region = region
	var best_set: Dictionary = {}
	for p in best_region:
		best_set[p] = true
	var result := tiles.duplicate()
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if tiles[y * width + x] == DungeonMap.Tile.FLOOR and not best_set.has(p):
				result[y * width + x] = DungeonMap.Tile.WALL
	return result

static func _find_floor_tile(tiles: PackedByteArray, width: int, height: int,
		rng: RandomNumberGenerator) -> Vector2i:
	var floor_tiles: Array[Vector2i] = []
	for y in range(height):
		for x in range(width):
			if tiles[y * width + x] == DungeonMap.Tile.FLOOR:
				floor_tiles.append(Vector2i(x, y))
	if floor_tiles.is_empty():
		return Vector2i(width / 2, height / 2)
	return floor_tiles[rng.randi_range(0, floor_tiles.size() - 1)]

static func _farthest_floor(origin: Vector2i, tiles: PackedByteArray,
		width: int, height: int) -> Vector2i:
	var dist: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var farthest: Vector2i = origin
	var max_d: int = 0
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		var d: int = int(dist[p])
		if d > max_d:
			max_d = d
			farthest = p
		for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var n: Vector2i = p + step
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if dist.has(n):
				continue
			var t: int = tiles[n.y * width + n.x]
			if t == DungeonMap.Tile.WALL:
				continue
			dist[n] = d + 1
			frontier.append(n)
	return farthest
