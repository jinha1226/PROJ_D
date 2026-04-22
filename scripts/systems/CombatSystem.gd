class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills stubbed at 0; full formula with
## weapon skill / brands lands with SkillSystem (Week 2).

const UNARMED_DAMAGE: int = 2

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	var stat_source: int = player.strength
	var skill_id: String = ""
	var weapon_plus: int = 0
	if player.equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if w != null:
			var entry: Dictionary = player.equipped_weapon_entry()
			weapon_plus = int(entry.get("plus", 0))
			weapon_dmg = max(UNARMED_DAMAGE, w.damage + weapon_plus)
			skill_id = w.category
			if w.category == "dagger":
				stat_source = player.dexterity
	var stat_bonus: int = stat_source / 3
	var skill_level: int = 0
	if skill_id != "":
		skill_level = player.get_skill_level(skill_id)
	var to_hit_base: int = 15 + stat_bonus + skill_level + weapon_plus
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < monster.data.ev:
		CombatLog.miss("You miss the %s." % monster.data.display_name)
		return
	var raw: int = weapon_dmg + stat_bonus / 2 + randi_range(0, 3)
	var soak: int = randi_range(0, monster.data.ac + 1)
	var base_final: int = max(1, raw - soak)
	var mult: float = 1.0 + float(skill_level) * 0.05
	var final: int = max(1, int(round(float(base_final) * mult)))
	CombatLog.hit("You hit the %s for %d." % [monster.data.display_name, final])
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	if skill_id != "":
		player.grant_skill_xp(skill_id, 1.0)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		player.grant_xp(monster.data.xp_value)
		player.register_kill()
		GameManager.try_kill_unlock(monster.data.id)

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
	var raw: int = randi_range(1, max(1, dmg_base))
	var soak: int = randi_range(0, player.ac + 1)
	var final: int = max(1, raw - soak)
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

	var to_hit_base: int = 15 + monster.data.hd
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < player.ev:
		CombatLog.miss("The %s misses you." % monster.data.display_name)
		return
	var raw: int = randi_range(1, max(1, dmg_base)) + monster.data.hd / 2
	var soak: int = randi_range(0, player.ac + 1)
	var final: int = max(1, raw - soak)
	CombatLog.damage_taken("The %s hits you for %d." % [monster.data.display_name, final])
	player.take_damage(final, monster.data.id)
	var poison_turns: int = int(attack.get("poison_turns", 0))
	if poison_turns > 0 and player.hp > 0:
		player.apply_status("poison", poison_turns)
		CombatLog.damage_taken("You are poisoned.")
