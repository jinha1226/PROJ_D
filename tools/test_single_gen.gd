extends SceneTree
## Minimal: just one generate(1) call, print result.
func _init() -> void:
	var gm_script := load("res://scripts/core/GameManager.gd")
	var gm: Node = gm_script.new()
	gm.name = "GameManager"
	root.add_child(gm)
	var gen = load("res://scripts/dungeon/DungeonGenerator.gd").new()
	var t0: int = Time.get_ticks_msec()
	gen.generate(1, 42)
	var dt: int = Time.get_ticks_msec() - t0
	var floor_count: int = 0
	for x in gen.MAP_WIDTH:
		for y in gen.MAP_HEIGHT:
			if gen.map[x][y] == gen.TileType.FLOOR:
				floor_count += 1
	print("generate(1): ", dt, "ms rooms=", gen.rooms.size(), " floor=", floor_count)
	quit()
