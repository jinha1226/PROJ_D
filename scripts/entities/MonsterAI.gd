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
		# DCSS caster monsters may throw a spell instead of closing. Roll
		# against the combined frequency of their spellbook; each row fires
		# at `freq` / 200 chance per turn (freq 15 ≈ 7.5%/turn), matching
		# the look of DCSS mon-cast.cc handle_mon_spell pacing.
		if _try_cast_at(m, target):
			return
		_step_toward(m, ppos)
		return

	_maybe_wander(m)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


const _MONSTER_SPELLBOOKS_JSON: String = "res://assets/dcss_mons/spellbooks.json"
static var _mon_spellbooks: Dictionary = {}
static var _mon_spellbooks_loaded: bool = false


## DCSS mon-spell.h spellbooks, loaded lazily. Structure:
##   { book_id: [{spell, freq, flags}, ...] }
## Book id matches `MonsterData.spells_book` which comes from
## `dat/mons/*.yaml` `spells:` field.
static func _ensure_spellbooks_loaded() -> void:
	if _mon_spellbooks_loaded:
		return
	_mon_spellbooks_loaded = true
	var f := FileAccess.open(_MONSTER_SPELLBOOKS_JSON, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) == TYPE_DICTIONARY:
		_mon_spellbooks = parsed


## DCSS handle_mon_spell: each spell has a frequency 1..100 and each turn
## the monster rolls 1d200 — if under freq, it casts. We keep the same
## shape so caster monsters cast about 5-10% of their turns instead of
## whacking with melee.
static func _try_cast_at(m: Monster, target: Node) -> bool:
	if m == null or m.data == null:
		return false
	var book: String = String(m.data.spells_book)
	if book == "":
		return false
	_ensure_spellbooks_loaded()
	var rows: Array = _mon_spellbooks.get(book, [])
	if rows.is_empty():
		return false
	# Silence zone around the target: DCSS suppresses wizard/priest casts.
	if target != null and "has_meta" in target and target.has_method("has_meta") \
			and target.has_meta("_silenced_turns"):
		return false
	# Pick a spell weighted by freq. Total weight also gates whether we cast
	# at all: a book summing to 60 weight casts 60/200 = 30% of turns.
	var total_w: int = 0
	for row in rows:
		total_w += int(row.get("freq", 0))
	if total_w <= 0:
		return false
	if randi() % 200 >= total_w:
		return false
	var roll: int = randi() % total_w
	var acc: int = 0
	var picked: Dictionary = {}
	for row in rows:
		acc += int(row.get("freq", 0))
		if roll < acc:
			picked = row
			break
	if picked.is_empty():
		return false
	return _apply_mon_spell(m, target, String(picked.get("spell", "")))


## Apply a cast spell from monster `m` onto `target`. We key off the
## damage zap data in SpellRegistry — if the spell has a zap, roll it at
## the monster's HD-scaled power; otherwise branch on a small table of
## non-damage effects. Returns true on a successful cast.
static func _apply_mon_spell(m: Monster, target: Node, spell_id: String) -> bool:
	if spell_id == "" or target == null:
		return false
	# Monster spell power scales with HD, roughly DCSS mons_power = HD * 12.
	var hd: int = int(m.data.hd if m.data else 1)
	var power: int = max(12, hd * 12)
	# Direct-damage zaps go through SpellRegistry.roll_damage.
	var dmg: int = SpellRegistry.roll_damage(spell_id, power)
	if dmg >= 0:
		if target.has_method("take_damage"):
			target.take_damage(dmg)
			var mname: String = m.data.display_name if m.data else "monster"
			CombatLog.add("The %s casts %s for %d damage!" % [
					mname, spell_id.replace("_", " "), dmg])
		return true
	# Non-damage spells: hex / heal-other / summon / invisibility. Minimum
	# viable coverage so priests and wizards feel like DCSS rather than
	# standing silent. Anything not matched here silently fails — caller
	# still returns true so the monster spends a turn on the attempt.
	match spell_id:
		"confuse":
			if target.has_method("set_meta"):
				target.set_meta("_confused", true)
				var ct: int = 4 + int(hd / 4)
				target.set_meta("_confusion_turns", ct)
			CombatLog.add("The %s confuses you!" % (m.data.display_name if m.data else "caster"))
			return true
		"paralyse":
			if target.has_method("set_meta"):
				target.set_meta("_paralysis_turns", 2 + int(hd / 6))
			CombatLog.add("The %s paralyses you!" % (m.data.display_name if m.data else "caster"))
			return true
		"invisibility":
			if m.has_method("set_meta"):
				m.set_meta("_invisible_turns", 20)
			return true
		"haste_other":
			# Monster hastes itself. We stash a meta the MonsterAI doesn't
			# yet honour, so the effect is purely narrative for now.
			return true
		"heal_other", "minor_healing", "major_healing":
			m.hp = min(m.hp + randi_range(5, 15), m.data.hp if m.data else m.hp)
			return true
		"cantrip", "smiting":
			# Smiting ignores armour: fixed 7-17 damage.
			if target.has_method("take_damage"):
				target.take_damage(randi_range(7, 17))
			return true
		"pain":
			if target.has_method("take_damage"):
				target.take_damage(randi_range(3, 8))
			return true
		_:
			return false


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
