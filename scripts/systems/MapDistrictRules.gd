class_name MapDistrictRules extends RefCounted

## Lightweight authored district metadata for fixed 96x96 expedition maps.
## These rules make each floor read as a place with recognizable sub-areas,
## visible risk/reward pockets, and skill-relevant landmarks.

const DISTRICTS: Dictionary = {
	"dungeon": [
		{"name": "Entry Hall", "rect": [8, 74, 34, 14], "role": "entry", "profile": "ruin"},
		{"name": "Ossuary Ring", "rect": [32, 42, 30, 22], "role": "pressure", "profile": "bones"},
		{"name": "Pilgrim Cache", "rect": [62, 58, 24, 18], "role": "reward", "profile": "cache", "skill": "tracking"},
		{"name": "Undertaker Cells", "rect": [8, 16, 28, 20], "role": "skill", "profile": "locked", "skill": "lockpicking"},
		{"name": "Upper Chapel", "rect": [58, 10, 28, 18], "role": "exit", "profile": "shrine"},
	],
	"lair": [
		{"name": "Root Entry", "rect": [4, 74, 36, 14], "role": "entry", "profile": "roots"},
		{"name": "Central Pool", "rect": [32, 36, 34, 20], "role": "hazard", "profile": "water", "skill": "survival"},
		{"name": "Fungal Grotto", "rect": [48, 58, 28, 16], "role": "reward", "profile": "fungus"},
		{"name": "Swamp Gate", "rect": [8, 16, 26, 16], "role": "branch", "profile": "gate"},
		{"name": "High Roost", "rect": [70, 10, 20, 16], "role": "exit", "profile": "roost", "skill": "tracking"},
	],
	"orc_mines": [
		{"name": "Old Mine Lift", "rect": [6, 72, 24, 16], "role": "entry", "profile": "mine"},
		{"name": "Ore Yard Loop", "rect": [28, 36, 34, 24], "role": "pressure", "profile": "ore"},
		{"name": "Crusher Lane", "rect": [52, 62, 28, 14], "role": "hazard", "profile": "machinery", "skill": "tactics"},
		{"name": "Pay Chest Office", "rect": [62, 36, 20, 14], "role": "reward", "profile": "gold", "skill": "lockpicking"},
		{"name": "Locked Armory", "rect": [68, 22, 18, 12], "role": "skill", "profile": "armory", "skill": "lockpicking"},
		{"name": "Frozen Breach", "rect": [70, 70, 18, 14], "role": "branch", "profile": "ice"},
	],
	"elven_halls": [
		{"name": "Southern Gallery", "rect": [34, 72, 28, 14], "role": "entry", "profile": "gallery"},
		{"name": "Lower Gardens", "rect": [10, 58, 28, 18], "role": "skill", "profile": "garden", "skill": "stealth"},
		{"name": "Silent Library", "rect": [12, 32, 30, 18], "role": "reward", "profile": "library", "skill": "magery"},
		{"name": "Mirror Court", "rect": [42, 36, 24, 22], "role": "pressure", "profile": "mirror", "skill": "tactics"},
		{"name": "Burning Mirror Gate", "rect": [70, 38, 18, 18], "role": "branch", "profile": "gate"},
		{"name": "Northern Sanctum", "rect": [36, 8, 28, 18], "role": "exit", "profile": "sanctum"},
	],
	"abyss": [
		{"name": "Last Descent", "rect": [34, 74, 28, 14], "role": "entry", "profile": "stable"},
		{"name": "Left Shard", "rect": [18, 48, 24, 18], "role": "pressure", "profile": "void"},
		{"name": "Right Shard", "rect": [54, 48, 24, 18], "role": "pressure", "profile": "void"},
		{"name": "Rift Market", "rect": [10, 34, 28, 14], "role": "reward", "profile": "weird"},
		{"name": "Time-Slip Gallery", "rect": [62, 28, 24, 20], "role": "hazard", "profile": "shift", "skill": "tactics"},
		{"name": "Memory Well", "rect": [24, 16, 24, 14], "role": "skill", "profile": "memory", "skill": "tracking"},
		{"name": "Final Gate", "rect": [40, 4, 20, 12], "role": "exit", "profile": "gate"},
	],
	"crypt": [
		{"name": "Flooded Entry", "rect": [34, 72, 28, 16], "role": "entry", "profile": "water"},
		{"name": "Outer Tombs", "rect": [12, 42, 28, 22], "role": "pressure", "profile": "bones"},
		{"name": "Royal Vault", "rect": [56, 42, 26, 18], "role": "reward", "profile": "locked", "skill": "lockpicking"},
		{"name": "Lich Antechamber", "rect": [34, 12, 28, 18], "role": "exit", "profile": "shrine"},
	],
	"swamp": [
		{"name": "Reed Entry", "rect": [6, 72, 30, 18], "role": "entry", "profile": "roots"},
		{"name": "Bog Channel", "rect": [28, 42, 42, 18], "role": "hazard", "profile": "water", "skill": "survival"},
		{"name": "Supply Wreck", "rect": [10, 28, 24, 14], "role": "reward", "profile": "cache"},
		{"name": "Serpent Nest", "rect": [62, 12, 24, 18], "role": "exit", "profile": "gate", "skill": "tracking"},
	],
	"ice_caves": [
		{"name": "Frozen Breach", "rect": [66, 70, 22, 16], "role": "entry", "profile": "ice"},
		{"name": "Thin Ice Bridge", "rect": [38, 44, 28, 14], "role": "hazard", "profile": "ice", "skill": "survival"},
		{"name": "Reflective Archive", "rect": [14, 44, 24, 18], "role": "reward", "profile": "mirror", "skill": "tactics"},
		{"name": "Warm Shelter", "rect": [52, 24, 20, 12], "role": "skill", "profile": "cache", "skill": "survival"},
		{"name": "Glacial Throne", "rect": [12, 10, 28, 18], "role": "exit", "profile": "sanctum"},
	],
	"infernal": [
		{"name": "Ember Vestibule", "rect": [34, 72, 28, 16], "role": "entry", "profile": "gate"},
		{"name": "Lava Crucible", "rect": [32, 42, 34, 20], "role": "hazard", "profile": "machinery", "skill": "tactics"},
		{"name": "Counter-Ward", "rect": [12, 34, 22, 16], "role": "skill", "profile": "shrine", "skill": "magery"},
		{"name": "Treasure Furnace", "rect": [62, 34, 22, 16], "role": "reward", "profile": "gold"},
		{"name": "Tyrant Dais", "rect": [34, 10, 28, 18], "role": "exit", "profile": "sanctum"},
	],
}

static func districts(zone_id: String) -> Array:
	return DISTRICTS.get(zone_id, [])

static func rect_for(district: Dictionary) -> Rect2i:
	var raw: Array = district.get("rect", [0, 0, 0, 0])
	return Rect2i(int(raw[0]), int(raw[1]), int(raw[2]), int(raw[3]))

static func contains(district: Dictionary, pos: Vector2i) -> bool:
	return rect_for(district).has_point(pos)

static func pick_tile(map, zone_id: String, roles: Array,
		rng: RandomNumberGenerator, forbidden: Dictionary = {}) -> Vector2i:
	var candidates: Array[Vector2i] = []
	for d in districts(zone_id):
		if not roles.is_empty() and not roles.has(String(d.get("role", ""))):
			continue
		var rect: Rect2i = rect_for(d)
		for y in range(rect.position.y, rect.end.y):
			for x in range(rect.position.x, rect.end.x):
				var p := Vector2i(x, y)
				if forbidden.has(p):
					continue
				if map.in_bounds(p) and map.is_walkable(p):
					candidates.append(p)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[rng.randi_range(0, candidates.size() - 1)]
