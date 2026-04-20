class_name HyperUsage
extends RefCounted
## Usage-grid data structure — 1:1 port of DCSS 0.34 hyper_usage.lua.
##
## A usage grid is a 2D table of cell dicts that describe what's at each
## tile for layout purposes (separate from the final dungeon tile grid).
## Each cell can carry:
##   feature       String   — feature name ("floor", "rock_wall", "space", …)
##   space         bool     — empty / unused area (no paint applied)
##   solid         bool     — impassable (wall)
##   wall          bool     — is a wall feature (subset of solid)
##   carvable      bool     — may be turned into a corridor entrance
##   vault         bool     — part of an already-placed vault, do not overwrite
##   open          bool     — further rooms may be placed in this area
##   exit          bool     — @-style exit spot from a vault
##   room          Dict     — back-ref to the room this cell belongs to
##   room_dir      int      — final orient of the room
##   depth         int      — room depth for decor decisions
##   anchors       Array    — possible connection points on this cell
##   buffer        bool     — cell is a surround buffer, not real content
##   inner         bool     — cell is inside a wall-transformed room
##   restricted   bool     — cell cannot be carved into any more
##   protect       bool     — MMT_VAULT mask after build
##   connected     bool     — wall cell that currently connects rooms
##   eligibles_which String — "open" / "closed" / ""
##   spot          Vector2i — grid coord cached for eligibles
##
## Grid layout matches DCSS: `grid[y][x]` (row-major), eligibles are
## maintained in parallel arrays for quick random pick.

const NORMALS: Array = [
	{"x": 0, "y": -1, "dir": 0, "name": "n"},
	{"x": -1, "y": 0, "dir": 1, "name": "w"},
	{"x": 0, "y": 1, "dir": 2, "name": "s"},
	{"x": 1, "y": 0, "dir": 3, "name": "e"},
]

const DIAGONALS: Array = [
	{"x": -1, "y": -1, "dir": 0, "name": "nw"},
	{"x": -1, "y": 1, "dir": 1, "name": "sw"},
	{"x": 1, "y": 1, "dir": 2, "name": "se"},
	{"x": 1, "y": -1, "dir": 3, "name": "ne"},
]

const DIRECTIONS: Array = [
	{"x": 0, "y": -1, "dir": 0, "name": "n"},
	{"x": -1, "y": 0, "dir": 1, "name": "w"},
	{"x": 0, "y": 1, "dir": 2, "name": "s"},
	{"x": 1, "y": 0, "dir": 3, "name": "e"},
	{"x": -1, "y": -1, "dir": 0, "name": "nw"},
	{"x": -1, "y": 1, "dir": 1, "name": "sw"},
	{"x": 1, "y": 1, "dir": 2, "name": "se"},
	{"x": 1, "y": -1, "dir": 3, "name": "ne"},
]


## Create a new usage grid. `initialiser` is an optional Callable that
## takes (x, y) → cell dict. When omitted, cells start as empty space.
static func new_usage(width: int, height: int, initialiser: Callable = Callable()) -> Dictionary:
	var g: Dictionary = {
		"width": width,
		"height": height,
		"eligibles": {"open": [], "closed": []},
		"anchors": [],
	}
	for y in height:
		var row: Dictionary = {}
		for x in width:
			var cell: Dictionary
			if initialiser.is_valid():
				cell = initialiser.call(x, y)
			else:
				cell = {
					"feature": "space",
					"solid": true,
					"space": true,
					"carvable": true,
					"vault": false,
					"anchors": [],
				}
			row[x] = cell
		g[y] = row
	return g


static func get_usage(usage_grid: Dictionary, x: int, y: int) -> Dictionary:
	if not usage_grid.has(y):
		return {}
	var row: Dictionary = usage_grid[y]
	return row.get(x, {})


## Update a cell, maintaining the eligibles/anchors side-indexes. Mirrors
## DCSS hyper.usage.set_usage — the slightly awkward sequence (remove old
## from eligibles, add new) is what keeps the fast-pick lists consistent.
static func set_usage(usage_grid: Dictionary, x: int, y: int, usage: Dictionary) -> bool:
	if not usage_grid.has(y):
		return false
	var row: Dictionary = usage_grid[y]
	if not row.has(x):
		return false
	var current: Dictionary = row[x]
	# Remove old from eligibles if listed there.
	var which: String = String(current.get("eligibles_which", ""))
	if which != "":
		var lst: Array = usage_grid["eligibles"][which]
		for i in range(lst.size()):
			if lst[i] == current:
				lst.remove_at(i)
				break
	# Remove old anchors from the global anchors list when swapping.
	if current != usage and current.get("anchors", []) is Array:
		for anchor in current["anchors"]:
			var ga: Array = usage_grid["anchors"]
			var idx: int = ga.find(anchor)
			if idx >= 0:
				ga.remove_at(idx)
	# Insert into eligibles if eligible. Vaults never become eligible.
	if not bool(usage.get("vault", false)) \
			and (bool(usage.get("carvable", false)) or not bool(usage.get("solid", true))):
		usage["spot"] = Vector2i(x, y)
		var which_tbl: String = "closed" if bool(usage.get("solid", true)) else "open"
		usage_grid["eligibles"][which_tbl].append(usage)
		usage["eligibles_which"] = which_tbl
	else:
		# Explicitly clear so lookups don't see stale data.
		usage.erase("eligibles_which")
	# Register anchors.
	if usage.get("anchors", []) is Array:
		for anchor in usage["anchors"]:
			usage_grid["anchors"].append(anchor)
	row[x] = usage
	return true


## Filter a region of the grid, applying `transform` to every cell that
## matches `filter`. Both can be either Callable (usage → bool / Dict)
## or plain Dicts used as match-all-keys / apply-all-keys tables.
static func filter_usage(usage_grid: Dictionary, filter, transform, region = null) -> void:
	var x1: int = 0
	var y1: int = 0
	var x2: int = int(usage_grid["width"]) - 1
	var y2: int = int(usage_grid["height"]) - 1
	if region != null:
		x1 = int(region.get("x1", 0))
		y1 = int(region.get("y1", 0))
		x2 = int(region.get("x2", x2))
		y2 = int(region.get("y2", y2))
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			var current: Dictionary = get_usage(usage_grid, x, y)
			var matched: bool = false
			if filter is Callable:
				matched = bool((filter as Callable).call(current))
			elif filter is Dictionary:
				matched = true
				for k in (filter as Dictionary):
					if current.get(k) != filter[k]:
						matched = false
						break
			if not matched:
				continue
			var new_cell: Dictionary = current
			if transform is Callable:
				new_cell = (transform as Callable).call(current)
			elif transform is Dictionary:
				for k in (transform as Dictionary):
					new_cell[k] = transform[k]
			set_usage(usage_grid, x, y, new_cell)


## Scan an existing usage grid and tag walls as carvable + fill in anchor
## records. Mirrors DCSS hyper.usage.analyse_grid_usage.
static func analyse_grid_usage(usage_grid: Dictionary, _options: Dictionary) -> void:
	var width: int = int(usage_grid["width"])
	var height: int = int(usage_grid["height"])
	for x in width:
		for y in height:
			var usage: Dictionary = get_usage(usage_grid, x, y)
			if usage.is_empty():
				continue
			if bool(usage.get("vault", false)):
				continue
			if bool(usage.get("wall", false)):
				# Any wall adjacent to non-solid space becomes carvable and
				# gains an anchor pointing *into* the wall — that anchor is
				# what a later room hangs itself off.
				for normal in NORMALS:
					var nx: int = x + int(normal["x"])
					var ny: int = y + int(normal["y"])
					var near: Dictionary = get_usage(usage_grid, nx, ny)
					if near.is_empty() or bool(near.get("solid", true)):
						continue
					usage["carvable"] = true
					var inv_dir: int = (int(normal["dir"]) + 2) % 4
					usage.get("anchors", []).append({
						"normal": NORMALS[inv_dir],
						"pos": {"x": 0, "y": 0},
						"grid_pos": {"x": x, "y": y},
					})
			elif not bool(usage.get("solid", true)):
				for normal in DIRECTIONS:
					var nx: int = x + int(normal["x"])
					var ny: int = y + int(normal["y"])
					var near: Dictionary = get_usage(usage_grid, nx, ny)
					if near.is_empty():
						continue
					if bool(near.get("solid", true)):
						usage["buffer"] = true
			set_usage(usage_grid, x, y, usage)
