class_name ItemData extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var kind: String = ""
@export var tier: int = 1
@export var tile_path: String = ""
@export var glyph: String = "?"
@export var glyph_color: Color = Color.WHITE

@export_group("Weapon")
@export var damage: int = 0
@export var delay: float = 1.0
@export var category: String = ""
@export var brand: String = ""

@export_group("Armor")
@export var ac_bonus: int = 0
@export var ev_penalty: int = 0
@export var slot: String = ""

@export_group("Consumable")
@export var effect: String = ""
@export var effect_value: int = 0

@export_group("Misc")
@export var plus: int = 0
@export var description: String = ""

@export_group("Unlocks / Grants")
## When this item is used, unlock the class with this id (if any).
@export var unlocks_class_id: String = ""
## When used, teach the spell with this id to the player (if not known).
@export var grants_spell_id: String = ""
## When used, teach all spells in this list (multi-spell books).
@export var grants_spell_ids: Array[String] = []

@export_group("Visuals")
## Overlay tile drawn on top of `tile_path` once GameManager.identify(id)
## has been called. DCSS-style "base parchment + stamped symbol" for
## scrolls / potions / books — lets pseudonym-only items show a
## generic look before the player learns what they are.
@export var identified_tile_path: String = ""
