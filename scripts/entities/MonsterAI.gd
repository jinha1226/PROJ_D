class_name MonsterAI

## Greedy 8-directional AI for M1. No A*.

static func act(m: Monster) -> void:
	if not m.is_alive:
		return
	# Poison DoT — ticked at the start of the monster's turn so the damage
	# hits before it gets to swing. Scroll of Poison / Alchemist spells
	# stash `_poison_turns` + `_poison_dmg` on the target.
	if m.has_meta("_poison_turns"):
		var pt: int = int(m.get_meta("_poison_turns", 0))
		if pt > 0:
			m.take_damage(int(m.get_meta("_poison_dmg", 2)))
			m.set_meta("_poison_turns", pt - 1)
			if pt <= 1:
				m.remove_meta("_poison_turns")
				m.remove_meta("_poison_dmg")
			if not m.is_alive:
				return
	# DCSS BEH_SLEEP handling. A sleeping monster first checks whether the
	# player (or a companion) is in its sight line; if so it wakes and
	# skips its first turn (DCSS charges a full-turn wake-up latency).
	# Otherwise it just idles — sleeping monsters do not wander.
	if m.is_sleeping:
		if _should_wake(m):
			wake(m)
		return
	# Paralysis (wand of paralysis, spells) — skip every turn and count
	# down until the hex wears off. Paralysed monsters can't even flee.
	if m.has_meta("_paralysis_turns"):
		var pt: int = int(m.get_meta("_paralysis_turns", 0))
		if pt > 0:
			m.set_meta("_paralysis_turns", pt - 1)
			if pt <= 1:
				m.remove_meta("_paralysis_turns")
			return
	# Rooted — same frame as paralysis for action economy, but the monster
	# can still strike adjacent targets (rooted ≠ helpless).
	var rooted: bool = false
	if m.has_meta("_rooted_turns"):
		var rt: int = int(m.get_meta("_rooted_turns", 0))
		if rt > 0:
			rooted = true
			m.set_meta("_rooted_turns", rt - 1)
			if rt <= 1:
				m.remove_meta("_rooted_turns")
	# Slow hex: skip this turn and count down.
	if m.slowed_turns > 0:
		m.slowed_turns -= 1
		return
	# Fear: flee from the nearest hostile.
	if m.has_meta("_flee_turns"):
		var ft: int = int(m.get_meta("_flee_turns", 0))
		if ft > 0:
			m.set_meta("_flee_turns", ft - 1)
			if ft <= 1:
				m.remove_meta("_flee_turns")
			var flee_from: Node = _nearest_hostile(m)
			if flee_from != null:
				_step_away_from(m, flee_from.grid_pos)
			return
		else:
			m.remove_meta("_flee_turns")
	# Vulnerability countdown.
	if m.has_meta("_vuln_turns"):
		var vt: int = int(m.get_meta("_vuln_turns", 0))
		if vt <= 1:
			m.remove_meta("_vuln_turns")
		else:
			m.set_meta("_vuln_turns", vt - 1)
	# Choose the nearest hostile (player OR companion). Companions count as
	# enemies to monsters, so a monster next to a summoned skeleton will
	# whack the skeleton instead of running past it toward the player.
	var target: Node = _nearest_hostile(m)
	if target == null:
		if not rooted:
			_maybe_wander(m)
		return
	if "is_alive" in target and not target.is_alive:
		return
	var ppos: Vector2i = target.grid_pos
	var dist: int = _cheb(m.grid_pos, ppos)
	# Keep the local `player` reference for the melee path below.
	var player: Node = target

	if dist <= 1:
		m.attack_animation_toward(ppos)
		# Companions use the same damage shape (take_damage + ac) as monsters,
		# so melee_attack_from_monster works for either target.
		CombatSystem.melee_attack_from_monster(m, player)
		return

	# Rooted: can't walk toward the target this turn. Just idle.
	if rooted:
		return

	if dist <= m.sight_range:
		_step_toward(m, ppos)
		return

	_maybe_wander(m)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## Wake a sleeping monster and propagate the alarm to adjacent sleepers.
## Called from MonsterAI.act() on LOS, and from Monster.take_damage() on
## hit — a monster woken by damage skips no turn (it reacts immediately).
static func wake(m: Monster) -> void:
	if m == null or not m.is_sleeping:
		return
	m.is_sleeping = false
	m.queue_redraw()
	# Alarm adjacent sleepers (DCSS: noise propagates, we approximate with a
	# 1-tile chain so a square of sleeping kobolds wakes together when one
	# spots the player). Only one ring — avoids map-wide instant wake chains.
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return
	for n in tree.get_nodes_in_group("monsters"):
		if n == m or not (n is Monster) or not n.is_alive:
			continue
		if not n.is_sleeping:
			continue
		if _cheb(n.grid_pos, m.grid_pos) <= 1:
			n.is_sleeping = false
			n.queue_redraw()


static func _should_wake(m: Monster) -> bool:
	# If the player's FOV includes this monster's tile, sight is bidirectional
	# in our game — the monster sees the player too.
	if m.generator == null:
		return false
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return false
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and "grid_pos" in player and "is_alive" in player and player.is_alive:
		# Invisibility (potion, spell) hides the player from sight-based wake
		# checks. DCSS also allows monsters to see invisible via special sight,
		# but until we model resists fall back to blanket hiding.
		var invis: bool = player.has_method("has_meta") and player.has_meta("_invisible_turns")
		if not invis \
				and _cheb(m.grid_pos, player.grid_pos) <= m.sight_range \
				and _monster_has_fov_to(m, player.grid_pos):
			return true
	# Companions are also hostile targets and break stealth.
	for c in tree.get_nodes_in_group("companions"):
		if c is Companion and c.is_alive and "grid_pos" in c:
			if _cheb(m.grid_pos, c.grid_pos) <= m.sight_range \
					and _monster_has_fov_to(m, c.grid_pos):
				return true
	return false


## Cheap LOS approximation: the player-side FOV already knows which tiles
## are visible from the player's position. Under symmetric LOS, if the
## player can see this monster's tile, the monster can see the player —
## so we just ask dmap whether m.grid_pos is currently visible.
static func _monster_has_fov_to(m: Monster, _target: Vector2i) -> bool:
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return false
	var dmap: Node = tree.get_first_node_in_group("dmap")
	if dmap == null:
		# Fallback if the scene hasn't registered a DungeonMap yet.
		return true
	if dmap.has_method("is_tile_visible"):
		return dmap.is_tile_visible(m.grid_pos)
	return true


## Pick the nearest hostile — player or any companion. Monsters treat both
## as enemies.
static func _nearest_hostile(m: Monster) -> Node:
	var best: Node = null
	var best_d: int = 999999
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return null
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and "grid_pos" in player and "is_alive" in player and player.is_alive:
		var pd: int = _cheb(m.grid_pos, player.grid_pos)
		if pd < best_d:
			best_d = pd
			best = player
	for c in tree.get_nodes_in_group("companions"):
		if c is Companion and c.is_alive and "grid_pos" in c:
			var cd: int = _cheb(m.grid_pos, c.grid_pos)
			if cd < best_d:
				best_d = cd
				best = c
	return best


static func _tile_occupied(pos: Vector2i, self_ref: Monster) -> bool:
	var tree: SceneTree = self_ref.get_tree()
	if tree == null:
		return false
	for n in tree.get_nodes_in_group("monsters"):
		if n == self_ref:
			continue
		if n is Monster and n.grid_pos == pos:
			return true
	for n in tree.get_nodes_in_group("companions"):
		if n is Companion and n.grid_pos == pos:
			return true
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and "grid_pos" in player and player.grid_pos == pos:
		return true
	return false


static func _can_enter(m: Monster, pos: Vector2i, allow_player_tile: bool = false) -> bool:
	if m.generator == null:
		return false
	if not m.generator.is_walkable(pos):
		return false
	if allow_player_tile:
		# only block on other monsters
		var tree: SceneTree = m.get_tree()
		if tree != null:
			for n in tree.get_nodes_in_group("monsters"):
				if n == m:
					continue
				if n is Monster and n.grid_pos == pos:
					return false
		return true
	return not _tile_occupied(pos, m)


static func _step_toward(m: Monster, target: Vector2i) -> void:
	var dx: int = sign(target.x - m.grid_pos.x)
	var dy: int = sign(target.y - m.grid_pos.y)
	var candidates: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		candidates.append(Vector2i(dx, dy))
	if dx != 0:
		candidates.append(Vector2i(dx, 0))
	if dy != 0:
		candidates.append(Vector2i(0, dy))
	# Fallbacks: perpendicular axis
	if dx == 0:
		candidates.append(Vector2i(1, 0))
		candidates.append(Vector2i(-1, 0))
	if dy == 0:
		candidates.append(Vector2i(0, 1))
		candidates.append(Vector2i(0, -1))
	for delta in candidates:
		var nxt: Vector2i = m.grid_pos + delta
		if _can_enter(m, nxt):
			_move_to(m, nxt)
			return


static func _step_away_from(m: Monster, threat: Vector2i) -> void:
	var dx: int = sign(m.grid_pos.x - threat.x)
	var dy: int = sign(m.grid_pos.y - threat.y)
	var candidates: Array[Vector2i] = []
	if dx != 0 and dy != 0:
		candidates.append(Vector2i(dx, dy))
	if dx != 0:
		candidates.append(Vector2i(dx, 0))
	if dy != 0:
		candidates.append(Vector2i(0, dy))
	# Perpendicular fallbacks
	candidates.append(Vector2i(-dy, dx))
	candidates.append(Vector2i(dy, -dx))
	for delta in candidates:
		var nxt: Vector2i = m.grid_pos + delta
		if _can_enter(m, nxt):
			_move_to(m, nxt)
			return
	_maybe_wander(m)


static func _maybe_wander(m: Monster) -> void:
	if randf() >= 0.5:
		return
	var dirs: Array = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
	]
	dirs.shuffle()
	for d in dirs:
		var nxt: Vector2i = m.grid_pos + d
		if _can_enter(m, nxt):
			_move_to(m, nxt)
			return


static func _move_to(m: Monster, pos: Vector2i) -> void:
	m.move_to_grid(pos)
