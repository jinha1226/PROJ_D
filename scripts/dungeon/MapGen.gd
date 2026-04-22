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

static func generate(width: int, height: int, map_seed: int = -1) -> Dictionary:
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
	_split(Rect2i(1, 1, width - 2, height - 2), 0, rng, tiles, width, rooms)
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

static func _split(rect: Rect2i, depth: int, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array) -> void:
	var area: int = rect.size.x * rect.size.y
	if depth >= MAX_SPLIT_DEPTH or area < MIN_LEAF_AREA \
			or rect.size.x < MIN_ROOM_W + 2 or rect.size.y < MIN_ROOM_H + 2:
		_carve_room(rect, rng, tiles, width, rooms)
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
		if split_at < MIN_ROOM_H + 1 or rect.size.y - split_at < MIN_ROOM_H + 1:
			_carve_room(rect, rng, tiles, width, rooms)
			return
		_split(Rect2i(rect.position, Vector2i(rect.size.x, split_at)),
			depth + 1, rng, tiles, width, rooms)
		_split(Rect2i(rect.position + Vector2i(0, split_at),
				Vector2i(rect.size.x, rect.size.y - split_at)),
			depth + 1, rng, tiles, width, rooms)
	else:
		var split_at: int = int(rect.size.x * rng.randf_range(0.4, 0.6))
		if split_at < MIN_ROOM_W + 1 or rect.size.x - split_at < MIN_ROOM_W + 1:
			_carve_room(rect, rng, tiles, width, rooms)
			return
		_split(Rect2i(rect.position, Vector2i(split_at, rect.size.y)),
			depth + 1, rng, tiles, width, rooms)
		_split(Rect2i(rect.position + Vector2i(split_at, 0),
				Vector2i(rect.size.x - split_at, rect.size.y)),
			depth + 1, rng, tiles, width, rooms)

static func _carve_room(leaf: Rect2i, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array) -> void:
	var max_w: int = min(MAX_ROOM_W, leaf.size.x - 2)
	var max_h: int = min(MAX_ROOM_H, leaf.size.y - 2)
	if max_w < MIN_ROOM_W or max_h < MIN_ROOM_H:
		return
	var room_w: int = rng.randi_range(MIN_ROOM_W, max_w)
	var room_h: int = rng.randi_range(MIN_ROOM_H, max_h)
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
