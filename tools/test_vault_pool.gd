extends SceneTree
## Verify the vault pool returns sensible counts per (branch, depth).
func _init() -> void:
	var VR = load("res://scripts/dungeon/VaultRegistry.gd")
	VR.ensure_dcss_loaded()
	for depth in [1, 3, 5, 8, 10, 15, 20]:
		for br in ["main", "mine", "forest", "swamp", "volcano"]:
			var pool: Array = VR.for_branch_at_depth(br, depth)
			print("br=", br, " d=", depth, " pool=", pool.size())
	# Dump first 3 vaults' dimensions at D:1 main.
	var pool1: Array = VR.for_branch_at_depth("main", 1)
	print("---")
	for i in min(5, pool1.size()):
		var m: Array = pool1[i]
		print("  vault#", i, " size=", String(m[0]).length(), "x", m.size(), " sample=", m[0])
	quit()
