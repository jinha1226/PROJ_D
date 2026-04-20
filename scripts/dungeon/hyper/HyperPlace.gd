class_name HyperPlace
extends RefCounted
## Room placement pipeline. 1:1 port of DCSS hyper_place.lua — builds
## rooms, picks places, processes overlap, and applies results to the
## shared usage_grid.
##
## Entry is `build_rooms(build, usage_grid, options)` — same shape as
## the DCSS entry. The inner loop keeps picking/placing until we reach
## `max_rooms` for the build pass, or `max_room_tries` consecutive
## failures.

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Public entry. Returns an array of placement result Dicts.
static func build_rooms(build: Dictionary, usage_grid: Dictionary,
		options: Dictionary) -> Array:
	var results: Array = []
	var rooms_placed: int = 0
	var times_failed: int = 0
	var total_failed: int = 0
	var room_count: int = int(build.get("max_rooms", options.get("max_rooms", 10)))
	var max_room_tries: int = int(options.get("max_room_tries", 27))
	var post_place = build.get("post_placement_callback",
			options.get("post_placement_callback", null))

	var total_rooms_placed: int = int(options.get("rooms_placed", 0))

	while rooms_placed < room_count and times_failed < max_room_tries:
		var placed: bool = false
		var room: Dictionary = HyperRooms.pick_room(build, options)
		if not room.is_empty():
			if not room.has("grid"):
				return results
			var result: Dictionary = place_room(room, build, usage_grid, options)
			if result.get("placed", false):
				placed = true
				rooms_placed += 1
				total_rooms_placed += 1
				options["rooms_placed"] = total_rooms_placed
				if post_place is Callable and (post_place as Callable).is_valid():
					(post_place as Callable).call(usage_grid, room, result, options)
				results.append(result)
				# Increment per-generator placement counter.
				var gen: Dictionary = room.get("generator_used", {})
				if not gen.is_empty():
					gen["placed_count"] = int(gen.get("placed_count", 0)) + 1
				times_failed = 0
		if not placed:
			times_failed += 1
			total_failed += 1
	return results


## Place a single room — picks a spot + anchor, vetos, applies.
static func place_room(room: Dictionary, build: Dictionary,
		usage_grid: Dictionary, options: Dictionary) -> Dictionary:
	var max_tries: int = int(options.get("max_place_tries", 50))
	var tries: int = 0
	var done: bool = false
	var state: Dictionary = {}

	var strategy: Dictionary = room.get("generator_used", {}).get("strategy",
			build.get("strategy", options.get("strategy", HyperStrategy.strategy_default())))
	if strategy.is_empty():
		return {"placed": false}

	while tries < max_tries and not done:
		tries += 1
		var place = (strategy["pick_place"] as Callable).call(room, build, usage_grid, options)
		if not (place is Dictionary) or place.is_empty():
			return {"placed": false}
		var anchor = (strategy["pick_anchor"] as Callable).call(place, room, build, usage_grid, options)
		if not (anchor is Dictionary) or (anchor is Dictionary and anchor.is_empty()) \
				or anchor == false:
			return {"placed": false}
		state = process_room_place(anchor, place, room, strategy, build, usage_grid, options)
		if not state.is_empty() and apply_room(state, room, build, usage_grid, options):
			done = true
	if not done:
		return {"placed": false}
	return {"placed": true, "coords_list": state.get("coords", []), "state": state}


## Map the room's cells onto world coords for the chosen orientation,
## run veto on each cell, and build a list of "real" cells (non-space,
## non-vault) for apply_room.
static func process_room_place(anchor: Dictionary, place: Dictionary,
		room: Dictionary, strategy: Dictionary, build: Dictionary,
		usage_grid: Dictionary, options: Dictionary) -> Dictionary:
	var pos: Dictionary = place["pos"]
	var usage: Dictionary = place.get("usage", {})
	var dir: int = int(anchor["dir"])
	var origin: Dictionary = anchor["origin"]

	var room_final_x_dir: int = (dir - 1 + 4) % 4
	var room_final_y_dir: int = (dir - 2 + 4) % 4
	var nx: Dictionary = HyperUsage.NORMALS[room_final_x_dir]
	var ny: Dictionary = HyperUsage.NORMALS[room_final_y_dir]
	var room_base: Dictionary = _add_mapped(pos, {
			"x": -int(origin["x"]), "y": -int(origin["y"])}, nx, ny)

	var state: Dictionary = {
		"anchor": anchor,
		"room": room,
		"usage": usage,
		"pos": pos,
		"base": room_base,
		"dir": dir,
		"build": build,
		"options": options,
		"normals": {"x": nx, "y": ny},
		# Needed by wall decorators so they can rewrite grid feature cells.
		"usage_grid": usage_grid,
	}

	var veto_place = options.get("veto_place_callback", strategy.get("veto_place", null))
	if veto_place is Callable and (veto_place as Callable).is_valid():
		if bool((veto_place as Callable).call(state, usage_grid)):
			return {}

	var coords_list: Array = []
	var is_clear: bool = true
	var place_check = room.get("generator_used", {}).get("veto_cell",
			build.get("veto_cell",
			strategy.get("veto_cell", Callable(HyperStrategy, "cell_veto_normal"))))

	for m in range(int(room["size"].y)):
		for n in range(int(room["size"].x)):
			var coord: Dictionary = {"room_pos": {"x": n, "y": m}}
			coord["grid_pos"] = _add_mapped(room_base, coord["room_pos"], nx, ny)
			coord["grid_usage"] = HyperUsage.get_usage(usage_grid,
					int(coord["grid_pos"]["x"]), int(coord["grid_pos"]["y"]))
			coord["room_cell"] = HyperUsage.get_usage(room["grid"], n, m)

			# Out of bounds: only accept if the room cell was pure space.
			var room_cell_is_space: bool = bool(coord["room_cell"].get("space", false))
			if not room_cell_is_space and coord["grid_usage"].is_empty():
				is_clear = false
				break
			if place_check is Callable and (place_check as Callable).is_valid():
				if bool((place_check as Callable).call(coord, state)):
					is_clear = false
					break
			if not room_cell_is_space \
					and not bool(coord["grid_usage"].get("vault", false)):
				coords_list.append(coord)
		if not is_clear:
			break
	if not is_clear:
		return {}
	state["coords"] = coords_list
	return state


## Apply the placed room back onto usage_grid + track door connections.
## Returns the coords list on success (truthy), empty on failure.
static func apply_room(state: Dictionary, room: Dictionary, build: Dictionary,
		usage_grid: Dictionary, options: Dictionary) -> Array:
	var coords_list: Array = state.get("coords", [])
	var final_orient: int = int(state["dir"])
	room["wall_type"] = String(options.get("layout_wall_type", "rock_wall"))

	var new_depth: int = 2
	if int(state.get("usage", {}).get("depth", 0)) > 0:
		new_depth = int(state["usage"]["depth"]) + 1

	var incidental_connections: Array = [[], [], [], []]
	var door_connections: Array = []

	for coord_v in coords_list:
		var coord: Dictionary = coord_v
		var room_cell: Dictionary = coord["room_cell"]
		var grid_cell: Dictionary = coord["grid_usage"]
		# Rotate any stored anchors into world orientation.
		if not (room_cell.get("anchors", []) is Array):
			room_cell["anchors"] = []
		for anchor in room_cell["anchors"]:
			var d: int = (int(anchor["normal"]["dir"]) + final_orient) % 4
			anchor["normal"] = HyperUsage.NORMALS[d]
			anchor["grid_pos"] = _add_mapped(state["base"], anchor["pos"],
					state["normals"]["x"], state["normals"]["y"])
		# Track which cells represent room-to-room connections.
		if bool(room_cell.get("carvable", false)):
			if bool(state["usage"].get("open_area", false)) \
					or not bool(state["usage"].get("solid", false)):
				room_cell["open_area"] = true
			var wall_info: Dictionary = {
				"room_coord": coord["room_pos"],
				"grid_pos": coord["grid_pos"],
				"usage": grid_cell,
				"cell": room_cell,
			}
			if bool(grid_cell.get("carvable", false)):
				room_cell["carvable"] = false
				room_cell["restricted"] = true
				if grid_cell.get("room") == state["usage"].get("room"):
					door_connections.append(wall_info)
				elif not room_cell.get("anchors", []).is_empty():
					var d_idx: int = int(room_cell["anchors"][0]["normal"]["dir"])
					incidental_connections[d_idx].append(wall_info)
			else:
				if not bool(grid_cell.get("solid", true)):
					door_connections.append(wall_info)
		room_cell["depth"] = new_depth
		room_cell["room"] = room
		room_cell["room_dir"] = final_orient
		HyperUsage.set_usage(usage_grid,
				int(coord["grid_pos"]["x"]), int(coord["grid_pos"]["y"]), room_cell)

	# Run wall decorator for doors.
	var decorate = build.get("wall_decorator",
			options.get("decorate_walls_callback", Callable(HyperDecor, "decorate_walls")))
	if decorate is Callable and (decorate as Callable).is_valid():
		(decorate as Callable).call(state, door_connections, true)
		for n in range(4):
			if not incidental_connections[n].is_empty():
				(decorate as Callable).call(state, incidental_connections[n], false)
	return coords_list


# ---- Utility ------------------------------------------------------------

## Translate a room-local offset into a world point, taking the room's
## rotated X / Y normal vectors into account.
static func _add_mapped(base: Dictionary, offset: Dictionary,
		nx: Dictionary, ny: Dictionary) -> Dictionary:
	return {
		"x": int(base["x"]) + int(offset["x"]) * int(nx["x"]) + int(offset["y"]) * int(ny["x"]),
		"y": int(base["y"]) + int(offset["x"]) * int(nx["y"]) + int(offset["y"]) * int(ny["y"]),
	}


static func set_seed(seed: int) -> void:
	_rng.seed = seed
