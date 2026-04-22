extends SceneTree
## One-shot parser smoke test. Run with:
##   godot --headless --script tools/test_des_parser.gd --path /mnt/d/PROJ_D

func _init() -> void:
	var DesParser = load("res://scripts/dungeon/DesParser.gd")
	var dirs := ["res://assets/dcss_des/variable", "res://assets/dcss_des/builder"]
	var total: int = 0
	var by_source: Dictionary = {}
	for d in dirs:
		var vaults: Array = DesParser.parse_directory(d)
		total += vaults.size()
		for v in vaults:
			var src: String = String(v.get("source", "?"))
			by_source[src] = int(by_source.get(src, 0)) + 1
	print("Total vaults parsed: ", total)
	var keys: Array = by_source.keys()
	keys.sort()
	for k in keys:
		print("  ", k, " -> ", by_source[k])
	quit()
