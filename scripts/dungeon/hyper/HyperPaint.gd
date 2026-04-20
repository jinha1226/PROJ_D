class_name HyperPaint
extends RefCounted
## Paint primitives for drawing shapes (floor, wall, space) into a
## usage_grid. 1:1 port of DCSS hyper_paint.lua.
##
## Each paint item is a Dict with:
##   type     — "floor" / "wall" / "space" / "proc" / (or raw feature string)
##   shape    — "quad" (default) / "ellipse" / "trapese" / "plot" / function
##   corner1  — {x, y} top-left of quad bounds (default 0,0)
##   corner2  — {x, y} bottom-right of quad bounds (default width-1, height-1)
##   open     — flag further rooms may spawn in this painted area
##   exit     — same as @ in vaults; door-connection hint
##   usage    — merge these extra keys onto every painted cell
##   points   — array of {x,y} for "plot" shape
##   callback — (x, y, ux, uy) → (feature_type, feature_usage) for "proc"
##
## Feature flags are derived from feature_type via `feature_flags`.


## Paint a list of items onto `usage_grid`.
static func paint_grid(paint: Array, options: Dictionary, usage_grid: Dictionary) -> void:
	for item_v in paint:
		var item: Dictionary = item_v
		var feature_type: String = ""
		if item.get("type", "") == "floor":
			feature_type = "floor"
		elif item.get("type", "") == "wall":
			feature_type = "wall"
		elif item.get("type", "") == "space" or item.get("type", "") == "proc":
			feature_type = "space"
		elif item.has("feature"):
			feature_type = String(item["feature"])

		var shape_type = item.get("shape", "quad")
		var feat_pack: Dictionary = feature_flags(feature_type, options)
		var feature: String = String(feat_pack["feature"])
		var space: bool = bool(feat_pack["space"])
		var solid: bool = bool(feat_pack["solid"])
		var wall: bool = bool(feat_pack["wall"])
		var feature_usage: Dictionary = item.get("usage", {})

		var open: bool = bool(item.get("open", false))
		var exit: bool = bool(item.get("exit", false))

		var c1: Dictionary = item.get("corner1", {"x": 0, "y": 0})
		var c2: Dictionary = item.get("corner2", {
			"x": int(usage_grid["width"]) - 1,
			"y": int(usage_grid["height"]) - 1,
		})

		if shape_type == "quad" or shape_type == "ellipse" \
				or shape_type == "trapese" or item.get("type", "") == "proc":
			for x in range(int(c1["x"]), int(c2["x"]) + 1):
				for y in range(int(c1["y"]), int(c2["y"]) + 1):
					var inside: bool = false
					if item.get("type", "") == "proc" or shape_type == "quad":
						inside = true
					elif shape_type == "ellipse":
						inside = inside_oval(x, y, item)
					elif shape_type == "trapese":
						inside = inside_trapese(x, y, item)
					elif shape_type is Callable:
						inside = (shape_type as Callable).call(x, y,
							_map_to_unit(x, y, item).x,
							_map_to_unit(x, y, item).y, item)
					if not inside:
						continue
					# For proc paint, re-resolve feature per cell.
					if item.get("type", "") == "proc" and item.has("callback"):
						var r = (item["callback"] as Callable).call(x, y,
							_map_to_unit(x, y, item).x,
							_map_to_unit(x, y, item).y)
						if r is Dictionary:
							feature_type = String(r.get("feature_type", "space"))
							feature_usage = r.get("usage", {})
							var fp2: Dictionary = feature_flags(feature_type, options)
							feature = String(fp2["feature"])
							space = bool(fp2["space"])
							solid = bool(fp2["solid"])
							wall = bool(fp2["wall"])
						else:
							feature = ""
					if feature == "":
						continue
					var cell: Dictionary = {
						"solid": solid,
						"feature": feature,
						"space": space,
						"open": open,
						"exit": exit,
						"wall": wall,
						"anchors": [],
					}
					if not feature_usage.is_empty():
						for k in feature_usage:
							cell[k] = feature_usage[k]
					HyperUsage.set_usage(usage_grid, x, y, cell)
		elif shape_type == "plot":
			var cell_base: Dictionary = {
				"solid": solid, "feature": feature, "space": space,
				"open": open, "exit": exit, "wall": wall, "anchors": [],
			}
			if item.has("points"):
				for pos in item["points"]:
					HyperUsage.set_usage(usage_grid, int(pos["x"]), int(pos["y"]),
							cell_base.duplicate())
			elif item.has("x") and item.has("y"):
				HyperUsage.set_usage(usage_grid, int(item["x"]), int(item["y"]),
						cell_base.duplicate())


## Resolve a feature_type string into concrete feature name + solidity
## flags. Our game uses a smaller universe than DCSS so we just pattern-
## match the DCSS-style names.
static func feature_flags(feature_type: String, options: Dictionary) -> Dictionary:
	var feature: String = feature_type
	if feature_type == "floor":
		feature = String(options.get("layout_floor_type", "floor"))
	elif feature_type == "wall":
		feature = String(options.get("layout_wall_type", "rock_wall"))
	elif feature_type == "space":
		feature = "space"
	var space: bool = (feature == "space")
	var solid: bool = not space and not _feature_walkable(feature)
	var wall: bool = _feature_is_wall(feature)
	return {"feature": feature, "space": space, "solid": solid, "wall": wall}


## Map (x, y) to a unit square [0,1]×[0,1] for circle / trapese math.
static func _map_to_unit(x: int, y: int, item: Dictionary) -> Vector2:
	var c1: Dictionary = item.get("corner1", {"x": 0, "y": 0})
	var c2: Dictionary = item.get("corner2", {"x": 1, "y": 1})
	var sx: int = int(c2["x"]) - int(c1["x"])
	var sy: int = int(c2["y"]) - int(c1["y"])
	if sx <= 0: sx = 1
	if sy <= 0: sy = 1
	var rx: float = (float(x - int(c1["x"])) * (sx - 1) / sx) + 0.5
	var ry: float = (float(y - int(c1["y"])) * (sy - 1) / sy) + 0.5
	return Vector2(rx / sx, ry / sy)


static func inside_oval(x: int, y: int, item: Dictionary) -> bool:
	var uv: Vector2 = _map_to_unit(x, y, item)
	var ax: float = uv.x * 2.0 - 1.0
	var ay: float = uv.y * 2.0 - 1.0
	return ax * ax + ay * ay <= 1.0


static func inside_trapese(x: int, y: int, item: Dictionary) -> bool:
	var w1: float = float(item.get("width1", 0.0))
	var w2: float = float(item.get("width2", 1.0))
	var uv: Vector2 = _map_to_unit(x, y, item)
	var expected: float = uv.y * w2 + (1.0 - uv.y) * w1
	return abs(uv.x - 0.5) < (expected / 2.0)


# ---- Feature lookup helpers ---------------------------------------------

## Our game uses a finite tile set. These tables map DCSS feature strings
## to TileType flags. Anything we don't recognise is treated as solid rock
## so the layout engine can still carve it.
const _WALKABLE_FEATURES: Dictionary = {
	"floor": true,
	"open_door": true,
	"door_open": true,
	"stone_stairs_up": true,
	"stone_stairs_down": true,
	"escape_hatch_up": true,
	"escape_hatch_down": true,
	"shallow_water": true,
	"altar": true,
	"trap": true,
	"shop": true,
	"branch_stairs_up": true,
	"branch_stairs_down": true,
}

const _WALL_FEATURES: Dictionary = {
	"rock_wall": true,
	"stone_wall": true,
	"metal_wall": true,
	"crystal_wall": true,
	"wall": true,
	"tree": true,
	"permarock_wall": true,
}


static func _feature_walkable(feature: String) -> bool:
	return _WALKABLE_FEATURES.get(feature, false)


static func _feature_is_wall(feature: String) -> bool:
	return _WALL_FEATURES.get(feature, false)
