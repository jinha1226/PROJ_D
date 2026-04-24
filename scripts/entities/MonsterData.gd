class_name MonsterData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var tier: int = 1
@export var hp: int = 10
@export var hd: int = 1
@export var ac: int = 0
@export var ev: int = 5
@export var speed: int = 10
@export var sight_range: int = 8
@export var attacks: Array = []
@export var ranged_attack: Dictionary = {}  # {damage, range, verb, flavour}
@export var resists: Array = []
@export var min_depth: int = 1
@export var max_depth: int = 25
@export var weight: int = 10
@export var xp_value: int = 1
@export var is_boss: bool = false
@export var tile_path: String = ""
@export var glyph: String = "r"
@export var glyph_color: Color = Color(0.8, 0.8, 0.8)
@export var description: String = ""
@export var essence_id: String = ""   # specific essence this monster can drop; "" = random
