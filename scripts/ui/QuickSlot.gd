extends Button
class_name QuickSlot

signal pressed_slot(slot_index: int)

@export var slot_index: int = 0

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

func _ready() -> void:
	add_theme_font_size_override("font_size", 34)
	pressed.connect(func(): pressed_slot.emit(slot_index))


func set_item(icon: Texture2D, text: String) -> void:
	if icon_rect:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if label:
		label.text = text


## New API used for consumable quickslots: show a short label tinted with
## the consumable's colour. Empty string clears back to "+".
func set_slot_display(txt: String, color: Color) -> void:
	if icon_rect:
		icon_rect.visible = false
	if label:
		label.text = ""  # hide bottom label; use button text instead
	if txt == "":
		text = "+"
		self_modulate = Color(1, 1, 1, 1)
	else:
		text = txt
		self_modulate = Color(color.r, color.g, color.b, 1.0).lerp(Color(1, 1, 1, 1), 0.3)
