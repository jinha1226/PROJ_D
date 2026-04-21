class_name MonsterSpawner

const MONSTER_SCENE_PATH: String = "res://scenes/entities/Monster.tscn"
## DCSS dungeon.cc caps monster-wanted at 60. Keep the same cap.
const MAX_COUNT: int = 60


## DCSS mon-place.cc:_choose_band — a small set of leader→band mappings.
## Each entry names a follower id plus a count range. When the leader is
## picked on a floor, we also spawn `[min, max]` extra followers on
## nearby tiles so packs (orcs, jackals, gnolls) feel grouped instead of
## sprinkled. Kept compact; expand incrementally as more pack leaders
## land in the content set.
const _BANDS: Dictionary = {
	"orc":             {"follower": "orc",            "min": 2, "max": 5},
	"orc_wizard":      {"follower": "orc",            "min": 2, "max": 5},
	"orc_priest":      {"follower": "orc_warrior",    "min": 2, "max": 5},
	"orc_warrior":     {"follower": "orc_warrior",    "min": 2, "max": 5},
	"orc_knight":      {"follower": "orc_knight",     "min": 3, "max": 7},
	"orc_warlord":     {"follower": "orc_knight",     "min": 6, "max": 12},
	"orc_sorcerer":    {"follower": "orc_priest",     "min": 4, "max": 8},
	"gnoll":           {"follower": "gnoll",          "min": 2, "max": 4},
	"gnoll_shaman":    {"follower": "gnoll",          "min": 2, "max": 4},
	"kobold":          {"follower": "kobold",         "min": 1, "max": 3},
	"kobold_demonologist": {"follower": "kobold",     "min": 2, "max": 4},
	"jackal":          {"follower": "jackal",         "min": 2, "max": 4},
	"gnoll_sergeant":  {"follower": "gnoll",          "min": 3, "max": 5},
	"deep_elf_fighter":{"follower": "deep_elf_knight","min": 2, "max": 4},
	"centaur":         {"follower": "centaur",        "min": 1, "max": 3},
	"yaktaur":         {"follower": "yaktaur",        "min": 1, "max": 3},
	"two_headed_ogre": {"follower": "ogre",           "min": 1, "max": 3},
	"hobgoblin":       {"follower": "hobgoblin",      "min": 2, "max": 4},
	# --- Lair / Forest bands (DCSS mon-place: wolves hunt in packs,
	#     yaks roam in herds, spiders clutch together). Makes branch
	#     entrances feel appropriately wild instead of single foes.
	"wolf":            {"follower": "wolf",           "min": 2, "max": 4},
	"warg":            {"follower": "wolf",           "min": 2, "max": 4},
	"yak":             {"follower": "yak",            "min": 2, "max": 4},
	"hell_hound":      {"follower": "hell_hound",     "min": 1, "max": 3},
	"bear":            {"follower": "bear",           "min": 1, "max": 2},
	"adder":           {"follower": "adder",          "min": 1, "max": 2},
	"elephant":        {"follower": "elephant",       "min": 1, "max": 2},
	"hippogriff":      {"follower": "hippogriff",     "min": 1, "max": 3},
	# --- Snake / Spider sub-branch flavour (fang / spinneret packs) ---
	"black_mamba":     {"follower": "adder",          "min": 1, "max": 3},
	"anaconda":        {"follower": "black_mamba",    "min": 1, "max": 2},
	"spider":          {"follower": "spider",         "min": 1, "max": 3},
	"redback":         {"follower": "redback",        "min": 1, "max": 2},
	# --- Elven Halls faction packs (DCSS Elf spawns knights + mages) ---
	"deep_elf_archer":    {"follower": "deep_elf_fighter", "min": 2, "max": 4},
	"deep_elf_knight":    {"follower": "deep_elf_fighter", "min": 2, "max": 4},
	"deep_elf_priest":    {"follower": "deep_elf_fighter", "min": 2, "max": 4},
	"deep_elf_mage":      {"follower": "deep_elf_knight",  "min": 1, "max": 3},
	"deep_elf_sorcerer":  {"follower": "deep_elf_mage",    "min": 2, "max": 4},
	"deep_elf_demonologist": {"follower": "deep_elf_mage", "min": 2, "max": 4},
	# --- Vaults guards + Crypt undead packs ---
	"vault_guard":      {"follower": "vault_guard",    "min": 1, "max": 3},
	"vault_warden":     {"follower": "vault_guard",    "min": 2, "max": 4},
	"vault_sentinel":   {"follower": "vault_guard",    "min": 1, "max": 2},
	"skeletal_warrior": {"follower": "skeleton",       "min": 1, "max": 3},
	"mummy":            {"follower": "zombie",         "min": 1, "max": 3},
	"wraith":           {"follower": "wight",          "min": 1, "max": 2},
	# --- Slime Pits jelly sprawls ---
	"jelly":            {"follower": "jelly",          "min": 1, "max": 3},
	"acid_blob":        {"follower": "jelly",          "min": 1, "max": 2},
}


## DCSS dungeon.cc _mon_die_size (per-depth table). Spawn count is
## `roll_dice(3, die)` capped at MAX_COUNT. D:1 = 3d12 averaging ~19.5,
## which matches the canonical "20-25 monsters per floor on D:1" figure.
static func _mon_die_size(depth: int) -> int:
	match depth:
		1: return 12
		2: return 10
		3, 4: return 9
		5, 6: return 7
		7: return 6
		8, 9: return 5
		10: return 4
		11: return 5
		12, 13, 14, 15: return 6
		_: return 12

## Legacy fallback pool — used only if MonsterPopulation can't resolve any
## eligible monster (e.g. data file missing). Kept so a broken JSON never
## leaves us with empty floors.
const _FALLBACK_REGULARS: Dictionary = {
	"main":    ["rat", "bat", "goblin", "kobold", "jackal", "hobgoblin"],
	"mine":    ["hobgoblin", "kobold", "gnoll", "orc", "orc_warrior"],
	"forest":  ["jackal", "adder", "ball_python", "boggart"],
	"swamp":   ["adder", "boggart", "bog_body", "alligator"],
	"volcano": ["hell_hound", "fire_sprite", "ghoul", "orc_warrior"],
}

## Boss-floor (depth % 5 == 0) → boss id. One named monster per segment.
const _BOSSES: Dictionary = {
	5:  "ogre",
	10: "orc_knight",
	15: "dryad",
	20: "swamp_dragon",
	25: "fire_dragon",
}


static func spawn_for_depth(depth: int, gen: DungeonGenerator, container: Node) -> Array[Monster]:
	var result: Array[Monster] = []
	if gen == null or container == null:
		return result
	var scene: PackedScene = load(MONSTER_SCENE_PATH)
	if scene == null:
		push_error("MonsterSpawner: failed to load Monster.tscn")
		return result

	var branch: String = _branch_for(depth)
	var floor_tiles: Array[Vector2i] = _collect_floor_tiles(gen)
	if floor_tiles.is_empty():
		return result
	floor_tiles.shuffle()

	var used: Dictionary = {}
	used[gen.spawn_pos] = true
	var spawn_rng := RandomNumberGenerator.new()
	spawn_rng.randomize()

	# Boss floor: place 1 boss in the stairs-down room first, then half the
	# usual regulars so the floor doesn't feel emptier than a normal one.
	var is_boss_floor: bool = _BOSSES.has(depth)
	var boss_data: MonsterData = null
	if is_boss_floor:
		boss_data = _load_monster(String(_BOSSES[depth]))
	if boss_data != null:
		var boss_tile: Vector2i = _pick_boss_tile(gen, used, floor_tiles)
		if boss_tile != Vector2i(-1, -1):
			used[boss_tile] = true
			var b: Monster = scene.instantiate()
			container.add_child(b)
			b.setup(gen, boss_tile, boss_data)
			result.append(b)

	# DCSS _num_mons_wanted: 3d(_mon_die_size(depth)) capped at 60.
	var die: int = _mon_die_size(depth)
	var base_count: int = spawn_rng.randi_range(1, die) \
			+ spawn_rng.randi_range(1, die) \
			+ spawn_rng.randi_range(1, die)
	base_count = min(base_count, MAX_COUNT)
	# Boss floors get half the regulars so the boss doesn't get drowned out.
	if is_boss_floor:
		base_count = clamp(base_count / 2, 5, MAX_COUNT)
	var count: int = base_count

	var spawned: int = 0
	var null_picks: int = 0
	for tile in floor_tiles:
		if spawned >= count:
			break
		if used.has(tile):
			continue
		used[tile] = true
		var data: MonsterData = _pick_monster(branch, depth, spawn_rng)
		if data == null:
			null_picks += 1
			continue
		var m: Monster = scene.instantiate()
		container.add_child(m)
		m.setup(gen, tile, data)
		result.append(m)
		spawned += _spawn_band_for(data, tile, gen, container, floor_tiles,
				used, scene, result, spawn_rng)
		spawned += 1
	print("[MonsterSpawner] depth=%d branch=%s want=%d spawned=%d null_picks=%d floor_tiles=%d" \
			% [depth, branch, count, spawned, null_picks, floor_tiles.size()])
	return result


## DCSS population → MonsterRegistry. If the weighted pick lands on an id
## we don't have data for (common — DCSS has 667 monsters), retry a few
## times before falling back to the hand-curated per-branch list.
static func _pick_monster(branch: String, depth: int, rng: RandomNumberGenerator) -> MonsterData:
	# DCSS pop tables are branch-local (Lair runs 1..6, Dungeon 1..27). Our
	# 5-per-branch layout maps depth 11 to forest:1, depth 12 to forest:2, etc.
	var local_depth: int = MonsterPopulation.branch_local_depth(depth)
	for _i in 10:
		var id: String = MonsterPopulation.pick(branch, local_depth, rng)
		if id == "":
			break
		var d: MonsterData = MonsterRegistry.fetch(id)
		if d != null:
			return d
	# Fallback: hand-curated pool for this branch.
	var fb: Array = _FALLBACK_REGULARS.get(branch, ["rat", "goblin"])
	for _i in 5:
		var id2: String = String(fb[rng.randi() % fb.size()])
		var d2: MonsterData = MonsterRegistry.fetch(id2)
		if d2 != null:
			return d2
	return null


static func _load_monster(id: String) -> MonsterData:
	# MonsterRegistry checks .tres overrides first, then falls back to the
	# DCSS JSON. Missing ids return null with a warning.
	return MonsterRegistry.fetch(id)


## Spawn a pack of followers around a just-placed leader, reading the
## `_BANDS` table. Returns the number of extra monsters placed so the
## outer spawn loop can count them against the floor cap.
static func _spawn_band_for(leader: MonsterData, leader_tile: Vector2i,
		gen: DungeonGenerator, container: Node, floor_tiles: Array,
		used: Dictionary, scene: PackedScene, result: Array[Monster],
		rng: RandomNumberGenerator) -> int:
	if leader == null or leader.id == "":
		return 0
	var band: Dictionary = _BANDS.get(String(leader.id), {})
	if band.is_empty():
		return 0
	var follower_id: String = String(band.get("follower", ""))
	if follower_id == "":
		return 0
	var follower_data: MonsterData = _load_monster(follower_id)
	if follower_data == null:
		return 0
	var lo: int = int(band.get("min", 1))
	var hi: int = int(band.get("max", 2))
	var want: int = rng.randi_range(lo, hi)
	var placed: int = 0
	# Search outward from leader_tile in Chebyshev rings for walkable
	# unoccupied floor. Cap the scan so a packed floor doesn't spin.
	for tile in _nearby_free_tiles(leader_tile, floor_tiles, used, 5):
		if placed >= want:
			break
		used[tile] = true
		var f: Monster = scene.instantiate()
		container.add_child(f)
		f.setup(gen, tile, follower_data)
		result.append(f)
		placed += 1
	return placed


## Candidate free tiles in Chebyshev rings 1..`radius` from `center`,
## filtered by `floor_tiles` membership and `used` set. Returned in ring
## order so followers cluster near the leader.
static func _nearby_free_tiles(center: Vector2i, floor_tiles: Array,
		used: Dictionary, radius: int) -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	for r in range(1, radius + 1):
		for dy in range(-r, r + 1):
			for dx in range(-r, r + 1):
				if max(abs(dx), abs(dy)) != r:
					continue
				var p: Vector2i = center + Vector2i(dx, dy)
				if seen.has(p):
					continue
				seen[p] = true
				if used.has(p):
					continue
				if floor_tiles.has(p):
					out.append(p)
	return out


## Boss prefers the room around the stairs-down tile (the player's eventual
## destination), so the encounter feels intentional rather than random.
static func _pick_boss_tile(gen: DungeonGenerator, used: Dictionary, fallback: Array[Vector2i]) -> Vector2i:
	var target: Vector2i = gen.stairs_down_pos
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var p: Vector2i = target + Vector2i(dx, dy)
			if p == target:
				continue
			if used.has(p):
				continue
			if gen.get_tile(p) == DungeonGenerator.TileType.FLOOR:
				return p
	for tile in fallback:
		if not used.has(tile):
			return tile
	return Vector2i(-1, -1)


static func _branch_for(d: int) -> String:
	# When the player is inside a real DCSS branch (Lair/Orc/Vaults/…),
	# spawn from that branch's pool directly. Otherwise fall back to the
	# legacy depth-bucketed rotation used on the main trunk.
	var mgr: Node = null
	if Engine.get_main_loop() != null:
		mgr = Engine.get_main_loop().root.get_node_or_null("GameManager")
	if mgr != null and "current_branch" in mgr:
		var cb = mgr.current_branch
		if typeof(cb) == TYPE_STRING and String(cb) != "" and String(cb) != "dungeon":
			return String(cb)
	if d <= 5:
		return "main"
	if d <= 10:
		return "mine"
	if d <= 15:
		return "forest"
	if d <= 20:
		return "swamp"
	return "volcano"


static func _collect_floor_tiles(gen: DungeonGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var p: Vector2i = Vector2i(x, y)
			if gen.get_tile(p) == DungeonGenerator.TileType.FLOOR:
				out.append(p)
	return out
