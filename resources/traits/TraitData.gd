class_name TraitData
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var category: String = "general"
@export var str_bonus: int = 0
@export var dex_bonus: int = 0
@export var int_bonus: int = 0
@export var hp_bonus_pct: float = 0.0
@export var mp_bonus_pct: float = 0.0
@export var ac_bonus: int = 0
@export var special: String = ""
@export var starting_spells: Array[String] = []
@export var skill_aptitudes: Dictionary = {}
