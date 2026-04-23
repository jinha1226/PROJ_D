class_name RaceData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_sprite_path: String = ""

## Unlock gating. If `unlocked` is true (or the id has been granted
## via GameManager.unlock), the race shows up as pickable. Otherwise
## `unlock_kind` + `unlock_trigger_id` describes how to earn it:
##   "kill"      → kill a monster whose id matches unlock_trigger_id
##   "use_item"  → use an item whose id matches unlock_trigger_id
##   "" / other  → TBD, stays locked until unlocked programmatically
@export var unlocked: bool = false
@export var unlock_kind: String = ""
@export var unlock_trigger_id: String = ""

# Stat deltas applied on top of class starting values.
@export var str_mod: int = 0
@export var dex_mod: int = 0
@export var int_mod: int = 0
@export var hp_mod: int = 0
@export var mp_mod: int = 0

## Racial resistance entries appended to Player.resists on class-apply.
## Format: Status.gd — ["fire+", "cold++", "necromancy+"], etc.
@export var resist_mods: Array = []

func unlock_hint() -> String:
	if unlocked:
		return ""
	match unlock_kind:
		"kill":
			return "Slay a %s to unlock." % unlock_trigger_id.capitalize()
		"use_item":
			return "Use a %s to unlock." % unlock_trigger_id.replace("_", " ")
	return "Locked."
