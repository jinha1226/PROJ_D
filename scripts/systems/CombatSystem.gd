class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills stubbed at 0; full formula with
## weapon skill / brands lands with SkillSystem (Week 2).

const UNARMED_DAMAGE: int = 2

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	var stat_source: int = player.strength
	if player.equipped_weapon_id != "":
		var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if w != null:
			weapon_dmg = max(UNARMED_DAMAGE, w.damage)
			if w.category == "dagger" or w.category == "short":
				stat_source = player.dexterity
	var stat_bonus: int = stat_source / 3
	var to_hit_base: int = 15 + stat_bonus
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < monster.data.ev:
		CombatLog.miss("You miss the %s." % monster.data.display_name)
		return
	var raw: int = weapon_dmg + stat_bonus / 2 + randi_range(0, 3)
	var soak: int = randi_range(0, monster.data.ac + 1)
	var final: int = max(1, raw - soak)
	CombatLog.hit("You hit the %s for %d." % [monster.data.display_name, final])
	var was_alive: bool = monster.hp > 0
	monster.take_damage(final)
	if was_alive and monster.hp <= 0:
		CombatLog.hit("You kill the %s." % monster.data.display_name)
		player.grant_xp(monster.data.xp_value)
		player.register_kill()

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
