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
@export var starting_shield: String = ""
@export var robe_path: String = ""  # overrides DOLL_BODY_MAP for portrait and paperdoll
@export var starting_skills: Dictionary = {}
@export var starting_spells: Array = []
## Skills that begin in the "active/training" set on run start.
## Empty → Game.gd falls back to ["fighting"] (universal HP skill).
@export var default_active_skills: Array = []
## Items granted at run start (item ids, e.g. "potion_healing").
@export var starter_items: Array = []
@export var starting_xl: int = 0
@export var passive: String = ""
@export var class_group: String = ""  # "fighter" | "wizard" | "rogue" — empty = archetype/test

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
