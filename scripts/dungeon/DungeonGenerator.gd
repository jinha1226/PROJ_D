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

enum TileType { WALL, FLOOR, DOOR_OPEN, DOOR_CLOSED, STAIRS_DOWN, STAIRS_UP, WATER, LAVA, TRAP, BRANCH_ENTRANCE, SHOP, ALTAR, TREE, ACID, CRYSTAL_WALL, GLASS_WALL }

var map: Array = []
var rooms: Array[Rect2i] = []
var stairs_down_pos: Vector2i = Vector2i.ZERO
var stairs_down_pos2: Vector2i = Vector2i.ZERO
var spawn_pos: Vector2i = Vector2i.ZERO
var spawn_pos2: Vector2i = Vector2i.ZERO
## Branch entrance tile locations: `{Vector2i: branch_id}`. Populated by
## `_place_branch_entrances` after the trunk floor is built. Empty on
## non-dungeon floors and on dungeon floors that aren't an entry depth
## for any child branch.
var branch_entrances: Dictionary = {}
## Altar tile → god id. Temple floors get three (one per god); most
## dungeon floors get zero, ~12% get a single random altar.
var altars: Dictionary = {}
## Shop tile → shop inventory dict. ~1-in-6 floors get a shop; the
## inventory is rolled at generation and serialised with the floor.
var shops: Dictionary = {}
## Trap tile → trap type dict. DCSS hides most traps; our MVP shows
## them visible. Step onto the tile to trigger.
var traps: Dictionary = {}

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()
# DCSS layout_basic emits three stair pairs; cache them so _place_stairs can
# use the authentic positions instead of re-deriving via room centres.
var _dcss_stairs_down: Array = []
var _dcss_stairs_up: Array = []

func generate(depth: int, run_seed: int = -1) -> void:
	if run_seed == -1:
		_rng.randomize()
	else:
		_rng.seed = run_seed + depth * 1000
	rooms.clear()
	_dcss_stairs_down.clear()
	_dcss_stairs_up.clear()
	_init_map()
	var branch: String = _current_branch()
	match branch:
		"main":    _build_dcss_overlapping_boxes(depth)
		# Orcish Mines — rougher caves, more rock debris, a few bigger
		# rooms to simulate the mined-out caverns. DCSS Mines use open
		# layouts with pillar-rooms; our closest approximation is wider
		# caves + extra debris.
		"mine":    _build_caves(); _decorate_rock_debris(14)
		# Lair — classic forest tileset with dense trees plus a couple
		# of small freshwater ponds so animals have terrain to lurk in.
		# Previously trees-only felt dry for a "wild lair" floor.
		"forest":  _build_caves(); _decorate_trees(28); \
				_place_pools(TileType.WATER, 2, 2, 5)
		"swamp":   _build_caves(); _decorate_trees(10); _place_pools(TileType.WATER, 4, 4, 9)
		"volcano": _build_caves(); _place_pools(TileType.LAVA, 3, 3, 7)
		# Elven Halls — DCSS uses ornate room-heavy layouts. We reuse the
		# main overlapping-boxes gen but with extra vault stamps for the
		# decorative feel. Shops bumped too — elves trade heavily.
		"elf":     _build_dcss_overlapping_boxes(depth)
		# Slime Pits — DCSS splatters acidic pools. TileType.ACID is
		# the dedicated floor variant (distinct from LAVA so the UI /
		# damage paths can differentiate). Caves feel wet and cramped.
		"slime":   _build_caves(); _place_pools(TileType.ACID, 4, 3, 8)
		# Crypt / Tomb — tight rooms-and-corridors with cramped halls.
		# Tomb goes even tighter. Population pool already weights heavy
		# toward undead.
		"crypt":   _build_dcss_overlapping_boxes(depth)
		# Vaults — DCSS Vaults branch is dense vault-stamp territory. Reuse
		# main gen but fire extra vault placements below.
		"vaults":  _build_dcss_overlapping_boxes(depth)
		# Zot — wide open "arena" floors with crystal walls. After cave
		# generation, recolour the regular stone WALLs in the outer ring
		# to CRYSTAL_WALL so the floor reads as Zot's signature pink
		# glass halls.
		"crystal":
			_build_caves()
			_decorate_rock_debris(18)
			for x in MAP_WIDTH:
				for y in MAP_HEIGHT:
					if map[x][y] == TileType.WALL and (_rng.randf() < 0.6):
						map[x][y] = TileType.CRYSTAL_WALL
		# Abyss — chaotic: sparse caves + lava pockets + void gaps.
		# DCSS Abyss regenerates each turn; we don't model that yet,
		# so the floor is a static chaotic layout.
		"abyss":
			_build_caves()
			_place_pools(TileType.LAVA, 3, 2, 5)
			_decorate_rock_debris(10)
		# Pandemonium — demon-infested chaos. Overlapping boxes layout
		# with heavy lava contamination.
		"pan":
			_build_dcss_overlapping_boxes(depth)
			_place_pools(TileType.LAVA, 4, 3, 7)
		# Hell sub-branches (Dis/Gehenna/Cocytus/Tartarus) — each has
		# its own flavor but share cave + hazard layout. We route by
		# tileset name; theme-specific hazards fold in below.
		"hell":
			_build_caves()
			_place_pools(TileType.LAVA, 5, 3, 8)  # Gehenna-like default
			_decorate_rock_debris(10)
		# Sewer portal — damp caves + more water than Lair, no trees.
		# DCSS Sewer is a swimming-hazard test.
		"sewer":   _build_caves(); _place_pools(TileType.WATER, 5, 3, 7)
		_:         _build_dcss_overlapping_boxes(depth)
	# Up to 3 vault placements per floor so DCSS's ~100-vault pool actually
	# shows up visibly. Each call only stamps one vault (or none) — repeated
	# calls naturally thin out if the map has no more room.
	_place_vault(branch, depth)
	_place_vault(branch, depth)
	_place_vault(branch, depth)
	# Vault-branch floors stamp extra vaults (DCSS Vaults branch is
	# literally vaults-stacked-on-vaults). Elf gets a bit more too for
	# the ornate feel.
	if branch == "vaults":
		_place_vault(branch, depth)
		_place_vault(branch, depth)
		_place_vault(branch, depth)
	elif branch == "elf":
		_place_vault(branch, depth)
		_place_vault(branch, depth)
	if branch == "main":
		_decorate_rock_debris(6)
	_ensure_reachability()
	_place_stairs()
	_place_branch_entrances(depth, run_seed)
	_place_altars()
	_place_shops(depth)
	_place_traps(depth)


# ---- Builder: DCSS overlapping-boxes port --------------------------------

## Direct GDScript port of DCSS 0.34 `dgn_build_basic_level` — the actual D-level
## layout from crawl-ref/source/dgn-layouts.cc. Produces three winding trails
## with stair triplets, L-joined together, then ~15-25 random rooms stamped
## where their walls touch a corridor. This is why DCSS levels feel like
## "rooms branching off corridors" — the rooms are literally attached to the
## trail geometry.
func _build_dcss_overlapping_boxes(depth: int) -> void:
	var result: Dictionary = DCSSLayout.build_basic({
		"width": MAP_WIDTH,
		"height": MAP_HEIGHT,
		"depth": depth,
		"rng": _rng,
	})
	var features: Array = result.get("features", [])
	for x in MAP_WIDTH:
		for y in MAP_HEIGHT:
			map[x][y] = _dcss_feature_to_tile(String(features[x][y]))
	rooms = result.get("rooms", [])
	# Remember the DCSS stair picks for _place_stairs to re-use instead of
	# clobbering them.
	_dcss_stairs_down = result.get("stairs_down", [])
	_dcss_stairs_up = result.get("stairs_up", [])


static func _dcss_feature_to_tile(f: String) -> int:
	match f:
		"floor":              return TileType.FLOOR
		"rock_wall":          return TileType.WALL
		"closed_door":        return TileType.DOOR_CLOSED
		"stone_stairs_down":  return TileType.STAIRS_DOWN
		"stone_stairs_up":    return TileType.STAIRS_UP
	return TileType.WALL


func _current_branch() -> String:
	# DungeonGenerator's tile-theming + layout builders key off the
	# tileset_branch (main/mine/forest/swamp/volcano/…) rather than the
	# raw DCSS branch id, so Lair can reuse the "forest" cave layout etc.
	var mgr: Node = null
	if Engine.get_main_loop() != null:
		mgr = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if mgr == null:
		return "main"
	if mgr.has_method("tileset_branch"):
		return mgr.call("tileset_branch")
	# Safer than `String(x or y)` — that crashed with "Nonexistent String
	# constructor" under some Godot 4.6 paths when `mgr.get(...)` returned
	# a typed-String default, because the `or` coerced the branch types.
	if "current_branch" in mgr:
		var cb = mgr.current_branch
		if typeof(cb) == TYPE_STRING and String(cb) != "":
			return String(cb)
	return "main"


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

func _place_vault(branch: String, depth: int) -> void:
	var pool: Array = VaultRegistry.for_branch_at_depth(branch, depth)
	if pool.is_empty():
		return
	# Up to 3 vault attempts per floor so DCSS's large pool gets some coverage;
	# each attempt picks a different template then tries 15 positions.
	for _attempt in 3:
		var template: Array = pool[_rng.randi_range(0, pool.size() - 1)]
		if template.is_empty():
			continue
		var h: int = template.size()
		var w: int = String(template[0]).length()
		if w >= MAP_WIDTH - 4 or h >= MAP_HEIGHT - 4:
			continue
		for _i in 15:
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

## DCSS `_place_branch_entrances` — on a dungeon floor, scatter a tile
## for each child branch whose entry-depth matches this floor. We only
## do this while on the main trunk; child branches don't nest deeper
## still in our port.
func _place_branch_entrances(depth: int, run_seed: int) -> void:
	branch_entrances.clear()
	var mgr: Node = null
	if Engine.get_main_loop() != null:
		mgr = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var parent: String = "dungeon"
	if mgr != null and "current_branch" in mgr:
		var cb = mgr.current_branch
		if typeof(cb) == TYPE_STRING and String(cb) != "":
			parent = String(cb)
	if parent != "dungeon":
		return
	var to_place: Array = BranchRegistry.children_entering_at(parent, depth)
	if to_place.is_empty():
		return
	# Pick distinct entries per-run: only place a given branch's entrance
	# at one specific depth in [min, max], hashed from run_seed so save/
	# restore converges on the same placement.
	for bid in to_place:
		var entry_depth: int = BranchRegistry.entry_depth_for(bid, run_seed)
		if entry_depth != depth:
			continue
		var pos: Vector2i = _pick_branch_entrance_tile()
		if pos == Vector2i(-1, -1):
			continue
		map[pos.x][pos.y] = TileType.BRANCH_ENTRANCE
		branch_entrances[pos] = bid


## Scatter altars. In DCSS Temple (when that branch loads) is wall-to-
## wall altars; on the regular dungeon trunk each floor has ~12% chance
## of a single random altar so god-pledging feels discoverable without
## being free.
func _place_altars() -> void:
	altars.clear()
	var mgr: Node = null
	if Engine.get_main_loop() != null:
		mgr = Engine.get_main_loop().root.get_node_or_null("GameManager")
	var branch: String = "dungeon"
	if mgr != null and "current_branch" in mgr:
		var cb = mgr.current_branch
		if typeof(cb) == TYPE_STRING and String(cb) != "":
			branch = String(cb)
	var god_ids: Array = GodRegistry.all_ids()
	if god_ids.is_empty():
		return
	if branch == "temple":
		# Temple: one altar per god.
		for gid in god_ids:
			var pos: Vector2i = _pick_branch_entrance_tile()
			if pos != Vector2i(-1, -1):
				map[pos.x][pos.y] = TileType.ALTAR
				altars[pos] = String(gid)
		return
	# Regular floor: ~1-in-8 chance of a single random altar.
	if _rng.randi() % 8 != 0:
		return
	var chosen_god: String = String(god_ids[_rng.randi() % god_ids.size()])
	var spot: Vector2i = _pick_branch_entrance_tile()
	if spot != Vector2i(-1, -1):
		map[spot.x][spot.y] = TileType.ALTAR
		altars[spot] = chosen_god


## DCSS shop placement: a rare (1-in-6 per floor) single shop with a
## rolled inventory of 5-8 items. Shop "type" picks a rough theme
## (potion shop / scroll shop / weapon shop / general). Prices are
## rolled by category and written into the inventory so the shop UI
## doesn't have to recompute on every visit.
func _place_shops(depth: int) -> void:
	shops.clear()
	if _rng.randi() % 6 != 0:
		return
	var spot: Vector2i = _pick_branch_entrance_tile()
	if spot == Vector2i(-1, -1):
		return
	map[spot.x][spot.y] = TileType.SHOP
	var kind: String = ["potion", "scroll", "weapon", "armour", "general"][_rng.randi() % 5]
	var inv: Array = _roll_shop_inventory(kind, depth)
	shops[spot] = {"kind": kind, "inventory": inv}


func _roll_shop_inventory(kind: String, depth: int) -> Array:
	var out: Array = []
	var count: int = 4 + _rng.randi() % 5   # 4..8 items
	var pool: Array = []
	match kind:
		"potion":
			for cid in ["potion_curing", "potion_heal_wounds", "potion_haste",
					"potion_might", "potion_brilliance", "potion_magic",
					"potion_invisibility", "potion_berserk_rage", "potion_resistance"]:
				pool.append({"id": cid, "price_base": 40})
		"scroll":
			for cid in ["scroll_teleport", "scroll_blink", "scroll_identify",
					"scroll_magic_map", "scroll_remove_curse",
					"scroll_enchant_weapon", "scroll_enchant_armor",
					"scroll_fog", "scroll_acquirement"]:
				pool.append({"id": cid, "price_base": 60})
		"weapon":
			# Light bias per depth through the existing tier tables.
			for wid in ["dagger", "short_sword", "rapier", "mace", "longsword",
					"waraxe", "short_bow"]:
				pool.append({"id": wid, "kind": "weapon", "price_base": 80})
		"armour":
			for aid in ["leather_armour", "ring_mail", "scale_mail",
					"chain_mail", "plate_armour", "cloak", "helmet", "buckler"]:
				pool.append({"id": aid, "kind": "armor", "price_base": 100})
		_:
			for cid in ["potion_curing", "scroll_identify", "scroll_teleport",
					"dagger", "leather_armour", "cloak", "potion_haste"]:
				pool.append({"id": cid, "price_base": 50})
	pool.shuffle()
	for i in min(count, pool.size()):
		var entry: Dictionary = pool[i].duplicate()
		var base: int = int(entry.get("price_base", 50))
		entry["price"] = max(5, base + depth * 8 + _rng.randi() % 30)
		out.append(entry)
	return out


## Scatter 2-6 traps per floor. DCSS traps.cc places hidden traps; our
## MVP places them visible (player sees before stepping) and uses a
## small trap-type pool weighted by depth. Each trap entry stores the
## chosen type so revisits remember which trap is where.
func _place_traps(depth: int) -> void:
	traps.clear()
	var want: int = 2 + _rng.randi() % 5    # 2..6 traps
	var types: Array = ["dart", "arrow", "spear", "teleport", "alarm"]
	if depth >= 4:
		types.append("net")
	if depth >= 8:
		types.append("bolt")
	# Shaft: DCSS shaft drops the victim 1-3 floors down. Only place on
	# non-terminal floors so the drop has somewhere to land. `MAX_DEPTH`
	# lives in GameBootstrap; we defensively cap at depth 24 which is
	# one below the usual 25-floor endgame floor.
	if depth >= 3 and depth <= 24:
		types.append("shaft")
	for _i in want:
		var spot: Vector2i = _pick_branch_entrance_tile()
		if spot == Vector2i(-1, -1):
			break
		var tt: String = String(types[_rng.randi() % types.size()])
		map[spot.x][spot.y] = TileType.TRAP
		traps[spot] = {"type": tt, "depth": depth}


func _pick_branch_entrance_tile() -> Vector2i:
	# Try up to 40 random floor tiles, preferring ones that aren't
	# adjacent to existing stairs so entrances don't clump.
	for _i in 40:
		var x: int = 1 + _rng.randi() % (MAP_WIDTH - 2)
		var y: int = 1 + _rng.randi() % (MAP_HEIGHT - 2)
		var p: Vector2i = Vector2i(x, y)
		if map[x][y] != TileType.FLOOR:
			continue
		if p == spawn_pos or p == stairs_down_pos \
				or p == spawn_pos2 or p == stairs_down_pos2:
			continue
		return p
	return Vector2i(-1, -1)


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
	# DCSS layout_basic already placed three stair pairs via its trails. If
	# the current build produced them, respect those positions so the corridor
	# endpoints align with the stairs (otherwise stairs show up in odd spots
	# because room centres don't sit on corridor ends).
	if _dcss_stairs_up.size() >= 1 and _dcss_stairs_down.size() >= 1:
		# DCSS layout can drop stair glyphs on wall-pocket coordinates
		# when the trail walker hits a dead end. Re-anchor each stair to
		# the nearest walkable tile that has at least one walkable 4-
		# neighbour so descending doesn't strand the player.
		spawn_pos = _ensure_stair_has_exit(_dcss_stairs_up[0])
		stairs_down_pos = _ensure_stair_has_exit(_dcss_stairs_down[0])
		spawn_pos2 = _ensure_stair_has_exit(_dcss_stairs_up[1]) if _dcss_stairs_up.size() >= 2 else spawn_pos
		stairs_down_pos2 = _ensure_stair_has_exit(_dcss_stairs_down[1]) if _dcss_stairs_down.size() >= 2 else stairs_down_pos
		map[spawn_pos.x][spawn_pos.y] = TileType.STAIRS_UP
		map[stairs_down_pos.x][stairs_down_pos.y] = TileType.STAIRS_DOWN
		if spawn_pos2 != spawn_pos:
			map[spawn_pos2.x][spawn_pos2.y] = TileType.STAIRS_UP
		if stairs_down_pos2 != stairs_down_pos:
			map[stairs_down_pos2.x][stairs_down_pos2.y] = TileType.STAIRS_DOWN
		return
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


## Given a stair coordinate, return the nearest position where the
## stair tile is (a) on floor and (b) has at least one walkable
## 4-neighbour. This guards against layouts that drop stair glyphs
## at wall pockets with all four cardinal neighbours solid, which
## traps the player on arrival. Starts from the input and expands
## outward in rings; falls back to the map centre if nothing fits.
func _ensure_stair_has_exit(hint: Vector2i) -> Vector2i:
	if _stair_tile_ok(hint):
		return hint
	for r in range(1, max(MAP_WIDTH, MAP_HEIGHT)):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if absi(dx) != r and absi(dy) != r:
					continue  # only ring cells, not interior
				var p: Vector2i = hint + Vector2i(dx, dy)
				if _stair_tile_ok(p):
					return p
	return _pick_floor_tile_near(hint)


## `hint` is usable for a stair iff (a) it's in bounds, (b) already
## floor (or convertible — we only accept floor to keep the logic
## simple), and (c) at least one of its 4 cardinal neighbours is
## walkable (FLOOR or open-door terrain).
func _stair_tile_ok(p: Vector2i) -> bool:
	if not _in_bounds(p):
		return false
	var t: int = map[p.x][p.y]
	if t != TileType.FLOOR and t != TileType.STAIRS_UP and t != TileType.STAIRS_DOWN:
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = p + d
		if not _in_bounds(n):
			continue
		var nt: int = map[n.x][n.y]
		if nt == TileType.FLOOR or nt == TileType.DOOR_OPEN \
				or nt == TileType.DOOR_CLOSED \
				or nt == TileType.STAIRS_UP or nt == TileType.STAIRS_DOWN:
			return true
	return false


func _in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.x < MAP_WIDTH and p.y >= 0 and p.y < MAP_HEIGHT


func get_tile(p: Vector2i) -> int:
	if not _in_bounds(p):
		return TileType.WALL
	return map[p.x][p.y]


func is_walkable(p: Vector2i) -> bool:
	var t: int = get_tile(p)
	return t == TileType.FLOOR or t == TileType.STAIRS_DOWN or t == TileType.STAIRS_UP \
			or t == TileType.DOOR_OPEN or t == TileType.BRANCH_ENTRANCE \
			or t == TileType.ALTAR or t == TileType.SHOP or t == TileType.TRAP


func open_door(p: Vector2i) -> void:
	if not _in_bounds(p):
		return
	if map[p.x][p.y] == TileType.DOOR_CLOSED:
		map[p.x][p.y] = TileType.DOOR_OPEN
