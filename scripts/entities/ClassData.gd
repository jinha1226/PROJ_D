class_name ClassData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var starting_hp: int = 30
@export var starting_mp: int = 5
@export var starting_str: int = 8
@export var starting_dex: int = 8
@export var starting_int: int = 8
@export var starting_weapon: String = ""
@export var starting_armor: String = ""
@export var starting_skills: Dictionary = {}
@export var starting_spells: Array = []
@export var passive: String = ""

## Unlock gating. See RaceData for field contract. Default-true for the
## 3 core classes (warrior / mage / rogue) that ship unlocked.
@export var unlocked: bool = true
@export var unlock_kind: String = ""
@export var unlock_trigger_id: String = ""

func unlock_hint() -> String:
	if unlocked:
		return ""
	match unlock_kind:
		"kill":
			return "Slay a %s to unlock." % unlock_trigger_id.capitalize()
		"use_item":
			return "Use a %s to unlock." % unlock_trigger_id.replace("_", " ")
	return "Locked."
