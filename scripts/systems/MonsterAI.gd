class_name MonsterAI extends RefCounted

## Monster AI: adjacent → attack; player in FOV → step toward + update
## last_known_player_pos; alerted but no LOS → chase last known position;
## idle → random step.

static func take_turn(monster: Monster, map: DungeonMap) -> void:
	var player: Player = _find_player()
	if player == null or player.hp <= 0:
		return
	if Status.will_skip_turn(monster):
		return
	if Status.has(player, "time_stopped"):
		return
	if Status.has(player, "hasted") and randf() < 0.5:
		return
	if Status.is_fleeing(monster):
		_flee_step(monster, map, player.grid_pos)
		return
	var confusion: float = Status.confusion_chance(monster)
	if confusion > 0.0 and randf() < confusion:
		_random_step(monster, map)
		return
	var dist: int = _chebyshev(monster.grid_pos, player.grid_pos)
	if dist == 1:
		CombatSystem.monster_attack_player(monster, player)
		return
	if _can_see(monster, map, player.grid_pos):
		monster.last_known_player_pos = player.grid_pos
		monster.is_alerted = true
		if _try_ranged(monster, player, dist):
			return
		_step_toward(monster, map, player.grid_pos)
	elif monster.is_alerted and monster.last_known_player_pos != Vector2i(-1, -1):
		# Chase the last known position. Clear alert once we reach it.
		var chase_dist: int = _chebyshev(monster.grid_pos, monster.last_known_player_pos)
		if chase_dist <= 1:
			monster.is_alerted = false
			monster.last_known_player_pos = Vector2i(-1, -1)
		else:
			_step_toward(monster, map, monster.last_known_player_pos)
	else:
		_random_step(monster, map)

static func _flee_step(monster: Monster, map: DungeonMap,
		threat: Vector2i) -> void:
	# Step toward the tile that maximises chebyshev distance to threat.
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = _chebyshev(monster.grid_pos, threat)
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var opt := Vector2i(ddx, ddy)
			var next: Vector2i = monster.grid_pos + opt
			if not map.is_walkable(next) or _occupied(next, monster):
				continue
			var d: int = _chebyshev(next, threat)
			if d > best_d:
				best = opt
				best_d = d
	if best != Vector2i.ZERO:
		monster.try_move(best)

static func _try_ranged(monster: Monster, player: Player, dist: int) -> bool:
	var ra: Dictionary = monster.data.ranged_attack
	if ra.is_empty():
		return false
	var max_range: int = int(ra.get("range", 6))
	if dist > max_range:
		return false
	CombatSystem.monster_ranged_attack_player(monster, player, ra)
	return true

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
	var tried: Array = []
	for opt in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if opt == Vector2i.ZERO or tried.has(opt):
			continue
		tried.append(opt)
		var next: Vector2i = monster.grid_pos + opt
		if map.is_walkable(next) and not _occupied(next, monster):
			monster.try_move(opt)
			return
	# Fallback: any 8-dir neighbor that doesn't increase chebyshev
	# distance to the target. Keeps chasers pushing through a blocked
	# cardinal step instead of idling for a turn.
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = _chebyshev(monster.grid_pos, target)
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var opt := Vector2i(ddx, ddy)
			if tried.has(opt):
				continue
			var next: Vector2i = monster.grid_pos + opt
			if not map.is_walkable(next):
				continue
			if _occupied(next, monster):
				continue
			var d: int = _chebyshev(next, target)
			if d < best_d:
				best = opt
				best_d = d
	if best != Vector2i.ZERO:
		monster.try_move(best)

static func _random_step(monster: Monster, map: DungeonMap) -> void:
	# Was 50% idle — felt too slack. 20% idle keeps wandering enemies
	# closing on the player more often without turning it into a full
	# chase while they're out of sight.
	if randf() < 0.2:
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
