extends Control
class_name BottomHUD

signal rest_pressed
signal bag_pressed
signal skills_pressed
signal magic_pressed
signal status_pressed
signal act_pressed
signal pickup_pressed
signal menu_pressed
signal quickslot_pressed(index: int)
signal quickslot_long_pressed(index: int)
signal quickslot_swap_requested(from_index: int, to_index: int)

@onready var rest_button: Button = $BottomMargin/MainVBox/MainRow/RestButton
@onready var act_button: Button = $BottomMargin/MainVBox/MainRow/ActButton
@onready var bag_button: Button = $BottomMargin/MainVBox/MenuRow/BagButton
@onready var pickup_button: Button = $BottomMargin/MainVBox/MenuRow/PickupButton
@onready var skills_button: Button = $BottomMargin/MainVBox/MenuRow/SkillsButton
@onready var magic_button: Button = $BottomMargin/MainVBox/MenuRow/MagicButton
@onready var status_button: Button = $BottomMargin/MainVBox/MenuRow/StatusButton
@onready var menu_button: Button = $BottomMargin/MainVBox/MenuRow/MenuButton
@onready var quick_slots: Array = [
	$BottomMargin/MainVBox/MainRow/QuickSlot0,
	$BottomMargin/MainVBox/MainRow/QuickSlot1,
	$BottomMargin/MainVBox/MainRow/QuickSlot2,
	$BottomMargin/MainVBox/MainRow/QuickSlot3,
	$BottomMargin/MainVBox/MainRow/QuickSlot4,
	$BottomMargin/MainVBox/MainRow/QuickSlot5,
]


func _ready() -> void:
	theme = GameTheme.create()
	rest_button.pressed.connect(func(): rest_pressed.emit())
	act_button.pressed.connect(func(): act_pressed.emit())
	bag_button.pressed.connect(func(): bag_pressed.emit())
	if pickup_button != null:
		pickup_button.pressed.connect(func(): pickup_pressed.emit())
	skills_button.pressed.connect(func(): skills_pressed.emit())
	magic_button.pressed.connect(func(): magic_pressed.emit())
	status_button.pressed.connect(func(): status_pressed.emit())
	if menu_button != null:
		menu_button.pressed.connect(func(): menu_pressed.emit())
	for i in quick_slots.size():
		var qs = quick_slots[i]
		qs.slot_index = i
		if qs.has_signal("pressed_slot"):
			qs.pressed_slot.connect(func(idx): quickslot_pressed.emit(idx))
		if qs.has_signal("long_pressed_slot"):
			qs.long_pressed_slot.connect(func(idx): quickslot_long_pressed.emit(idx))
		if qs.has_signal("drag_released"):
			qs.drag_released.connect(_on_quickslot_drag_released)


func set_rest_label(monster_in_sight: bool) -> void:
	if rest_button != null:
		rest_button.text = "WAIT" if monster_in_sight else "REST"


func set_act_label(monster_in_sight: bool) -> void:
	if act_button != null:
		act_button.text = "ATK" if monster_in_sight else "AUTO"


func set_quickslot(i: int, icon: Texture2D, text: String) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_item(icon, text)


func set_quickslot_display(i: int, txt: String, color: Color) -> void:
	if i >= 0 and i < quick_slots.size():
		quick_slots[i].set_slot_display(txt, color)


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
