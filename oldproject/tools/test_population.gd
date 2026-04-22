extends SceneTree
## Smoke-test MonsterPopulation with branch-local depths.
func _init() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1
	var pairs := [["main", 1], ["main", 3], ["main", 5],
			["mine", 1], ["mine", 3], ["mine", 5],
			["forest", 1], ["forest", 3], ["forest", 5],
			["swamp", 1], ["swamp", 3], ["swamp", 5],
			["volcano", 1], ["volcano", 3], ["volcano", 5]]
	for p in pairs:
		var branch: String = p[0]
		var depth: int = p[1]
		var counts: Dictionary = {}
		for _i in 100:
			var id: String = MonsterPopulation.pick(branch, depth, rng)
			if id == "":
				continue
			counts[id] = int(counts.get(id, 0)) + 1
		var arr: Array = []
		for k in counts.keys():
			arr.append({"id": k, "n": counts[k]})
		arr.sort_custom(func(a, b): return a["n"] > b["n"])
		var s := ""
		for q in arr.slice(0, 5):
			s += " %s(%d)" % [q["id"], q["n"]]
		print("%-8s d=%d:" % [branch, depth], s)
	quit()
