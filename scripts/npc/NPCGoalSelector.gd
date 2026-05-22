class_name NPCGoalSelector extends RefCounted

## Utility-layer goal selector. Evaluates weighted utility scores against the
## current world state to pick the highest-priority GOAP goal for NPCActor.
##
## Extending NPC types can override select_goal() or individual _utility_*()
## methods to tune personality (cowardly / aggressive / greedy / social).

var actor: NPCActor

## Returns the goal Dictionary to pass to GOAPPlanner, or {} for idle.
func select_goal(world_state: Dictionary) -> Dictionary:
	var hp_ratio: float = float(actor.hp) / float(max(actor.hp_max, 1))

	# Survival: flee when critically wounded and enemy present
	if hp_ratio < 0.3 and world_state.get("has_enemy_in_sight", false):
		return {"hp_critical": false}

	# Combat: kill visible enemy (unless we should ally instead)
	if world_state.get("has_enemy_in_sight", false):
		if _should_ally(world_state):
			return {"ally_proposed": true}
		return {"enemy_is_dead": true}

	# Loot: collect nearby floor items when no immediate threat
	if world_state.get("has_loot_nearby", false):
		return {"loot_collected": true}

	# Idle
	return {}

## Override to change when this NPC prefers alliance over combat.
func _should_ally(world_state: Dictionary) -> bool:
	return (world_state.get("enemy_is_strong", false)
		and world_state.get("has_potential_ally", false))
