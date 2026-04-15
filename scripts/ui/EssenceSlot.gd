extends Button
class_name EssenceSlot

signal tapped

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label
@onready var border: Panel = $Border

var essence_id: String = ""
var border_style: StyleBoxFlat

func _ready() -> void:
	custom_minimum_size = Vector2(96, 96)
	border_style = StyleBoxFlat.new()
	border_style.bg_color = Color(0, 0, 0, 0)
	border_style.border_color = Color(0.5, 0.5, 0.5)
	border_style.border_width_left = 3
	border_style.border_width_top = 3
	border_style.border_width_right = 3
	border_style.border_width_bottom = 3
	if border:
		border.add_theme_stylebox_override("panel", border_style)
	pressed.connect(func(): tapped.emit())
	_update_empty()

func set_essence(id: String, type_color: Color) -> void:
	essence_id = id
	if id == "":
		_update_empty()
	else:
		if label:
			label.text = id
		if icon_rect:
			icon_rect.visible = true
		border_style.border_color = type_color
		if border:
			border.add_theme_stylebox_override("panel", border_style)

func _update_empty() -> void:
	essence_id = ""
	if label:
		label.text = "○"
	if icon_rect:
		icon_rect.visible = false
	border_style.border_color = Color(0.4, 0.4, 0.4)
	if border:
		border.add_theme_stylebox_override("panel", border_style)
