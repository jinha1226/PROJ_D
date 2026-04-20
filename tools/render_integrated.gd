extends SceneTree
## Full pipeline: DungeonGenerator → tile grid → ASCII render.
## Verifies VaultRegistry + DesParser + DungeonGenerator + DCSSLayout play nice.

func _init() -> void:
	var gm = load("res://scripts/core/GameManager.gd").new()
	gm.name = "GameManager"
	root.add_child(gm)
	var gen = load("res://scripts/dungeon/DungeonGenerator.gd").new()
	var t_vault0 := Time.get_ticks_msec()
	load("res://scripts/dungeon/VaultRegistry.gd").ensure_dcss_loaded()
	print("[DCSS vault load: ", Time.get_ticks_msec() - t_vault0, "ms]")
	for seed in [1, 7, 99]:
		var t0 := Time.get_ticks_msec()
		gen.generate(1, seed)
		print("[generate(1): ", Time.get_ticks_msec() - t0, "ms]")
		print("============================================")
		print("seed=", seed, " depth=1  rooms=", gen.rooms.size(),
				" spawn=", gen.spawn_pos, " stairs_dn=", gen.stairs_down_pos)
		print("============================================")
		for y in 72:
			var row := ""
			for x in 50:
				var t: int = gen.map[x][y]
				if Vector2i(x, y) == gen.spawn_pos: row += "@"
				else:
					match t:
						gen.TileType.FLOOR: row += "."
						gen.TileType.WALL: row += "#"
						gen.TileType.DOOR_CLOSED: row += "+"
						gen.TileType.DOOR_OPEN: row += "'"
						gen.TileType.STAIRS_DOWN: row += ">"
						gen.TileType.STAIRS_UP: row += "<"
						gen.TileType.TREE: row += "T"
						gen.TileType.WATER: row += "~"
						gen.TileType.LAVA: row += "L"
						_: row += "?"
			print(row)
	quit()
