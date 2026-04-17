class_name JobData
extends Resource

@export var id: String
@export var display_name: String
@export var description: String
@export var icon: Texture2D

@export var str_bonus: int = 0
@export var dex_bonus: int = 0
@export var int_bonus: int = 0

@export var starting_equipment: Array[String] = []
@export var starting_skills: Dictionary = {}
# Spell ids pre-learned at character creation. Magic backgrounds start
# already knowing one or two school spells so they can cast from turn 1.
@export var starting_spells: Array[String] = []

@export var unique_ability: String = ""
@export var essence_affinity: Dictionary = {}
@export var unlock_requirement: String = ""
