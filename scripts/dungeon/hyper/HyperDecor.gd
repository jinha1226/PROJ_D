class_name HyperDecor
extends RefCounted
## Wall decoration — places doors, windows, and solid-fill walls at
## the carvable connection points between rooms. 1:1 port (subset) of
## DCSS hyper_decor.lua, which itself is the default wall decorator.
##
## Call shape matches DCSS: decorate_walls(state, wall_info_list,
## is_primary). `is_primary` == true means at least one of these
## connections MUST become a door so the room isn't isolated; false
## allows 0..N doors on incidental edges.

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## `walls` is the list of {room_coord, grid_pos, cell, usage} wall info
## Dicts produced by HyperPlace.apply_room. Picks at least one door on a
## primary list; 0..N doors on incidental lists (each tile 25% chance).
static func decorate_walls(state: Dictionary, walls: Array, is_primary: bool) -> void:
	if walls.is_empty():
		return
	var usage_grid: Dictionary = state.get("usage_grid", {})
	var forced_door_idx: int = -1
	if is_primary:
		# Primary wall list — force one carved door so connectivity is
		# guaranteed. Random cell chosen uniformly.
		forced_door_idx = _rng.randi_range(0, walls.size() - 1)
	for i in range(walls.size()):
		var info: Dictionary = walls[i]
		var place_door: bool = (i == forced_door_idx) or (_rng.randf() < 0.25)
		if place_door:
			info["cell"]["feature"] = "open_door"
			info["cell"]["solid"] = false
			info["cell"]["wall"] = false
			info["cell"]["carvable"] = false
		else:
			info["cell"]["feature"] = "rock_wall"
			info["cell"]["solid"] = true
			info["cell"]["wall"] = true
			info["cell"]["carvable"] = false
		# HyperPlace.apply_room has already set_usage'd this cell; but we
		# want the feature change visible, so re-set it.
		if usage_grid.has("width"):
			HyperUsage.set_usage(usage_grid,
					int(info["grid_pos"]["x"]), int(info["grid_pos"]["y"]),
					info["cell"])


static func set_seed(seed: int) -> void:
	_rng.seed = seed
