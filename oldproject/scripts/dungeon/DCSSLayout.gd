class_name DCSSLayout
extends Object
## Native GDScript port of DCSS 0.34 `dgn_build_basic_level`
## (crawl-ref/source/dgn-layouts.cc). This is the dominant D-level layout
## in DCSS (weight 35 on Dungeon, highest of any layout).
##
## Algorithm summary:
##   1. Init grid with rock wall.
##   2. Carve three winding corridor "trails", each with stone stairs at
##      start and end (III pairs).
##   3. Connect the three upstair points with L-path join_the_dots lines
##      so the player can reach every stair set.
##   4. Stamp ~15-25 random rectangular rooms on top of the existing
##      corridor geometry. Rooms only commit if their walls touch an
##      existing floor tile (a "good door spot") — this is what makes
##      rooms appear to branch off corridors.
##   5. Open doors on sides that touch corridors, with a per-level
##      door_level roll.
##
## Output: Dictionary { features, rooms, stairs_down, stairs_up }.
##   features is Array[Array[String]] with values "floor", "rock_wall",
##   "closed_door", "stone_stairs_down", "stone_stairs_up".
##   stairs_down/up are Array[Vector2i] (three each — matches DCSS's
##   I/II/III stair triplets).

const F_WALL := "rock_wall"
const F_FLOOR := "floor"
const F_DOOR := "closed_door"
const F_STAIRS_DOWN := "stone_stairs_down"
const F_STAIRS_UP := "stone_stairs_up"

# DCSS constants. Our map is 50x72 vs DCSS's 80x70; the x-axis bounds are
# scaled proportionally so corridors don't run off-grid.
const _DCSS_GXM: int = 80
const _DCSS_GYM: int = 70


## Build a DCSS layout_basic level. Options:
##   width, height (ints) — map dimensions (required)
##   depth (int, 1+) — current floor; affects pool/lava extras
##   rng (RandomNumberGenerator) — for deterministic runs
static func build_basic(options: Dictionary) -> Dictionary:
	var w: int = int(options.get("width", 50))
	var h: int = int(options.get("height", 72))
	var depth: int = int(options.get("depth", 1))
	var rng: RandomNumberGenerator = options.get("rng", RandomNumberGenerator.new())

	# Fill with rock wall.
	var grid: Array = _make_grid(w, h, F_WALL)

	# DCSS parameters (direct port).
	var corrlength: int = 2 + rng.randi() % 14                 # 2-15
	var no_corr: int = 30 + rng.randi() % 200                  # 30-229
	if _one_chance_in(rng, 100):
		no_corr = 500 + rng.randi() % 500
	var intersect_chance: int = rng.randi() % 20               # 0-19
	if _one_chance_in(rng, 20):
		intersect_chance = 400

	# Trail start rectangles, adapted from DCSS's three-trail seeding. DCSS
	# uses (35,30,35,20), (10,15,10,15), (50,20,10,15) on an 80×70 map —
	# roughly one trail near each corner plus one in the middle-right. For
	# our 50×72 map we rescale to hit mid-right, upper-left, and lower-right
	# so trails cover the full map height (our map is taller than DCSS's).
	var stairs_down: Array[Vector2i] = []
	var stairs_up: Array[Vector2i] = []
	# Trail 1: middle-right (mid-y seed so it tends to reach the center).
	var r1: Dictionary = _make_trail(grid, w, h, rng,
			int(w * 0.45), int(w * 0.30),
			int(h * 0.30), int(h * 0.40),
			corrlength, intersect_chance, no_corr)
	_claim_trail_stairs(grid, r1, stairs_down, stairs_up)
	# Trail 2: upper-left quadrant.
	var r2: Dictionary = _make_trail(grid, w, h, rng,
			int(w * 0.10), int(w * 0.25),
			int(h * 0.10), int(h * 0.25),
			corrlength, intersect_chance, no_corr)
	_claim_trail_stairs(grid, r2, stairs_down, stairs_up)
	# Trail 3: lower-right quadrant — ensures bottom of map gets reached.
	var r3: Dictionary = _make_trail(grid, w, h, rng,
			int(w * 0.55), int(w * 0.30),
			int(h * 0.60), int(h * 0.30),
			corrlength, intersect_chance, no_corr)
	_claim_trail_stairs(grid, r3, stairs_down, stairs_up)

	# Connect upstair points so all three trails are joined.
	for i in range(stairs_up.size()):
		for j in range(i + 1, stairs_up.size()):
			_join_the_dots(grid, w, h, stairs_up[i], stairs_up[j])

	# Main rooms. DCSS: no_rooms = weighted{636: 5+random2avg(29,2), 49: 100,
	# 15: 1} — usually ~16 rooms, rarely 100 (tight network), very rarely 1.
	var door_level: int = rng.randi() % 11                  # 0-10
	var room_size: int = 4 + rng.randi() % 5 + rng.randi() % 6    # 4-14
	var no_rooms: int = _weighted_room_count(rng)
	# Room placement area: allow rooms anywhere inside the margin. The DCSS
	# numbers (50, 40 / 55, 45) carved out a safe interior on 80×70; ours
	# are proportional to (w, h) so we get rooms all over a 50×72 map.
	var max_x: int = max(4, w - 12)
	var max_y: int = max(4, h - 12)
	_make_random_rooms(grid, w, h, rng, no_rooms, 2 + rng.randi() % 8,
			door_level, max_x, max_y, room_size)

	# Extra 1-3 tiny rooms.
	_make_random_rooms(grid, w, h, rng, 1 + rng.randi() % 3, 1,
			door_level, w - 10, h - 10, 6)

	# Flood-fill cleanup: drop small disconnected regions.
	_keep_largest_region(grid, w, h)

	# Build rooms rect list for consumers (stair placement etc).
	var rooms: Array[Rect2i] = _detect_room_rects(grid, w, h)

	return {
		"features": grid,
		"rooms": rooms,
		"stairs_down": stairs_down,
		"stairs_up": stairs_up,
	}


# ---- Trail carving (DCSS _make_trail) -------------------------------------

## Pull begin/end out of a _make_trail result and stamp the stair features.
static func _claim_trail_stairs(grid: Array, r: Dictionary,
		downs: Array[Vector2i], ups: Array[Vector2i]) -> void:
	if r.is_empty():
		return
	var b: Vector2i = r.get("begin", Vector2i.ZERO)
	var e: Vector2i = r.get("end", Vector2i.ZERO)
	if b == e:
		return
	grid[b.x][b.y] = F_STAIRS_DOWN
	grid[e.x][e.y] = F_STAIRS_UP
	downs.append(b)
	ups.append(e)


static func _make_trail(grid: Array, w: int, h: int, rng: RandomNumberGenerator,
		xs: int, xr: int, ys: int, yr: int,
		corrlength: int, intersect_chance: int, no_corr: int) -> Dictionary:
	# Find a viable start: inside bounds, on rock or floor, with rock neighbour.
	var pos: Vector2i = Vector2i.ZERO
	var tries: int = 200
	while tries > 0:
		tries -= 1
		pos = Vector2i(xs + rng.randi() % max(1, xr),
				ys + rng.randi() % max(1, yr))
		if _viable_trail_start(grid, w, h, pos):
			break
	if tries <= 0:
		return {}

	var begin: Vector2i = pos
	var finish: int = 0
	var length: int = 0
	var dir: Vector2i = Vector2i.ZERO
	# DCSS bounds trail attempts at 200; because our map is smaller per cell
	# but trails are in y-stretched shape, we give trails more budget so they
	# reach the far end of the map.
	var guard: int = 400

	while finish < no_corr and guard > 0:
		guard -= 1
		dir = Vector2i.ZERO
		if _coinflip(rng):
			dir.x = _trail_random_dir(rng, pos.x, w, 15)
		else:
			dir.y = _trail_random_dir(rng, pos.y, h, 15)
		if dir == Vector2i.ZERO:
			continue

		# Choose segment length when going horizontal or when restarting.
		if dir.x == 0 or length == 0:
			length = rng.randi() % max(1, corrlength) + 2

		for _bi in length:
			# Bounce off map edges (4-cell margin).
			if pos.x < 4:
				dir = Vector2i(1, 0)
			elif pos.x > w - 5:
				dir = Vector2i(-1, 0)
			elif pos.y < 4:
				dir = Vector2i(0, 1)
			elif pos.y > h - 5:
				dir = Vector2i(0, -1)

			# Stop if an existing corridor/room is two steps ahead — but
			# `intersect_chance` of the time we cross over anyway.
			var look: Vector2i = pos + dir * 2
			if _in_bounds(look, w, h) and grid[look.x][look.y] == F_FLOOR \
					and not _one_chance_in(rng, intersect_chance + 1):
				break

			pos += dir
			if not _in_bounds(pos, w, h):
				pos -= dir
				break
			if grid[pos.x][pos.y] == F_WALL:
				grid[pos.x][pos.y] = F_FLOOR

		# DCSS quirk: if we ended on a wall right at the last step, rewind
		# counter so the trail doesn't terminate inside rock.
		if finish == no_corr - 1 and grid[pos.x][pos.y] != F_FLOOR:
			finish -= 2
		finish += 1

	return {"begin": begin, "end": pos}


static func _viable_trail_start(grid: Array, w: int, h: int,
		pos: Vector2i) -> bool:
	if not _in_bounds(pos, w, h):
		return false
	var f: String = String(grid[pos.x][pos.y])
	if f != F_WALL and f != F_FLOOR:
		return false
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = pos + d
		if _in_bounds(n, w, h) and grid[n.x][n.y] == F_WALL:
			return true
	return false


static func _trail_random_dir(rng: RandomNumberGenerator, pos: int,
		bound: int, margin: int) -> int:
	var dir: int = 0
	if pos < margin:
		dir = 1
	elif pos > bound - margin:
		dir = -1
	if dir == 0 or _x_chance_in_y(rng, 2, 5):
		dir = 1 if _coinflip(rng) else -1
	return dir


# ---- Random-rooms placement (DCSS _make_random_rooms / _make_room) ---------

static func _make_random_rooms(grid: Array, w: int, h: int,
		rng: RandomNumberGenerator, num: int, max_doors: int,
		door_level: int, max_x: int, max_y: int, max_room_size: int) -> void:
	var i: int = 0
	var time_run: int = 0
	while i < num:
		var overlap_tries: int = 100
		var sx: int = 0
		var sy: int = 0
		var ex: int = 0
		var ey: int = 0
		while overlap_tries > 0:
			overlap_tries -= 1
			sx = 4 + rng.randi() % max(1, max_x)
			sy = 4 + rng.randi() % max(1, max_y)
			ex = sx + 2 + rng.randi() % max(1, max_room_size)
			ey = sy + 2 + rng.randi() % max(1, max_room_size)
			if ex < w - 2 and ey < h - 2:
				break
		if overlap_tries <= 0:
			time_run += 1
			if time_run > 30:
				time_run = 0
				i += 1
			continue
		if _try_make_room(grid, w, h, rng, sx, sy, ex, ey, max_doors, door_level):
			i += 1
			time_run = 0
		else:
			time_run += 1
			if time_run > 30:
				time_run = 0
				i += 1


static func _try_make_room(grid: Array, w: int, h: int,
		rng: RandomNumberGenerator, sx: int, sy: int, ex: int, ey: int,
		max_doors: int, door_level: int) -> bool:
	# Count 'good door spots' on the perimeter: a wall cell that has existing
	# floor on one side (meaning the new room's wall touches a corridor).
	var find_door: int = 0
	var diag_door: int = 0
	for rx in range(sx, ex + 1):
		find_door += _good_door_spot(grid, w, h, rx, sy)
		find_door += _good_door_spot(grid, w, h, rx, ey)
	for ry in range(sy + 1, ey):
		find_door += _good_door_spot(grid, w, h, sx, ry)
		find_door += _good_door_spot(grid, w, h, ex, ry)
	diag_door += _good_door_spot(grid, w, h, sx, sy)
	diag_door += _good_door_spot(grid, w, h, ex, sy)
	diag_door += _good_door_spot(grid, w, h, sx, ey)
	diag_door += _good_door_spot(grid, w, h, ex, ey)

	if diag_door + find_door > 1 and max_doors == 1:
		return false
	if find_door == 0 or find_door > max_doors:
		return false

	# Commit: carve room interior to floor. Perimeter remains wall unless
	# already floor (so overlaps with a corridor still pass through).
	for rx in range(sx + 1, ex):
		for ry in range(sy + 1, ey):
			if grid[rx][ry] == F_WALL:
				grid[rx][ry] = F_FLOOR

	# Place doors where our wall is adjacent to an existing corridor on both
	# sides of the adjacent tile — DCSS's "solid on both sides" rule.
	for ry in range(sy + 1, ey):
		_try_place_door(grid, w, h, rng, sx - 1, ry, door_level, true)
		_try_place_door(grid, w, h, rng, ex + 1, ry, door_level, true)
	for rx in range(sx + 1, ex):
		_try_place_door(grid, w, h, rng, rx, sy - 1, door_level, false)
		_try_place_door(grid, w, h, rng, rx, ey + 1, door_level, false)
	return true


## Returns 1 if (x, y) is a floor tile adjacent to the room, meaning the
## room wall could reasonably open here. Mirrors DCSS _good_door_spot.
static func _good_door_spot(grid: Array, w: int, h: int, x: int, y: int) -> int:
	if not _in_bounds(Vector2i(x, y), w, h):
		return 0
	if grid[x][y] == F_FLOOR:
		return 1
	return 0


static func _try_place_door(grid: Array, w: int, h: int,
		rng: RandomNumberGenerator, x: int, y: int,
		door_level: int, horizontal: bool) -> void:
	if not _in_bounds(Vector2i(x, y), w, h):
		return
	if grid[x][y] != F_FLOOR:
		return
	# Require solid walls on both orthogonal sides so doors read as "in a
	# wall segment" and not floating in the corridor.
	if horizontal:
		if not _is_solid(grid, w, h, x, y - 1) or not _is_solid(grid, w, h, x, y + 1):
			return
	else:
		if not _is_solid(grid, w, h, x - 1, y) or not _is_solid(grid, w, h, x + 1, y):
			return
	if _x_chance_in_y(rng, door_level, 10):
		grid[x][y] = F_DOOR


static func _is_solid(grid: Array, w: int, h: int, x: int, y: int) -> bool:
	if not _in_bounds(Vector2i(x, y), w, h):
		return true
	var f: String = String(grid[x][y])
	return f == F_WALL


# ---- join_the_dots -------------------------------------------------------

## L-shaped corridor carve between two points. DCSS uses pathfinding; we use
## a simpler x-first-or-y-first carve which looks identical on empty grids.
static func _join_the_dots(grid: Array, w: int, h: int,
		a: Vector2i, b: Vector2i) -> void:
	var x1: int = min(a.x, b.x)
	var x2: int = max(a.x, b.x)
	var y1: int = min(a.y, b.y)
	var y2: int = max(a.y, b.y)
	var corner_y: int = a.y if randi() % 2 == 0 else b.y
	for x in range(x1, x2 + 1):
		if _in_bounds(Vector2i(x, corner_y), w, h) and grid[x][corner_y] == F_WALL:
			grid[x][corner_y] = F_FLOOR
	var corner_x: int = b.x if corner_y == a.y else a.x
	for y in range(y1, y2 + 1):
		if _in_bounds(Vector2i(corner_x, y), w, h) and grid[corner_x][y] == F_WALL:
			grid[corner_x][y] = F_FLOOR


# ---- Post-process: keep largest reachable region --------------------------

static func _keep_largest_region(grid: Array, w: int, h: int) -> void:
	var visited: Array = _make_grid(w, h, false)
	var regions: Array = []
	for x in w:
		for y in h:
			if visited[x][y]:
				continue
			if not _is_walkable(grid[x][y]):
				continue
			var region: Array = []
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				if not _in_bounds(p, w, h) or visited[p.x][p.y]:
					continue
				if not _is_walkable(grid[p.x][p.y]):
					continue
				visited[p.x][p.y] = true
				region.append(p)
				queue.append(Vector2i(p.x + 1, p.y))
				queue.append(Vector2i(p.x - 1, p.y))
				queue.append(Vector2i(p.x, p.y + 1))
				queue.append(Vector2i(p.x, p.y - 1))
			regions.append(region)
	if regions.size() <= 1:
		return
	var biggest: int = 0
	for i in regions.size():
		if regions[i].size() > regions[biggest].size():
			biggest = i
	for i in regions.size():
		if i == biggest:
			continue
		for p in regions[i]:
			grid[p.x][p.y] = F_WALL


static func _is_walkable(feature: String) -> bool:
	return feature == F_FLOOR or feature == F_DOOR \
			or feature == F_STAIRS_DOWN or feature == F_STAIRS_UP


## Identify rectangular-ish room regions by scanning for all floor blobs
## and reporting bounding rects. Consumers (stair placement, monster spawn)
## don't need the geometry to be precise — a rect for each cluster is enough.
static func _detect_room_rects(grid: Array, w: int, h: int) -> Array[Rect2i]:
	var visited: Array = _make_grid(w, h, false)
	var out: Array[Rect2i] = []
	for x in w:
		for y in h:
			if visited[x][y]:
				continue
			if not _is_walkable(grid[x][y]):
				continue
			var queue: Array[Vector2i] = [Vector2i(x, y)]
			var min_x: int = w
			var min_y: int = h
			var max_x: int = -1
			var max_y: int = -1
			var size: int = 0
			while not queue.is_empty():
				var p: Vector2i = queue.pop_back()
				if not _in_bounds(p, w, h) or visited[p.x][p.y]:
					continue
				if not _is_walkable(grid[p.x][p.y]):
					continue
				visited[p.x][p.y] = true
				size += 1
				min_x = min(min_x, p.x)
				min_y = min(min_y, p.y)
				max_x = max(max_x, p.x)
				max_y = max(max_y, p.y)
				queue.append(Vector2i(p.x + 1, p.y))
				queue.append(Vector2i(p.x - 1, p.y))
				queue.append(Vector2i(p.x, p.y + 1))
				queue.append(Vector2i(p.x, p.y - 1))
			# Skip trivial 1-tile corridors — those aren't rooms.
			if size >= 4 and max_x > min_x and max_y > min_y:
				out.append(Rect2i(min_x, min_y,
						max_x - min_x + 1, max_y - min_y + 1))
	return out


# ---- Helpers ---------------------------------------------------------------

static func _make_grid(w: int, h: int, fill) -> Array:
	var g: Array = []
	g.resize(w)
	for x in w:
		var col: Array = []
		col.resize(h)
		for y in h:
			col[y] = fill
		g[x] = col
	return g


static func _in_bounds(p: Vector2i, w: int, h: int) -> bool:
	return p.x >= 0 and p.x < w and p.y >= 0 and p.y < h


static func _scaled_trail_rect(dx: int, dxr: int, dy: int, dyr: int,
		w: int, h: int) -> Dictionary:
	var fx: float = float(w) / float(_DCSS_GXM)
	var fy: float = float(h) / float(_DCSS_GYM)
	return {
		"xs": max(2, int(round(dx * fx))),
		"xr": max(3, int(round(dxr * fx))),
		"ys": max(2, int(round(dy * fy))),
		"yr": max(3, int(round(dyr * fy))),
	}


static func _coinflip(rng: RandomNumberGenerator) -> bool:
	return (rng.randi() & 1) == 0


static func _one_chance_in(rng: RandomNumberGenerator, n: int) -> bool:
	if n <= 1:
		return true
	return (rng.randi() % n) == 0


static func _x_chance_in_y(rng: RandomNumberGenerator, x: int, y: int) -> bool:
	if x <= 0:
		return false
	if x >= y:
		return true
	return (rng.randi() % y) < x


## DCSS `random_choose_weighted(636, A, 49, 100, 15, 1)` where
## A = 5 + random2avg(29, 2) — mean ~19. Total weight 700.
static func _weighted_room_count(rng: RandomNumberGenerator) -> int:
	var roll: int = rng.randi() % 700
	if roll < 636:
		# 5 + random2avg(29, 2): sum of two random2(29) div 2, mean ~14.
		var a: int = rng.randi() % 29
		var b: int = rng.randi() % 29
		return 5 + (a + b) / 2
	elif roll < 636 + 49:
		return 100
	else:
		return 1
