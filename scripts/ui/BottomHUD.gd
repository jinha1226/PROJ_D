extends Control
class_name BottomHUD

signal quickslot_pressed(index: int)
signal rest_pressed
signal bag_pressed
signal skills_pressed
signal magic_pressed
signal status_pressed
signal wait_pressed
signal menu_pressed
signal auto_move_pressed
signal auto_attack_pressed

@onready var quick_slots: Array = [
	$Margin/VBox/Row1/QuickSlot0,
	$Margin/VBox/Row1/QuickSlot1,
	$Margin/VBox/Row1/QuickSlot2,
	$Margin/VBox/Row1/QuickSlot3,
	$Margin/VBox/Row1/QuickSlot4,
	$Margin/VBox/Row1/QuickSlot5,
	$Margin/VBox/Row1/QuickSlot6,
	$Margin/VBox/Row1/QuickSlot7,
]
@onready var rest_button: Button = $Margin/VBox/Row1/RestButton
@onready var bag_button: Button = $Margin/VBox/Row2/BagButton
@onready var skills_button: Button = $Margin/VBox/Row2/SkillsButton
@onready var magic_button: Button = $Margin/VBox/Row2/MagicButton
@onready var status_button: Button = $Margin/VBox/Row2/StatusButton
@onready var wait_button: Button = $Margin/VBox/Row2/WaitButton
@onready var auto_move_button: Button = $Margin/VBox/Row2/AutoMoveButton
@onready var auto_attack_button: Button = $Margin/VBox/Row2/AutoAttackButton
@onready var menu_button: Button = $Margin/VBox/Row2/MenuButton


func _ready() -> void:
	theme = GameTheme.create()
	for i in quick_slots.size():
		var qs = quick_slots[i]
		qs.slot_index = i
		if qs.has_signal("pressed_slot"):
			qs.pressed_slot.connect(func(idx): quickslot_pressed.emit(idx))
	rest_button.pressed.connect(func(): rest_pressed.emit())
	bag_button.pressed.connect(func(): bag_pressed.emit())
	skills_button.pressed.connect(func(): skills_pressed.emit())
	magic_button.pressed.connect(func(): magic_pressed.emit())
	status_button.pressed.connect(func(): status_pressed.emit())
	wait_button.pressed.connect(func(): wait_pressed.emit())
	auto_move_button.pressed.connect(func(): auto_move_pressed.emit())
	auto_attack_button.pressed.connect(func(): auto_attack_pressed.emit())
	menu_button.pressed.connect(func(): menu_pressed.emit())


func set_quickslot(i: int, icon: Texture2D, text: String) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_item(icon, text)


func set_quickslot_display(i: int, txt: String, color: Color) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_slot_display(txt, color)


func set_essence(_id: String, _type_color: Color) -> void:
	pass

signal essence_slot_tapped
