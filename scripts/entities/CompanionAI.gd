class_name CompanionAI
## AI for player allies. Target monsters, never the player.

const FOLLOW_RADIUS: int = 4  # step toward player when farther than this


static func act(c: Companion) -> void:
	if not c.is_alive:
		return
	var target: Node = _find_nearest_monster(c)
	if target != null:
		var dist: int = _cheb(c.grid_pos, target.grid_pos)
		if dist <= 1:
			_melee(c, target)
			return
		_step_toward(c, target.grid_pos)
		return
	# No enemy in sight — follow the player if they've wandered far.
	var player: Node = _get_player(c)
	if player != null and "grid_pos" in player:
		var pdist: int = _cheb(c.grid_pos, player.grid_pos)
		if pdist > FOLLOW_RADIUS:
			_step_toward(c, player.grid_pos)
			return
	# Otherwise idle in place — no wander.


static func _get_player(c: Companion) -> Node:
	return c.get_tree().get_first_node_in_group("player")


static func _find_nearest_monster(c: Companion) -> Monster:
	var best: Monster = null
	var best_d: int = 999999
	for m in c.get_tree().get_nodes_in_group("monsters"):
		if not is_instance_valid(m) or not m.is_alive:
			continue
		if not (m is Monster) or not ("grid_pos" in m):
			continue
		var d: int = _cheb(c.grid_pos, m.grid_pos)
		if d < best_d and d <= c.sight_range:
			best_d = d
			best = m
	return best


static func _melee(c: Companion, target: Monster) -> void:
	# Simple damage formula: base_atk = str/2 + 3 (matches monster formula).
	var base_atk: int = int(c.data.str) / 2 + 3 if c.data != null else 4
	var def_ac: int = target.ac if target != null else 0
	var dmg: int = max(1, base_atk - def_ac + randi_range(-2, 2))
	target.take_damage(dmg)


static func _step_toward(c: Companion, target_pos: Vector2i) -> void:
	var dx: int = sign(target_pos.x - c.grid_pos.x)
	var dy: int = sign(target_pos.y - c.grid_pos.y)
	var candidates: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		candidates.append(Vector2i(dx, dy))
	if dx != 0:
		candidates.append(Vector2i(dx, 0))
	if dy != 0:
		candidates.append(Vector2i(0, dy))
	for delta in candidates:
		var nxt: Vector2i = c.grid_pos + delta
		if _can_enter(c, nxt):
			c.move_to_grid(nxt)
			return


static func _can_enter(c: Companion, pos: Vector2i) -> bool:
	if c.generator == null or not c.generator.is_walkable(pos):
		return false
	# Blocked by monsters, player, or other companions.
	var tree: SceneTree = c.get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return false
	for n in tree.get_nodes_in_group("companions"):
		if n == c:
			continue
		if n is Companion and n.grid_pos == pos:
			return false
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and "grid_pos" in player and player.grid_pos == pos:
		return false
	return true


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
