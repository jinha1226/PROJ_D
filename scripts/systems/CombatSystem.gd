class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills stubbed at 0; full formula with
## weapon skill / brands lands with SkillSystem (Week 2).

const UNARMED_DAMAGE: int = 2

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	var stat_source: int = player.strength
	var stat_scale: float = 0.35
	var skill_id: String = ""
	var weapon_plus: int = 0
	var req_hit_pen: int = 0
	var req_dmg_pct: float = 1.0
	if player.equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if w != null:
			var entry: Dictionary = player.equipped_weapon_entry()
			weapon_plus = int(entry.get("plus", 0))
			weapon_dmg = max(UNARMED_DAMAGE, w.damage + weapon_plus)
			skill_id = w.category
			if w.category == "dagger" or w.category == "ranged":
				stat_source = player.dexterity
				stat_scale = 0.25
			var pen: Dictionary = _weapon_req_penalty(player, w)
			req_hit_pen = pen.hit
			req_dmg_pct = pen.dmg_pct
	var stat_bonus: int = stat_source / 3
	var skill_level: int = 0
	if skill_id != "":
		skill_level = player.get_skill_level(skill_id)
	var to_hit_base: int = 15 + stat_bonus + skill_level + weapon_plus + req_hit_pen
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < monster.data.ev:
		CombatLog.miss("You miss the %s." % monster.data.display_name)
		return
	var raw: int = weapon_dmg + int(float(stat_source) * stat_scale) + randi_range(0, 3)
	if req_dmg_pct < 1.0:
		raw = max(1, int(float(raw) * req_dmg_pct))
	if Status.has(player, "damage_boost"):
		raw += randi_range(1, 4)
	var soak: int = randi_range(0, monster.data.ac + 1)
	var base_final: int = max(1, raw - soak)
	var mult: float = 1.0 + float(skill_level) * 0.04
	var final: int = max(1, int(round(float(base_final) * mult)))
	final += player.get_skill_level("fighting") / 2
	final += RacePassiveSystem.melee_damage_bonus(player)
	var brand: String = _weapon_brand(player)
	var brand_extra: int = 0
	if brand != "":
		var brand_element: String = brand_element_of(brand)
		var roll: int = _brand_damage_roll(brand)
		brand_extra = Status.resist_scale(roll, monster.data.resists,
			brand_element)
		final += brand_extra
	CombatLog.hit(_hit_log(monster.data.display_name, brand, final, brand_extra))
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	if brand != "" and brand_extra > 0 and monster.hp > 0:
		_apply_brand_status(monster, brand)
	if monster.hp > 0 and EssenceSystem.has_venom_touch(player):
		Status.apply(monster, "poison", 3)
	if monster.hp > 0:
		EssenceSystem.apply_melee_hit_effects(player, monster)
	if skill_id != "":
		player.grant_skill_xp(skill_id, 1.0)
	player.grant_skill_xp("fighting", 0.5)
	# Cleave: axe attacks all monsters adjacent to player
	if skill_id == "axe":
		_cleave_hit(player, monster, final)
	# Swift Strike: dagger skill gives chance to attack again
	if skill_id == "dagger" and monster.hp > 0:
		var swift_chance: float = player.get_skill_level("dagger") * 0.05
		if swift_chance > 0.0 and randf() < swift_chance:
			CombatLog.hit("Swift strike!")
			_dagger_swift_strike(player, monster)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		player.grant_xp(monster.data.xp_value)
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
	var soak: int = randi_range(0, monster.data.ac + 1)
	var final: int = max(1, raw - soak)
	CombatLog.hit("You hit the %s for %d." % [monster.data.display_name, final])
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		player.grant_xp(monster.data.xp_value)
		player.register_kill()
		GameManager.try_kill_unlock(monster.data.id)

static func _weapon_brand(player: Player) -> String:
	if player.equipped_weapon_id == "":
		return ""
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	if w == null:
		return ""
	return String(w.brand)

static func brand_element_of(brand: String) -> String:
	match brand:
		"flaming":  return "fire"
		"freezing": return "cold"
		"venom":    return "poison"
		"electric": return "electric"
		"draining": return "necromancy"
	return ""

static func _brand_damage_roll(brand: String) -> int:
	match brand:
		"venom":   return randi_range(1, 3)
		"electric": return randi_range(1, 6)
		_:         return randi_range(1, 4)

static func _weapon_req_penalty(player: Player, w: ItemData) -> Dictionary:
	var req: int = w.required_skill
	if req == 0:
		return {"hit": 0, "dmg_pct": 1.0}
	var skill_lv: int = player.get_skill_level(w.category)
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

static func _hit_log(name: String, brand: String, total: int, extra: int) -> String:
	if brand == "" or extra <= 0:
		return "You hit the %s for %d." % [name, total]
	match brand:
		"flaming":
			return "You torch the %s for %d (+%d fire)." % [name, total, extra]
		"freezing":
			return "You chill the %s for %d (+%d cold)." % [name, total, extra]
		"venom":
			return "You envenom the %s for %d (+%d poison)." % [name, total, extra]
		"electric":
			return "You shock the %s for %d (+%d electric)." % [name, total, extra]
		"draining":
			return "You drain the %s for %d (+%d)." % [name, total, extra]
	return "You hit the %s for %d (+%d)." % [name, total, extra]

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
		player.grant_skill_xp("dodge", 0.3)
		return
	# Shield block (ranged)
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		var _sh: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id)
		if _sh != null:
			var block_pct: float = float(_sh.effect_value) / 100.0 \
				+ player.get_skill_level("shield") * 0.03
			if randf() < block_pct:
				CombatLog.miss("You block the %s's attack!" % monster.data.display_name)
				player.grant_skill_xp("shield", 0.5)
				return
	var raw: int = randi_range(1, max(1, dmg_base))
	var soak: int = randi_range(0, player.ac + 1)
	var final: int = max(1, raw - soak)
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken("The %s %s you for %d." \
			% [monster.data.display_name, verb, final])
	player.take_damage(final, monster.data.id)

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
		player.grant_skill_xp("dodge", 0.5)
		return
	# Shield block
	if player.equipped_shield_id != "" and not player.has_two_handed_weapon():
		var _sh: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id)
		if _sh != null:
			var block_pct: float = float(_sh.effect_value) / 100.0 \
				+ player.get_skill_level("shield") * 0.03
			if randf() < block_pct:
				CombatLog.miss("You block the %s's attack!" % monster.data.display_name)
				player.grant_skill_xp("shield", 0.5)
				return
	# Parry: blade weapon skill gives chance to halve damage
	if player.equipped_weapon_id != "":
		var _wp: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if _wp != null and _wp.category == "blade":
			var parry_chance: float = player.get_skill_level("blade") * 0.03
			if parry_chance > 0.0 and randf() < parry_chance:
				CombatLog.miss("You parry the %s's attack!" % monster.data.display_name)
				player.grant_skill_xp("blade", 0.3)
				return
	var raw: int = randi_range(1, max(1, dmg_base)) + monster.data.hd / 2
	var soak: int = randi_range(0, player.ac + 1)
	if Status.has(player, "stoneskin"):
		soak += randi_range(2, 5)
	var final: int = max(1, raw - soak)
	final = RacePassiveSystem.on_player_hit(player, final)
	CombatLog.damage_taken("The %s hits you for %d." % [monster.data.display_name, final])
	player.take_damage(final, monster.data.id)
	var poison_turns: int = int(attack.get("poison_turns", 0))
	if poison_turns > 0 and player.hp > 0:
		player.apply_status("poison", poison_turns)
		CombatLog.damage_taken("You are poisoned.")
