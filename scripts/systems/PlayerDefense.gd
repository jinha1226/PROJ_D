class_name PlayerDefense
extends Object
## Faithful DCSS 0.34 player defense port.
##
## Source:
##   crawl-ref/source/player.cc
##     _player_evasion                         (lines ~2167..2203)
##     _player_armour_adjusted_dodge_bonus     (lines ~2150..2164)
##     _player_evasion_size_factor             (lines ~2009..2014)
##     _player_base_evasion_modifiers          (lines ~2049..2074)
##     unadjusted_body_armour_penalty          (lines ~6158..6169)
##     adjusted_body_armour_penalty            (lines ~6178..6185)
##     adjusted_shield_penalty                 (lines ~6193..6203)
##
## Port scope:
##   - Base evasion, dodge bonus, armour/shield/aux penalties match DCSS
##     arithmetic line-for-line (scale=100 fixed-point, STR/skill
##     quadratics, etc.).
##   - What's deferred because the data model hasn't caught up:
##     body-size factor → hard-coded to 0 (medium) until race_res carries
##     size; form EV bonus → pulled from FormRegistry if set; archery
##     bow-ego penalty-halving → TODO; acrobat/agility/heavenly-storm
##     durations → not yet implemented.
##
## All public functions return values in integer tiles of EV — the same
## scale the existing Stats.EV expects.

const _EV_SCALE: int = 100


## DCSS _player_evasion(100, ignore_temporary=false), scaled back to int.
## This is what Stats.EV should equal after gear/skill recompute.
static func player_evasion(player: Node, skill_system) -> int:
	var raw: int = _player_evasion_raw(player, skill_system, _EV_SCALE)
	return int(round(float(raw) / float(_EV_SCALE)))


## DCSS _player_evasion, preserving the fixed-point scale for any caller
## that wants sub-integer precision (e.g. attack.cc test_hit).
static func _player_evasion_raw(player: Node, skill_system, scale: int) -> int:
	var size_factor: int = _size_factor(player)
	var size_base_ev: int = (10 + size_factor) * scale
	var natural: int = size_base_ev \
			+ _armour_adjusted_dodge_bonus(player, skill_system, scale) \
			- adjusted_body_armour_penalty(player, skill_system, scale) \
			- adjusted_shield_penalty(player, skill_system, scale) \
			- _aux_evasion_penalty(player, scale) \
			+ _form_ev_bonus(player) \
			+ _base_evasion_modifiers(player) * scale
	# Transient effects.
	if player.has_meta("_petrifying") and bool(player.get_meta("_petrifying", false)):
		natural /= 2
	if player.has_meta("_caught") and bool(player.get_meta("_caught", false)):
		natural /= 2
	# Amulet of the Acrobat: +5 EV when the player did not melee-attack or
	# cast a spell this turn. The flag "_acrobat_active" is set by Player at
	# the start of each turn and cleared on any melee or spell action.
	if player.has_meta("_amulet_acrobat") and player.has_meta("_acrobat_active"):
		natural += 5 * scale
	return natural


## DCSS `_player_evasion_size_factor` — `2 * (SIZE_MEDIUM - size)`.
## Returns 0 for medium races. Positive for smaller (harder to hit),
## negative for larger. We read `race_res.size_factor` if present; every
## unmapped race falls back to medium.
static func _size_factor(player: Node) -> int:
	if player == null:
		return 0
	if "race_res" in player and player.race_res != null:
		if "size_factor" in player.race_res:
			return int(player.race_res.size_factor)
	return 0


## DCSS _player_armour_adjusted_dodge_bonus.
## base_dodge = (800 + dodging*10 * dex * 8) * scale
##              / (20 - size_factor) / 10 / 10
## Reduced by body-armour STR penalty.
static func _armour_adjusted_dodge_bonus(player: Node, skill_system, scale: int) -> int:
	var dodging: int = _skill(skill_system, player, "dodging")
	var dex: int = int(player.stats.DEX)
	var size_factor: int = _size_factor(player)
	var dodge_bonus: int = (800 + dodging * 10 * dex * 8) * scale \
			/ maxi(1, 20 - size_factor) / 10 / 10
	var armour_pen: int = unadjusted_body_armour_penalty(player) - 3
	if armour_pen <= 0:
		return dodge_bonus
	var strv: int = maxi(1, int(player.stats.STR))
	if armour_pen >= strv:
		return dodge_bonus * strv / (armour_pen * 2)
	return dodge_bonus - dodge_bonus * armour_pen / (strv * 2)


## DCSS unadjusted_body_armour_penalty — (-PARM_EVASION)/10, floored at 0.
## We don't yet split body armour into base/randart so the raw stored
## `ev_penalty` is treated as the DCSS `-PARM_EVASION` direct value.
static func unadjusted_body_armour_penalty(player: Node) -> int:
	if player == null or not ("equipped_armor" in player):
		return 0
	var body: Dictionary = player.equipped_armor.get("chest", {})
	if body.is_empty():
		return 0
	var raw_ev_pen: int = int(body.get("ev_penalty", 0))
	# DCSS stores PARM_EVASION as negative; ours mirrors that. If a
	# registry entry accidentally stored it positive, take abs(). The
	# final unit is "encumbrance tiers" (0 = unencumbered).
	return maxi(0, absi(raw_ev_pen) / 10)


## DCSS adjusted_body_armour_penalty:
## `2 * evp^2 * (450 - armour_skill*10) * scale / (5 * (str+3)) / 450`
## Armour skill buys off the penalty; STR divides it.
static func adjusted_body_armour_penalty(player: Node, skill_system, scale: int) -> int:
	var base_evp: int = unadjusted_body_armour_penalty(player)
	if base_evp <= 0:
		return 0
	var armour_lv: int = _skill(skill_system, player, "armour")
	var strv: int = int(player.stats.STR)
	return 2 * base_evp * base_evp * (450 - armour_lv * 10) \
			* scale / (5 * (strv + 3)) / 450


## DCSS adjusted_shield_penalty.
## `2 * shield_pen^2 * (270 - shield_skill*10) * scale / (25 + 5*str) / 270`
static func adjusted_shield_penalty(player: Node, skill_system, scale: int) -> int:
	if player == null or not ("equipped_armor" in player):
		return 0
	var shield_slot: Dictionary = player.equipped_armor.get("shield", {})
	if shield_slot.is_empty():
		return 0
	var base_shield_pen: int = maxi(0, absi(int(shield_slot.get("ev_penalty", 0))) / 10)
	if base_shield_pen <= 0:
		return 0
	var shields_lv: int = _skill(skill_system, player, "shields")
	var strv: int = int(player.stats.STR)
	return 2 * base_shield_pen * base_shield_pen \
			* (270 - shields_lv * 10) * scale \
			/ (25 + 5 * strv) / 270


## Aux-slot armour (helmet/gloves/boots/cloak/barding) with base EV
## penalty. Each slot's penalty/3 stacks. Matches
## `_player_aux_evasion_penalty` in player.cc:2029.
static func _aux_evasion_penalty(player: Node, scale: int) -> int:
	if player == null or not ("equipped_armor" in player):
		return 0
	var total: int = 0
	for slot_key in player.equipped_armor.keys():
		if slot_key == "chest" or slot_key == "shield":
			continue
		var slot: Dictionary = player.equipped_armor[slot_key]
		if slot.is_empty():
			continue
		var pen: int = absi(int(slot.get("ev_penalty", 0))) / 3
		if pen > 0:
			total += pen
	return total * scale / 10


## Flat permanent EV bonuses from rings, EV mutations, tengu flight, etc.
## Scaled at the callsite (multiplied by `scale`).
static func _base_evasion_modifiers(player: Node) -> int:
	if player == null:
		return 0
	var evbonus: int = 0
	if "equipped_rings" in player:
		for ring in player.equipped_rings:
			if typeof(ring) == TYPE_DICTIONARY and not ring.is_empty():
				evbonus += int(ring.get("ev", 0))
	# Mutations that directly grant EV. Stored on player.mutations.
	if "mutations" in player and typeof(player.mutations) == TYPE_DICTIONARY:
		evbonus += int(player.mutations.get("gelatinous_body", 0))
		var dist: int = int(player.mutations.get("distortion_field", 0))
		if dist > 0:
			evbonus += dist + 1
		var slow: int = int(player.mutations.get("slow_reflexes", 0))
		if slow > 0:
			evbonus -= slow * 5
	# Tengu flight +4 EV while airborne.
	if "race_res" in player and player.race_res != null:
		if String(player.race_res.racial_trait) == "tengu_flight":
			evbonus += 4
	return evbonus


## Form EV bonus (per FormRegistry entry, already in raw EV tiles).
## DCSS returns scaled by 100 so we normalise to the scale here.
static func _form_ev_bonus(player: Node) -> int:
	if player == null or not ("current_form" in player):
		return 0
	var form_id: String = String(player.current_form)
	if form_id == "":
		return 0
	var form: Dictionary = FormRegistry.get_info(form_id)
	if form.is_empty():
		return 0
	return int(form.get("ev_bonus", 0)) * _EV_SCALE


## Skill level lookup. Prefers SkillSystem if the caller passes one in;
## otherwise falls back to the player's internal `_skill_level` helper
## (which reads `skill_state` + `job_res.starting_skills`) so this module
## works during Player.recompute_stats before SkillSystem is wired.
static func _skill(skill_system, player: Node, skill_id: String) -> int:
	if player == null:
		return 0
	if skill_system != null and skill_system.has_method("get_level"):
		return int(skill_system.get_level(player, skill_id))
	if player.has_method("_skill_level"):
		return int(player._skill_level(skill_id))
	return 0
