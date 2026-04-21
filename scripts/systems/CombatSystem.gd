class_name CombatSystem extends Node
## M1 combat. DCSS-inspired formula with skill system integration:
##   damage = max(1, ATK - effective_AC + rand(-2, 2))
## where
##   ATK = int(weapon_dmg * (1 + weapon_skill/20)) + STR/2 + fighting_skill/4
##   effective_AC = defender.ac + armour_skill/4

const UNARMED_DAMAGE: int = 3


static func roll_damage(attacker_atk: int, defender_ac: int) -> int:
	return max(1, attacker_atk - defender_ac + randi_range(-2, 2))


## Holy-wrath brand target check: DCSS triggers extra damage on undead
## and demonic creatures. We key off the "undead" shape or an "undead"/
## "demonic" flag on the monster data.
static func _is_undead_or_demon(defender) -> bool:
	if defender == null or not ("data" in defender) or defender.data == null:
		return false
	var shape: String = String(defender.data.shape if "shape" in defender.data else "")
	if shape == "undead":
		return true
	var flags: Array = defender.data.flags if "flags" in defender.data else []
	for f in flags:
		var lf: String = String(f).to_lower()
		if lf == "undead" or lf == "demonic":
			return true
	return false


## Player → defender melee. `skill_sys` is a SkillSystem instance; if null,
## skills contribute 0 (useful for pre-init / test paths). Returns damage.
static func melee_attack(attacker, defender, skill_sys = null) -> int:
	var weapon_id: String = ""
	if "equipped_weapon_id" in attacker:
		weapon_id = String(attacker.equipped_weapon_id)

	var weapon_dmg: int = UNARMED_DAMAGE
	if weapon_id != "" and WeaponRegistry.is_weapon(weapon_id):
		weapon_dmg = WeaponRegistry.weapon_damage_for(weapon_id)
	# DCSS attack.cc:840 player_apply_slaying_bonuses applies weapon
	# plus + ring-of-slaying as `+random2(1+plus)` AFTER skill
	# multipliers — NOT as a flat pre-roll add (the old code doubled
	# enchant value at high skill because it multiplied by 2+). We now
	# carry weapon_bonus_dmg (essences, mobile-only) as the only flat
	# pre-mult term. The DCSS slaying random2 lands after skills below.
	if "weapon_bonus_dmg" in attacker:
		weapon_dmg += int(attacker.weapon_bonus_dmg)
	if weapon_id == "" and "trait_res" in attacker and attacker.trait_res != null \
			and attacker.trait_res.special == "brawler":
		weapon_dmg *= 2
	elif weapon_id == "" and "race_res" in attacker and attacker.race_res != null \
			and attacker.race_res.racial_trait == "catfolk_claws":
		weapon_dmg += 3
	elif weapon_id == "" and "race_res" in attacker and attacker.race_res != null \
			and attacker.race_res.racial_trait == "ghoul_claws":
		weapon_dmg += 3
	# DCSS form-specific fist damage. Dragon form adds +8 base, storm
	# form +24, tree +9, etc. Stacks above the racial claws bump for
	# players who pick a clawed race and transform.
	if weapon_id == "" and attacker.has_method("has_meta") \
			and attacker.has_meta("_form_unarmed_base"):
		weapon_dmg += int(attacker.get_meta("_form_unarmed_base", 0))

	# Unarmed swings train "unarmed_combat" (DCSS SK_UNARMED_COMBAT) and
	# its level scales both damage (via the weapon-skill multiplier) and
	# attack-delay mindelay just like any other weapon school.
	var weapon_skill_id: String = WeaponRegistry.weapon_skill_for(weapon_id)
	if weapon_id == "":
		weapon_skill_id = "unarmed_combat"
		# DCSS unarmed: +1 damage per 3 skill levels on top of the skill
		# multiplier. Keeps fists scaling into the late game.
		if skill_sys != null:
			weapon_dmg += skill_sys.get_level(attacker, "unarmed_combat") / 3
	var weapon_skill_level: int = 0
	var fighting_level: int = 0
	if skill_sys != null:
		if weapon_skill_id != "":
			weapon_skill_level = skill_sys.get_level(attacker, weapon_skill_id)
		fighting_level = skill_sys.get_level(attacker, "fighting")

	var base_stat_atk: int = 0
	if "stats" in attacker and attacker.stats != null:
		base_stat_atk = attacker.stats.get_attack()

	# DCSS player to-hit (attack.cc:calc_pre_roll_to_hit):
	#   mhit = 15 + dex/2
	#   mhit += random2(fighting_skill*100+1) / 100
	#   mhit += random2(weapon_skill*100+1) / 100
	#   mhit += weapon.plus                       (enchant)
	#   mhit += slaying_bonus
	# Then roll random2(mhit+1) vs target EV; miss if < EV.
	var dex_for_hit: int = 10
	if "stats" in attacker and attacker.stats != null:
		dex_for_hit = attacker.stats.DEX
	var to_hit: int = 15 + dex_for_hit / 2
	to_hit += (randi() % (fighting_level * 100 + 1)) / 100
	to_hit += (randi() % (weapon_skill_level * 100 + 1)) / 100
	if "equipped_weapon_plus" in attacker:
		to_hit += int(attacker.equipped_weapon_plus)
	# Slaying from rings (aggregated through gear_damage_bonus — treated
	# equally as to-hit in DCSS `you.slaying()`).
	if attacker.has_method("gear_damage_bonus"):
		to_hit += int(attacker.gear_damage_bonus())
	var def_ev: int = 0
	if "stats" in defender and defender.stats != null:
		def_ev = defender.stats.EV
	elif "data" in defender and defender.data != null and "ev" in defender.data:
		def_ev = int(defender.data.ev)
	var to_hit_roll: int = randi() % (to_hit + 1)
	if to_hit_roll < def_ev:
		var miss_name: String = ""
		if "data" in defender and defender.data != null:
			miss_name = String(defender.data.display_name)
		if miss_name != "":
			CombatLog.add("You miss the %s." % miss_name)
		_show_hit_feedback(defender, 0, Color(0.8, 0.8, 0.8))
		return 0

	# DCSS multiplicative damage pipeline (attack.cc player path):
	#   potential  = weapon_damage * 100  (fixed base × 100)
	#   potential *= stat_modify_damage    (STR/DEX → 75..175% + scale)
	#   damage     = random2(potential+1) / 100  (roll)
	#   damage    *= apply_weapon_skill   (1.0..2.08x)
	#   damage    *= apply_fighting_skill (1.0..1.9x)
	var attr: int = 10
	if "stats" in attacker and attacker.stats != null:
		# Short blades / polearms / ranged use DEX; everything else uses STR.
		if weapon_skill_id in ["short_blade", "bow", "throwing"]:
			attr = attacker.stats.DEX
		else:
			attr = attacker.stats.STR
	var stat_mult: int = max(1, 75 + (25 * attr) / 10)  # 75 + 2.5*attr, integer
	var potential: int = max(weapon_dmg, 1) * stat_mult
	var base_damage: int = (randi() % (potential + 1)) / 100
	# Weapon-skill multiplier (scale 2500, skill scaled ×100 to match DCSS
	# internal representation).
	var w_skill_scaled: int = weapon_skill_level * 100
	base_damage = base_damage * (2500 + (randi() % (w_skill_scaled + 1))) / 2500
	# Fighting-skill multiplier (scale 3000).
	var f_skill_scaled: int = fighting_level * 100
	base_damage = base_damage * (3000 + (randi() % (f_skill_scaled + 1))) / 3000
	# DCSS player_apply_slaying_bonuses (attack.cc:840). Apply weapon
	# enchant + ring-of-slaying as `+random2(1+plus)` AFTER skill
	# multipliers. Negative plus subtracts `random2(1-plus)`.
	var slaying: int = 0
	if "equipped_weapon_plus" in attacker:
		slaying += int(attacker.equipped_weapon_plus)
	if attacker.has_method("gear_damage_bonus"):
		slaying += int(attacker.gear_damage_bonus())
	if slaying >= 0:
		base_damage += randi() % (1 + slaying)
	else:
		base_damage -= randi() % (1 - slaying)
	# DCSS Weakness: weak attackers deal 2/3 damage (mostly for monster
	# spell effects & the sickness aftermath). Uses floor div so very
	# low rolls can still miss meaningfully.
	if attacker.has_method("has_meta") and attacker.has_meta("_weak_turns"):
		base_damage = base_damage * 2 / 3
	var atk: int = max(1, base_damage)

	var def_ac: int = 0
	if "ac" in defender:
		def_ac = defender.ac
	elif "stats" in defender and defender.stats != null:
		def_ac = defender.stats.AC
	# Vulnerability (from Scroll of Vulnerability) strips half AC.
	if defender.has_method("has_meta") and defender.has_meta("_vuln_turns"):
		def_ac = def_ac / 2

	# DCSS actor::apply_ac, ac_type::normal (actor.cc:355):
	#   saved = random2(1 + ac)
	# We previously rolled random2(2*ac+1), which averages AC damage
	# blocked instead of AC/2 — effectively a doubled-AC shield that
	# made mid-game armour feel invulnerable. This now matches DCSS.
	var soak: int = (randi() % (def_ac + 1)) if def_ac > 0 else 0
	# GDR (guaranteed damage reduction): body armour guarantees at least
	# a percentage of the hit absorbed, capped at ac/2. DCSS derives gdr
	# from base armour EVP; we approximate with body encumbrance tiers.
	var gdr_pct: int = _gdr_percent(defender)
	if gdr_pct > 0 and def_ac > 0:
		var gdr_soak: int = mini(gdr_pct * max(potential / 100, 1) / 100, def_ac / 2)
		soak = maxi(soak, gdr_soak)
	var dmg: int = max(1, atk - soak)
	var trait_special: String = ""
	if "trait_res" in attacker and attacker.trait_res != null:
		trait_special = attacker.trait_res.special
	elif "race_res" in attacker and attacker.race_res != null:
		trait_special = attacker.race_res.racial_trait
	# DCSS melee-attack.cc:handle_phase_aux — after the main hit lands,
	# racial auxiliary attacks fire at ~1/3 each. Each aux rolls its
	# own damage and applies before the combined total is dealt; stays
	# on the main target so the UI reads as one hit.
	var race_trait_aux: String = ""
	if "race_res" in attacker and attacker.race_res != null:
		race_trait_aux = String(attacker.race_res.racial_trait)
	var xl: int = 1
	if attacker.has_method("get") and attacker.get("level") != null:
		xl = int(attacker.level)
	match race_trait_aux:
		"minotaur_headbutt":
			# DCSS: base 5 + random2(XL) (weaker than DCSS real formula
			# but reads correctly).
			if randf() < 0.35:
				var hb: int = 5 + (randi() % maxi(1, xl))
				dmg += hb
				CombatLog.add("You headbutt!")
		"naga_tail_slap":
			if randf() < 0.33:
				var ts: int = 3 + (randi() % maxi(1, xl))
				dmg += ts
				if defender.has_method("apply_poison"):
					defender.apply_poison(1, "tail slap")
				CombatLog.add("Your tail slap envenoms!")
		"tengu_kick":
			if randf() < 0.33:
				dmg += 4 + (randi() % maxi(1, xl / 2 + 1))
				CombatLog.add("You kick!")
		"centaur_kick":
			if randf() < 0.33:
				dmg += 6 + (randi() % maxi(1, xl))
				CombatLog.add("You kick!")
		"draconian_tail":
			if randf() < 0.25:
				dmg += 3 + (randi() % maxi(1, xl / 2 + 1))
				CombatLog.add("Your tail strikes!")
		"octopode_tentacle":
			if randf() < 0.33:
				dmg += 2 + (randi() % 4)
				CombatLog.add("Your tentacles lash!")
	if trait_special == "fierce":
		if randf() < 0.25:
			dmg += randi_range(2, 5)
	if trait_special == "war_cry" and "stats" in attacker and attacker.stats != null:
		if attacker.stats.HP < attacker.stats.hp_max * 0.5:
			dmg = int(dmg * 1.5)
	if trait_special == "backstab" and "has_meta" in attacker:
		if not attacker.has_meta("_backstab_used"):
			dmg *= 3
			attacker.set_meta("_backstab_used", true)
		else:
			dmg = int(dmg * 1.15)
	# DCSS SPARM_HARM ego — when the attacker (player or monster) wears
	# a harm armour ego, they deal +30% damage. The defender half is
	# applied in Player.take_damage.
	if attacker.has_method("has_meta") and attacker.has_meta("_ego_harm"):
		dmg = (dmg * 130) / 100
	# DCSS stab (attack.cc:1426 player_stab_weapon_bonus +
	# fight.cc:639 find_player_stab_type + 706 stab_bonus_denom):
	#   stab_bonus = 1 for sleeping/paralysed/petrified  → full bonus
	#              = 4 for confused/distracted/fleeing/held  → quarter
	# Roll an attempt chance for the non-helpless stabs, then apply the
	# damage pipeline: DEX-scaled flat bonus on good stabs, plus a pair
	# of skill-scaled multipliers and a small random additional bonus.
	var stab_bonus: int = _find_stab_denom(defender)
	if stab_bonus > 0:
		var stab_attempt: bool = true
		if stab_bonus > 1:
			# attack.cc:1535 — chance = (wpn_skill + stealth)/2 + dex + 1.
			var wpn_half: int = 0
			var stealth_half: int = 0
			if skill_sys != null:
				wpn_half = skill_sys.get_level(attacker, weapon_skill_id) / 2 \
						if weapon_skill_id != "" else 0
				stealth_half = skill_sys.get_level(attacker, "stealth") / 2
			var atk_dex: int = attacker.stats.DEX if "stats" in attacker and attacker.stats != null else 10
			var stab_try: int = wpn_half + stealth_half + atk_dex + 1
			stab_attempt = (randi() % 100) < stab_try
		if stab_attempt:
			dmg = _apply_stab_bonus(attacker, dmg, weapon_skill_id, stab_bonus, skill_sys)
			CombatLog.add("Stab!")
	# Racial passive: naga venom bite adds a flat +1 to every melee hit.
	var race_trait: String = ""
	if "race_res" in attacker and attacker.race_res != null:
		race_trait = String(attacker.race_res.racial_trait)
	if race_trait == "naga_poison_spit":
		dmg += 1
	# Kobold sneak attack: stealth_skill_level / 3 added to damage, so the
	# kobold's stealth investment translates into a real combat bonus.
	if race_trait == "kobold_sneak" and skill_sys != null:
		var stealth_lv: int = skill_sys.get_level(attacker, "stealth")
		dmg += stealth_lv / 3
	# Ring-of-slaying / ring-of-fire flat bonus is already folded into
	# the DCSS slaying roll above (random2(1+plus)). No second add here,
	# or we'd double-count.
	# DCSS weapon brand: Scroll of Brand Weapon stamps a permanent brand
	# onto the wielded weapon; each brand adds a flat elemental proc on top
	# of the base physical damage.
	# DCSS weapon brands (item-prop-enum.h SPWPN_*). Numeric damage adds
	# pull from attack.cc::apply_damage_brand; status riders dispatch
	# via defender metas so Monster.take_damage routes them correctly.
	var brand_key: String = "_weapon_brand_" + weapon_id
	var brand_element: String = ""
	if weapon_id != "" and attacker.has_method("has_meta") and attacker.has_meta(brand_key):
		var brand: String = String(attacker.get_meta(brand_key))
		var brand_dmg: int = 0
		match brand:
			"flaming":
				brand_dmg = randi_range(1, 6)
				brand_element = "fire"
			"freezing":
				brand_dmg = randi_range(1, 6)
				brand_element = "cold"
			"electrocution":
				# DCSS: 1/4 chance of 8-20 dmg burst, else 1..4.
				if randi() % 4 == 0:
					brand_dmg = randi_range(8, 20)
				else:
					brand_dmg = randi_range(1, 4)
				brand_element = "elec"
			"venom":
				brand_dmg = randi_range(1, 4)
				if defender.has_method("apply_poison"):
					defender.apply_poison(1, "venomous weapon")
			"holy_wrath":
				brand_dmg = randi_range(2, 5) if _is_undead_or_demon(defender) else 0
				brand_element = "holy"
			"draining":
				# DCSS: 2d4 dmg + drain status on the target.
				brand_dmg = randi_range(2, 8)
				brand_element = "neg"
				if defender.has_method("set_meta"):
					defender.set_meta("_drained_turns", 15)
			"pain":
				# DCSS: +necromancy skill as damage (capped).
				var necro: int = 0
				if skill_sys != null:
					necro = skill_sys.get_level(attacker, "necromancy")
				brand_dmg = (randi() % maxi(1, necro + 1))
				brand_element = "neg"
			"distortion":
				# DCSS: random chance to blink defender / teleport / banish.
				var roll: int = randi() % 100
				if roll < 5 and defender.has_method("set_meta"):
					defender.set_meta("_banish_queued", true)  # deferred to Monster.take_damage
				elif roll < 25:
					# Random blink of the target 1-3 tiles.
					_blink_random(defender, 3)
			"protection":
				# Passive +5 AC; no per-hit bonus damage but track so the
				# status/equip screens can show the ego.
				pass
			"antimagic":
				# Burn 2 MP per hit if defender has any. Helpful vs caster
				# monsters; no effect on melee-only foes.
				if "stats" in defender and defender.stats != null \
						and "MP" in defender.stats and defender.stats.MP > 0:
					defender.stats.MP = maxi(0, defender.stats.MP - 2)
			"vorpal":
				# DCSS SPWPN_VORPAL: +25% damage on ~1/3 swings (DCSS uses
				# a weapon-type-specific roll). Good against fleshy foes.
				if randi() % 3 == 0:
					brand_dmg = dmg / 4
			"reaping":
				# DCSS: if the hit kills, 50% chance to raise a zombie.
				# Queue the intent; Monster.take_damage honours it.
				if defender.has_method("set_meta"):
					defender.set_meta("_reaping_pending", true)
			"chaos":
				# Random weapon brand each hit — pick a die-roll element
				# from the DCSS chaos pool. We don't recurse the match;
				# instead we just slap a small element-tagged bonus.
				var chaos_picks: Array = [
					{"e": "fire",  "d": 4},
					{"e": "cold",  "d": 4},
					{"e": "elec",  "d": 3},
					{"e": "poison","d": 3},
					{"e": "neg",   "d": 3},
					{"e": "holy",  "d": 3},
					{"e": "",      "d": 5},
				]
				var pick: Dictionary = chaos_picks[randi() % chaos_picks.size()]
				brand_dmg = 1 + (randi() % int(pick["d"]))
				brand_element = String(pick["e"])
		dmg += brand_dmg
	if defender.has_method("take_damage"):
		if brand_element != "":
			defender.take_damage(dmg, brand_element)
		else:
			defender.take_damage(dmg)
	var def_name: String = ""
	if "data" in defender and defender.data != null and "display_name" in defender.data:
		def_name = String(defender.data.display_name)
	if def_name != "":
		CombatLog.add("You hit the %s for %d." % [def_name, dmg])
	_show_hit_feedback(defender, dmg, Color(1.0, 1.0, 0.3))
	_show_slash_fx(defender)
	return dmg


## Player ranged attack. Walks a beam from attacker to target_pos,
## applies skill+dex-driven to-hit against the first monster in the
## path, and rolls damage through the same weapon-skill multiplier as
## melee (so training Bows past 10 halves the to-hit roll gap between
## miss and hit, just like any other weapon school).
##
## `weapon_id` must be a bow/sling/crossbow (skill == "bow"). Callers
## guard on that before entering targeting mode. `dist` is pre-computed
## Chebyshev so the range check is cheap.
##
## Range penalty (DCSS): -3 to-hit per tile past 2. Damage itself
## doesn't fall off — DCSS only penalises accuracy.
static func ranged_attack(attacker, target, target_pos: Vector2i, skill_sys = null) -> int:
	if attacker == null or target == null:
		return 0
	var weapon_id: String = ""
	if "equipped_weapon_id" in attacker:
		weapon_id = String(attacker.equipped_weapon_id)
	var weapon_skill_id: String = WeaponRegistry.weapon_skill_for(weapon_id)
	if weapon_skill_id != "bow":
		return 0
	var weapon_dmg: int = WeaponRegistry.weapon_damage_for(weapon_id)
	if "weapon_bonus_dmg" in attacker:
		weapon_dmg += int(attacker.weapon_bonus_dmg)
	var skill_lv: int = 0
	var fighting_lv: int = 0
	if skill_sys != null:
		skill_lv = skill_sys.get_level(attacker, "bow")
		fighting_lv = skill_sys.get_level(attacker, "fighting")
	# DCSS uses DEX for bow to-hit. Our Stats has DEX.
	var dex: int = 10
	if "stats" in attacker and attacker.stats != null:
		dex = attacker.stats.DEX
	var dist: int = maxi(abs(target_pos.x - attacker.grid_pos.x),
			abs(target_pos.y - attacker.grid_pos.y))
	var range_pen: int = maxi(0, (dist - 2) * 3)
	var to_hit: int = 15 + dex / 2
	to_hit += (randi() % (fighting_lv * 100 + 1)) / 100
	to_hit += (randi() % (skill_lv * 100 + 1)) / 100
	if "equipped_weapon_plus" in attacker:
		to_hit += int(attacker.equipped_weapon_plus)
	to_hit -= range_pen
	var ev: int = 0
	if "stats" in target and target.stats != null:
		ev = int(target.stats.EV)
	elif "data" in target and target.data != null:
		ev = int(target.data.ev)
	var roll: int = randi() % maxi(1, to_hit + 1)
	if roll < ev:
		var mname_miss: String = "target"
		if "data" in target and target.data != null:
			mname_miss = String(target.data.display_name)
		CombatLog.add("You miss the %s." % mname_miss)
		_show_hit_feedback(target, 0, Color(0.8, 0.8, 0.8))
		return 0
	# Damage: same pipeline as melee but using DEX as the stat input
	# (DCSS bow/thrown/sling reads DEX). Skill multiplier matches melee.
	var attr: int = dex
	var stat_mult: int = max(1, 75 + (25 * attr) / 10)
	var potential: int = max(weapon_dmg, 1) * stat_mult
	var base_damage: int = (randi() % (potential + 1)) / 100
	var w_skill_scaled: int = skill_lv * 100
	base_damage = base_damage * (2500 + (randi() % (w_skill_scaled + 1))) / 2500
	var f_skill_scaled: int = fighting_lv * 100
	base_damage = base_damage * (3000 + (randi() % (f_skill_scaled + 1))) / 3000
	var slaying: int = 0
	if "equipped_weapon_plus" in attacker:
		slaying += int(attacker.equipped_weapon_plus)
	if attacker.has_method("gear_damage_bonus"):
		slaying += int(attacker.gear_damage_bonus())
	if slaying >= 0:
		base_damage += randi() % (1 + slaying)
	else:
		base_damage -= randi() % (1 - slaying)
	var atk: int = max(1, base_damage)
	# AC soak identical to melee (random2(1+ac) + GDR).
	var def_ac: int = 0
	if "ac" in target:
		def_ac = target.ac
	elif "stats" in target and target.stats != null:
		def_ac = target.stats.AC
	var soak: int = (randi() % (def_ac + 1)) if def_ac > 0 else 0
	var dmg: int = max(1, atk - soak)
	if target.has_method("take_damage"):
		target.take_damage(dmg, "physical")
	var tname: String = "target"
	if "data" in target and target.data != null:
		tname = String(target.data.display_name)
	CombatLog.add("You shoot the %s for %d." % [tname, dmg])
	_show_hit_feedback(target, dmg, Color(1.0, 0.9, 0.4))
	return dmg


## Monster → player melee. Monsters don't have skills in M1, so this path
## keeps the legacy formula.
static func melee_attack_from_monster(m, defender) -> int:
	# DCSS-faithful damage: every attack entry on the monster rolls a
	# separate 1..damage swing, with a proper to-hit roll vs the
	# defender's EV so high-dodge mages actually evade. Multi-attack
	# beasts swing each attack with diminishing per-swing odds, matching
	# the shape of `mons_attack_spec` averages.
	var def_ac: int = 0
	var def_ev: int = 0
	if "stats" in defender and defender.stats != null:
		def_ac = defender.stats.AC
		def_ev = defender.stats.EV
	elif "ac" in defender:
		def_ac = int(defender.ac)

	var hd: int = int(m.data.hd) if m.data else 1
	# DCSS `mon_to_hit_base(hd, fighter)` = `18 + hd * (fighter ? 5 : 3) / 2`.
	# Fighter monsters (orc_warrior, knight class etc.) flagged via the
	# `fighter` entry in data.flags.
	var is_fighter: bool = false
	if m.data and "flags" in m.data:
		for f in m.data.flags:
			if String(f).to_lower() == "fighter":
				is_fighter = true
				break
	var mhit_base: int = 18 + hd * (5 if is_fighter else 3) / 2
	var atks: Array = m.data.attacks if m.data and "attacks" in m.data else []
	var total: int = 0
	var dealt_any: bool = false
	var missed_any: bool = false
	if atks.is_empty():
		# Fallback for data-less monsters: single swing vs EV.
		var to_hit: int = randi() % (mhit_base + 1)
		if to_hit >= def_ev:
			var raw_f: int = max(1, (int(m.data.str) / 2 + 3) if m.data else 3)
			total = max(0, raw_f - (randi() % (def_ac + 1)))
			dealt_any = total > 0
		else:
			missed_any = true
	else:
		for i in atks.size():
			var a: Dictionary = atks[i]
			var base: int = int(a.get("damage", 0))
			if base <= 0:
				continue
			var chance: float = 1.0 / float(1 + i)
			if i > 0 and randf() >= chance:
				continue
			# DCSS to-hit: `random2(mhit_base+1)` vs EV. Miss if roll < EV.
			var to_hit_roll: int = randi() % (mhit_base + 1)
			if to_hit_roll < def_ev:
				missed_any = true
				continue
			# Each connecting swing: 1 + random2(base), then AC soaks
			# `random2(1+AC)` (DCSS actor::apply_ac, ac_type::normal).
			var raw: int = 1 + (randi() % base)
			var soak: int = randi() % (def_ac + 1) if def_ac > 0 else 0
			var after_ac: int = max(0, raw - soak)
			if after_ac > 0:
				total += after_ac
				dealt_any = true
			var flav: String = String(a.get("flavour", ""))
			# DCSS melee-attack.cc mons_apply_attack_flavour + mon-util.cc
			# flavour_damage. Elemental flavours deal extra damage on top of
			# the physical hit, routed through the defender's resistance.
			# We collect the delta and add it below so a single take_damage
			# call carries the elemental tag for player resist scaling.
			var flav_bonus: int = 0
			var flav_element: String = ""
			match flav:
				"poison":
					if defender.has_method("apply_poison"):
						var aname: String = m.data.display_name if m.data else "the monster"
						defender.apply_poison(1, aname)
				"drain", "drain_xp":
					if defender.has_method("set_meta"):
						defender.set_meta("_drained_turns", 20)
				"fire":
					flav_bonus = hd + (randi() % maxi(1, hd))
					flav_element = "fire"
				"cold":
					flav_bonus = hd + (randi() % maxi(1, hd * 2))
					flav_element = "cold"
				"elec", "electric":
					flav_bonus = hd + (randi() % maxi(1, hd / 2 + 1))
					flav_element = "elec"
				"pure_fire":
					flav_bonus = hd * 3 / 2 + (randi() % maxi(1, hd))
					flav_element = "fire"
				"acid":
					flav_bonus = 4 + (randi() % 9)  # DCSS acid proxy
					flav_element = "acid"
				"holy":
					# AF_HOLY damages demonic/undead attackers, nothing else.
					# Our defender is always the player, so this path never
					# fires against us — logged here for completeness / future
					# monster-vs-monster melee.
					pass
				"drown":
					# AF_DROWN: HD*3/4 + random2(HD*3/4), no element resist
					# in DCSS (purely raw). We treat as physical bonus.
					flav_bonus = hd * 3 / 4 + (randi() % maxi(1, hd * 3 / 4))
					flav_element = ""
				"vampiric":
					# AF_VAMPIRIC: heal attacker for half the damage dealt
					# to defender. No elemental scaling; pure life-drain.
					if m.is_alive and "hp" in m and "data" in m and m.data != null:
						var heal: int = maxi(1, after_ac / 2)
						m.hp = mini(m.hp + heal, int(m.data.hp))
			if flav_bonus > 0 and defender.has_method("take_damage"):
				# Apply the elemental rider now with its own resist routing so
				# rF+/rC+ scale the bonus before it's added to the physical
				# total. The caller's single take_damage below applies AC-
				# resisted physical on its own.
				var bonus_after: int = flav_bonus
				if defender.has_method("_apply_elem_resist"):
					bonus_after = int(defender._apply_elem_resist(flav_bonus, flav_element))
				total += bonus_after
				if bonus_after > 0:
					dealt_any = true

	# DCSS attack.cc: every connecting swing deals at least 1 HP when some
	# hit landed (the "glancing hit" floor). If every connecting hit was
	# fully AC-soaked, take 1. If every swing missed entirely, take 0.
	if total > 0:
		dealt_any = true
	if not dealt_any:
		if missed_any:
			var atk_name_m: String = m.data.display_name if m.data else "monster"
			CombatLog.add("The %s misses you!" % atk_name_m)
			return 0
		total = 1  # glancing hit fallback (all connected but soaked)

	var def_trait: String = ""
	if "trait_res" in defender and defender.trait_res != null:
		def_trait = defender.trait_res.special
	if def_trait == "iron_will" and randf() < 0.3:
		total = max(1, total / 2)
	var hp_before: int = 0
	if "stats" in defender and defender.stats != null:
		hp_before = int(defender.stats.HP)
	if defender.has_method("take_damage"):
		defender.take_damage(total)
	var hp_after: int = 0
	if "stats" in defender and defender.stats != null:
		hp_after = int(defender.stats.HP)
	var atk_name: String = ""
	if "data" in m and m.data != null and "display_name" in m.data:
		atk_name = String(m.data.display_name)
	if atk_name != "":
		var real_dealt: int = hp_before - hp_after
		CombatLog.add("The %s hits you for %d! (%d→%d)" % [atk_name, total, hp_before, hp_after])
		# Diag: if the log damage doesn't match HP delta we know whether it's
		# the compute or the apply that's eating the hit.
		if real_dealt != total:
			print("[monster-melee] %s: rolled=%d applied=%d (hp %d→%d)" % \
					[atk_name, total, real_dealt, hp_before, hp_after])
	_show_hit_feedback(defender, total, Color(1.0, 0.3, 0.3))
	_show_slash_fx(defender)
	return total


## Port of fight.cc::find_player_stab_type + stab_bonus_denom. Returns:
##   0  — no stab possible (standard hit)
##   1  — "good stab" (sleeping / paralysed / petrified): full bonus
##   4  — "bad stab" (confused / petrifying / held / fleeing):
##        quarter bonus. DCSS also includes distracted/invisible/blind,
##        which we fold into "confused" until we model those conditions.
static func _find_stab_denom(defender) -> int:
	if defender == null or not defender.has_method("has_meta"):
		return 0
	if "is_sleeping" in defender and defender.is_sleeping:
		return 1
	if defender.has_meta("_paralysis_turns"):
		return 1
	if defender.has_meta("_petrified_turns"):
		# DCSS: petrified is full stab (1), petrifying is partial (4).
		# We don't track the in-progress state separately yet; treat the
		# metadata as "petrified".
		return 1
	if defender.has_meta("_confused"):
		return 4
	if defender.has_meta("_net_turns"):
		return 4
	if defender.has_meta("_fleeing_turns"):
		return 4
	return 0


## DCSS attack.cc:1426 player_stab_weapon_bonus.
##   stab_skill = wpn_skill*50 + stealth_skill*50
##   good_stab  = (stab_bonus == 1)
##   if good_stab:
##       bonus = dex * (stab_skill + 100) / (dagger ? 500 : 1000)
##       bonus = stepdown(bonus, 10, max=30)          # capped growth
##       damage += bonus
##       damage *= 10 + stab_skill / (100 * stab_bonus)
##       damage /= 10
##   damage *= 12 + stab_skill / (100 * stab_bonus)
##   damage /= 12
##   damage += random2(stab_skill / (200 * stab_bonus))
static func _apply_stab_bonus(attacker, damage: int, wpn_skill_id: String, stab_bonus: int, skill_sys) -> int:
	if damage <= 0:
		damage = 1
	var wpn_lv: int = 0
	var stealth_lv: int = 0
	if skill_sys != null:
		if wpn_skill_id != "":
			wpn_lv = skill_sys.get_level(attacker, wpn_skill_id)
		stealth_lv = skill_sys.get_level(attacker, "stealth")
	var stab_skill: int = wpn_lv * 50 + stealth_lv * 50
	if stab_bonus <= 0:
		return damage
	if stab_bonus == 1:
		var dex: int = 10
		if "stats" in attacker and attacker.stats != null:
			dex = int(attacker.stats.DEX)
		# DCSS dagger divisor 500 vs 1000 for other short_blades.
		var divisor: int = 1000
		if wpn_skill_id == "short_blade" and "equipped_weapon_id" in attacker:
			if String(attacker.equipped_weapon_id) == "dagger":
				divisor = 500
		var bonus: int = dex * (stab_skill + 100) / divisor
		# DCSS stepdown_value(bonus, stepping=10, first_step=10, ceiling=30).
		bonus = _stab_stepdown(bonus, 10, 10, 30)
		damage += bonus
		damage = damage * (10 + stab_skill / (100 * stab_bonus)) / 10
	damage = damage * (12 + stab_skill / (100 * stab_bonus)) / 12
	var tail_range: int = stab_skill / (200 * stab_bonus)
	if tail_range > 0:
		damage += randi() % tail_range
	return damage


## Simplified stepdown matching DCSS stepdown_value(bonus, step=first_step=stepping, ceiling).
## For our usage (bonus, 10, 10, 30): when bonus ≤ 10 passes through, above
## 10 it's log-compressed, ceiling at 30. Sufficient for the stab flat bonus
## which rarely exceeds 30 even with maxed DEX + skill.
static func _stab_stepdown(value: int, stepping: int, first_step: int, ceiling: int) -> int:
	if value <= first_step:
		return value
	if ceiling > 0 and value > ceiling:
		value = ceiling
	# step * log2(1 + (v-(first_step-step))/step). first_step=stepping=10 →
	# (value - 0)/10 = value/10 → step * log2(1 + value/step).
	var over: float = float(value - (first_step - stepping))
	var stepped: float = float(stepping) * log(1.0 + over / float(stepping)) / log(2.0)
	var out: int = int(stepped)
	if ceiling > 0 and out > ceiling:
		out = ceiling
	return out


## Blink a defender to a random walkable tile within `radius` Chebyshev.
## Used by the DCSS distortion brand — on a roll the target flashes
## somewhere safe nearby. Silent no-op if no free tile is found.
static func _blink_random(defender, radius: int) -> void:
	if defender == null or not ("grid_pos" in defender) \
			or not ("generator" in defender) or defender.generator == null:
		return
	var candidates: Array[Vector2i] = []
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var cell: Vector2i = defender.grid_pos + Vector2i(dx, dy)
			if defender.generator.is_walkable(cell):
				candidates.append(cell)
	if candidates.is_empty():
		return
	var dest: Vector2i = candidates[randi() % candidates.size()]
	defender.grid_pos = dest
	if "position" in defender:
		defender.position = Vector2(dest.x * 32 + 16, dest.y * 32 + 16)


## DCSS player::gdr_perc (player.cc:6620): `16 * sqrt(sqrt(ac))`.
## Returns a percentage (0..100). Applies to any actor with an AC stat;
## monsters get 0 until we wire the monster-armour table.
static func _gdr_percent(actor) -> int:
	var ac: int = 0
	if actor == null:
		return 0
	if "stats" in actor and actor.stats != null:
		ac = int(actor.stats.AC)
	elif "ac" in actor:
		ac = int(actor.ac)
	if ac <= 0:
		return 0
	return int(16.0 * sqrt(sqrt(float(ac))))


static func _show_hit_feedback(target: Node, dmg: int, color: Color) -> void:
	if target == null or not is_instance_valid(target):
		return
	if not (target is Node2D):
		return
	var target_2d: Node2D = target as Node2D
	# Flash white — quicker pop so it doesn't blur the glyph in ASCII mode.
	var prev_mod: Color = target_2d.modulate
	target_2d.modulate = Color(3.0, 3.0, 3.0, 1.0)
	var tw: Tween = target_2d.create_tween()
	tw.tween_property(target_2d, "modulate", prev_mod, 0.15)
	# Brief shake proportional to damage — capped so small hits don't twitch.
	_apply_hit_shake(target_2d, dmg)
	# Floating damage number — size scales with damage, colour shifts red as
	# the hit gets heavier so big numbers read at a glance.
	var label := Label.new()
	label.text = str(dmg)
	var font_size: int
	var text_color: Color
	if dmg >= 40:
		font_size = 72
		text_color = Color(1.0, 0.3, 0.25)
	elif dmg >= 20:
		font_size = 60
		text_color = Color(1.0, 0.55, 0.25)
	elif dmg >= 8:
		font_size = 52
		text_color = color
	else:
		font_size = 44
		text_color = color.lightened(0.15)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", text_color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	label.add_theme_constant_override("outline_size", 4)
	label.position = Vector2(-20, -32)
	label.z_index = 100
	target_2d.add_child(label)
	var rise_px: float = 60.0 + clamp(float(dmg) * 1.2, 0.0, 40.0)
	var duration: float = 0.85
	var tw2: Tween = label.create_tween()
	tw2.tween_property(label, "position:y", label.position.y - rise_px, duration) \
			.set_ease(Tween.EASE_OUT)
	tw2.parallel().tween_property(label, "modulate:a", 0.0, duration) \
			.set_delay(duration * 0.35)
	tw2.tween_callback(label.queue_free)


## Horizontal jitter on the target Node2D proportional to damage.
##
## Skipped for the player: Player.position is being driven by the move
## tween most frames, and layering a second position tween on top fights
## the walk interpolation — end-of-shake would snap the sprite back to
## the pre-hit tile, which read as a "knockback". The player already
## gets camera shake on damage, so the per-entity shake is cosmetic
## redundancy anyway. Monsters still shake normally.
static func _apply_hit_shake(target: Node2D, dmg: int) -> void:
	if target is Player:
		return
	var amplitude: float = clamp(float(dmg) * 0.5, 3.0, 10.0)
	var base: Vector2 = target.position
	var tw: Tween = target.create_tween()
	tw.tween_property(target, "position", base + Vector2(amplitude, 0), 0.04)
	tw.tween_property(target, "position", base + Vector2(-amplitude, 0), 0.04)
	tw.tween_property(target, "position", base + Vector2(amplitude * 0.5, 0), 0.04)
	tw.tween_property(target, "position", base, 0.04)


static func _show_slash_fx(target: Node) -> void:
	if target == null or not is_instance_valid(target) or not (target is Node2D):
		return
	var fx := Node2D.new()
	fx.z_index = 99
	(target as Node2D).add_child(fx)
	fx.set_script(_SlashDraw)
	var tw: Tween = fx.create_tween()
	tw.tween_property(fx, "modulate:a", 0.0, 0.15)
	tw.tween_callback(fx.queue_free)


class _SlashDraw extends Node2D:
	func _draw() -> void:
		var sz: float = 14.0
		# Diagonal slash lines
		draw_line(Vector2(-sz, -sz), Vector2(sz, sz), Color(1.0, 1.0, 1.0, 0.9), 2.5, true)
		draw_line(Vector2(sz, -sz), Vector2(-sz, sz), Color(1.0, 1.0, 1.0, 0.7), 2.0, true)
		# Short cross cuts
		draw_line(Vector2(-sz * 0.5, 0), Vector2(sz * 0.5, 0), Color(1.0, 1.0, 0.8, 0.6), 1.5, true)
