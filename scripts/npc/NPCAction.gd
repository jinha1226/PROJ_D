class_name NPCAction

## Base class for all GOAP actions available to NPCActor.
## Subclasses set preconditions/effects in _init() and override execute().

var action_name: String = ""
var cost: float = 1.0

## Keys that must match the current world state for this action to be applicable.
var preconditions: Dictionary = {}

## Keys this action sets in the world state after execution (used by planner).
var effects: Dictionary = {}

func is_applicable(world_state: Dictionary) -> bool:
	for key in preconditions:
		if world_state.get(key) != preconditions[key]:
			return false
	return true

## Perform the action. Returns true on success.
func execute(actor: NPCActor) -> bool:
	return true
