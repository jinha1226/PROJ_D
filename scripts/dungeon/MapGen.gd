class_name MapGen extends RefCounted

## DCSS-inspired map generators.
## BSP: standard dungeon / Infernal (large rooms)
## Cave (CA): Swamp, Ice Caves — organic open spaces
## Crypt: formal rectangular grid chambers

const MIN_LEAF_AREA: int = 55
const MIN_ROOM_W: int = 4
const MIN_ROOM_H: int = 3
const MAX_ROOM_W: int = 8
const MAX_ROOM_H: int = 6
const MAX_SPLIT_DEPTH: int = 4
const SPLIT_MIN: float = 0.42
const SPLIT_MAX: float = 0.58

# ── Entry point ────────────────────────────────────────────────────────────

## style: "bsp" | "bsp_large" | "cave" | "crypt" | "temple"
static func generate_styled(width: int, height: int, map_seed: int,
		style: String, branch_entrance: bool = false) -> Dictionary:
	match style:
		"cave":
			return generate_cave(width, height, map_seed, branch_entrance)
		"crypt":
			return generate_crypt(width, height, map_seed)
		"bsp_large":
			return generate_bsp_large(width, height, map_seed, branch_entrance)
		"temple":
			return generate_temple(width, height)
		_:
			return generate(width, height, map_seed, branch_entrance)

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
	var stairs_down: Vector2i = _pick_primary_down_stairs(spawn, tiles, width, height, rng)
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
		"extra_stairs_down": [],
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

# ══ Cave generator (Cellular Automata) ════════════════════════════════════
# DCSS Swamp / Ice Caves: organic open spaces with irregular walls.

static func generate_cave(width: int, height: int, map_seed: int = -1,
		branch_entrance: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed >= 0 else randi()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	# Seed with ~44% floor noise (borders always wall)
	for y in range(height):
		for x in range(width):
			var idx: int = y * width + x
			if x == 0 or y == 0 or x == width - 1 or y == height - 1:
				tiles[idx] = DungeonMap.Tile.WALL
			else:
				tiles[idx] = DungeonMap.Tile.WALL if rng.randf() < 0.44 else DungeonMap.Tile.FLOOR
	# CA iterations: standard B5678/S45678 smoothing
	for _iter in range(5):
		var next := tiles.duplicate()
		for y in range(1, height - 1):
			for x in range(1, width - 1):
				var walls: int = _count_wall_neighbors(x, y, tiles, width, height)
				if tiles[y * width + x] == DungeonMap.Tile.WALL:
					next[y * width + x] = DungeonMap.Tile.FLOOR if walls < 4 else DungeonMap.Tile.WALL
				else:
					next[y * width + x] = DungeonMap.Tile.WALL if walls >= 5 else DungeonMap.Tile.FLOOR
		tiles = next
	# Pick a spawn in the densest floor region (center-biased BFS probe)
	var spawn: Vector2i = _cave_spawn(tiles, width, height, rng)
	# Seal off any floor tiles unreachable from spawn (ensures connectivity)
	_seal_disconnected(spawn, tiles, width, height)
	var stairs_down: Vector2i = _pick_primary_down_stairs(spawn, tiles, width, height, rng)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	var branch_pos := Vector2i(-1, -1)
	if branch_entrance:
		branch_pos = _cave_branch_pos(spawn, stairs_down, tiles, width, height)
		if branch_pos != Vector2i(-1, -1):
			tiles[branch_pos.y * width + branch_pos.x] = DungeonMap.Tile.BRANCH_DOWN
	var empty_rooms: Array[Rect2i] = []
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down,
			"extra_stairs_down": [], "stairs_up": spawn, "rooms": empty_rooms, "branch_pos": branch_pos}

static func _count_wall_neighbors(x: int, y: int, tiles: PackedByteArray,
		width: int, height: int) -> int:
	var count: int = 0
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx == 0 and dy == 0:
				continue
			var nx: int = x + dx; var ny: int = y + dy
			if nx < 0 or ny < 0 or nx >= width or ny >= height:
				count += 1
			elif tiles[ny * width + nx] == DungeonMap.Tile.WALL:
				count += 1
	return count

static func _cave_spawn(tiles: PackedByteArray, width: int, height: int,
		rng: RandomNumberGenerator) -> Vector2i:
	# Try center area first, fallback to any floor tile.
	var cx: int = width / 2; var cy: int = height / 2
	for radius in range(0, maxi(width, height)):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x: int = cx + dx; var y: int = cy + dy
				if x < 1 or y < 1 or x >= width - 1 or y >= height - 1:
					continue
				if tiles[y * width + x] == DungeonMap.Tile.FLOOR:
					return Vector2i(x, y)
	return Vector2i(1, 1)

static func _seal_disconnected(origin: Vector2i, tiles: PackedByteArray,
		width: int, height: int) -> void:
	var reachable: Dictionary = {origin: true}
	var frontier: Array[Vector2i] = [origin]
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_back()
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + step
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height: continue
			if reachable.has(n): continue
			if tiles[n.y * width + n.x] == DungeonMap.Tile.WALL: continue
			reachable[n] = true
			frontier.append(n)
	for y in range(height):
		for x in range(width):
			var p := Vector2i(x, y)
			if tiles[y * width + x] != DungeonMap.Tile.WALL and not reachable.has(p):
				tiles[y * width + x] = DungeonMap.Tile.WALL

static func _cave_branch_pos(spawn: Vector2i, stairs: Vector2i,
		tiles: PackedByteArray, width: int, height: int) -> Vector2i:
	# Mid-distance floor tile, not too close to either staircase.
	var cx: int = (spawn.x + stairs.x) / 2
	var cy: int = (spawn.y + stairs.y) / 2
	for radius in range(0, 8):
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				var x: int = cx + dx; var y: int = cy + dy
				if x < 1 or y < 1 or x >= width - 1 or y >= height - 1: continue
				var p := Vector2i(x, y)
				if tiles[y * width + x] == DungeonMap.Tile.FLOOR \
						and _chebyshev_v(p, spawn) > 4 and _chebyshev_v(p, stairs) > 4:
					return p
	return Vector2i(-1, -1)

static func _chebyshev_v(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


# ══ Crypt generator (Formal grid) ══════════════════════════════════════════
# DCSS Crypt: regular rectangular mausoleum chambers, narrow corridors.

static func generate_crypt(width: int, height: int, map_seed: int = -1) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed >= 0 else randi()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in tiles.size():
		tiles[i] = DungeonMap.Tile.WALL
	# 3 columns × 3 rows = 9 chambers
	const COLS: int = 3; const ROWS: int = 3
	var cell_w: int = (width - 2) / COLS
	var cell_h: int = (height - 2) / ROWS
	var rooms: Array[Rect2i] = []
	for row in range(ROWS):
		for col in range(COLS):
			var margin: int = 2
			var x0: int = 1 + col * cell_w + margin
			var y0: int = 1 + row * cell_h + margin
			var rw: int = cell_w - margin * 2
			var rh: int = cell_h - margin * 2
			if rw < 3 or rh < 3:
				continue
			var room := Rect2i(x0, y0, rw, rh)
			rooms.append(room)
			for y in range(y0, y0 + rh):
				for x in range(x0, x0 + rw):
					tiles[y * width + x] = DungeonMap.Tile.FLOOR
	# Connect horizontally adjacent rooms via 1-tile corridor
	for row in range(ROWS):
		for col in range(COLS - 1):
			var ri: int = row * COLS + col
			if ri + 1 >= rooms.size() or ri >= rooms.size():
				continue
			var r1: Rect2i = rooms[ri]; var r2: Rect2i = rooms[ri + 1]
			var cy: int = r1.position.y + r1.size.y / 2
			_carve_h(cy, r1.position.x + r1.size.x, r2.position.x, tiles, width)
	# Connect vertically adjacent rooms via 1-tile corridor
	for row in range(ROWS - 1):
		for col in range(COLS):
			var ri: int = row * COLS + col
			if ri + COLS >= rooms.size() or ri >= rooms.size():
				continue
			var r1: Rect2i = rooms[ri]; var r2: Rect2i = rooms[ri + COLS]
			var cx: int = r1.position.x + r1.size.x / 2
			_carve_v(cx, r1.position.y + r1.size.y, r2.position.y, tiles, width)
	if rooms.is_empty():
		return generate(width, height, map_seed, false)
	var spawn: Vector2i = rooms[0].get_center()
	var stairs_down: Vector2i = rooms[rooms.size() - 1].get_center()
	var extra_stairs_down: Array[Vector2i] = _pick_extra_down_stairs(spawn, stairs_down, tiles, width, height, 1)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	for p in extra_stairs_down:
		tiles[p.y * width + p.x] = DungeonMap.Tile.STAIRS_DOWN
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down,
			"extra_stairs_down": extra_stairs_down, "stairs_up": spawn, "rooms": rooms, "branch_pos": Vector2i(-1, -1)}


# ══ Large-room BSP (Infernal) ══════════════════════════════════════════════
# Grand halls: fewer splits, larger rooms, minimal cross-connections.

static func generate_bsp_large(width: int, height: int, map_seed: int = -1,
		branch_entrance: bool = false) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = map_seed if map_seed >= 0 else randi()
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in tiles.size():
		tiles[i] = DungeonMap.Tile.WALL
	var rooms: Array[Rect2i] = []
	_split_large(Rect2i(1, 1, width - 2, height - 2), 0, rng, tiles, width, rooms)
	if rooms.is_empty():
		return generate(width, height, map_seed, branch_entrance)
	for i in range(rooms.size() - 1):
		_connect_rooms(rooms[i], rooms[i + 1], tiles, width, rng)
	# Fewer cross-connections than standard BSP (more isolated chambers)
	for i in range(rooms.size()):
		for j in range(i + 2, rooms.size()):
			if _room_gap(rooms[i], rooms[j]) <= 3 and rng.randf() < 0.20:
				_connect_rooms(rooms[i], rooms[j], tiles, width, rng)
	var spawn: Vector2i = rooms[0].get_center()
	var stairs_down: Vector2i = _pick_primary_down_stairs(spawn, tiles, width, height, rng)
	var extra_stairs_down: Array[Vector2i] = _pick_extra_down_stairs(spawn, stairs_down, tiles, width, height, 1)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_down.y * width + stairs_down.x] = DungeonMap.Tile.STAIRS_DOWN
	for p in extra_stairs_down:
		tiles[p.y * width + p.x] = DungeonMap.Tile.STAIRS_DOWN
	if branch_entrance and rooms.size() >= 2:
		var mid: Rect2i = rooms[rooms.size() / 2]
		var c: Vector2i = mid.get_center()
		if tiles[c.y * width + c.x] == DungeonMap.Tile.FLOOR:
			tiles[c.y * width + c.x] = DungeonMap.Tile.BRANCH_DOWN
	return {"tiles": tiles, "spawn": spawn, "stairs_down": stairs_down,
			"extra_stairs_down": extra_stairs_down, "stairs_up": spawn, "rooms": rooms, "branch_pos": Vector2i(-1, -1)}

static func _split_large(rect: Rect2i, depth: int, rng: RandomNumberGenerator,
		tiles: PackedByteArray, width: int, rooms: Array[Rect2i]) -> void:
	const MAX_D: int = 3
	const MIN_AREA: int = 90
	const MIN_W: int = 6; const MIN_H: int = 5
	const MAX_W: int = 14; const MAX_H: int = 10
	var area: int = rect.size.x * rect.size.y
	if depth >= MAX_D or area < MIN_AREA or rect.size.x < MIN_W + 2 or rect.size.y < MIN_H + 2:
		var mw: int = mini(MAX_W, rect.size.x - 2)
		var mh: int = mini(MAX_H, rect.size.y - 2)
		if mw < MIN_W or mh < MIN_H:
			return
		var rw: int = rng.randi_range(MIN_W, mw)
		var rh: int = rng.randi_range(MIN_H, mh)
		var x0: int = rect.position.x + rng.randi_range(1, maxi(1, rect.size.x - rw - 1))
		var y0: int = rect.position.y + rng.randi_range(1, maxi(1, rect.size.y - rh - 1))
		var room := Rect2i(x0, y0, rw, rh)
		rooms.append(room)
		for y in range(y0, y0 + rh):
			for x in range(x0, x0 + rw):
				tiles[y * width + x] = DungeonMap.Tile.FLOOR
		return
	var horizontal: bool = rect.size.y > rect.size.x if rect.size.x != rect.size.y else rng.randf() < 0.5
	if horizontal:
		var s: int = clampi(int(rect.size.y * rng.randf_range(0.40, 0.60)), MIN_H + 2, rect.size.y - MIN_H - 2)
		if s <= 0 or s >= rect.size.y: _split_large(rect, MAX_D, rng, tiles, width, rooms); return
		_split_large(Rect2i(rect.position, Vector2i(rect.size.x, s)), depth + 1, rng, tiles, width, rooms)
		_split_large(Rect2i(rect.position + Vector2i(0, s), Vector2i(rect.size.x, rect.size.y - s)), depth + 1, rng, tiles, width, rooms)
	else:
		var s: int = clampi(int(rect.size.x * rng.randf_range(0.40, 0.60)), MIN_W + 2, rect.size.x - MIN_W - 2)
		if s <= 0 or s >= rect.size.x: _split_large(rect, MAX_D, rng, tiles, width, rooms); return
		_split_large(Rect2i(rect.position, Vector2i(s, rect.size.y)), depth + 1, rng, tiles, width, rooms)
		_split_large(Rect2i(rect.position + Vector2i(s, 0), Vector2i(rect.size.x - s, rect.size.y)), depth + 1, rng, tiles, width, rooms)


# ══ Temple generator (B3 symmetric Pantheon) ══════════════════════════════
# DCSS-Temple-inspired: bilaterally symmetric, formal halls and side wings,
# fixed stair positions top/bottom, preset altar slots.
#
# Layout  (width=32, height=36):
#   Entry corridor      x:14–17  y:1–5      (stairs_up  at 15,1)
#   Upper antechamber   x:11–20  y:4–10
#   Upper side wings    x:2–11 / x:20–29    y:4–9   (mirrored)
#   Central grand hall  x:6–25              y:10–25
#   Mid side wings      x:2–6  / x:25–29   y:13–21  (mirrored)
#   Lower antechamber   x:11–20             y:24–30
#   Lower side wings    x:2–11 / x:20–29   y:25–30  (mirrored)
#   Exit corridor       x:14–17             y:29–34  (stairs_down at 15,34)

static func generate_temple(width: int, height: int) -> Dictionary:
	var tiles := PackedByteArray()
	tiles.resize(width * height)
	for i in tiles.size():
		tiles[i] = DungeonMap.Tile.WALL

	var offset_x: int = maxi(0, (width - 32) / 2)
	var offset_y: int = maxi(0, (height - 36) / 2)
	var r := func(x: int, y: int, w: int, h: int) -> Rect2i:
		return Rect2i(x + offset_x, y + offset_y, w, h)

	# Entry spine and vestibule.
	_carve_rect(r.call(14, 1, 4, 4), tiles, width)
	_carve_rect(r.call(11, 4, 10, 5), tiles, width)

	# Symmetric shrine complex with distinct altar rooms.
	var nw_shrine: Rect2i = r.call(3, 5, 7, 6)
	var ne_shrine: Rect2i = r.call(22, 5, 7, 6)
	var center_hall: Rect2i = r.call(10, 10, 12, 7)
	var sw_shrine: Rect2i = r.call(3, 23, 7, 6)
	var se_shrine: Rect2i = r.call(22, 23, 7, 6)
	var rear_sanctum: Rect2i = r.call(11, 28, 10, 4)
	var west_aisle: Rect2i = r.call(6, 12, 5, 10)
	var east_aisle: Rect2i = r.call(21, 12, 5, 10)
	var lower_nave: Rect2i = r.call(10, 18, 12, 6)
	var exit_corridor: Rect2i = r.call(14, 32, 4, 3)

	for room in [nw_shrine, ne_shrine, center_hall, sw_shrine, se_shrine, rear_sanctum, west_aisle, east_aisle, lower_nave, exit_corridor]:
		_carve_rect(room, tiles, width)

	# Narrow connectors keep the temple room-based rather than one open blob.
	_carve_rect(r.call(10, 6, 2, 2), tiles, width)
	_carve_rect(r.call(20, 6, 2, 2), tiles, width)
	_carve_rect(r.call(14, 8, 4, 3), tiles, width)
	_carve_rect(r.call(10, 14, 2, 2), tiles, width)
	_carve_rect(r.call(20, 14, 2, 2), tiles, width)
	_carve_rect(r.call(10, 21, 2, 2), tiles, width)
	_carve_rect(r.call(20, 21, 2, 2), tiles, width)
	_carve_rect(r.call(14, 24, 4, 5), tiles, width)
	_carve_rect(r.call(14, 31, 4, 2), tiles, width)

	var spawn := Vector2i(15 + offset_x, 1 + offset_y)
	var stairs_dn := Vector2i(15 + offset_x, 34 + offset_y)
	tiles[spawn.y * width + spawn.x] = DungeonMap.Tile.STAIRS_UP
	tiles[stairs_dn.y * width + stairs_dn.x] = DungeonMap.Tile.STAIRS_DOWN

	# One altar per shrine room.
	var faith_altars: Array[Vector2i] = [
		nw_shrine.get_center(),
		ne_shrine.get_center(),
		rear_sanctum.get_center(),
		sw_shrine.get_center(),
		se_shrine.get_center(),
	]

	# Decorative broken altars in secondary aisles and vestibule.
	var broken_altars: Array[Vector2i] = [
		west_aisle.get_center(),
		east_aisle.get_center(),
		Vector2i(15 + offset_x, 6 + offset_y),
		Vector2i(15 + offset_x, 20 + offset_y),
		Vector2i(8 + offset_x, 17 + offset_y),
		Vector2i(23 + offset_x, 17 + offset_y),
	]

	var rooms: Array[Rect2i] = [nw_shrine, ne_shrine, center_hall, sw_shrine, se_shrine, rear_sanctum, west_aisle, east_aisle, lower_nave]
	return {
		"tiles":                  tiles,
		"spawn":                  spawn,
		"stairs_down":            stairs_dn,
		"extra_stairs_down":      [],
		"stairs_up":              spawn,
		"rooms":                  rooms,
		"branch_pos":             Vector2i(-1, -1),
		"preset_faith_altars":    faith_altars,
		"preset_broken_altars":   broken_altars,
	}

static func _carve_rect(rect: Rect2i, tiles: PackedByteArray, width: int) -> void:
	for y in range(rect.position.y, rect.position.y + rect.size.y):
		for x in range(rect.position.x, rect.position.x + rect.size.x):
			tiles[y * width + x] = DungeonMap.Tile.FLOOR

## Carve left_rect and its horizontal mirror (x_right = width - x_left - size.x).
static func _carve_symmetric(left_rect: Rect2i, tiles: PackedByteArray, width: int) -> void:
	_carve_rect(left_rect, tiles, width)
	var rx: int = width - left_rect.position.x - left_rect.size.x
	_carve_rect(Rect2i(rx, left_rect.position.y, left_rect.size.x, left_rect.size.y),
			tiles, width)

# ── BFS farthest floor ─────────────────────────────────────────────────────


static func _pick_primary_down_stairs(origin: Vector2i, tiles: PackedByteArray,
		width: int, height: int, rng: RandomNumberGenerator) -> Vector2i:
	var dist: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var floors: Array[Vector2i] = []
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		if p != origin and tiles[p.y * width + p.x] == DungeonMap.Tile.FLOOR:
			floors.append(p)
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + step
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if dist.has(n):
				continue
			var t: int = tiles[n.y * width + n.x]
			if t == DungeonMap.Tile.WALL:
				continue
			dist[n] = int(dist[p]) + 1
			frontier.append(n)
	if floors.is_empty():
		return origin
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(dist[a]) > int(dist[b]))
	var candidate_count: int = maxi(1, mini(6, floors.size()))
	return floors[rng.randi_range(0, candidate_count - 1)]

static func _pick_extra_down_stairs(origin: Vector2i, primary: Vector2i,
		tiles: PackedByteArray, width: int, height: int, count: int = 1) -> Array[Vector2i]:
	var dist: Dictionary = {origin: 0}
	var frontier: Array[Vector2i] = [origin]
	var floors: Array[Vector2i] = []
	while not frontier.is_empty():
		var p: Vector2i = frontier.pop_front()
		if p != origin and p != primary and tiles[p.y * width + p.x] == DungeonMap.Tile.FLOOR:
			floors.append(p)
		for step in [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]:
			var n: Vector2i = p + step
			if n.x < 0 or n.y < 0 or n.x >= width or n.y >= height:
				continue
			if dist.has(n):
				continue
			var t: int = tiles[n.y * width + n.x]
			if t == DungeonMap.Tile.WALL:
				continue
			dist[n] = int(dist[p]) + 1
			frontier.append(n)
	floors.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return int(dist[a]) > int(dist[b]))
	var picked: Array[Vector2i] = []
	for p in floors:
		if _chebyshev_v(p, primary) <= 4:
			continue
		picked.append(p)
		if picked.size() >= count:
			break
	if picked.is_empty():
		for p in floors:
			if not picked.has(p):
				picked.append(p)
				break
	return picked

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
