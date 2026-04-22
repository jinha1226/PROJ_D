class_name RaceData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var description: String = ""
@export var base_sprite_path: String = ""
@export var unlocked: bool = true
@export var unlock_cost: int = 0  # Rune Shards required to unlock later.

# Stat deltas applied on top of class starting values.
@export var str_mod: int = 0
@export var dex_mod: int = 0
@export var int_mod: int = 0
@export var hp_mod: int = 0
@export var mp_mod: int = 0
