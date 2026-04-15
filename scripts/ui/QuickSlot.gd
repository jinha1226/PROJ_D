extends Button
class_name QuickSlot

signal pressed_slot(slot_index: int)

@export var slot_index: int = 0

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

func _ready() -> void:
	custom_minimum_size = Vector2(112, 112)
	pressed.connect(func(): pressed_slot.emit(slot_index))

func set_item(icon: Texture2D, text: String) -> void:
	if icon_rect:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if label:
		label.text = text
