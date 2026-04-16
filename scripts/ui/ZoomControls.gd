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
	# Use explicit position/size — anchors are unreliable inside nested CanvasLayers.
	# Viewport is always 1080×2340 (canvas_items stretch mode).
	# Place on right edge, vertically centred between TopHUD (148px) and BottomHUD (144px).
	const VP_W := 1080
	const VP_H := 2340
	const TOP_H := 148
	const BOT_H := 144
	const BTN_W := 80
	const MARGIN := 8
	var mid_y := TOP_H + (VP_H - TOP_H - BOT_H) / 2
	position = Vector2(VP_W - BTN_W - MARGIN, mid_y - 90)
	size = Vector2(BTN_W, 180)

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
