class_name NpcActionAttack extends NPCAction

func _init() -> void:
	action_name = "attack_enemy"
	cost = 1.0
	preconditions = {adjacent_to_enemy = true, has_enemy_in_sight = true}
	effects       = {enemy_is_dead = true}

func execute(actor: NPCActor) -> bool:
	var target = actor._known_enemy
	if target == null or target.hp <= 0:
		return false
	var dist: int = max(abs(target.grid_pos.x - actor.grid_pos.x),
					abs(target.grid_pos.y - actor.grid_pos.y))
	if dist > 1:
		return false

	actor.facing = (target.grid_pos - actor.grid_pos).sign()

	# Simple damage roll: 1–6 + slay_bonus. Full weapon-item lookup can be
	# wired once CombatSystem has an actor-vs-actor path.
	var dmg: int = randi_range(1, 6) + actor.slay_bonus
	target.take_damage(dmg, actor.npc_name)

	if actor.CombatLog != null:
		actor.CombatLog.post(
			"%s attacks for %d damage." % [actor.npc_name, dmg],
			Color(0.9, 0.6, 0.4))
	return true
