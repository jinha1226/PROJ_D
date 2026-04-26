extends Control
class_name BottomHUD

signal quickslot_pressed(index: int)
signal quickslot_long_pressed(index: int)
signal quickslot_swap_requested(from_index: int, to_index: int)
signal rest_pressed
signal bag_pressed
signal skills_pressed
signal magic_pressed
signal status_pressed
signal act_pressed
signal simulation_pressed
signal menu_pressed

@onready var quick_slots: Array = [
	$Margin/VBox/Row1/QuickSlot0,
	$Margin/VBox/Row1/QuickSlot1,
	$Margin/VBox/Row1/QuickSlot2,
	$Margin/VBox/Row1/QuickSlot3,
	$Margin/VBox/Row1/QuickSlot4,
]
@onready var rest_button: Button = $Margin/VBox/Row1/RestButton
@onready var bag_button: Button = $Margin/VBox/Row2/BagButton
@onready var skills_button: Button = $Margin/VBox/Row2/SkillsButton
@onready var magic_button: Button = $Margin/VBox/Row2/MagicButton
@onready var status_button: Button = $Margin/VBox/Row2/StatusButton
@onready var act_button: Button = $Margin/VBox/Row2/ActButton
@onready var simulation_button: Button = $Margin/VBox/Row2/SimButton
@onready var menu_button: Button = $Margin/VBox/Row2/MenuButton


func _ready() -> void:
	theme = GameTheme.create()
	for i in quick_slots.size():
		var qs = quick_slots[i]
		qs.slot_index = i
		if qs.has_signal("pressed_slot"):
			qs.pressed_slot.connect(func(idx): quickslot_pressed.emit(idx))
		if qs.has_signal("long_pressed_slot"):
			qs.long_pressed_slot.connect(func(idx): quickslot_long_pressed.emit(idx))
		if qs.has_signal("drag_released"):
			qs.drag_released.connect(_on_quickslot_drag_released)
	rest_button.pressed.connect(func(): rest_pressed.emit())
	bag_button.pressed.connect(func(): bag_pressed.emit())
	skills_button.pressed.connect(func(): skills_pressed.emit())
	magic_button.pressed.connect(func(): magic_pressed.emit())
	status_button.pressed.connect(func(): status_pressed.emit())
	act_button.pressed.connect(func(): act_pressed.emit())
	simulation_button.pressed.connect(func(): simulation_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())


## Update REST button label to hint at current mode.
func set_rest_label(monster_in_sight: bool) -> void:
	if rest_button != null:
		rest_button.text = "WAIT" if monster_in_sight else "REST"


func set_quickslot(i: int, icon: Texture2D, text: String) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_item(icon, text)


func set_quickslot_display(i: int, txt: String, color: Color) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_slot_display(txt, color)


func set_simulation_active(active: bool) -> void:
	if simulation_button != null:
		simulation_button.text = "STOP" if active else "SIM"


func _on_quickslot_drag_released(from_index: int, release_pos: Vector2) -> void:
	var to_index: int = -1
	for i in quick_slots.size():
		var qs = quick_slots[i]
		if qs is Control and qs.get_global_rect().has_point(release_pos):
			to_index = i
			break
	if to_index < 0 or to_index == from_index:
		return
	quickslot_swap_requested.emit(from_index, to_index)
