class_name MapDistrictRules extends RefCounted

## Lightweight authored district metadata for fixed 96x96 expedition maps.
## These rules make each floor read as a place with recognizable sub-areas,
## visible risk/reward pockets, and skill-relevant landmarks.

## All rects are [x, y, w, h] for a 56×62 tile map.
## Convention: y increases downward; entry districts sit near the bottom (y≈46+),
## exit/boss districts near the top (y≈6-20).
const DISTRICTS: Dictionary = {
	"dungeon": [
		{"name": "Entry Hall",       "rect": [4, 46, 28, 12], "role": "entry",    "profile": "ruin"},
		{"name": "Ossuary Ring",     "rect": [16, 26, 22, 16], "role": "pressure", "profile": "bones"},
		{"name": "Pilgrim Cache",    "rect": [34, 38, 16, 14], "role": "reward",   "profile": "cache",   "skill": "tracking"},
		{"name": "Undertaker Cells", "rect": [4, 8, 20, 16],   "role": "skill",    "profile": "locked",  "skill": "lockpicking"},
		{"name": "Upper Chapel",     "rect": [32, 6, 18, 14],  "role": "exit",     "profile": "shrine"},
	],
	"lair": [
		{"name": "Root Entry",    "rect": [4, 46, 24, 12],  "role": "entry",   "profile": "roots"},
		{"name": "Central Pool",  "rect": [16, 26, 26, 16], "role": "hazard",  "profile": "water",  "skill": "survival"},
		{"name": "Fungal Grotto", "rect": [32, 38, 18, 14], "role": "reward",  "profile": "fungus"},
		{"name": "Swamp Gate",    "rect": [4, 8, 18, 14],   "role": "branch",  "profile": "gate"},
		{"name": "High Roost",    "rect": [36, 6, 16, 12],  "role": "exit",    "profile": "roost",  "skill": "tracking"},
	],
	"orc_mines": [
		{"name": "Old Mine Lift",    "rect": [4, 46, 16, 12],  "role": "entry",    "profile": "mine"},
		{"name": "Ore Yard Loop",    "rect": [14, 24, 22, 18], "role": "pressure", "profile": "ore"},
		{"name": "Crusher Lane",     "rect": [6, 36, 16, 12],  "role": "hazard",   "profile": "machinery", "skill": "survival"},
		{"name": "Pay Chest Office", "rect": [36, 28, 14, 12], "role": "reward",   "profile": "gold",      "skill": "lockpicking"},
		{"name": "Locked Armory",    "rect": [38, 10, 14, 12], "role": "skill",    "profile": "armory",    "skill": "lockpicking"},
		{"name": "Frozen Breach",    "rect": [38, 46, 14, 12], "role": "branch",   "profile": "ice"},
	],
	"elven_halls": [
		{"name": "Southern Gallery",  "rect": [18, 46, 20, 12], "role": "entry",    "profile": "gallery"},
		{"name": "Lower Gardens",     "rect": [4, 34, 18, 14],  "role": "skill",    "profile": "garden",  "skill": "dodging"},
		{"name": "Silent Library",    "rect": [4, 18, 20, 14],  "role": "reward",   "profile": "library", "skill": "magery"},
		{"name": "Mirror Court",      "rect": [24, 22, 18, 16], "role": "pressure", "profile": "mirror",  "skill": "survival"},
		{"name": "Burning Mirror Gate","rect": [38, 26, 14, 14],"role": "branch",   "profile": "gate"},
		{"name": "Northern Sanctum",  "rect": [18, 4, 20, 14],  "role": "exit",     "profile": "sanctum"},
	],
	"abyss": [
		{"name": "Last Descent",       "rect": [18, 46, 20, 12], "role": "entry",   "profile": "stable"},
		{"name": "Left Shard",         "rect": [4, 28, 16, 14],  "role": "pressure","profile": "void"},
		{"name": "Right Shard",        "rect": [36, 28, 16, 14], "role": "pressure","profile": "void"},
		{"name": "Rift Market",        "rect": [4, 20, 18, 10],  "role": "reward",  "profile": "weird"},
		{"name": "Time-Slip Gallery",  "rect": [34, 16, 16, 12], "role": "hazard",  "profile": "shift",  "skill": "survival"},
		{"name": "Memory Well",        "rect": [14, 8, 16, 12],  "role": "skill",   "profile": "memory", "skill": "tracking"},
		{"name": "Final Gate",         "rect": [20, 2, 16, 10],  "role": "exit",    "profile": "gate"},
	],
	"crypt": [
		{"name": "Flooded Entry",    "rect": [18, 46, 20, 12], "role": "entry",    "profile": "water"},
		{"name": "Outer Tombs",      "rect": [4, 24, 18, 16],  "role": "pressure", "profile": "bones"},
		{"name": "Royal Vault",      "rect": [34, 24, 18, 16], "role": "reward",   "profile": "locked", "skill": "lockpicking"},
		{"name": "Lich Antechamber", "rect": [18, 6, 20, 14],  "role": "exit",     "profile": "shrine"},
	],
	"swamp": [
		{"name": "Reed Entry",   "rect": [4, 46, 20, 12],  "role": "entry",  "profile": "roots"},
		{"name": "Bog Channel",  "rect": [14, 26, 28, 14], "role": "hazard", "profile": "water", "skill": "survival"},
		{"name": "Supply Wreck", "rect": [4, 16, 18, 12],  "role": "reward", "profile": "cache"},
		{"name": "Serpent Nest", "rect": [34, 6, 18, 14],  "role": "exit",   "profile": "gate",  "skill": "tracking"},
	],
	"ice_caves": [
		{"name": "Frozen Breach",      "rect": [36, 44, 16, 12], "role": "entry",  "profile": "ice"},
		{"name": "Thin Ice Bridge",    "rect": [20, 28, 18, 12], "role": "hazard", "profile": "ice",    "skill": "survival"},
		{"name": "Reflective Archive", "rect": [4, 26, 16, 14],  "role": "reward", "profile": "mirror", "skill": "survival"},
		{"name": "Warm Shelter",       "rect": [28, 12, 16, 12], "role": "skill",  "profile": "cache",  "skill": "survival"},
		{"name": "Glacial Throne",     "rect": [4, 6, 20, 14],   "role": "exit",   "profile": "sanctum"},
	],
	"infernal": [
		{"name": "Ember Vestibule", "rect": [18, 46, 20, 12], "role": "entry",  "profile": "gate"},
		{"name": "Lava Crucible",   "rect": [16, 24, 22, 16], "role": "hazard", "profile": "machinery", "skill": "survival"},
		{"name": "Counter-Ward",    "rect": [4, 20, 16, 14],  "role": "skill",  "profile": "shrine",    "skill": "magery"},
		{"name": "Treasure Furnace","rect": [36, 20, 16, 14], "role": "reward", "profile": "gold"},
		{"name": "Tyrant Dais",     "rect": [18, 6, 20, 14],  "role": "exit",   "profile": "sanctum"},
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
