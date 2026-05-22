class_name CompanionAI extends RefCounted

## Companion turn AI. Mirrors MonsterAI._take_ally_turn but operates on Companion
## nodes (which extend Actor, not Monster). Priorities:
##   1. Attack nearest visible enemy in melee range
##   2. Step toward nearest visible enemy if one exists
##   3. Follow player if no enemies visible within FOLLOW_RANGE
##   4. Stay idle if already close enough to player

const FOLLOW_RANGE: int = 3   # stop following once within this Chebyshev dist
const SIGHT_RANGE: int = 6    # companion's effective threat detection range


static func take_turn(companion, map: DungeonMap) -> void:
	if companion.hp <= 0 or map == null:
		return
	if Status.will_skip_turn(companion):
		return
	var target = _find_nearest_enemy(companion)
	if target != null:
		var dist: int = _chebyshev(companion.grid_pos, target.grid_pos)
		if dist == 1:
			_attack(companion, target)
		else:
			_step_toward(companion, map, target.grid_pos)
		return
	# No enemies — follow player if too far
	var player: Player = _find_player()
	if player != null and _chebyshev(companion.grid_pos, player.grid_pos) > FOLLOW_RANGE:
		_step_toward(companion, map, player.grid_pos)


# ── Combat ─────────────────────────────────────────────────────────────────────

static func _attack(companion, target: Monster) -> void:
	var weapon_id: String = companion.equipped_weapon_id
	var base_dmg: int = 3 + companion.xl
	if weapon_id != "" and ItemRegistry != null:
		var entry: Dictionary = ItemRegistry.generate(weapon_id)
		base_dmg = max(1, int(entry.get("damage", base_dmg)) + companion.strength / 4)
	var raw: int = randi_range(max(1, base_dmg * 3 / 5), max(1, base_dmg * 3 / 2))
	var soak: int = randi_range(0, max(0, target.data.hd / 2))
	var final_dmg: int = max(1, raw - soak)
	if CombatLog != null:
		CombatLog.post(
			companion.data.display_name + "이(가) " +
			target.data.display_name + "에게 " + str(final_dmg) + " 피해를 입혔습니다.",
			Color(0.55, 0.85, 0.55))
	target.hp -= final_dmg
	target.emit_signal("hit_taken", final_dmg)
	companion.facing = target.grid_pos - companion.grid_pos
	if companion.facing != Vector2i.ZERO:
		companion.facing = Vector2i(
			sign(companion.facing.x), sign(companion.facing.y))
	companion.queue_redraw()
	if target.hp <= 0:
		target.die()


# ── Movement ───────────────────────────────────────────────────────────────────

static func _step_toward(companion, map: DungeonMap, target_pos: Vector2i) -> void:
	var best: Vector2i = Vector2i.ZERO
	var best_dist: int = _chebyshev(companion.grid_pos, target_pos)
	for dx in [-1, 0, 1]:
		for dy in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var next: Vector2i = companion.grid_pos + Vector2i(dx, dy)
			if not map.is_walkable(next):
				continue
			if _tile_occupied(next, companion):
				continue
			var d: int = _chebyshev(next, target_pos)
			if d < best_dist:
				best_dist = d
				best = Vector2i(dx, dy)
	if best != Vector2i.ZERO:
		_do_move(companion, map, best)


static func _do_move(companion, map: DungeonMap, dir: Vector2i) -> void:
	var next: Vector2i = companion.grid_pos + dir
	companion.grid_pos = next
	companion.position = map.grid_to_world(next)
	companion.facing = dir
	companion.queue_redraw()


# ── Helpers ────────────────────────────────────────────────────────────────────

static func _find_nearest_enemy(companion) -> Monster:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Monster = null
	var best_dist: int = SIGHT_RANGE + 1
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster) or n.hp <= 0 or n.is_ally:
			continue
		var d: int = _chebyshev(companion.grid_pos, n.grid_pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best


static func _find_player() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var nodes := tree.get_nodes_in_group("player")
	if nodes.is_empty():
		return null
	return nodes[0] as Player


static func _tile_occupied(pos: Vector2i, self_companion) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("monsters"):
		if n != self_companion and (n is Monster) and (n as Monster).grid_pos == pos:
			return true
	for n in tree.get_nodes_in_group("companions"):
		if n != self_companion and n.grid_pos == pos:
			return true
	var player: Player = _find_player()
	if player != null and player.grid_pos == pos:
		return true
	return false


static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))
