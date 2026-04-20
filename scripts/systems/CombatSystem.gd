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
	# Flat bonuses from the equipped weapon's own enchant level + any
	# legacy whole-player weapon_bonus_dmg field (kept for essences).
	if "equipped_weapon_plus" in attacker:
		weapon_dmg += int(attacker.equipped_weapon_plus)
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

	var weapon_skill_id: String = WeaponRegistry.weapon_skill_for(weapon_id)
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
	if trait_special == "fierce" or trait_special == "minotaur_headbutt":
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
	# DCSS stab mechanic: attacking sleeping / paralysed / petrified /
	# mesmerised / confused / held targets multiplies damage. Short-
	# blades benefit most (4× vs the standard 1.5×) matching DCSS's
	# stab classifications. Wakes the target as a side effect.
	if defender.has_method("has_meta"):
		var stabbable: bool = false
		if "is_sleeping" in defender and defender.is_sleeping:
			stabbable = true
		if defender.has_meta("_paralysis_turns") or defender.has_meta("_petrified_turns") \
				or defender.has_meta("_confused"):
			stabbable = true
		if stabbable:
			var stab_mult: float = 1.5
			if weapon_skill_id == "short_blade":
				stab_mult = 4.0
			elif weapon_skill_id == "long_blade":
				stab_mult = 2.0
			dmg = int(dmg * stab_mult)
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
	# Flat damage bonus from rings of slaying / ring of fire / etc.
	if attacker.has_method("gear_damage_bonus"):
		dmg += int(attacker.gear_damage_bonus())
	# DCSS weapon brand: Scroll of Brand Weapon stamps a permanent brand
	# onto the wielded weapon; each brand adds a flat elemental proc on top
	# of the base physical damage.
	var brand_key: String = "_weapon_brand_" + weapon_id
	if weapon_id != "" and attacker.has_method("has_meta") and attacker.has_meta(brand_key):
		var brand: String = String(attacker.get_meta(brand_key))
		var brand_dmg: int = 0
		match brand:
			"flaming":        brand_dmg = randi_range(1, 6)
			"freezing":       brand_dmg = randi_range(1, 6)
			"electrocution":  brand_dmg = randi_range(1, 4) * (2 if randi() % 4 == 0 else 1)
			"venom":          brand_dmg = randi_range(1, 4)
			"holy_wrath":     brand_dmg = randi_range(2, 5) if _is_undead_or_demon(defender) else 0
		dmg += brand_dmg
	if defender.has_method("take_damage"):
		defender.take_damage(dmg)
	var def_name: String = ""
	if "data" in defender and defender.data != null and "display_name" in defender.data:
		def_name = String(defender.data.display_name)
	if def_name != "":
		CombatLog.add("You hit the %s for %d." % [def_name, dmg])
	_show_hit_feedback(defender, dmg, Color(1.0, 1.0, 0.3))
	_show_slash_fx(defender)
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
			match flav:
				"poison":
					if defender.has_method("set_meta"):
						defender.set_meta("_poison_turns", 5)
						defender.set_meta("_poison_dmg", max(1, base / 4))
				"drain", "drain_xp":
					if defender.has_method("set_meta"):
						defender.set_meta("_drained_turns", 20)
				"fire":
					pass

	if not dealt_any:
		if missed_any:
			var atk_name_m: String = m.data.display_name if m.data else "monster"
			CombatLog.add("The %s misses you!" % atk_name_m)
			return 0
		total = 1  # glancing hit fallback

	var def_trait: String = ""
	if "trait_res" in defender and defender.trait_res != null:
		def_trait = defender.trait_res.special
	if def_trait == "iron_will" and randf() < 0.3:
		total = max(1, total / 2)
	if defender.has_method("take_damage"):
		defender.take_damage(total)
	var atk_name: String = ""
	if "data" in m and m.data != null and "display_name" in m.data:
		atk_name = String(m.data.display_name)
	if atk_name != "":
		CombatLog.add("The %s hits you for %d!" % [atk_name, total])
	_show_hit_feedback(defender, total, Color(1.0, 0.3, 0.3))
	_show_slash_fx(defender)
	return total


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
