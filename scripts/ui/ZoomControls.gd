extends Control
class_name ZoomControls
## Small "+" / "-" button cluster anchored to the right edge, mid-height.
## Wired to a ZoomController instance provided externally.

signal zoom_in_pressed
signal zoom_out_pressed

var _plus_btn: Button
var _minus_btn: Button


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_PASS
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -88.0
	offset_right = -8.0
	offset_top = -90.0
	offset_bottom = 90.0

	var vbox: VBoxContainer = VBoxContainer.new()
	vbox.anchor_right = 1.0
	vbox.anchor_bottom = 1.0
	vbox.add_theme_constant_override("separation", 8)
	add_child(vbox)

	_plus_btn = Button.new()
	_plus_btn.text = "+"
	_plus_btn.custom_minimum_size = Vector2(72, 72)
	_plus_btn.add_theme_font_size_override("font_size", 32)
	_plus_btn.pressed.connect(func(): zoom_in_pressed.emit())
	vbox.add_child(_plus_btn)

	_minus_btn = Button.new()
	_minus_btn.text = "-"
	_minus_btn.custom_minimum_size = Vector2(72, 72)
	_minus_btn.add_theme_font_size_override("font_size", 32)
	_minus_btn.pressed.connect(func(): zoom_out_pressed.emit())
	vbox.add_child(_minus_btn)
