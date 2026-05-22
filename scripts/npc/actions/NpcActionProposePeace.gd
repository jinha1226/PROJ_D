class_name NpcActionProposePeace extends NPCAction

## Propose an alliance to the nearest NPC with non-negative trust.
## On acceptance, both parties gain trust = 0.5; on betrayal the trust can
## drop below -0.3 causing them to re-enter combat as enemies.

func _init() -> void:
	action_name = "propose_peace"
	cost = 1.0
	preconditions = {has_potential_ally = true}
	effects       = {ally_proposed = true}

func execute(actor: NPCActor) -> bool:
	# Find nearest NPC in FOV with trust >= 0 and propose alliance
	var fov := actor.compute_fov()
	var best: NPCActor = null
	var best_dist: int = 999
	for node in actor.get_tree().get_nodes_in_group("npcs"):
		if node == actor or not is_instance_valid(node) or not (node is NPCActor):
			continue
		if not fov.has(node.grid_pos):
			continue
		var trust: float = actor._relation_trust(node)
		if trust < 0.0:
			continue
		var d: int = max(abs(node.grid_pos.x - actor.grid_pos.x),
						 abs(node.grid_pos.y - actor.grid_pos.y))
		if d < best_dist:
			best_dist = d
			best = node

	if best == null:
		return false

	# Mutual trust bump — initiator raises trust, target may or may not respond
	actor.set_relation(best, 0.5, actor._relation_threat(best))
	best.set_relation(actor, 0.5, best._relation_threat(actor))
	actor.alliance_members.append(best)
	best.alliance_members.append(actor)

	if actor.CombatLog != null:
		actor.CombatLog.post(
			"%s and %s form an alliance." % [actor.npc_name, best.npc_name],
			Color(0.6, 0.9, 0.9))
	return true
