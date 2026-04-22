extends SceneTree
## Smoke-test MonsterRegistry. Confirms JSON loads and a few IDs resolve.
func _init() -> void:
	var ids = MonsterRegistry.all_ids()
	print("Total known monster ids: ", ids.size())
	for id in ["orc", "kobold", "adder", "fire_dragon", "ancient_lich",
			"rat", "goblin", "gnoll"]:
		var d: MonsterData = MonsterRegistry.fetch(id)
		if d == null:
			print("  MISSING: ", id)
			continue
		print("  %-18s hd=%2d hp=%4d ac=%2d ev=%2d spd=%3d glyph=%s size=%s"
				% [id, d.hd, d.hp, d.ac, d.ev, d.speed, d.glyph_char, d.size])
	quit()
