class_name MonsterAI extends RefCounted

## Minimal AI per guide §4.9. Monster.take_turn() delegates here.
## Per-turn decision: adjacent → attack; player in FOV → step toward;
## else → 50% idle / 50% random step.

static func take_turn(monster: Monster, map: DungeonMap) -> void:
	var player: Player = _find_player()
	if player == null or player.hp <= 0:
		return
	var dist: int = _chebyshev(monster.grid_pos, player.grid_pos)
	if dist == 1:
		CombatSystem.monster_attack_player(monster, player)
		return
	if _can_see(monster, map, player.grid_pos):
		_step_toward(monster, map, player.grid_pos)
	else:
		_random_step(monster, map)

static func _find_player() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("player"):
		if n is Player:
			return n
	return null

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

static func _can_see(monster: Monster, map: DungeonMap, target: Vector2i) -> bool:
	var radius: int = monster.data.sight_range
	if _chebyshev(monster.grid_pos, target) > radius:
		return false
	var is_opaque := func(p: Vector2i) -> bool: return map.is_opaque(p)
	var vis: Dictionary = FieldOfView.compute(monster.grid_pos, radius, is_opaque)
	return vis.has(target)

static func _step_toward(monster: Monster, map: DungeonMap, target: Vector2i) -> void:
	var dx: int = sign(target.x - monster.grid_pos.x)
	var dy: int = sign(target.y - monster.grid_pos.y)
	var options: Array = [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]
	for opt in options:
		if opt == Vector2i.ZERO:
			continue
		var next: Vector2i = monster.grid_pos + opt
		if map.is_walkable(next) and not _occupied(next, monster):
			monster.try_move(opt)
			return

static func _random_step(monster: Monster, map: DungeonMap) -> void:
	if randf() > 0.5:
		return
	var dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()
	for d in dirs:
		var next: Vector2i = monster.grid_pos + d
		if map.is_walkable(next) and not _occupied(next, monster):
			monster.try_move(d)
			return

static func _occupied(pos: Vector2i, self_monster: Monster) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	# Player blocks
	for n in tree.get_nodes_in_group("player"):
		if n is Player and n.grid_pos == pos:
			return true
	for n in tree.get_nodes_in_group("monsters"):
		if n == self_monster:
			continue
		if n is Monster and n.grid_pos == pos:
			return true
	return false
