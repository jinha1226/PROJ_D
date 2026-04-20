class_name HyperRooms
extends RefCounted
## Room generation + analysis. 1:1 port of DCSS hyper_rooms.lua, adapted
## to our Dictionary-based representation.
##
## A "room" here is a Dict holding:
##   type            "grid" | "vault" | "transform"
##   size            Vector2i
##   grid            usage_grid (small) describing the room's cells
##   generator_used  the generator Dict used to produce this room
##   walls           per-direction wall-analysis info (dir → {eligible})
##   wall_type       chosen outer wall feature (set at placement)
##   preserve_wall   bool (vault tag)
##   id              integer identifier
##
## The public entry is `pick_room(build, options)` — it selects a
## generator by weight, then runs a generator-specific make_* that
## paints the room's internal grid.

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Picks a weighted generator and builds a single room instance.
static func pick_room(build: Dictionary, options: Dictionary) -> Dictionary:
	var weights: Array = build.get("generators", options.get("room_type_weights", []))
	var chosen: Dictionary = _random_weighted(weights, func(gen):
		return _effective_weight(gen, options))
	if chosen.is_empty():
		return {}
	var tries: int = 0
	var max_tries: int = 50
	var veto: bool = false
	var room: Dictionary = {}
	while tries < max_tries and (room.is_empty() or veto):
		tries += 1
		veto = false
		room = make_room(options, chosen)
		if options.has("veto_room_callback") and (options["veto_room_callback"] as Callable).is_valid():
			veto = bool((options["veto_room_callback"] as Callable).call(room))
	return room


## Effective weight includes max_rooms / min_total / max_total gates.
static func _effective_weight(generator: Dictionary, options: Dictionary) -> int:
	if generator.has("max_rooms") and generator.has("placed_count") \
			and int(generator["placed_count"]) >= int(generator["max_rooms"]):
		return 0
	if generator.has("min_total_rooms") \
			and int(options.get("rooms_placed", 0)) < int(generator["min_total_rooms"]):
		return 0
	if generator.has("max_total_rooms") \
			and int(options.get("rooms_placed", 0)) >= int(generator["max_total_rooms"]):
		return 0
	if generator.has("weight_callback") and (generator["weight_callback"] as Callable).is_valid():
		return int((generator["weight_callback"] as Callable).call(generator, options))
	return int(generator.get("weight", 1))


static func _random_weighted(items: Array, weight_fn: Callable) -> Dictionary:
	var total: int = 0
	var weights: Array = []
	for it in items:
		var w: int = max(0, int(weight_fn.call(it)))
		weights.append(w)
		total += w
	if total <= 0:
		return {}
	var roll: int = _rng.randi_range(0, total - 1)
	var acc: int = 0
	for i in range(items.size()):
		acc += int(weights[i])
		if roll < acc:
			return items[i]
	return items[items.size() - 1]


## Dispatch to generator-specific maker, then run analysis and optional
## post-transform (e.g. add_walls).
static func make_room(options: Dictionary, generator: Dictionary) -> Dictionary:
	var room: Dictionary = {}
	var kind: String = String(generator.get("generator", "code"))
	if kind == "code":
		room = make_code_room(generator, options)
	elif kind == "tagged":
		# Vault-by-tag isn't wired — we don't have DCSS's .des lookup.
		return {}
	if room.is_empty():
		return {}

	var analyse: bool = bool(generator.get("analyse", true))
	if analyse:
		analyse_room(room, options)

	var transform = generator.get("room_transform", options.get("room_transform", null))
	if transform != null and transform is Callable:
		room = (transform as Callable).call(room, options)
		if analyse:
			analyse_room(room, options)

	room["id"] = int(options.get("rooms_placed", 0))
	return room


## Create a code-paint room.
static func make_code_room(chosen: Dictionary, options: Dictionary) -> Dictionary:
	var size: Vector2i
	if chosen.has("size"):
		var raw = chosen["size"]
		if raw is Callable:
			size = (raw as Callable).call(options, chosen)
		elif raw is Vector2i:
			size = raw
		elif raw is Dictionary:
			size = Vector2i(int(raw.get("x", 0)), int(raw.get("y", 0)))
	else:
		var size_fn: Callable = chosen.get("size_callback", HyperShapes.size_default)
		size = size_fn.call(chosen, options)
	if size.x <= 0 or size.y <= 0:
		return {}

	var room: Dictionary = {
		"type": "grid",
		"size": size,
		"generator_used": chosen,
		"grid": HyperUsage.new_usage(size.x, size.y),
	}
	# Run the paint callback.
	if chosen.has("paint_callback") and (chosen["paint_callback"] as Callable).is_valid():
		var paint: Array = (chosen["paint_callback"] as Callable).call(room, options, chosen)
		HyperPaint.paint_grid(paint, options, room["grid"])
	# Optional post-paint decoration.
	if chosen.has("decorate_callback") and (chosen["decorate_callback"] as Callable).is_valid():
		(chosen["decorate_callback"] as Callable).call(room["grid"], room, options)
	return room


## After painting the internal grid, figure out which edge cells can
## serve as attachment anchors. Mirrors DCSS analyse_room.
static func analyse_room(room: Dictionary, options: Dictionary) -> void:
	room["walls"] = {}
	for n in range(4):
		room["walls"][n] = {"eligible": false}

	var size: Vector2i = room["size"]
	var inspect_cells: Array = []
	var has_exits: bool = false
	for m in range(size.y):
		for n in range(size.x):
			var cell: Dictionary = HyperUsage.get_usage(room["grid"], n, m)
			if bool(cell.get("exit", false)):
				has_exits = true
			cell["anchors"] = []
			if not bool(cell.get("space", false)) \
					and (bool(cell.get("carvable", false)) or not bool(cell.get("solid", true))):
				inspect_cells.append({"cell": cell, "pos": Vector2i(n, m)})

	var allow_diag: bool = bool(room.get("allow_diagonals", false))
	var dirs: Array = HyperUsage.DIRECTIONS if allow_diag else HyperUsage.NORMALS
	for inspect in inspect_cells:
		var cell: Dictionary = inspect["cell"]
		var n: int = inspect["pos"].x
		var m: int = inspect["pos"].y
		if has_exits and not bool(cell.get("exit", false)):
			continue
		for normal in dirs:
			var near_pos: Vector2i = Vector2i(n + int(normal["x"]), m + int(normal["y"]))
			var near: Dictionary = HyperUsage.get_usage(room["grid"], near_pos.x, near_pos.y)
			if not near.is_empty() and not bool(near.get("space", false)):
				continue
			var anchor_ok: bool = true
			var anchor_pos = normal
			if bool(cell.get("solid", true)):
				anchor_ok = false
				if bool(cell.get("carvable", false)):
					var opp: Dictionary = HyperUsage.get_usage(
							room["grid"], n - int(normal["x"]), m - int(normal["y"]))
					if not opp.is_empty() and not bool(opp.get("solid", true)):
						anchor_pos = {"x": 0, "y": 0}
						anchor_ok = true
			if anchor_ok:
				cell["anchors"].append({
					"normal": normal,
					"pos": anchor_pos,
					"origin": {"x": n, "y": m},
				})
				cell["connected"] = true
		HyperUsage.set_usage(room["grid"], n, m, cell)


## Wrap a room's grid in a ring of wall cells — 2 tiles larger on each
## axis. Carvable walls are marked where they border connectable cells.
static func add_walls(room: Dictionary, options: Dictionary) -> Dictionary:
	var new_size: Vector2i = Vector2i(
			int(room["size"].x) + 2, int(room["size"].y) + 2)
	var walled: Dictionary = {
		"type": "transform",
		"size": new_size,
		"generator_used": room["generator_used"],
		"transform": "add_walls",
		"inner_room": room,
		"inner_room_pos": Vector2i(1, 1),
	}
	walled["grid"] = HyperUsage.new_usage(new_size.x, new_size.y)
	for m in range(new_size.y):
		for n in range(new_size.x):
			var usage: Dictionary = HyperUsage.get_usage(room["grid"], n - 1, m - 1)
			if usage.is_empty():
				usage = {"space": true}
			if not bool(usage.get("space", false)):
				usage["inner"] = true
				HyperUsage.set_usage(walled["grid"], n, m, usage)
				continue
			# Space cell — may need a wall placed here.
			var any_open: bool = false
			for normal in HyperUsage.DIRECTIONS:
				var near: Dictionary = HyperUsage.get_usage(room["grid"],
						n + int(normal["x"]) - 1, m + int(normal["y"]) - 1)
				if near.is_empty():
					continue
				if not bool(near.get("space", false)) and not bool(near.get("solid", true)):
					any_open = true
					break
			if any_open:
				var wall_cell: Dictionary = {
					"feature": "rock_wall",
					"solid": true,
					"wall": true,
					"protect": true,
					"anchors": [],
				}
				# Walls touching a connected floor cell become carvable.
				for normal in HyperUsage.NORMALS:
					var near: Dictionary = HyperUsage.get_usage(room["grid"],
							n + int(normal["x"]) - 1, m + int(normal["y"]) - 1)
					if not near.is_empty() and bool(near.get("connected", false)):
						wall_cell["carvable"] = true
						wall_cell["connected"] = true
				HyperUsage.set_usage(walled["grid"], n, m, wall_cell)
	return walled


## Used with add_walls to also add a 1-tile buffer ring around the walls
## so rooms don't touch each other's outer walls on placement.
static func add_buffer(room: Dictionary, _options: Dictionary) -> Dictionary:
	var new_size: Vector2i = Vector2i(
			int(room["size"].x) + 2, int(room["size"].y) + 2)
	var padded: Dictionary = {
		"type": "transform",
		"size": new_size,
		"generator_used": room["generator_used"],
		"transform": "add_buffer",
		"inner_room": room.get("inner_room", room),
		"inner_room_pos": Vector2i(
				int(room.get("inner_room_pos", Vector2i(0, 0)).x) + 1,
				int(room.get("inner_room_pos", Vector2i(0, 0)).y) + 1),
	}
	padded["grid"] = HyperUsage.new_usage(new_size.x, new_size.y)
	for m in range(new_size.y):
		for n in range(new_size.x):
			var usage: Dictionary = HyperUsage.get_usage(room["grid"], n - 1, m - 1)
			if usage.is_empty():
				usage = {"space": true}
			if not bool(usage.get("space", false)):
				usage["inner"] = true
				HyperUsage.set_usage(padded["grid"], n, m, usage)
				continue
			var any_open: bool = false
			for normal in HyperUsage.DIRECTIONS:
				var near: Dictionary = HyperUsage.get_usage(room["grid"],
						n + int(normal["x"]) - 1, m + int(normal["y"]) - 1)
				if near.is_empty():
					continue
				if not bool(near.get("space", false)):
					any_open = true
					break
			if any_open:
				HyperUsage.set_usage(padded["grid"], n, m,
						{"space": true, "buffer": true, "anchors": []})
	return padded


static func add_buffer_walls(room: Dictionary, options: Dictionary) -> Dictionary:
	return add_buffer(add_walls(room, options), options)


static func set_seed(seed: int) -> void:
	_rng.seed = seed
