class_name PropPlacer extends RefCounted

## Scatter thematic decorative props on a freshly-generated DungeonMap floor.
## Props are visual only — they do not block movement or pathfinding.
## Call scatter() after map.generate() / map.generate_fixed_from_file().

# ---------------------------------------------------------------------------
# Zone themes: zone_id → { density: float, props: [[path, weight], ...] }
# density = fraction of eligible room-interior floor tiles that get a prop.
# ---------------------------------------------------------------------------
const _D  := "res://assets/tiles/individual/dngn/decor/"
const _S  := "res://assets/tiles/individual/dngn/statues/"
const _T  := "res://assets/tiles/individual/dngn/trees/"
const _TR := "res://assets/tiles/individual/dngn/traps/"

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
		"density": 0.06,
		"props": [
			[_D + "blue_fountain.png",         4],
			[_D + "blue_fountain2.png",        4],
			[_S + "crumbled_column_1.png",     3],
			[_S + "crumbled_column_2.png",     3],
			[_S + "depths_column.png",         2],
			[_T + "tree_demonic1.png",         1],
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

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _weighted_pick(paths: Array, weights: Array, total: int,
		rng: RandomNumberGenerator) -> String:
	var roll: int = rng.randi_range(0, total - 1)
	var acc: int = 0
	for i in range(paths.size()):
		acc += weights[i]
		if roll < acc:
			return paths[i]
	return paths[-1]

## Restore prop_tiles (Texture2D) from cached prop_tile_paths (String paths).
## Call after restoring a floor from cache / save.
static func restore_textures(map: DungeonMap) -> void:
	map.prop_tiles.clear()
	for pos in map.prop_tile_paths.keys():
		var path: String = str(map.prop_tile_paths[pos])
		if ResourceLoader.exists(path):
			map.prop_tiles[pos] = load(path) as Texture2D
