class_name NpcActionPickupItem extends NPCAction

func _init() -> void:
	action_name = "pickup_item"
	cost = 1.0
	preconditions = {at_loot_pos = true, has_loot_nearby = true}
	effects       = {loot_collected = true, has_loot_nearby = false}

func execute(actor: NPCActor) -> bool:
	# Find a floor item at actor's tile and pick it up (add to essence/inventory)
	for node in actor.get_tree().get_nodes_in_group("floor_items"):
		if not is_instance_valid(node):
			continue
		if node.grid_pos != actor.grid_pos:
			continue
		# Notify Game via signal so it can remove the floor item node
		actor.emit_signal("item_picked_up", node.entry if node.get("entry") != null else {}, actor.grid_pos)
		if actor.CombatLog != null:
			actor.CombatLog.post(
				"%s picks up an item." % actor.npc_name,
				Color(0.7, 0.85, 0.7))
		return true
	return false
