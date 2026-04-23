class_name SpellData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var school: String = ""      # evocation / conjuration / transmutation / necromancy / abjuration / enchantment
@export var spell_level: int = 1     # 1–9 (SRD spell slot level)
@export var xl_required: int = 1     # minimum player XL to cast
@export var mp_cost: int = 2
@export var difficulty: int = 1
@export var base_damage: int = 0
@export var max_range: int = 5
@export var targeting: String = "single"
@export var element: String = ""
@export var effect: String = "damage"
@export var description: String = ""
