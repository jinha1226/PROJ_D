extends SceneTree
## Quick visual comparison — renders several DCSSLayout maps as ASCII to
## stdout so we can eyeball the layout without running the full game.
## Run: godot --headless --script tools/render_maps.gd

func _init() -> void:
	var DCSSLayout = load("res://scripts/dungeon/DCSSLayout.gd")
	var samples := [
		{"seed": 1, "depth": 1},
		{"seed": 7, "depth": 1},
		{"seed": 12, "depth": 5},
		{"seed": 99, "depth": 10},
	]
	for s in samples:
		print("============================================")
		print("seed=", s.seed, " depth=", s.depth)
		print("============================================")
		var rng := RandomNumberGenerator.new()
		rng.seed = int(s.seed)
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = DCSSLayout.build_basic({
			"width": 50, "height": 72, "depth": int(s.depth), "rng": rng,
		})
		var dt := Time.get_ticks_msec() - t0
		_print_map(res)
		var features: Array = res["features"]
		var floor_ct := 0
		var door_ct := 0
		for x in 50:
			for y in 72:
				var f := String(features[x][y])
				if f == "floor": floor_ct += 1
				elif f == "closed_door": door_ct += 1
		print("-- ", dt, "ms  floor=", floor_ct, "/", 50*72,
				" (", int(100.0 * floor_ct / (50*72)), "%)  doors=", door_ct,
				" stairs_down=", res["stairs_down"].size(),
				" stairs_up=", res["stairs_up"].size())
	quit()

func _print_map(res: Dictionary) -> void:
	var features: Array = res["features"]
	for y in 72:
		var row := ""
		for x in 50:
			var f := String(features[x][y])
			match f:
				"floor": row += "."
				"rock_wall": row += "#"
				"closed_door": row += "+"
				"stone_stairs_down": row += ">"
				"stone_stairs_up": row += "<"
				_: row += "?"
		print(row)
