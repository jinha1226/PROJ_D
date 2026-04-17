class_name EssenceData
extends Resource

enum EssenceType { GIANT, UNDEAD, NATURE, ELEMENTAL, ABYSS, DRAGON }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: String
@export var display_name: String
@export var description: String
@export var essence_type: EssenceType
@export var rarity: Rarity
@export var icon: Texture2D

@export var str_bonus: int = 0
@export var dex_bonus: int = 0
@export var int_bonus: int = 0
@export var hp_bonus: int = 0
@export var armor_bonus: int = 0
@export var evasion_bonus: int = 0

@export var source_monsters: Array[String] = []
@export var drop_chance: float = 0.3
