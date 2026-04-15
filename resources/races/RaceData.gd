class_name RaceData
extends Resource

@export var id: String
@export var display_name: String
@export var description: String

@export var base_str: int = 10
@export var base_dex: int = 10
@export var base_int: int = 10

@export var hp_per_level: int = 3
@export var mp_per_level: int = 2
@export var move_speed_mod: int = 0

@export var essence_affinity: Dictionary = {}
@export var lpc_asset: String = ""
