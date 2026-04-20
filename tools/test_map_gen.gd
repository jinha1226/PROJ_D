extends SceneTree
## Generate a D:1 map via DungeonGenerator and report whether it used the
## hyper engine or fell back to BSP, plus how many DCSS vaults stamp visibly.

func _init() -> void:
	# Fake-instantiate GameManager so _current_branch resolves to "main".
	var gm_script := load("res://scripts/core/GameManager.gd")
	var gm: Node = gm_script.new()
	gm.name = "GameManager"
	root.add_child(gm)

	var gen_script := load("res://scripts/dungeon/DungeonGenerator.gd")
	var gen = gen_script.new()

	for depth in [1, 3, 5, 8]:
		# Count rooms and floor tiles before and after vault placement.
		gen.generate(depth, 42)
		var floor_count: int = 0
		for x in gen.MAP_WIDTH:
			for y in gen.MAP_HEIGHT:
				if gen.map[x][y] == gen.TileType.FLOOR:
					floor_count += 1
		print("depth=", depth,
				" rooms=", gen.rooms.size(),
				" floor=", floor_count,
				" spawn=", gen.spawn_pos,
				" stairs_dn=", gen.stairs_down_pos)
	quit()
