class_name CombatSystem extends RefCounted

## Minimal melee per guide §4.5a. Skills are stubbed at 0 until SkillSystem
## lands (Week 2). Weapon damage reads from player's equipped item when
## inventory is wired (Day 4); until then, unarmed fallback.

const UNARMED_DAMAGE: int = 3

static func player_attack_monster(player: Player, monster: Monster) -> void:
	if monster.data == null:
		return
	var stat_bonus: int = player.strength / 3
	var to_hit_base: int = 15 + stat_bonus
	var to_hit_roll: int = randi_range(0, to_hit_base)
	if to_hit_roll < monster.data.ev:
		CombatLog.miss("You miss the %s." % monster.data.display_name)
		return
	var weapon_dmg: int = UNARMED_DAMAGE
	var raw: int = weapon_dmg + stat_bonus / 2 + randi_range(0, 3)
	var soak: int = randi_range(0, monster.data.ac + 1)
	var final: int = max(1, raw - soak)
	CombatLog.hit("You hit the %s for %d." % [monster.data.display_name, final])
	monster.take_damage(final)

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
