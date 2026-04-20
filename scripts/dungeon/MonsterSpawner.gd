class_name MonsterSpawner

const MONSTER_SCENE_PATH: String = "res://scenes/entities/Monster.tscn"
const MAX_COUNT: int = 14

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

	# Boss floors also get a handful of normal regulars as guards.
	var base_count: int = clamp(3 + depth, 5, MAX_COUNT)
	if is_boss_floor:
		base_count = clamp(base_count / 2, 2, 5)
	var count: int = base_count

	var spawned: int = 0
	for tile in floor_tiles:
		if spawned >= count:
			break
		if used.has(tile):
			continue
		used[tile] = true
		var data: MonsterData = _pick_monster(branch, depth, spawn_rng)
		if data == null:
			continue
		var m: Monster = scene.instantiate()
		container.add_child(m)
		m.setup(gen, tile, data)
		result.append(m)
		spawned += 1
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
