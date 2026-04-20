class_name HyperLayout
extends RefCounted
## Main layout engine entry — 1:1 port of DCSS hyper.lua build_layout.
##
## Drives the fixture pipeline: init usage_grid → analyse → run each
## "build" task → post-fixture callback. Each task is a Dict with
## `type = "build" | "place" | "filter"` and the relevant parameters.
##
## Usage from our DungeonGenerator:
##   var state := HyperLayout.build({
##       "name": "Main Dungeon",
##       "width": 50, "height": 72,
##       "room_type_weights": [
##           { "generator": "code", "paint_callback": …, "weight": 1,
##             "min_size": 4, "max_size": 10 },
##       ],
##       "build_fixture": [
##           { "type": "build", "max_rooms": 12 },
##       ],
##   })
##   # state.usage_grid is the finished grid to read tiles from.


## Default options. Merged with caller options; layout-specific values
## (room sizes, branches, etc.) override these.
static func default_options() -> Dictionary:
	return {
		"max_rooms": 27,
		"max_room_depth": 0,
		"min_distance_from_wall": 2,
		"max_room_tries": 27,
		"max_place_tries": 50,
		"strict_veto": true,
		"min_room_size": 3,
		"max_room_size": 8,
		"room_type_weights": [
			{
				"generator": "code",
				"paint_callback": HyperLayout._default_floor_paint,
				"weight": 1,
				"min_size": 4,
				"max_size": 10,
				"empty": true,
			},
		],
		"layout_wall_type": "rock_wall",
		"layout_floor_type": "floor",
		"layout_wall_weights": [
			{"feature": "rock_wall", "weight": 1},
		],
	}


## Build a layout. Returns the main_state Dict, which has:
##   usage_grid  — the finished grid
##   results     — list of per-build placement results
static func build(options: Dictionary) -> Dictionary:
	var merged: Dictionary = default_options()
	for k in options:
		merged[k] = options[k]
	options = merged
	if not options.has("build_fixture"):
		options["build_fixture"] = [
			{"type": "build", "generators": options["room_type_weights"]},
		]

	var gxm: int = int(options.get("width", 80))
	var gym: int = int(options.get("height", 70))
	var main_state: Dictionary = {
		"usage_grid": HyperUsage.new_usage(gxm, gym,
				options.get("grid_initialiser", Callable())),
		"results": [],
	}

	# If caller provided a pre-painted grid, skip analyse (nothing to scan).
	if bool(options.get("skip_analyse", false)) == false:
		HyperUsage.analyse_grid_usage(main_state["usage_grid"], options)

	for item_v in options["build_fixture"]:
		var item: Dictionary = item_v
		var enabled = item.get("enabled", null)
		var is_on: bool = true
		if enabled is Callable:
			is_on = bool((enabled as Callable).call(item, main_state))
		elif enabled != null:
			is_on = bool(enabled)
		if not is_on:
			continue
		match String(item.get("type", "build")):
			"build":
				if not item.has("generators"):
					item["generators"] = options["room_type_weights"]
				var results: Array = HyperPlace.build_rooms(item,
						main_state["usage_grid"], options)
				main_state["results"].append_array(results)
			"filter":
				HyperUsage.filter_usage(main_state["usage_grid"],
						item.get("filter", {}),
						item.get("transform", {}),
						item.get("region", null))
			"place":
				_place_single(item, main_state["usage_grid"], options)

	if options.has("post_fixture_callback") \
			and (options["post_fixture_callback"] as Callable).is_valid():
		(options["post_fixture_callback"] as Callable).call(main_state, options)

	return main_state


## Simple single-placement handler — paints one shape at a fixed spot.
static func _place_single(item: Dictionary, usage_grid: Dictionary,
		options: Dictionary) -> void:
	if item.has("paint"):
		HyperPaint.paint_grid(item["paint"], options, usage_grid)


## Default floor-vault paint callback: fills the whole room with floor
## tiles. Mirrors rooms_primitive.floor_vault from DCSS.
static func _default_floor_paint(room: Dictionary, _options: Dictionary,
		_chosen: Dictionary) -> Array:
	var size: Vector2i = room["size"]
	return [
		{
			"type": "floor",
			"corner1": {"x": 0, "y": 0},
			"corner2": {"x": size.x - 1, "y": size.y - 1},
			"open": true,
		},
	]


static func set_seed(seed: int) -> void:
	HyperShapes.set_seed(seed)
	HyperRooms.set_seed(seed + 1)
	HyperStrategy.set_seed(seed + 2)
	HyperPlace.set_seed(seed + 3)
	HyperDecor.set_seed(seed + 4)
