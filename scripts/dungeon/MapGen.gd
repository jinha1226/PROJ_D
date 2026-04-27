class_name MapGen extends RefCounted

## DCSS-inspired BSP generator.
## Corridors connect nearest room edges (not centers) → shorter corridors.
## Cross-connections added to reduce dead ends.
## Doors placed at room entrances (narrow passage points).

const MIN_LEAF_AREA: int = 55
const MIN_ROOM_W: int = 4
const MIN_ROOM_H: int = 3
const MAX_ROOM_W: int = 8
const MAX_ROOM_H: int = 6
const MAX_SPLIT_DEPTH: int = 4
const SPLIT_MIN: float = 0.42
const SPLIT_MAX: float = 0.58

## Single large symmetric hall — no monsters, faith choice on entry.
static func generate_pantheon(width: int, height: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in tiles.size():
		tiles[i] = DungeonMap.Tile.WALL

	var room_w: int = 16
	var room_h: int = 10
	var rx: int = (width - room_w) / 2
	var ry: int = (height - room_h) / 2
	var room := Rect2i(rx, ry, room_w, room_h)

	for y in range(ry, ry + room_h):
		for x in range(rx, rx + room_w):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

	var spawn := Vector2i(rx + 1, ry + room_h / 2)
	var stairs_down := Vector2i(rx + room_w - 2, ry + room_h / 2)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN

	return {
		"tiles": tiles,
		"spawn": spawn,
		"stairs_down": stairs_down,
		"stairs_up": spawn,
		"rooms": [room],
		"branch_pos": Vector2i(-1, -1),
	}

static func generate(width: int, height: int, map_seed: int = -1,
		branch_entrance: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed >= 0 else randi()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in tiles.size():
		tiles[i] = DungeonMap.Tile.WALL
	var rooms: Array[Rect2i] = []
	_split(Rect2i(1, 1, width - 2, height - 2), 0, rng, tiles, width, rooms)
	if rooms.is_empty():
		var fb := Rect2i(width / 2 - 4, height / 2 - 3, 8, 6)
		rooms.append(fb)
		for y in range(fb.position.y, fb.end.y):
			for x in range(fb.position.x, fb.end.x):
				tiles[y * width + x] = DungeonMap.Tile.FLOOR
	# Connect BSP-ordered rooms via nearest-edge corridors.
	for i in range(rooms.size() - 1):
		_connect_rooms(rooms[i], rooms[i + 1], tiles, width, rng)
	# Extra cross-connections between close non-adjacent rooms → fewer dead ends.
	_add_cross_connections(rooms, tiles, width, rng)
	# Place doors at narrow room entrances.
	_place_doors(rooms, tiles, width, height, rng)
	var spawn: Vector2i = rooms[0].get_center()
	var stairs_down: Vector2i = _farthest_floor(spawn, tiles, width, height)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	var branch_pos: Vector2i = Vector2i(-1, -1)
	if branch_entrance and rooms.size() >= 2:
		# Place branch entrance in a middle room, away from stairs.
		var mid_idx: int = rooms.size() / 2
		var mid_room: Rect2i = rooms[mid_idx]
		var candidate: Vector2i = mid_room.get_center()
		if tiles[candidate.y * width + candidate.x] == DungeonMap.Tile.FLOOR:
			tiles[candidate.y * width + candidate.x] = DungeonMap.Tile.BRANCH_DOWN
			branch_pos = candidate
	return {
		"tiles": tiles,
		"spawn": spawn,
		"stairs_down": stairs_down,
		"stairs_up": spawn,
		"rooms": rooms,
		"branch_pos": branch_pos,
	}

# ── BSP split ──────────────────────────────────────────────────────────────

static func _split(rect: Rect2i, depth: int, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array[Rect2i]) -> void:
	var area: int = rect.size.x * rect.size.y
	if depth >= MAX_SPLIT_DEPTH or area < MIN_LEAF_AREA \
			or rect.size.x < MIN_ROOM_W + 2 or rect.size.y < MIN_ROOM_H + 2:
		_carve_room(rect, rng, tiles, width, rooms)
		return
	var horizontal: bool
	if rect.size.x > int(rect.size.y * 1.3):
		horizontal = false
	elif rect.size.y > int(rect.size.x * 1.3):
		horizontal = true
	else:
		horizontal = rng.randf() < 0.5
	if horizontal:
		var raw: int = int(rect.size.y * rng.randf_range(SPLIT_MIN, SPLIT_MAX))
		var split_at: int = clampi(raw, MIN_ROOM_H + 2, rect.size.y - MIN_ROOM_H - 2)
		if split_at <= 0 or split_at >= rect.size.y:
			_carve_room(rect, rng, tiles, width, rooms)
			return
		_split(Rect2i(rect.position, Vector2i(rect.size.x, split_at)),
				depth + 1, rng, tiles, width, rooms)
		_split(Rect2i(rect.position + Vector2i(0, split_at),
				Vector2i(rect.size.x, rect.size.y - split_at)),
				depth + 1, rng, tiles, width, rooms)
	else:
		var raw: int = int(rect.size.x * rng.randf_range(SPLIT_MIN, SPLIT_MAX))
		var split_at: int = clampi(raw, MIN_ROOM_W + 2, rect.size.x - MIN_ROOM_W - 2)
		if split_at <= 0 or split_at >= rect.size.x:
			_carve_room(rect, rng, tiles, width, rooms)
			return
		_split(Rect2i(rect.position, Vector2i(split_at, rect.size.y)),
				depth + 1, rng, tiles, width, rooms)
		_split(Rect2i(rect.position + Vector2i(split_at, 0),
				Vector2i(rect.size.x - split_at, rect.size.y)),
				depth + 1, rng, tiles, width, rooms)

static func _carve_room(leaf: Rect2i, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array[Rect2i]) -> void:
	var max_w: int = mini(MAX_ROOM_W, leaf.size.x - 2)
	var max_h: int = mini(MAX_ROOM_H, leaf.size.y - 2)
	if max_w < MIN_ROOM_W or max_h < MIN_ROOM_H:
		return
	var room_w: int = rng.randi_range(MIN_ROOM_W, max_w)
	var room_h: int = rng.randi_range(MIN_ROOM_H, max_h)
	var x0: int = leaf.position.x + rng.randi_range(1, maxi(1, leaf.size.x - room_w - 1))
	var y0: int = leaf.position.y + rng.randi_range(1, maxi(1, leaf.size.y - room_h - 1))
	var room := Rect2i(x0, y0, room_w, room_h)
	rooms.append(room)
	for y in range(y0, y0 + room_h):
		for x in range(x0, x0 + room_w):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

# ── Nearest-edge corridor ──────────────────────────────────────────────────

static func _connect_rooms(a: Rect2i, b: Rect2i,
		tiles: PackedByteArray, width: int, rng: RandomNumberGenerator) -> void:
	var ax0: int = a.position.x; var ax1: int = a.position.x + a.size.x - 1
	var ay0: int = a.position.y; var ay1: int = a.position.y + a.size.y - 1
	var bx0: int = b.position.x; var bx1: int = b.position.x + b.size.x - 1
	var by0: int = b.position.y; var by1: int = b.position.y + b.size.y - 1
	# X-ranges overlap → single vertical corridor.
	var ox0: int = maxi(ax0, bx0); var ox1: int = mini(ax1, bx1)
	if ox1 >= ox0:
		var cx: int = rng.randi_range(ox0, ox1)
		_carve_v(cx, ay1 if ay1 < by0 else ay0, by0 if ay1 < by0 else by1, tiles, width)
		return
	# Y-ranges overlap → single horizontal corridor.
	var oy0: int = maxi(ay0, by0); var oy1: int = mini(ay1, by1)
	if oy1 >= oy0:
		var cy: int = rng.randi_range(oy0, oy1)
		_carve_h(cy, ax1 if ax1 < bx0 else ax0, bx0 if ax1 < bx0 else bx1, tiles, width)
		return
	# No overlap → L-shape from nearest corner pair.
	var px_a: int = ax1 if ax1 < bx0 else ax0
	var px_b: int = bx0 if ax1 < bx0 else bx1
	var py_a: int = ay1 if ay1 < by0 else ay0
	var py_b: int = by0 if ay1 < by0 else by1
	if rng.randf() < 0.5:
		_carve_h(py_a, px_a, px_b, tiles, width)
		_carve_v(px_b, py_a, py_b, tiles, width)
	else:
		_carve_v(px_a, py_a, py_b, tiles, width)
		_carve_h(py_b, px_a, px_b, tiles, width)

static func _add_cross_connections(rooms: Array[Rect2i], tiles: PackedByteArray,
		width: int, rng: RandomNumberGenerator) -> void:
	for i in range(rooms.size()):
		for j in range(i + 2, rooms.size()):
			if _room_gap(rooms[i], rooms[j]) <= 5 and rng.randf() < 0.35:
				_connect_rooms(rooms[i], rooms[j], tiles, width, rng)

static func _room_gap(a: Rect2i, b: Rect2i) -> int:
	var ax1: int = a.position.x + a.size.x - 1; var ay1: int = a.position.y + a.size.y - 1
	var bx1: int = b.position.x + b.size.x - 1; var by1: int = b.position.y + b.size.y - 1
	var dx: int = maxi(0, maxi(b.position.x - ax1, a.position.x - bx1))
	var dy: int = maxi(0, maxi(b.position.y - ay1, a.position.y - by1))
	return dx + dy

# ── Door placement ─────────────────────────────────────────────────────────

static func _place_doors(rooms: Array[Rect2i], tiles: PackedByteArray,
		width: int, height: int, rng: RandomNumberGenerator) -> void:
	for room in rooms:
		var rx0: int = room.position.x; var ry0: int = room.position.y
		var rx1: int = room.position.x + room.size.x - 1
		var ry1: int = room.position.y + room.size.y - 1
		# Scan cells just outside each edge of the room.
		for x in range(rx0, rx1 + 1):
			_try_place_door(x, ry0 - 1, tiles, width, height, rng)
			_try_place_door(x, ry1 + 1, tiles, width, height, rng)
		for y in range(ry0, ry1 + 1):
			_try_place_door(rx0 - 1, y, tiles, width, height, rng)
			_try_place_door(rx1 + 1, y, tiles, width, height, rng)

static func _try_place_door(x: int, y: int, tiles: PackedByteArray,
		width: int, height: int, rng: RandomNumberGenerator) -> void:
	if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
		return
	if tiles[y * width + x] != DungeonMap.Tile.FLOOR:
		return
	var door_closed: int = DungeonMap.Tile.DOOR_CLOSED
	# Skip if an adjacent cell already has a door (avoids double-door between close rooms).
	for step in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		if tiles[(y + step.y) * width + (x + step.x)] == door_closed:
			return
	# Only place door where walls flank on the perpendicular axis
	# (ensures it's a 1-tile-wide passage, not an open area).
	var left: int  = tiles[y * width + (x - 1)]
	var right: int = tiles[y * width + (x + 1)]
	var up: int    = tiles[(y - 1) * width + x]
	var down: int  = tiles[(y + 1) * width + x]
	var wall: int  = DungeonMap.Tile.WALL
	var h_pass: bool = (left == wall and right == wall)
	var v_pass: bool = (up  == wall and down  == wall)
	if not (h_pass or v_pass):
		return
	# 45% closed door, 20% open door, 35% no door (plain floor).
	var roll: float = rng.randf()
	if roll < 0.45:
		tiles[y * width + x] = DungeonMap.Tile.DOOR_CLOSED
	elif roll < 0.65:
		tiles[y * width + x] = DungeonMap.Tile.DOOR_OPEN

# ── Carve helpers ──────────────────────────────────────────────────────────

static func _carve_h(y: int, x0: int, x1: int,
		tiles: PackedByteArray, width: int) -> void:
	var lo: int = mini(x0, x1); var hi: int = maxi(x0, x1)
	for x in range(lo, hi + 1):
		if tiles[y * width + x] == DungeonMap.Tile.WALL:
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

static func _carve_v(x: int, y0: int, y1: int,
		tiles: PackedByteArray, width: int) -> void:
	var lo: int = mini(y0, y1); var hi: int = maxi(y0, y1)
	for y in range(lo, hi + 1):
		if tiles[y * width + x] == DungeonMap.Tile.WALL:
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

# ── BFS farthest floor ─────────────────────────────────────────────────────

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
			max_d = d; farthest = p
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
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
