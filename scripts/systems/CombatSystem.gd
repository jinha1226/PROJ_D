class_name CombatSystem extends Node
## M1 combat. DCSS-inspired formula with skill system integration:
##   damage = max(1, ATK - effective_AC + rand(-2, 2))
## where
##   ATK = int(weapon_dmg * (1 + weapon_skill/20)) + STR/2 + fighting_skill/4
##   effective_AC = defender.ac + armour_skill/4

const UNARMED_DAMAGE: int = 3


static func roll_damage(attacker_atk: int, defender_ac: int) -> int:
	return max(1, attacker_atk - defender_ac + randi_range(-2, 2))


## Player → defender melee. `skill_sys` is a SkillSystem instance; if null,
## skills contribute 0 (useful for pre-init / test paths). Returns damage.
static func melee_attack(attacker, defender, skill_sys = null) -> int:
	var weapon_id: String = ""
	if "equipped_weapon_id" in attacker:
		weapon_id = String(attacker.equipped_weapon_id)

	var weapon_dmg: int = UNARMED_DAMAGE
	if weapon_id != "" and WeaponRegistry.is_weapon(weapon_id):
		weapon_dmg = WeaponRegistry.weapon_damage_for(weapon_id)
	# Scroll of Enchant Weapon stacks: attacker.weapon_bonus_dmg adds directly.
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

	var atk: int = int(weapon_dmg * (1.0 + float(weapon_skill_level) / 20.0)) \
			+ base_stat_atk + fighting_level / 4

	var def_ac: int = 0
	if "ac" in defender:
		def_ac = defender.ac
	elif "stats" in defender and defender.stats != null:
		def_ac = defender.stats.AC
	# Vulnerability (from Scroll of Vulnerability) strips half AC.
	if defender.has_method("has_meta") and defender.has_meta("_vuln_turns"):
		def_ac = def_ac / 2

	# Defender armour skill bonus (monsters don't have one; safe 0 fallback).
	var armour_skill_level: int = 0
	if skill_sys != null and defender.has_method("get_current_weapon_skill"):
		# Heuristic: only players expose skill sheets we manage.
		armour_skill_level = skill_sys.get_level(defender, "armour")
	var effective_ac: int = def_ac + armour_skill_level / 4

	var dmg: int = roll_damage(atk, effective_ac)
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
	var base_atk: int = int(m.data.str) / 2 + 3
	var def_ac: int = 0
	if "stats" in defender and defender.stats != null:
		def_ac = defender.stats.AC
	elif "ac" in defender:
		def_ac = int(defender.ac)
	var dmg: int = roll_damage(base_atk, def_ac)
	var def_trait: String = ""
	if "trait_res" in defender and defender.trait_res != null:
		def_trait = defender.trait_res.special
	if def_trait == "iron_will" and randf() < 0.3:
		dmg = max(1, dmg / 2)
	if defender.has_method("take_damage"):
		defender.take_damage(dmg)
	var atk_name: String = ""
	if "data" in m and m.data != null and "display_name" in m.data:
		atk_name = String(m.data.display_name)
	if atk_name != "":
		CombatLog.add("The %s hits you for %d!" % [atk_name, dmg])
	_show_hit_feedback(defender, dmg, Color(1.0, 0.3, 0.3))
	_show_slash_fx(defender)
	return dmg


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


## Horizontal jitter on the target Node2D proportional to damage. Keeps the
## original position via a Tween so concurrent movement tweens on the entity
## aren't clobbered (we restore to the end-of-shake baseline).
static func _apply_hit_shake(target: Node2D, dmg: int) -> void:
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
