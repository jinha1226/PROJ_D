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
@export var lpc_asset: String = ""  # legacy, unused after preset composition refactor

# --- LPC composition ---
# Used by Player._compose_preset to build a CharacterSprite-ready dict.
@export var body_def: String = "body_male"
@export var skin_tint: String = "peach"
@export var hair_def: String = "hair_parted"
@export var hair_color: String = "brown"
@export var beard_def: String = ""          # "" = no beard
@export var beard_color: String = "brown"
@export var horns_def: String = ""          # "" = no horns
@export var horns_color: String = "brown"
@export var ears_def: String = ""           # "" = default human ears
@export var ears_color: String = "brown"
@export var base_ac: int = 0                # racial intrinsic AC
# Freeform trait id for racial abilities (implemented in M2+).
# Examples: "trollregen", "demonspawn_mutations", "spriggan_speed".
@export var racial_trait: String = ""
# DCSS-style skill aptitudes. Keys are SkillSystem.SKILL_IDS entries.
# Each value is an int (-5 to +5) — higher = learns faster. Missing keys
# default to 0. SkillSystem multiplies incoming XP by 2^(apt/2).
@export var skill_aptitudes: Dictionary = {}
