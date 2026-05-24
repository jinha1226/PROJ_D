class_name PropPlacer extends RefCounted

## Scatter thematic decorative props on a freshly-generated DungeonMap floor.
## Large props can block movement, pathfinding, and field of view.
## Call scatter() after map.generate() / map.generate_fixed_from_file().

# ---------------------------------------------------------------------------
# Zone themes: zone_id → { density: float, props: [[path, weight], ...] }
# density = fraction of eligible room-interior floor tiles that get a prop.
# ---------------------------------------------------------------------------
const _D  := "res://assets/tiles/individual/dngn/decor/"
const _S  := "res://assets/tiles/individual/dngn/statues/"
const _T  := "res://assets/tiles/individual/dngn/trees/"
const _TR := "res://assets/tiles/individual/dngn/traps/"
const _V  := "res://assets/tiles/individual/dngn/vaults/"

const ZONE_THEMES: Dictionary = {
	# Catacombs — stone ruins, dust, cobwebs
	"dungeon": {
		"density": 0.06,
		"props": [
			[_S + "crumbled_column_1.png", 4],
			[_S + "crumbled_column_2.png", 4],
			[_S + "crumbled_column_3.png", 3],
			[_S + "crumbled_column_4.png", 2],
			[_D + "dry_fountain.png",      3],
			[_S + "metal_statue.png",      2],
			[_TR+ "cobweb_none_0.png",     3],
			[_TR+ "cobweb_none_1.png",     3],
			[_TR+ "cobweb_none_2.png",     2],
		],
	},
	# Lair — overgrown, natural cave
	"lair": {
		"density": 0.07,
		"props": [
			[_T + "tree1.png",          3],
			[_T + "tree2.png",          3],
			[_T + "tree3.png",          3],
			[_T + "tree4.png",          2],
			[_T + "mangrove1.png",      3],
			[_T + "mangrove2.png",      2],
			[_D + "flower_patch_0.png", 3],
			[_D + "flower_patch_1.png", 3],
			[_D + "flower_patch_2.png", 2],
			[_D + "garden_patch.png",   2],
		],
	},
	# Orc Mines — crude idols, warrior symbols
	"orc_mines": {
		"density": 0.05,
		"props": [
			[_S + "orcish_idol.png",    5],
			[_S + "statue_axe.png",     3],
			[_S + "crumbled_column_1.png", 2],
			[_S + "crumbled_column_5.png", 2],
			[_D + "cache_of_meat_0.png",   2],
			[_D + "cache_of_meat_1.png",   2],
		],
	},
	# Elven Halls — elegant, arcane
	"elven_halls": {
		"density": 0.06,
		"props": [
			[_D + "sparkling_fountain.png",  4],
			[_D + "sparkling_fountain2.png", 3],
			[_D + "blue_fountain.png",       3],
			[_S + "statue_archer.png",       3],
			[_S + "statue_angel.png",        2],
			[_D + "flower_patch_0.png",      3],
			[_D + "flower_patch_3.png",      3],
			[_D + "garden_patch.png",        2],
		],
	},
	# Abyss — demonic, eldritch
	"abyss": {
		"density": 0.07,
		"props": [
			[_T + "tree_demonic1.png",             3],
			[_T + "tree_demonic2.png",             3],
			[_T + "tree_demonic3.png",             3],
			[_T + "dead_tree_of_woe1.png",         3],
			[_T + "dead_tree_of_woe2.png",         2],
			[_D + "blood_fountain.png",            3],
			[_D + "blood_fountain2.png",           2],
			[_S + "statue_depths_fangs.png",       2],
			[_S + "statue_depths_asmodeus.png",    1],
			[_D + "eyes_fountain.png",             2],
		],
	},
	# ── Branch themes ───────────────────────────────────────────────────────
	"swamp": {
		"density": 0.07,
		"props": [
			[_T + "mangrove1.png",         4],
			[_T + "mangrove2.png",         4],
			[_T + "mangrove3.png",         3],
			[_T + "dead_tree_of_woe1.png", 3],
			[_T + "dead_tree_of_woe2.png", 2],
			[_D + "flower_patch_1.png",    2],
		],
	},
	"ice_caves": {
		"density": 0.08,
		"props": [
			[_D + "blue_fountain.png",         4],
			[_D + "blue_fountain2.png",        4],
			[_V + "bedevilled_crystal_coc_0.png", 4],
			[_V + "bedevilled_crystal_coc_1.png", 4],
			[_V + "bedevilled_crystal_dis_0.png", 2],
			[_V + "bedevilled_crystal_dis_1.png", 2],
			[_S + "depths_column.png",         2],
		],
	},
	"infernal": {
		"density": 0.07,
		"props": [
			[_T + "tree_demonic1.png",             3],
			[_T + "tree_demonic4.png",             3],
			[_T + "tree_demonic7.png",             3],
			[_D + "blood_fountain.png",            3],
			[_D + "blood_fountain2.png",           2],
			[_S + "statue_demonic_bust.png",       3],
			[_S + "statue_depths_asmodeus.png",    2],
			[_S + "statue_cerebov.png",            1],
		],
	},
	"crypt": {
		"density": 0.06,
		"props": [
			[_S + "crumbled_column_1.png",      4],
			[_S + "crumbled_column_2.png",      3],
			[_S + "depths_crumbled_column.png", 3],
			[_D + "dry_fountain.png",           3],
			[_S + "statue_ancient_hero.png",    3],
			[_S + "statue_ancient_evil.png",    2],
			[_S + "statue_depths_tomes.png",    2],
		],
	},
}

# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

## Scatter props on map for the given zone/branch id and seed.
## Populates map.prop_tile_paths and map.prop_tiles.
static func scatter(map: DungeonMap, zone_id: String, seed_val: int) -> void:
	map.prop_tile_paths.clear()
	map.prop_tiles.clear()
	map.prop_blocking.clear()

	var theme: Dictionary = ZONE_THEMES.get(zone_id, {})
	if theme.is_empty():
		return

	var density: float = float(theme.get("density", 0.06))
	var prop_list: Array = theme.get("props", [])
	if prop_list.is_empty():
		return

	# Build weighted pick table.
	var paths: Array = []
	var weights: Array = []
	var total_w: int = 0
	for entry in prop_list:
		paths.append(str(entry[0]))
		weights.append(int(entry[1]))
		total_w += int(entry[1])
	if total_w == 0:
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = seed_val ^ zone_id.hash()

	# Collect eligible tiles: walkable floor inside rooms, away from stairs/branch.
	var forbidden: Dictionary = {}
	forbidden[map.spawn_pos] = true
	forbidden[map.stairs_down_pos] = true
	forbidden[map.stairs_up_pos] = true
	for p in map.extra_stairs_down_positions:
		forbidden[p] = true

	var candidates: Array = []
	for room in map.rooms:
		# Interior only — skip the 1-tile border of each room.
		for ry in range(room.position.y + 1, room.position.y + room.size.y - 1):
			for rx in range(room.position.x + 1, room.position.x + room.size.x - 1):
				var p := Vector2i(rx, ry)
				if map.is_walkable(p) and not forbidden.has(p):
					candidates.append(p)

	if candidates.is_empty():
		for y in range(map.GRID_H):
			for x in range(map.GRID_W):
				var p := Vector2i(x, y)
				if map.is_walkable(p) and not forbidden.has(p):
					candidates.append(p)
	if candidates.is_empty():
		_place_district_landmarks(map, zone_id, rng)
		return

	candidates.shuffle()  # use GDScript built-in shuffle (not seeded, but just order)
	# Reseed and pick count deterministically.
	var count: int = max(1, int(round(float(candidates.size()) * density)))
	count = min(count, candidates.size())

	# Deterministic selection: pick first 'count' after seeded partial sort.
	# Simple approach: assign a random key to each candidate, sort, take first N.
	var keyed: Array = []
	for c in candidates:
		keyed.append([rng.randi(), c])
	keyed.sort_custom(func(a, b): return a[0] < b[0])

	for i in range(count):
		var pos: Vector2i = keyed[i][1]
		var path: String = _weighted_pick(paths, weights, total_w, rng)
		if not ResourceLoader.exists(path):
			continue
		map.prop_tile_paths[pos] = path
		map.prop_tiles[pos] = load(path) as Texture2D
		if _is_blocking_prop(path):
			map.prop_blocking[pos] = true
	_place_district_landmarks(map, zone_id, rng)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _place_district_landmarks(map: DungeonMap, zone_id: String,
		rng: RandomNumberGenerator) -> void:
	for district in MapDistrictRules.districts(zone_id):
		var profile: String = String(district.get("profile", ""))
		var role: String = String(district.get("role", ""))
		var paths: Array = _district_profile_props(profile) + _district_role_props(role)
		if paths.is_empty():
			continue
		var count: int = _district_prop_count(district)
		var forbidden: Dictionary = map.prop_tile_paths.duplicate()
		forbidden[map.spawn_pos] = true
		forbidden[map.stairs_down_pos] = true
		forbidden[map.stairs_up_pos] = true
		for p in map.extra_stairs_down_positions:
			forbidden[p] = true
		for _i in range(count):
			var pos: Vector2i = _pick_tile_in_district(map, district, rng, forbidden)
			if pos == Vector2i(-1, -1):
				break
			var path: String = String(paths[rng.randi_range(0, paths.size() - 1)])
			if not ResourceLoader.exists(path):
				forbidden[pos] = true
				continue
			map.prop_tile_paths[pos] = path
			map.prop_tiles[pos] = load(path) as Texture2D
			if _is_blocking_prop(path):
				map.prop_blocking[pos] = true
			forbidden[pos] = true

static func _pick_tile_in_district(map: DungeonMap, district: Dictionary,
		rng: RandomNumberGenerator, forbidden: Dictionary) -> Vector2i:
	var rect: Rect2i = MapDistrictRules.rect_for(district)
	var candidates: Array[Vector2i] = []
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

static func _district_prop_count(district: Dictionary) -> int:
	var role: String = String(district.get("role", ""))
	var rect: Rect2i = MapDistrictRules.rect_for(district)
	var area_bonus: int = clampi(rect.get_area() / 180, 0, 3)
	match role:
		"entry":
			return 3 + area_bonus
		"pressure", "hazard":
			return 6 + area_bonus
		"reward", "skill":
			return 5 + area_bonus
		"branch", "exit":
			return 4 + area_bonus
		_:
			return 4 + area_bonus

static func _district_profile_props(profile: String) -> Array:
	match profile:
		"ruin":
			return [_S + "crumbled_column_1.png", _S + "crumbled_column_3.png",
					_S + "crumbled_column_4.png", _D + "dry_fountain.png",
					_V + "brick_dark_leak.png", _V + "brick_dark_skeleton.png"]
		"bones":
			return [_TR + "cobweb_none_0.png", _TR + "cobweb_none_1.png",
					_TR + "cobweb_none_2.png", _D + "dry_fountain.png",
					_S + "statue_ancient_evil.png", _V + "brick_dark_skeleton.png"]
		"cache":
			return [_D + "cache_of_meat_0.png", _D + "cache_of_meat_1.png",
					_D + "cache_of_baked_goods_1.png", _D + "cache_of_fruit_0.png",
					_D + "cache_of_fruit_2.png"]
		"locked":
			return [_S + "metal_statue.png", _S + "depths_column.png",
					_S + "statue_depths_tomes.png", _TR + "pressure_plate.png"]
		"shrine", "sanctum":
			return [_D + "sparkling_fountain.png", _D + "sparkling_fountain2.png",
					_S + "statue_ancient_hero.png", _S + "statue_angel.png",
					_TR + "binding_sigil.png"]
		"roots":
			return [_T + "tree1.png", _T + "tree2.png", _T + "tree5.png",
					_T + "mangrove1.png", _T + "mangrove2.png",
					_D + "flower_patch_0.png"]
		"water":
			return [_D + "blue_fountain.png", _D + "blue_fountain2.png",
					_T + "mangrove1.png", _T + "mangrove3.png",
					_D + "flower_patch_1.png"]
		"fungus":
			return [_D + "flower_patch_1.png", _D + "flower_patch_2.png",
					_D + "flower_patch_3.png", _D + "garden_patch.png",
					_T + "tree_petrified1.png"]
		"gate":
			return [_S + "depths_column.png", _S + "statue_depths_fangs.png",
					_S + "statue_depths_zot_orb_guardian.png", _V + "dimensional_conduit_0.png",
					_V + "dimensional_conduit_1.png"]
		"roost":
			return [_S + "statue_archer.png", _S + "statue_centaur.png",
					_S + "statue_tengu.png", _T + "tree_dead1.png"]
		"mine", "ore":
			return [_S + "orcish_idol.png", _S + "statue_axe.png",
					_S + "statue_dwarf.png", _V + "earthen_conduit_0.png",
					_V + "earthen_conduit_1.png", _D + "cache_of_meat_0.png"]
		"machinery":
			return [_S + "statue_iron.png", _S + "depths_column.png",
					_TR + "pressure_plate.png", _TR + "spear.png",
					_V + "earthen_conduit_2.png", _V + "earthen_conduit_3.png"]
		"gold":
			return [_V + "golden_statue_1.png", _V + "golden_statue_2.png",
					_V + "golden_iron_statue.png", _V + "gilded_reliquary.png",
					_D + "cache_of_baked_goods_2.png"]
		"armory":
			return [_S + "statue_sword.png", _S + "statue_axe.png",
					_S + "statue_polearm.png", _V + "wall/wall_sword_gold.png",
					_V + "oka_iron_statue_1.png", _V + "golden_iron_statue.png"]
		"gallery", "mirror":
			return [_D + "sparkling_fountain2.png", _S + "statue_archer.png",
					_S + "statue_princess.png", _S + "statue_sword.png",
					_V + "arcane_conduit_0.png", _V + "arcane_conduit_1.png"]
		"garden":
			return [_D + "flower_patch_0.png", _D + "flower_patch_2.png",
					_D + "flower_patch_3.png", _D + "garden_patch.png",
					_T + "tree_fall1.png", _T + "tree_fall3.png"]
		"library", "memory":
			return [_V + "stacked_books_1.png", _V + "stacked_books_2.png",
					_V + "stacked_books_3.png", _S + "statue_depths_tomes.png",
					_V + "arcane_conduit_0.png", _V + "arcane_conduit_2.png"]
		"stable":
			return [_S + "crumbled_column_2.png", _S + "crumbled_column_5.png",
					_D + "dry_fountain.png", _D + "decorative_floor.png"]
		"void", "weird", "shift":
			return [_D + "eyes_fountain.png", _S + "statue_depths_zot_tentacles.png",
					_S + "statue_zot_orb.png", _S + "zot_entropy_orb_statue.png",
					_TR + "teleport.png", _TR + "dispersal.png",
					_V + "dimension_edge.png", _V + "dimensional_conduit_2.png"]
		"ice":
			return [_V + "bedevilled_crystal_coc_0.png", _V + "bedevilled_crystal_coc_1.png",
					_V + "bedevilled_crystal_dis_0.png", _V + "bedevilled_crystal_dis_1.png",
					_V + "teleporter_ice_cave.png", _D + "blue_fountain.png"]
		_:
			return []

static func _district_role_props(role: String) -> Array:
	match role:
		"entry":
			return [_S + "crumbled_column_1.png", _D + "dry_fountain.png"]
		"pressure":
			return [_TR + "alarm.png", _TR + "net.png", _TR + "pressure_plate.png"]
		"hazard":
			return [_TR + "dispersal.png", _TR + "shaft.png", _TR + "teleport.png"]
		"reward":
			return [_V + "golden_statue_1.png", _V + "silver_statue_1.png",
					_D + "cache_of_baked_goods_1.png", _V + "gilded_reliquary.png"]
		"skill":
			return [_TR + "binding_sigil.png", _V + "stacked_books_1.png",
					_V + "arcane_conduit_2.png", _S + "statue_depths_tomes.png"]
		"branch":
			return [_V + "dimensional_conduit_0.png", _V + "dimensional_conduit_3.png",
					_S + "depths_column.png"]
		"exit":
			return [_S + "statue_ancient_hero.png", _S + "depths_column.png",
					_D + "sparkling_fountain.png"]
		_:
			return []

static func _weighted_pick(paths: Array, weights: Array, total: int,
		rng: RandomNumberGenerator) -> String:
	var roll: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	for i in range(paths.size()):
		acc += weights[i]
		if roll < acc:
			return paths[i]
	return paths[-1]

static func _is_blocking_prop(path: String) -> bool:
	if path.contains("/dngn/statues/") or path.contains("/dngn/trees/"):
		return true
	if path.contains("/dngn/vaults/"):
		return not path.contains("/wall/")
	return false

## Restore prop_tiles (Texture2D) from cached prop_tile_paths (String paths).
## Call after restoring a floor from cache / save.
static func restore_textures(map: DungeonMap) -> void:
	map.prop_tiles.clear()
	map.prop_blocking.clear()
	for pos in map.prop_tile_paths.keys():
		var path: String = str(map.prop_tile_paths[pos])
		if ResourceLoader.exists(path):
			map.prop_tiles[pos] = load(path) as Texture2D
			if _is_blocking_prop(path):
				map.prop_blocking[pos] = true
