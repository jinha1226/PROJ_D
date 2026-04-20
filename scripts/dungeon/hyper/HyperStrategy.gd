class_name HyperStrategy
extends RefCounted
## Placement strategies — bundles of (pick_place, pick_anchor,
## veto_place, veto_cell) callbacks that control how a room attaches to
## the usage grid. 1:1 port of DCSS hyper_strategy.lua.
##
## The engine picks a strategy from the room's generator (or falls back
## to the build default, then the global default). Each strategy is a
## plain Dict so layouts can compose/override individual callbacks.

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


# ---- Place picking ------------------------------------------------------

## Totally random coord within grid (or generator-specified bounds).
static func pick_place_random(room: Dictionary, _build: Dictionary,
		usage_grid: Dictionary, _options: Dictionary) -> Dictionary:
	var bounds: Dictionary = room.get("generator_used", {}).get("bounds", {
		"x1": 0, "y1": 0,
		"x2": int(usage_grid["width"]), "y2": int(usage_grid["height"]),
	})
	var padding: int = int(room.get("generator_used", {}).get("place_padding", 0))
	var xmin: int = int(bounds["x1"]) + padding
	var xmax: int = int(bounds["x2"]) - 1 - int(room["size"].x) - padding
	var ymin: int = int(bounds["y1"]) + padding
	var ymax: int = int(bounds["y2"]) - 1 - int(room["size"].y) - padding
	if xmax < xmin or ymax < ymin:
		return {}
	var x: int = _rng.randi_range(xmin, xmax)
	var y: int = _rng.randi_range(ymin, ymax)
	return {"pos": {"x": x, "y": y},
			"usage": HyperUsage.get_usage(usage_grid, x, y)}


## Pick an eligible open floor spot (existing rooms' interiors / gaps).
static func pick_place_open(room: Dictionary, build: Dictionary,
		usage_grid: Dictionary, options: Dictionary) -> Dictionary:
	var pool: Array = usage_grid["eligibles"]["open"]
	if pool.is_empty():
		return pick_place_random(room, build, usage_grid, options)
	var u: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	return {"pos": u.get("spot", {"x": 0, "y": 0}), "usage": u}


## Pick an eligible wall (carvable) spot.
static func pick_place_closed(room: Dictionary, build: Dictionary,
		usage_grid: Dictionary, options: Dictionary) -> Dictionary:
	var pool: Array = usage_grid["eligibles"]["closed"]
	if pool.is_empty():
		return pick_place_random(room, build, usage_grid, options)
	var u: Dictionary = pool[_rng.randi_range(0, pool.size() - 1)]
	return {"pos": u.get("spot", {"x": 0, "y": 0}), "usage": u}


# ---- Anchor picking -----------------------------------------------------

static func anchor_origin(_place = null, _room = null, _build = null,
		_usage_grid = null, _options = null) -> Dictionary:
	return {"dir": 0, "origin": {"x": 0, "y": 0}}


static func anchor_random(_place = null, _room = null, _build = null,
		_usage_grid = null, _options = null) -> Dictionary:
	return {"dir": _rng.randi_range(0, 3), "origin": {"x": 0, "y": 0}}


## Attach the room to an existing carvable wall. If the anchor cell lives
## in open space (no pre-existing wall anchors), we just pick a random
## orientation; otherwise we match the normal already stored on the cell.
static func anchor_wall(place: Dictionary, room: Dictionary, _build: Dictionary,
		_usage_grid: Dictionary, _options: Dictionary):
	var room_anchors: Array = room["grid"].get("anchors", [])
	if room_anchors.is_empty():
		return false
	var anchor: Dictionary = room_anchors[_rng.randi_range(0, room_anchors.size() - 1)]
	var usage: Dictionary = place.get("usage", {})
	var v_normal_dir: int
	if not bool(usage.get("solid", false)) or usage.get("anchors", []).is_empty():
		v_normal_dir = int(HyperUsage.NORMALS[_rng.randi_range(0, 3)]["dir"])
	else:
		var u_anchor: Dictionary = usage["anchors"][_rng.randi_range(0, usage["anchors"].size() - 1)]
		v_normal_dir = int(u_anchor["normal"]["dir"])
	var final_orient: int = (v_normal_dir - int(anchor["normal"]["dir"]) + 2) % 4
	return {
		"origin": {
			"x": int(anchor["origin"]["x"]) + int(anchor["pos"]["x"]),
			"y": int(anchor["origin"]["y"]) + int(anchor["pos"]["y"]),
		},
		"dir": final_orient,
	}


# ---- Cell-level veto ----------------------------------------------------

## Baseline: never overwrite vaults, bail on off-map except for the
## room's own "space" cells (transparent).
static func cell_veto_standard(coord: Dictionary, _state: Dictionary) -> bool:
	var target_usage: Dictionary = coord.get("grid_usage", {})
	var room_cell: Dictionary = coord.get("room_cell", {})
	if target_usage.is_empty() and bool(room_cell.get("buffer", false)):
		return true
	if target_usage.is_empty():
		return not bool(room_cell.get("space", false))
	if bool(target_usage.get("vault", false)):
		return true
	return false


## Default veto — allows carving into rock, rooms-in-rooms, and attaching
## rooms to other rooms' carvable walls.
static func cell_veto_normal(coord: Dictionary, state: Dictionary) -> bool:
	if cell_veto_standard(coord, state):
		return true
	var target_usage: Dictionary = coord.get("grid_usage", {})
	if target_usage.is_empty():
		return false
	var usage: Dictionary = state.get("usage", {})
	var room_cell: Dictionary = coord.get("room_cell", {})
	if not bool(usage.get("solid", false)):
		# Open placement
		if target_usage.get("room") != usage.get("room"):
			return true
		if bool(room_cell.get("buffer", false)) \
				and (bool(target_usage.get("solid", false)) or bool(target_usage.get("wall", false))):
			return true
	elif bool(usage.get("open_area", false)):
		# Open attached placement
		if not bool(room_cell.get("space", false)) \
				and target_usage.get("room") == usage.get("room") \
				and not bool(target_usage.get("wall", false)):
			return true
		if target_usage.get("room") != usage.get("room") \
				and not bool(room_cell.get("space", false)) \
				and not bool(room_cell.get("buffer", false)) \
				and (bool(target_usage.get("solid", false)) or bool(target_usage.get("restricted", false))):
			return true
	else:
		# Enclosed (wall-carving) placement
		if not bool(room_cell.get("space", false)) \
				and not bool(target_usage.get("solid", false)):
			return true
	return false


# ---- Strategy bundles ---------------------------------------------------

## For an initial primary room that paints the level bulk.
static func strategy_primary() -> Dictionary:
	return {
		"pick_place": HyperStrategy.pick_place_random,
		"pick_anchor": HyperStrategy.anchor_origin,
		"veto_cell": HyperStrategy._veto_none,
	}


## Default: carve rooms into rock from existing wall cells.
static func strategy_default() -> Dictionary:
	return {
		"pick_place": HyperStrategy.pick_place_closed,
		"pick_anchor": HyperStrategy.anchor_wall,
		"veto_cell": HyperStrategy.cell_veto_normal,
	}


## Places in open areas by attaching to eligible open cells.
static func strategy_open() -> Dictionary:
	return {
		"pick_place": HyperStrategy.pick_place_open,
		"pick_anchor": HyperStrategy.anchor_wall,
		"veto_cell": HyperStrategy.cell_veto_normal,
	}


static func _veto_none(_coord: Dictionary, _state: Dictionary) -> bool:
	return false


static func set_seed(seed: int) -> void:
	_rng.seed = seed
