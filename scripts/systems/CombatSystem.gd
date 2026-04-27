class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills stubbed at 0; full formula with
## weapon skill / brands lands with SkillSystem (Week 2).

const UNARMED_DAMAGE: int = 2
const BACKSTAB_BASE_BONUS: float = 0.5
const BACKSTAB_PER_AGILITY: float = 0.05
const BACKSTAB_ROGUE_BONUS: float = 0.25
const BACKSTAB_DAGGER_BONUS: float = 0.25
const BACKSTAB_MAX_BONUS: float = 1.0
const XP_PACE_MULTIPLIER: float = 1.35

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	var stat_source: int = player.strength
	var stat_scale: float = 0.35
	var skill_id: String = "melee"
	var weapon: ItemData = null
	var weapon_plus: int = 0
	var req_hit_pen: int = 0
	var req_dmg_pct: float = 1.0
	if player.equipped_weapon_id != "":
		weapon = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if weapon != null:
			var entry: Dictionary = player.equipped_weapon_entry()
			weapon_plus = int(entry.get("plus", 0))
			weapon_dmg = max(UNARMED_DAMAGE, weapon.damage + weapon_plus)
			if weapon.category == "ranged":
				skill_id = "ranged"
				stat_source = player.dexterity
				stat_scale = 0.25
			elif weapon.category == "staff":
				skill_id = "magic"
				stat_source = player.intelligence
				stat_scale = 0.25
			elif weapon.category == "dagger":
				skill_id = "melee"
				stat_source = player.dexterity
				stat_scale = 0.25
			else:
				skill_id = "melee"
			var pen: Dictionary = _weapon_req_penalty(player, weapon)
			req_hit_pen = pen.hit
			req_dmg_pct = pen.dmg_pct
	var stat_bonus: int = stat_source / 3
	var skill_level: int = 0
	if skill_id != "":
		skill_level = player.get_skill_level(skill_id)
	var to_hit_base: int = 20 + stat_bonus + skill_level + weapon_plus + req_hit_pen
	var to_hit_roll: int = randi_range(0, to_hit_base)
	var eff_ev: int = max(0, monster.data.ev - (2 if Status.has(monster, "drained") else 0))
	if to_hit_roll < eff_ev:
		monster.become_aware(player.grid_pos)
		CombatLog.miss("You miss the %s." % monster.data.display_name)
		return
	var raw: int = weapon_dmg + int(float(stat_source) * stat_scale) + randi_range(0, 3)
	if req_dmg_pct < 1.0:
		raw = max(1, int(float(raw) * req_dmg_pct))
	if Status.has(player, "damage_boost"):
		raw += randi_range(1, 4)
	var eff_ac: int = max(0, monster.data.ac - (2 if Status.has(monster, "corroded") else 0))
	var soak: int = randi_range(0, eff_ac + 1)
	var base_final: int = max(1, raw - soak)
	var mult: float = 1.0 + float(skill_level) * 0.04
	# Tempest: ranged attacks deal +15%
	if skill_id == "ranged":
		mult *= EssenceSystem.ranged_damage_mult(player)
		mult *= FaithSystem.ranged_damage_mult(player)
	var final: int = max(1, int(round(float(base_final) * mult)))
	# Faith melee damage mult (War +10%, Arcana -10%)
	if skill_id == "melee" or skill_id == "":
		final = max(1, int(round(float(final) * FaithSystem.melee_damage_mult(player))))
	final += player.get_skill_level("melee") / 2
	final += RacePassiveSystem.melee_damage_bonus(player)
	var backstab_bonus: int = _backstab_bonus(player, monster, weapon, weapon_plus)
	final += backstab_bonus
	# Gloam: first strike on unaware target deals +35% damage
	if not monster.is_aware:
		var uw_mult: float = EssenceSystem.unaware_damage_mult(player)
		if uw_mult > 1.0:
			final = max(1, int(round(float(final) * uw_mult)))
	# Plague: +20% damage vs. poisoned targets
	if player.essence_slots.has("essence_plague") and Status.has(monster, "poison"):
		final = max(1, int(round(float(final) * 1.2)))
	var brand: String = _weapon_brand(player)
	var brand_extra: int = 0
	if brand != "":
		var brand_element: String = brand_element_of(brand)
		var roll: int = _brand_damage_roll(brand)
		brand_extra = Status.resist_scale(roll, monster.data.resists,
			brand_element)
		# Death faith: necro damage +15%
		if brand_element == "necro":
			brand_extra = max(1, int(round(float(brand_extra) * FaithSystem.necrotic_damage_mult(player))))
		final += brand_extra
	CombatLog.hit(_hit_log(monster.data.display_name, brand, final, brand_extra, backstab_bonus))
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	monster.become_aware(player.grid_pos)
	if brand != "" and brand_extra > 0 and monster.hp > 0:
		_apply_brand_status(monster, brand)
		if brand == "drain" and brand_extra > 0:
			var vamp_heal: int = max(1, brand_extra / 2)
			player.heal(vamp_heal)
	if monster.hp > 0 and EssenceSystem.has_venom_touch(player):
		Status.apply(monster, "poison", 3)
	if monster.hp > 0 and EssenceSystem.has_drain_touch(player):
		var drain_hp: int = 2
		monster.take_damage(drain_hp)
		player.heal(drain_hp)
	if monster.hp > 0:
		EssenceSystem.apply_melee_hit_effects(player, monster)
	# Cleave: axes hit adjacent monsters as a small splash.
	if weapon != null and weapon.category == "axe":
		_cleave_hit(player, monster, final)
	# Swift Strike: dagger gives chance to attack again (melee skill drives chance)
	if skill_id == "melee" and monster.hp > 0:
		var w_check: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if w_check != null and w_check.category == "dagger":
			var swift_chance: float = player.get_skill_level("melee") * 0.05
			if swift_chance > 0.0 and randf() < swift_chance:
				CombatLog.hit("Swift strike!")
				_dagger_swift_strike(player, monster)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		var xp_award: int = max(1, int(round(float(monster.data.xp_value) * XP_PACE_MULTIPLIER)))
		player.grant_xp(xp_award)
		player.grant_kill_skill_xp(float(xp_award), skill_id)
		player.register_kill()
		GameManager.try_kill_unlock(monster.data.id)
		RacePassiveSystem.on_player_killed_monster(player)
		EssenceSystem.apply_on_kill_effects(player)

static func _cleave_hit(player: Player, primary: Monster, base_dmg: int) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var cleave_dmg: int = max(1, base_dmg / 2)
	for node in tree.get_nodes_in_group("monsters"):
		if not (node is Monster):
			continue
		var m: Monster = node as Monster
		if m == primary or m.hp <= 0:
			continue
		var dist: int = max(abs(m.grid_pos.x - player.grid_pos.x),
				abs(m.grid_pos.y - player.grid_pos.y))
		if dist <= 1:
			CombatLog.hit("Cleave hits the %s for %d." % [m.data.display_name, cleave_dmg])
			m.take_damage(cleave_dmg)

static func _dagger_swift_strike(player: Player, monster: Monster) -> void:
	if monster.hp <= 0 or monster.data == null:
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	if player.equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if w != null:
			var entry: Dictionary = player.equipped_weapon_entry()
			var wplus: int = int(entry.get("plus", 0))
			weapon_dmg = max(UNARMED_DAMAGE, w.damage + wplus)
	var stat_bonus: int = player.dexterity / 3
	var raw: int = weapon_dmg + randi_range(0, 2)
	var eff_ac2: int = max(0, monster.data.ac - (2 if Status.has(monster, "corroded") else 0))
	var soak: int = randi_range(0, eff_ac2 + 1)
	var final: int = max(1, raw - soak)
	CombatLog.hit("You hit the %s for %d." % [monster.data.display_name, final])
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	monster.become_aware(player.grid_pos)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		var xp_award: int = max(1, int(round(float(monster.data.xp_value) * XP_PACE_MULTIPLIER)))
		player.grant_xp(xp_award)
		player.grant_kill_skill_xp(float(xp_award), "melee")
		player.register_kill()
		GameManager.try_kill_unlock(monster.data.id)

static func _weapon_brand(player: Player) -> String:
	if player.equipped_weapon_id == "":
		return ""
	# Runtime brand from item dict takes precedence
	for entry in player.items:
		if String(entry.get("id", "")) == player.equipped_weapon_id:
			var rb: String = String(entry.get("brand", ""))
			if rb != "":
				return rb
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	if w == null:
		return ""
	return String(w.brand)

static func _armor_brand(player: Player) -> String:
	if player.equipped_armor_id == "":
		return ""
	for entry in player.items:
		if String(entry.get("id", "")) == player.equipped_armor_id:
			var rb: String = String(entry.get("brand", ""))
			if rb != "":
				return rb
	return ""

static func _apply_armor_brand_retaliation(player: Player, monster: Monster) -> void:
	var brand: String = _armor_brand(player)
	if brand == "" or monster.hp <= 0:
		return
	if randf() >= 0.20:
		return
	match brand:
		"venom":
			Status.apply(monster, "poison", 3)
			CombatLog.post("Your armor's venom lashes back!", Color(0.4, 1.0, 0.4))
		"freezing":
			Status.apply(monster, "frozen", 1)
			CombatLog.post("Your armor freezes the attacker!", Color(0.5, 0.85, 1.0))
		"flaming":
			Status.apply(monster, "burning", 2)
			CombatLog.post("Your armor burns the attacker!", Color(1.0, 0.55, 0.2))
		"acid":
			Status.apply(monster, "corroded", 3)
			CombatLog.post("Your armor corrodes the attacker!", Color(0.6, 0.85, 0.3))
		"drain":
			Status.apply(monster, "drained", 3)
			CombatLog.post("Your armor drains the attacker!", Color(0.55, 0.35, 0.8))

static func brand_element_of(brand: String) -> String:
	match brand:
		"flaming":  return "fire"
		"freezing": return "cold"
		"venom":    return "poison"
		"electric": return "electric"
		"draining": return "necro"
		"drain":    return "necro"
		"acid":     return "acid"
	return ""

static func _brand_damage_roll(brand: String) -> int:
	match brand:
		"venom":   return randi_range(1, 3)
		"electric": return randi_range(1, 6)
		"acid":     return randi_range(1, 4)
		_:         return randi_range(1, 4)

static func _weapon_req_penalty(player: Player, w: ItemData) -> Dictionary:
	var req: int = w.required_skill
	if req == 0:
		return {"hit": 0, "dmg_pct": 1.0}
	var mapped_skill: String
	if w.category == "ranged":
		mapped_skill = "ranged"
	elif w.category == "staff":
		mapped_skill = "magic"
	else:
		mapped_skill = "melee"
	var skill_lv: int = player.get_skill_level(mapped_skill)
	var missing: int = max(0, req - skill_lv)
	if missing == 0:
		return {"hit": 0, "dmg_pct": 1.0}
	return {
		"hit": missing * -2,
		"dmg_pct": max(0.3, 1.0 - float(missing) * 0.05),
	}

static func _apply_brand_status(target: Monster, brand: String) -> void:
	match brand:
		"flaming":  Status.apply(target, "burning", 2)
		"freezing": Status.apply(target, "frozen", 1)
		"venom":    Status.apply(target, "poison", 3)
		"acid":     Status.apply(target, "corroded", 3)
		"drain":    Status.apply(target, "drained", 3)

static func _hit_log(name: String, brand: String, total: int, extra: int,
		backstab_bonus: int = 0) -> String:
	var suffix: String = ""
	if backstab_bonus > 0:
		suffix = " Ambush! (+%d)" % backstab_bonus
	if brand == "" or extra <= 0:
		return "You hit the %s for %d.%s" % [name, total, suffix]
	match brand:
		"flaming":
			return "You torch the %s for %d (+%d fire).%s" % [name, total, extra, suffix]
		"freezing":
			return "You chill the %s for %d (+%d cold).%s" % [name, total, extra, suffix]
		"venom":
			return "You envenom the %s for %d (+%d poison).%s" % [name, total, extra, suffix]
		"electric":
			return "You shock the %s for %d (+%d electric).%s" % [name, total, extra, suffix]
		"draining":
			return "You drain the %s for %d (+%d).%s" % [name, total, extra, suffix]
		"acid":
			return "You corrode the %s for %d (+%d acid).%s" % [name, total, extra, suffix]
		"drain":
			return "You drain the %s for %d (+%d necro).%s" % [name, total, extra, suffix]
	return "You hit the %s for %d (+%d).%s" % [name, total, extra, suffix]

static func _backstab_bonus(player: Player, monster: Monster, weapon: ItemData,
		weapon_plus: int) -> int:
	if monster == null or monster.is_aware:
		return 0
	var bonus_mult: float = BACKSTAB_BASE_BONUS
	bonus_mult += float(player.get_skill_level("agility")) * BACKSTAB_PER_AGILITY
	var cls: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
	if cls != null and cls.class_group == "rogue":
		bonus_mult += BACKSTAB_ROGUE_BONUS
	if weapon != null and weapon.category == "dagger":
		bonus_mult += BACKSTAB_DAGGER_BONUS
	bonus_mult = min(BACKSTAB_MAX_BONUS, bonus_mult)
	var base_damage: int = UNARMED_DAMAGE
	if weapon != null:
		base_damage = max(base_damage, weapon.damage + weapon_plus)
	return max(1, int(round(float(base_damage) * bonus_mult)))

static func monster_ranged_attack_player(monster: Monster, player: Player,
		ra: Dictionary) -> void:
	if player.hp <= 0:
		return
	var dmg_base: int = int(ra.get("damage", 2))
	var verb: String = String(ra.get("verb", "shoots"))
	var to_hit_base: int = 15 + monster.data.hd
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < player.ev:
		CombatLog.miss("The %s %s at you and misses." \
				% [monster.data.display_name, verb])
		return
	# Shield block (ranged)
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		var _sh: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id)
		if _sh != null:
			var _shield_skill: int = player.get_skill_level("defense")
			var _missing_sh: int = max(0, _sh.required_skill - _shield_skill)
			var block_pct: float = float(_sh.effect_value) / 100.0 \
				+ _shield_skill * 0.03 \
				- _missing_sh * 0.04
			if randf() < block_pct:
				CombatLog.miss("You block the %s's attack!" % monster.data.display_name)
				return
	var raw: int = randi_range(1, max(1, dmg_base))
	var soak: int = randi_range(0, player.ac + 1)
	var final: int = max(1, raw - soak)
	final = max(1, final - EssenceSystem.incoming_damage_reduction(player))
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken("The %s %s you for %d." \
			% [monster.data.display_name, verb, final])
	player.take_damage(final, monster.data.id)
	if player.hp > 0:
		_apply_armor_brand_retaliation(player, monster)

static func monster_attack_player(monster: Monster, player: Player) -> void:
	if monster.data == null or player.hp <= 0:
		return
	var attack: Dictionary = {}
	if not monster.data.attacks.is_empty():
		attack = monster.data.attacks[0]
	var dmg_base: int = int(attack.get("damage", 1))

	var eff_ev: int = player.ev + (3 if Status.has(player, "blur") else 0)
	var to_hit_base: int = 15 + monster.data.hd
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < eff_ev:
		CombatLog.miss("The %s misses you." % monster.data.display_name)
		return
	# Shield block
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		var _sh: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id)
		if _sh != null:
			var _shield_skill: int = player.get_skill_level("defense")
			var _missing_sh: int = max(0, _sh.required_skill - _shield_skill)
			var block_pct: float = float(_sh.effect_value) / 100.0 \
				+ _shield_skill * 0.03 \
				- _missing_sh * 0.04
			if randf() < block_pct:
				CombatLog.miss("You block the %s's attack!" % monster.data.display_name)
				return
	# Parry: blade weapon skill gives chance to halve damage
	if player.equipped_weapon_id != "":
		var _wp: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if _wp != null and _wp.category == "blade":
			var parry_chance: float = player.get_skill_level("melee") * 0.03
			if parry_chance > 0.0 and randf() < parry_chance:
				CombatLog.miss("You parry the %s's attack!" % monster.data.display_name)
				return
	var dmg_lo: int = max(1, dmg_base * 3 / 5)
	var dmg_hi: int = max(dmg_lo, dmg_base * 3 / 2)
	var raw: int = randi_range(dmg_lo, dmg_hi) + monster.data.hd / 2
	var soak: int = randi_range(0, player.ac + 1)
	if Status.has(player, "stoneskin"):
		soak += randi_range(2, 5)
	var final: int = max(1, raw - soak)
	final = max(1, final - EssenceSystem.incoming_damage_reduction(player))
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken("The %s hits you for %d." % [monster.data.display_name, final])
	player.take_damage(final, monster.data.id)
	if player.hp > 0:
		_apply_armor_brand_retaliation(player, monster)
	var poison_turns: int = int(attack.get("poison_turns", 0))
	if poison_turns > 0 and player.hp > 0:
		player.apply_status("poison", poison_turns)
		CombatLog.damage_taken("You are poisoned.")
