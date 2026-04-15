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

	# Defender armour skill bonus (monsters don't have one; safe 0 fallback).
	var armour_skill_level: int = 0
	if skill_sys != null and defender.has_method("get_current_weapon_skill"):
		# Heuristic: only players expose skill sheets we manage.
		armour_skill_level = skill_sys.get_level(defender, "armour")
	var effective_ac: int = def_ac + armour_skill_level / 4

	var dmg: int = roll_damage(atk, effective_ac)
	if defender.has_method("take_damage"):
		defender.take_damage(dmg)
	return dmg


## Monster → player melee. Monsters don't have skills in M1, so this path
## keeps the legacy formula.
static func melee_attack_from_monster(m, player) -> int:
	var base_atk: int = int(m.data.str) / 2 + 3
	var def_ac: int = 0
	if player.stats != null:
		def_ac = player.stats.AC
	var dmg: int = roll_damage(base_atk, def_ac)
	if player.has_method("take_damage"):
		player.take_damage(dmg)
	return dmg
