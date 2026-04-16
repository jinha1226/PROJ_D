class_name MonsterSpawner

const MONSTER_SCENE_PATH: String = "res://scenes/entities/Monster.tscn"
const MAX_COUNT: int = 12


static func spawn_for_depth(depth: int, gen: DungeonGenerator, container: Node) -> Array[Monster]:
	var result: Array[Monster] = []
	if gen == null or container == null:
		return result
	var scene: PackedScene = load(MONSTER_SCENE_PATH)
	if scene == null:
		push_error("MonsterSpawner: failed to load Monster.tscn")
		return result

	var pool: Array[MonsterData] = _load_pool(depth)
	if pool.is_empty():
		return result

	var count: int = min(MAX_COUNT, 4 + depth * 2)
	var floor_tiles: Array[Vector2i] = _collect_floor_tiles(gen)
	if floor_tiles.is_empty():
		return result
	floor_tiles.shuffle()

	var used: Dictionary = {}
	used[gen.spawn_pos] = true

	var spawned: int = 0
	for tile in floor_tiles:
		if spawned >= count:
			break
		if used.has(tile):
			continue
		used[tile] = true
		var data: MonsterData = pool[randi() % pool.size()]
		var m: Monster = scene.instantiate()
		container.add_child(m)
		m.setup(gen, tile, data)
		result.append(m)
		spawned += 1
	return result


static func _load_pool(depth: int) -> Array[MonsterData]:
	var pool: Array[MonsterData] = []
	var rat: Resource = load("res://resources/monsters/rat.tres")
	var goblin: Resource = load("res://resources/monsters/goblin.tres")
	if rat != null:
		pool.append(rat)
	if goblin != null:
		pool.append(goblin)
	if depth >= 4:
		var orc: Resource = load("res://resources/monsters/orc.tres")
		if orc != null:
			pool.append(orc)
	return pool


static func _collect_floor_tiles(gen: DungeonGenerator) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var p: Vector2i = Vector2i(x, y)
			if gen.get_tile(p) == DungeonGenerator.TileType.FLOOR:
				out.append(p)
	return out
