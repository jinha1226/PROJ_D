extends Control
class_name BottomHUD

signal quickslot_pressed(index: int)
signal essence_slot_tapped
signal rest_pressed

@onready var quick_slots: Array = [
	$Margin/HBox/QuickSlot0,
	$Margin/HBox/QuickSlot1,
	$Margin/HBox/QuickSlot2,
	$Margin/HBox/QuickSlot3,
]
@onready var essence_slot: Button = $Margin/HBox/EssenceSlot
@onready var rest_button: Button = $Margin/HBox/RestButton

func _ready() -> void:
	for i in quick_slots.size():
		var qs = quick_slots[i]
		qs.slot_index = i
		if qs.has_signal("pressed_slot"):
			qs.pressed_slot.connect(func(idx): quickslot_pressed.emit(idx))
	if essence_slot and essence_slot.has_signal("tapped"):
		essence_slot.tapped.connect(func(): essence_slot_tapped.emit())
	rest_button.pressed.connect(func(): rest_pressed.emit())

func set_quickslot(i: int, icon: Texture2D, text: String) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_item(icon, text)

func set_essence(id: String, type_color: Color) -> void:
	if essence_slot and essence_slot.has_method("set_essence"):
		essence_slot.set_essence(id, type_color)
