extends SceneTree
## Minimal DCSSLayout standalone test — no DungeonGenerator, no GameManager.
func _init() -> void:
	var DCSSLayout = load("res://scripts/dungeon/DCSSLayout.gd")
	for seed in [1, 2, 3, 42, 100]:
		var rng := RandomNumberGenerator.new()
		rng.seed = seed
		var t0 := Time.get_ticks_msec()
		var res: Dictionary = DCSSLayout.build_basic({
			"width": 50, "height": 72, "depth": 1, "rng": rng,
		})
		var dt := Time.get_ticks_msec() - t0
		var features: Array = res.get("features", [])
		var floor_ct := 0
		var door_ct := 0
		var stair_ct := 0
		for x in 50:
			for y in 72:
				var f := String(features[x][y])
				if f == "floor": floor_ct += 1
				elif f == "closed_door": door_ct += 1
				elif f.begins_with("stone_stairs"): stair_ct += 1
		print("seed=", seed, " ", dt, "ms  floor=", floor_ct,
				" door=", door_ct, " stair=", stair_ct)
	# Also render one sample to console.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var res2: Dictionary = DCSSLayout.build_basic({
		"width": 50, "height": 72, "depth": 1, "rng": rng,
	})
	var features: Array = res2["features"]
	for y in 72:
		var row := ""
		for x in 50:
			var f := String(features[x][y])
			if f == "floor": row += "."
			elif f == "rock_wall": row += "#"
			elif f == "closed_door": row += "+"
			elif f == "stone_stairs_down": row += ">"
			elif f == "stone_stairs_up": row += "<"
			else: row += "?"
		print(row)
	quit()
