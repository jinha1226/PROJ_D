class_name SpellCast
extends Object
## Faithful DCSS 0.34 spell-cast controller.
##
## Source:
##   crawl-ref/source/spl-cast.cc
##     cast_a_spell()   — top-level flow (lines ~867..1100)
##     your_spells()    — effect dispatch (lines ~2129..)
##     raw_spell_fail() / calc_spell_power() — power & fail (lines ~455..)
##   crawl-ref/source/player.cc
##     pay_mp() / refund_mp() — MP accounting (lines ~3945..3970)
##
## This module owns the single, authoritative flow for "player casts a
## spell." The previous project had three divergent paths
## (_execute_cast, _execute_targeted_cast, quickslot quick-cast) that
## duplicated MP-deduction and fail-roll logic — small drifts between
## them masked a bug where certain spells never actually consumed MP.
##
## DCSS spell lifecycle (spl-cast.cc::cast_a_spell, 2025-02-10 source):
##
##   1. Abort pre-checks (confusion is a special case — it still burns MP)
##   2. Range/target check   → may abort (NOT consume MP)
##   3. pay_mp(cost)         — spend MP up front
##   4. your_spells(...)     — roll fail, compute power, fire effect
##   5. If result == ABORT   → refund_mp(cost)
##      If result == FAIL    → MP stays spent (miscast from confusion
##                             included — this is DCSS's "fumble cost")
##      If result == SUCCESS → MP stays spent
##
## The caller passes an already-chosen target (a Node, Vector2i, or null
## for self / auto-pick). This module never opens UI — that's the
## caller's job.

const SPRET_ABORT: int = 0
const SPRET_FAIL: int = 1
const SPRET_SUCCESS: int = 2


## Cast result bundle.
##   spret:    SPRET_ABORT | SPRET_FAIL | SPRET_SUCCESS
##   message:  log line (can be empty)
##   damage:   total damage dealt on success (0 otherwise)
##   power:    computed spell power (0 on abort before power calc)
##   fail_pct: shown failure percentage (0 if not rolled)
##
## Returned as a Dictionary because GDScript lacks discriminated unions
## and this is the shape the existing cast sites already consume.
static func cast(player: Node, spell_id: String, target, ctx: Dictionary) -> Dictionary:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return _abort("Unknown spell: %s" % spell_id)
	if player == null or player.stats == null:
		return _abort("No player")

	# spl-cast.cc:1005 casting_uselessness_reason — silence blocks *every*
	# cast (no MP cost), confusion burns MP then fizzles.
	if player.has_meta("_silenced_turns"):
		return _abort("You are surrounded by silence — no casting.")

	var cost: int = int(info.get("mp", 1))
	if player.stats.MP < cost:
		return _abort("Not enough MP (%d/%d)" % [player.stats.MP, cost])

	if player.has_meta("_confused") and bool(player.get_meta("_confused", false)):
		_pay_mp(player, cost)  # DCSS burns the MP even on a confusion miscast.
		return {
			"spret": SPRET_FAIL,
			"message": "You are too confused to cast!",
			"damage": 0, "power": 0, "fail_pct": 100,
			"school": String(info.get("school", "")),
			"spell_color": info.get("color", Color.WHITE),
			"mp_cost": cost,
		}

	# Range / target resolution. For "self" spells the caller must pass
	# null; for single/area we auto-pick the nearest visible foe if the
	# caller didn't supply one (matches DCSS book-cast auto-targeting
	# for a monster in range).
	var targeting: String = String(info.get("targeting", "single"))
	var target_pos: Vector2i = Vector2i.ZERO
	var target_node = target
	if targeting != "self":
		if target_node == null:
			target_node = _find_nearest_visible_target(player, int(info.get("range", 6)), ctx)
			if target_node == null:
				return _abort("No visible target in range.")
		if target_node is Vector2i:
			target_pos = target_node
		elif target_node and "grid_pos" in target_node:
			target_pos = target_node.grid_pos

	# --- Pay MP (spl-cast.cc:1046 pay_mp). ------------------------------
	_pay_mp(player, cost)

	# Failure roll (spl-cast.cc ~2160 — your_spells rolls before effect).
	var fail_pct: int = SpellRegistry.failure_rate(spell_id, player)
	if randi() % 100 < fail_pct:
		return {
			"spret": SPRET_FAIL,
			"message": "Spell fizzles! (%d%% fail)" % fail_pct,
			"damage": 0, "power": 0, "fail_pct": fail_pct,
			"school": String(info.get("school", "")),
			"spell_color": info.get("color", Color.WHITE),
			"mp_cost": cost,
		}

	# Power (spl-cast.cc:550 calc_spell_power + staff/racial/gear bonuses).
	var power: int = SpellRegistry.calc_spell_power(spell_id, player)
	var staff_sch: String = WeaponRegistry.staff_spell_school(player.equipped_weapon_id)
	var school: String = String(info.get("school", "spellcasting"))
	if staff_sch == school or staff_sch == "":
		power += WeaponRegistry.staff_spell_bonus(player.equipped_weapon_id)
	if player.has_method("gear_spell_power_bonus"):
		power += int(player.gear_spell_power_bonus())
	if ctx.has("spellpower_fn"):
		power = int(ctx["spellpower_fn"].call(power))

	# Execution is caller-owned: SpellCast owns MP & fail; the effect
	# (damage rolls, status riders, area FX) lives in the caller because
	# it needs the scene-tree, SpellFX, and the monster list. We return
	# the resolved power/target so the caller can apply the effect.
	return {
		"spret": SPRET_SUCCESS,
		"message": "",
		"damage": 0, "power": power, "fail_pct": fail_pct,
		"school": school,
		"spell_color": info.get("color", Color.WHITE),
		"mp_cost": cost,
		"target": target_node,
		"target_pos": target_pos,
		"info": info,
	}


## Refund MP — spl-cast.cc:1061 refund_mp(cost).
## Call this if an effect determines post-hoc that the cast must abort
## (e.g., blink finds no safe tile). Not used on fizzle (fail keeps MP).
static func refund(player: Node, mp_cost: int) -> void:
	if player == null or player.stats == null:
		return
	player.stats.MP = mini(player.stats.mp_max, player.stats.MP + mp_cost)
	player.stats_changed.emit()


# --- private helpers ------------------------------------------------------

static func _pay_mp(player: Node, cost: int) -> void:
	player.stats.MP = maxi(0, player.stats.MP - cost)
	player.stats_changed.emit()


static func _abort(msg: String) -> Dictionary:
	return {
		"spret": SPRET_ABORT,
		"message": msg,
		"damage": 0, "power": 0, "fail_pct": 0,
		"school": "",
		"spell_color": Color.WHITE,
		"mp_cost": 0,
	}


## Locate the nearest visible hostile within `range_tiles` for auto-target
## flows (book-menu cast without manual targeting). Mirrors
## spl-cast.cc::spell_no_hostile_in_range by scanning the player's LOS.
static func _find_nearest_visible_target(player: Node, range_tiles: int, ctx: Dictionary):
	var tree: SceneTree = null
	if ctx.has("tree"):
		tree = ctx["tree"]
	elif player != null and player.is_inside_tree():
		tree = player.get_tree()
	if tree == null:
		return null
	var dmap = null
	if ctx.has("dmap"):
		dmap = ctx["dmap"]
	var best = null
	var best_dist: float = INF
	for m in tree.get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if not ("is_alive" in m) or not m.is_alive:
			continue
		if dmap != null and dmap.has_method("is_tile_visible") \
				and not dmap.is_tile_visible(m.grid_pos):
			continue
		var d: float = float(player.grid_pos.distance_to(m.grid_pos))
		if d <= float(range_tiles) and d < best_dist:
			best_dist = d
			best = m
	return best
