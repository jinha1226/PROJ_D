class_name NpcActionWait extends NPCAction

## Always-applicable idle action. Used when no other plan is possible.

func _init() -> void:
	action_name = "wait"
	cost = 1.0
	preconditions = {}
	effects       = {}

func execute(_actor: NPCActor) -> bool:
	return true
