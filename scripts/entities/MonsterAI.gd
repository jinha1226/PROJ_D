class_name MonsterAI

## Greedy 8-directional AI for M1. No A*.
##
## Returns the energy cost of the action taken (DCSS mon-data.h
## mon_energy_usage). Monster.take_turn decrements _action_energy by
## this value instead of a flat 10, so slow monsters (naga move=14)
## genuinely take longer per step while fast ones (bat move=5) get
## extra swings.

static func act(m: Monster) -> int:
	if not m.is_alive:
		return 10
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
				if m.has_meta("_poison_level"):
					m.remove_meta("_poison_level")
			if not m.is_alive:
				return 10
	# DCSS BEH_SLEEP handling. A sleeping monster first checks whether the
	# player (or a companion) is in its sight line; if so it wakes and
	# skips its first turn (DCSS charges a full-turn wake-up latency).
	# Otherwise it just idles — sleeping monsters do not wander.
	if m.is_sleeping:
		if _should_wake(m):
			wake(m)
		return 10
	# Paralysis (wand of paralysis, spells) — skip every turn and count
	# down until the hex wears off. Paralysed monsters can't even flee.
	if m.has_meta("_paralysis_turns"):
		var pt: int = int(m.get_meta("_paralysis_turns", 0))
		if pt > 0:
			m.set_meta("_paralysis_turns", pt - 1)
			if pt <= 1:
				m.remove_meta("_paralysis_turns")
			return 10
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
		return 10
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
			return _move_cost(m)
		else:
			m.remove_meta("_flee_turns")
	# Vulnerability countdown.
	if m.has_meta("_vuln_turns"):
		var vt: int = int(m.get_meta("_vuln_turns", 0))
		if vt <= 1:
			m.remove_meta("_vuln_turns")
		else:
			m.set_meta("_vuln_turns", vt - 1)
	# DCSS cowardice: intelligent monsters below 25% HP turn and run. Set
	# the flee meta so the existing fear path (above) handles movement; the
	# monster will re-engage once HP recovers past the threshold or the
	# counter expires.
	if _should_flee_from_low_hp(m) and not m.has_meta("_flee_turns"):
		m.set_meta("_flee_turns", 6)
		m.set_meta("_has_fled", true)
		CombatLog.add("The %s turns to flee!" % (m.data.display_name if m.data else "monster"))
		var flee_from: Node = _nearest_hostile(m)
		if flee_from != null:
			_step_away_from(m, flee_from.grid_pos)
		return _move_cost(m)
	# Choose the nearest hostile (player OR companion). Companions count as
	# enemies to monsters, so a monster next to a summoned skeleton will
	# whack the skeleton instead of running past it toward the player.
	var target: Node = _nearest_hostile(m)
	if target == null:
		if not rooted:
			_maybe_wander(m)
		return _move_cost(m)
	if "is_alive" in target and not target.is_alive:
		return 10
	var ppos: Vector2i = target.grid_pos
	var dist: int = _cheb(m.grid_pos, ppos)
	# Keep the local `player` reference for the melee path below.
	var player: Node = target

	if dist <= 1:
		# DCSS caster monsters prefer spell range over biting: if this
		# monster has a spellbook, try to cast first even when adjacent
		# (most zaps hit at any range and out-damage a single melee).
		# If casting didn't fire, kite one step away from the target so
		# the next turn opens back up — failed kiting falls through to
		# the melee swing.
		if _is_caster(m) and _try_cast_at(m, target):
			return _spell_cost(m)
		if not rooted and _is_caster(m) and _try_kite_away(m, ppos):
			return _move_cost(m)
		m.attack_animation_toward(ppos)
		# Companions use the same damage shape (take_damage + ac) as monsters,
		# so melee_attack_from_monster works for either target.
		CombatSystem.melee_attack_from_monster(m, player)
		return _attack_cost(m)

	# Rooted: can't walk toward the target this turn. Just idle.
	if rooted:
		return 10

	if dist <= m.sight_range:
		# DCSS caster monsters may throw a spell instead of closing. Roll
		# against the combined frequency of their spellbook; each row fires
		# at `freq` / 200 chance per turn (freq 15 ≈ 7.5%/turn), matching
		# the look of DCSS mon-cast.cc handle_mon_spell pacing.
		if _try_cast_at(m, target):
			return _spell_cost(m)
		# Archer / thrower monsters (data.ranged_damage > 0) lead with a
		# projectile when the target is in the weapon's range band. Melee
		# path still gets a crack next turn if the arrow missed or the
		# target closed the distance.
		if _try_ranged_at(m, target, dist):
			return _missile_cost(m)
		_step_toward(m, ppos)
		return _move_cost(m)

	_maybe_wander(m)
	return _move_cost(m)


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


## DCSS cowardice check. In actual DCSS most monsters fight to the death;
## flee is an explicit flag set by fear spells, not an automatic low-HP
## reaction. Our previous "anyone smart below 25% runs" caused packs to
## scatter constantly. Tightened to match DCSS intent:
##   - only monsters with HUMAN intel (excludes animal/plant/brainless)
##   - they must have NO ranged pressure (no spellbook, no ranged attacks)
##   - HP must be under 10% of max (was 25%)
##   - one flee window per monster per encounter; re-engage if healed back
##     past 40% (tracked via _has_fled meta)
## Casters, bosses, and packs of animals stand their ground — the user
## doesn't see a wave of retreats mid-fight anymore.
static func _should_flee_from_low_hp(m: Monster) -> bool:
	if m == null or m.data == null:
		return false
	if m.data.is_boss:
		return false
	var intel: String = String(m.data.intelligence)
	if intel != "human":
		return false
	# Casters (have a spellbook) and rangers (spear_thrower etc.) can kite;
	# they don't need to flee. Only front-liners with nothing to do at
	# range break off.
	var book_id: String = String(m.data.spells_book) if "spells_book" in m.data else ""
	if book_id != "":
		return false
	if "flags" in m.data:
		var flags_s: String = String(m.data.flags)
		if "ARCHER" in flags_s or "THROWER" in flags_s or "SPELLCASTER" in flags_s:
			return false
	var max_hp: int = int(m.data.hp) if m.data.hp > 0 else 10
	# Already fled once? Require a full heal past 40% to re-trigger.
	if m.has_meta("_has_fled"):
		if m.hp * 100 >= max_hp * 40:
			m.remove_meta("_has_fled")
		return false
	return m.hp * 10 <= max_hp  # below 10%


## DCSS mon_energy_usage readers. Each defaults to 10 if the monster
## data doesn't override — matches the DEFAULT_ENERGY macro in
## mon-data.h. Used by MonsterAI.act to return a per-action cost that
## Monster.take_turn drains from _action_energy.
static func _move_cost(m: Monster) -> int:
	if m == null or m.data == null:
		return 10
	return maxi(1, int(m.data.move_energy if "move_energy" in m.data else 10))


static func _attack_cost(m: Monster) -> int:
	if m == null or m.data == null:
		return 10
	return maxi(1, int(m.data.attack_energy if "attack_energy" in m.data else 10))


static func _spell_cost(m: Monster) -> int:
	if m == null or m.data == null:
		return 10
	return maxi(1, int(m.data.spell_energy if "spell_energy" in m.data else 10))


static func _missile_cost(m: Monster) -> int:
	if m == null or m.data == null:
		return 10
	return maxi(1, int(m.data.missile_energy if "missile_energy" in m.data else 10))


## DCSS archer path (mon-cast.cc + ranged_attack). Fires a bresenham
## arrow from the monster toward `target` if:
##   - data.ranged_damage > 0 (the monster is actually an archer)
##   - dist is ≤ data.ranged_range (weapon's useful band)
##   - no hostile-side monster blocks the lane (friendly-fire check)
## Damage rolls 1..ranged_damage with an HD/5 base bonus, then routes
## through the target's take_damage(physical). Returns true on launch.
static func _try_ranged_at(m: Monster, target: Node, dist: int) -> bool:
	if m == null or m.data == null or target == null:
		return false
	var rdmg: int = int(m.data.ranged_damage)
	if rdmg <= 0:
		return false
	var rrange: int = int(m.data.ranged_range)
	if rrange <= 0 or dist > rrange:
		return false
	# Very close — the melee branch above handles dist==1. Between 2 and
	# rrange inclusive is the archer's comfortable band.
	if dist < 2:
		return false
	# Friendly-fire: no sense clipping another orc between us and the
	# player. Reuse the beam tracer with a synthetic spell id so the
	# element-based gate treats this as a physical projectile.
	if _path_has_ally(m, target):
		return false
	# DCSS to-hit for ranged: mhit = HD*3 + 10; roll < EV miss.
	var hd: int = int(m.data.hd) if m.data.hd > 0 else 1
	var to_hit: int = 10 + hd * 3
	var target_ev: int = 0
	if "stats" in target and target.stats != null:
		target_ev = int(target.stats.EV)
	elif "data" in target and target.data != null:
		target_ev = int(target.data.ev)
	# DCSS range penalty: accuracy drops as distance grows past 2 tiles.
	var range_penalty: int = maxi(0, (dist - 2) * 3)
	var hit_roll: int = randi() % (to_hit + 1)
	var mname: String = m.data.display_name if m.data else "archer"
	if hit_roll <= target_ev + range_penalty:
		CombatLog.add("The %s fires at you but misses." % mname)
		return true
	# Damage: 1..rdmg + HD/5 flat bonus. Physical element (no resist path).
	var dmg: int = 1 + randi() % rdmg + hd / 5
	if target.has_method("take_damage"):
		target.take_damage(dmg, "physical")
		CombatLog.add("The %s shoots you for %d damage!" % [mname, dmg])
	return true


## Lightweight friendly-fire gate for physical projectiles. Same shape
## as _beam_friendly_fire but doesn't require a spell id.
static func _path_has_ally(m: Monster, target: Node) -> bool:
	if m == null or target == null:
		return false
	var from: Vector2i = m.grid_pos
	var to: Vector2i = target.grid_pos
	if from == to:
		return false
	var occupants: Dictionary = {}
	for other in m.get_tree().get_nodes_in_group("monsters"):
		if other == m or not is_instance_valid(other):
			continue
		if not (other is Monster) or not other.is_alive:
			continue
		occupants[other.grid_pos] = true
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var sx: int = 1 if dx > 0 else (-1 if dx < 0 else 0)
	var sy: int = 1 if dy > 0 else (-1 if dy < 0 else 0)
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	var x: int = from.x
	var y: int = from.y
	var err: int = adx - ady
	while Vector2i(x, y) != to:
		var e2: int = 2 * err
		if e2 > -ady:
			err -= ady
			x += sx
		if e2 < adx:
			err += adx
			y += sy
		var cell: Vector2i = Vector2i(x, y)
		if cell == to:
			break
		if occupants.has(cell):
			return true
	return false


## Is this monster a caster? A spellbook id means `_try_cast_at` may
## fire, so the AI treats the monster as preferring range over melee.
static func _is_caster(m: Monster) -> bool:
	if m == null or m.data == null:
		return false
	var book: String = String(m.data.spells_book) if "spells_book" in m.data else ""
	return book != ""


## DCSS caster kiting: step one tile away from `threat` only if the move
## actually increases the distance. Returns true if the monster moved.
## Used from the dist==1 branch so a gnoll shaman backs off instead of
## whacking with its staff.
static func _try_kite_away(m: Monster, threat: Vector2i) -> bool:
	if m == null:
		return false
	var before: Vector2i = m.grid_pos
	_step_away_from(m, threat)
	return m.grid_pos != before


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
		# Silence only stops "vocal" spells in DCSS (wizard/priest), not
		# "natural"/"breath"/"magical" ones. Filter instead of aborting.
		var filtered: Array = []
		for row in rows:
			var flags_v: Variant = row.get("flags", [])
			var is_vocal: bool = typeof(flags_v) == TYPE_ARRAY and "vocal" in flags_v
			if not is_vocal:
				filtered.append(row)
		rows = filtered
		if rows.is_empty():
			return false
	# DCSS emergency slot priority: monsters under 33% HP bias heavily
	# toward "emergency" flagged spells (heal_self / blink_self / haste_other /
	# swiftness). Non-emergency rows get their freq halved when low, and
	# emergency rows' freq is tripled — but only when low. Healthy
	# monsters never pick an emergency spell at all so a fresh gnoll
	# shaman doesn't blink away on turn 1.
	var max_hp: int = int(m.data.hp) if m.data.hp > 0 else 10
	var low_hp: bool = m.hp * 3 <= max_hp
	var effective: Array = []
	for row in rows:
		var flags_v: Variant = row.get("flags", [])
		var is_emergency: bool = typeof(flags_v) == TYPE_ARRAY and "emergency" in flags_v
		var eff_freq: int = int(row.get("freq", 0))
		if is_emergency:
			if not low_hp:
				continue  # gate: healthy mobs never pick emergency
			eff_freq *= 3
		elif low_hp:
			eff_freq = maxi(1, eff_freq / 2)
		if eff_freq <= 0:
			continue
		# DCSS tracer: single-target beam spells won't fire if another
		# hostile monster stands between the caster and the target.
		# _beam_friendly_fire looks up the spell's "pierce"/beam nature
		# via SpellRegistry.element_for (a spell with an element is our
		# zap list, all of which travel in a line).
		if target != null and _beam_friendly_fire(m, target, String(row.get("spell", ""))):
			continue
		effective.append({"spell": String(row.get("spell", "")), "freq": eff_freq})
	if effective.is_empty():
		return false
	var total_w: int = 0
	for e in effective:
		total_w += int(e["freq"])
	if total_w <= 0:
		return false
	if randi() % 200 >= total_w:
		return false
	var roll: int = randi() % total_w
	var acc: int = 0
	var picked_id: String = ""
	for e in effective:
		acc += int(e["freq"])
		if roll < acc:
			picked_id = String(e["spell"])
			break
	if picked_id == "":
		return false
	return _apply_mon_spell(m, target, picked_id)


## DCSS friendly-fire tracer. For a damage-dealing beam spell from `m`
## toward `target`, sweep a Bresenham line from caster to target; return
## true if any other hostile monster sits on the path. Non-damage /
## non-beam spells (self-buffs, summons, hexes) always return false so
## casters still pick them freely.
static func _beam_friendly_fire(m: Monster, target: Node, spell_id: String) -> bool:
	if spell_id == "" or m == null or target == null:
		return false
	# Only filter damage spells — SpellRegistry.element_for returns "" for
	# non-zap effects like summon / heal / haste.
	var elem: String = SpellRegistry.element_for(spell_id)
	if elem == "":
		return false
	var from: Vector2i = m.grid_pos
	var to: Vector2i = target.grid_pos
	if from == to:
		return false
	# Build a candidate occupancy dict once per check so we don't rescan
	# the monsters group for every cell along the path.
	var occupants: Dictionary = {}
	for other in m.get_tree().get_nodes_in_group("monsters"):
		if other == m or not is_instance_valid(other):
			continue
		if not (other is Monster) or not other.is_alive:
			continue
		occupants[other.grid_pos] = true
	# Bresenham supercover from `from` to `to`. Skip both endpoints —
	# we only care about cells between caster and target.
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var sx: int = 1 if dx > 0 else (-1 if dx < 0 else 0)
	var sy: int = 1 if dy > 0 else (-1 if dy < 0 else 0)
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	var x: int = from.x
	var y: int = from.y
	var err: int = adx - ady
	while Vector2i(x, y) != to:
		var e2: int = 2 * err
		if e2 > -ady:
			err -= ady
			x += sx
		if e2 < adx:
			err += adx
			y += sy
		var cell: Vector2i = Vector2i(x, y)
		if cell == to:
			break
		if occupants.has(cell):
			return true
	return false


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
	# Direct-damage zaps go through SpellRegistry.roll_damage with the
	# element routed to the defender's resistance check.
	var dmg: int = SpellRegistry.roll_damage(spell_id, power)
	if dmg >= 0:
		if target.has_method("take_damage"):
			var elem: String = SpellRegistry.element_for(spell_id)
			target.take_damage(dmg, elem)
			var dmg_mname: String = m.data.display_name if m.data else "monster"
			CombatLog.add("The %s casts %s for %d damage!" % [
					dmg_mname, spell_id.replace("_", " "), dmg])
		return true
	# Non-damage spells: hex / heal-other / summon / invisibility. Minimum
	# viable coverage so priests and wizards feel like DCSS rather than
	# standing silent. Anything not matched here silently fails — caller
	# still returns true so the monster spends a turn on the attempt.
	var mname: String = m.data.display_name if (m.data != null) else "caster"
	match spell_id:
		"confuse":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's confusion!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_confused", true)
				var ct: int = 4 + int(hd / 4)
				target.set_meta("_confusion_turns", ct)
			CombatLog.add("The %s confuses you!" % mname)
			return true
		"paralyse":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's paralysis!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_paralysis_turns", 2 + int(hd / 6))
			CombatLog.add("The %s paralyses you!" % mname)
			return true
		"slow":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's slow!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_slowed_turns", 4 + int(hd / 4))
			CombatLog.add("The %s slows you!" % mname)
			return true
		"fear":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's fear!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_afraid_turns", 3 + int(hd / 5))
			CombatLog.add("The %s fills you with dread!" % mname)
			return true
		"charm":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's charm!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_charmed_turns", 3 + int(hd / 5))
			CombatLog.add("The %s charms you!" % mname)
			return true
		"blind":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's blinding!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_blind_turns", 3 + int(hd / 6))
				if target.has_method("_recompute_gear_stats"):
					target._recompute_gear_stats()
			CombatLog.add("The %s blinds you!" % mname)
			return true
		"corona":
			if target.has_method("set_meta"):
				target.set_meta("_corona_turns", 5 + int(hd / 4))
			CombatLog.add("The %s surrounds you with a glowing corona!" % mname)
			return true
		"daze", "vertigo":
			if target.has_method("willpower_check") and target.willpower_check(hd):
				CombatLog.add("You resist the %s's daze!" % mname)
				return true
			if target.has_method("set_meta"):
				target.set_meta("_dazed_turns", 4 + int(hd / 5))
				if target.has_method("_recompute_gear_stats"):
					target._recompute_gear_stats()
			CombatLog.add("The %s dazes you!" % mname)
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


## Broadcast a noise pulse. Delegates to Noise (shout.cc port), which
## walks the tile grid with per-feature attenuation so walls and closed
## doors actually muffle the wave instead of a raw Chebyshev test.
static func broadcast_noise(tree: SceneTree, origin: Vector2i, loudness: int,
		stealth: int = 0) -> void:
	if tree == null:
		return
	var gen: DungeonGenerator = _find_generator(tree)
	if gen == null:
		# Without a map we fall back to the old disc test — better to
		# wake neighbours than nothing. Rare path; only hits when the
		# dungeon isn't loaded yet.
		var eff: int = maxi(0, loudness - stealth / 3)
		if eff <= 0:
			return
		for m in tree.get_nodes_in_group("monsters"):
			if not is_instance_valid(m) or not (m is Monster) or not m.is_alive:
				continue
			if not m.is_sleeping:
				continue
			if _cheb(m.grid_pos, origin) <= eff:
				wake(m)
		return
	var map_fn: Callable = func(cell: Vector2i) -> int:
		if cell.x < 0 or cell.x >= DungeonGenerator.MAP_WIDTH:
			return -1
		if cell.y < 0 or cell.y >= DungeonGenerator.MAP_HEIGHT:
			return -1
		return gen.map[cell.x][cell.y]
	DCSSNoise.broadcast(tree, origin, loudness, stealth, map_fn)


static func _find_generator(tree: SceneTree) -> DungeonGenerator:
	var game: Node = tree.root.get_node_or_null("Game")
	if game == null:
		return null
	var dmap = game.get_node_or_null("DungeonLayer/DungeonMap")
	if dmap == null or not ("generator" in dmap):
		return null
	return dmap.generator


## Wake a sleeping monster and propagate the alarm to adjacent sleepers.
## Called from MonsterAI.act() on LOS, and from Monster.take_damage() on
## hit — a monster woken by damage skips no turn (it reacts immediately).
static func wake(m: Monster) -> void:
	if m == null or not m.is_sleeping:
		return
	m.is_sleeping = false
	m.queue_redraw()
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return
	# DCSS shout.cc port — a monster that just spotted an enemy emits
	# a shout whose loudness is derived from the DCSS shout table
	# (silent=0, hiss=4, soft=6, default=8, loud=10, roar=12). We don't
	# carry an explicit per-monster shout type yet so we approximate
	# from HD: tiny bugs stay quiet, drakes+ roar loud. DCSSNoise runs
	# the wave through the grid so walls actually muffle the alarm
	# instead of instantly waking the whole floor.
	var hd: int = 1
	if m.data != null and "hd" in m.data:
		hd = int(m.data.hd)
	var loudness: int
	if hd <= 1:
		loudness = 4      # hiss / skitter equivalent
	elif hd <= 3:
		loudness = 6      # soft
	elif hd <= 7:
		loudness = 8      # default shout
	elif hd <= 12:
		loudness = 10     # loud
	else:
		loudness = 12     # roar
	# Some monsters are tagged silent in DCSS (mimics, jellies) — we
	# skip the shout for those so an ambush doesn't auto-alert the
	# room. Default path: the `silent` shape or `silent` flag muzzles.
	var silent: bool = false
	if m.data != null:
		if "shape" in m.data and String(m.data.shape) == "jelly":
			silent = true
		if "flags" in m.data:
			for f in m.data.flags:
				if String(f).to_lower() == "silent":
					silent = true
					break
	if not silent and loudness > 0:
		broadcast_noise(tree, m.grid_pos, loudness, 0)


static func _should_wake(m: Monster) -> bool:
	# DCSS shout.cc::check_awaken port. For a sleeping monster the
	# wake check is: (a) monster can see player, (b) not berserk / not
	# MUT_NO_STEALTH, (c) roll x_chance_in_y(monster_perception, stealth).
	# Higher stealth literally hides you; lower perception on dumb
	# beasts makes them sleep through near-adjacent casts.
	if m.generator == null:
		return false
	var tree: SceneTree = m.get_tree()
	if tree == null:
		return false
	var player: Node = tree.get_first_node_in_group("player")
	if player != null and "grid_pos" in player and "is_alive" in player and player.is_alive:
		var invis: bool = player.has_method("has_meta") and player.has_meta("_invisible_turns")
		if invis:
			return false
		# Monster must actually see the player. Bidirectional LOS under
		# our FOV engine: if the player can see the monster's cell, the
		# monster can see the player's.
		if _cheb(m.grid_pos, player.grid_pos) > m.sight_range:
			return false
		if not _monster_has_fov_to(m, player.grid_pos):
			return false
		# DCSS perception: `(5 + HD*3/2) * (intel_factor + awake_bonus) / 20`,
		# floored at 12. We treat the sleeping case (awake_bonus = 0).
		var perc: int = _monster_perception(m, true)
		var stealth: int = _player_stealth_scaled(player)
		# `x_chance_in_y(perc, stealth)` = perc/stealth probability.
		if stealth <= 0:
			return true
		if randi() % stealth < perc:
			return true
		return false
	# Companions are also hostile targets and break stealth.
	for c in tree.get_nodes_in_group("companions"):
		if c is Companion and c.is_alive and "grid_pos" in c:
			if _cheb(m.grid_pos, c.grid_pos) <= m.sight_range \
					and _monster_has_fov_to(m, c.grid_pos):
				return true
	return false


## Read the player's stealth skill. Kept as-is for legacy callers
## (e.g. caster-noise broadcast scaling).
static func _player_stealth(player: Node) -> int:
	if player == null or not ("skill_state" in player):
		return 0
	if typeof(player.skill_state) != TYPE_DICTIONARY:
		return 0
	var st: Dictionary = player.skill_state.get("stealth", {})
	return int(st.get("level", 0))


## DCSS player_stealth (player.cc:3329), scaled integer form suitable
## for x_chance_in_y. Returns `dex*3 + stealth_skill*15 - armour_pen`.
## Form/background mutations and gear egos are TODO.
static func _player_stealth_scaled(player: Node) -> int:
	if player == null:
		return 0
	var dex: int = 10
	if "stats" in player and player.stats != null:
		dex = int(player.stats.DEX)
	var sk: int = _player_stealth(player)
	var stealth: int = dex * 3 + sk * 15
	# Body armour stealth penalty: DCSS uses `player_armour_stealth_penalty`,
	# which reads body_armour PARM_EVASION. Approximate with our stored
	# ev_penalty on the chest slot (encumbrance tier).
	if "equipped_armor" in player and typeof(player.equipped_armor) == TYPE_DICTIONARY:
		var body: Dictionary = player.equipped_armor.get("chest", {})
		var evp_raw: int = absi(int(body.get("ev_penalty", 0))) / 10
		stealth -= evp_raw * evp_raw * 2 / 3
	# Confusion shreds stealth (DCSS divides it by 3).
	if player.has_method("has_meta") and player.has_meta("_confused"):
		stealth /= 3
	# Corona: glowing aura makes the player visible — stealth = 0.
	if player.has_method("has_meta") and player.has_meta("_corona_turns"):
		stealth = 0
	return maxi(0, stealth)


## DCSS monster_perception (shout.cc:252).
##   intel_factor = [15 (animal), 20 (normal), 30 (human)]
##   perc_mult = intel_factor + (awake ? 15 : 0)
##   perc = (5 + HD * 3/2) * perc_mult / 20
##   perc = max(12, perc)
static func _monster_perception(m: Monster, sleeping: bool) -> int:
	var hd: int = 1
	var intel: String = "normal"
	if m.data != null:
		if "hd" in m.data:
			hd = int(m.data.hd)
		if "intel" in m.data:
			intel = String(m.data.intel)
	# DCSS mon_intel_type (mon-enum.h:201): only three tiers.
	#   I_BRAINLESS → 15  (oozes, jellies, plants)
	#   I_ANIMAL    → 20  (rats, bats, hydras)
	#   I_HUMAN     → 30  (orcs, elves, wizards)
	var intel_factor: int
	match intel:
		"brainless": intel_factor = 15
		"animal":    intel_factor = 20
		"human":     intel_factor = 30
		_:           intel_factor = 20
	var perc_mult: int = intel_factor + (0 if sleeping else 15)
	var perc: int = (5 + hd * 3 / 2) * perc_mult / 20
	return maxi(12, perc)


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
	# DCSS: intelligent monsters open doors as they move through them.
	# Animals and plants can't. We treat DOOR_CLOSED as passable for
	# eligible monsters and let _move_to actually open it on step.
	if not m.generator.is_walkable(pos):
		if _monster_can_open_doors(m) \
				and m.generator.get_tile(pos) == DungeonGenerator.TileType.DOOR_CLOSED:
			pass  # fall through — treated as walkable for pathing
		else:
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


## DCSS pack formation: when wandering without a target, a monster
## prefers to stay near its pack rather than drift off solo. Picks the
## nearest ally within ~6 tiles and steps toward them; fully random
## wander only kicks in when truly isolated. Cuts the "pack scattered
## across the map" problem after the first engagement.
static func _maybe_wander(m: Monster) -> void:
	if randf() >= 0.5:
		return
	var ally: Node = _nearest_ally(m, 6)
	if ally != null:
		var gap: int = _cheb(m.grid_pos, ally.grid_pos)
		# Already close (≤2 tiles): a bit of jitter looks natural. Stepping
		# right on top just produces a conga line.
		if gap >= 3:
			_step_toward(m, ally.grid_pos)
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


## Nearest same-side monster within `max_dist` Chebyshev tiles. "Ally"
## for a hostile mob means another hostile Monster (not a Companion,
## not the player). Null if isolated.
static func _nearest_ally(m: Monster, max_dist: int) -> Node:
	if m == null or m.get_tree() == null:
		return null
	var best: Monster = null
	var best_d: int = max_dist + 1
	for other in m.get_tree().get_nodes_in_group("monsters"):
		if other == m or not is_instance_valid(other):
			continue
		if not (other is Monster) or not other.is_alive:
			continue
		var d: int = _cheb(m.grid_pos, other.grid_pos)
		if d < best_d:
			best_d = d
			best = other
	return best


static func _move_to(m: Monster, pos: Vector2i) -> void:
	# If the target tile is a closed door, open it (this is why
	# `_can_enter` let us path through it) and skip the move itself
	# — opening is the whole turn. DCSS monsters do the same.
	if m.generator != null \
			and m.generator.get_tile(pos) == DungeonGenerator.TileType.DOOR_CLOSED \
			and _monster_can_open_doors(m):
		m.generator.open_door(pos)
		return
	m.move_to_grid(pos)


## Intelligence check for door-opening. DCSS animals/plants/brainless
## can't work a latch; intelligent humanoids / caster monsters can.
static func _monster_can_open_doors(m: Monster) -> bool:
	if m == null or m.data == null:
		return false
	var intel: String = String(m.data.intelligence)
	return intel != "animal" and intel != "plant" and intel != "brainless"
