extends Button
class_name QuickSlot

signal pressed_slot(slot_index: int)
signal long_pressed_slot(slot_index: int)

@export var slot_index: int = 0

const LONGPRESS_TIME: float = 0.45

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

var _hold_timer: float = 0.0
var _holding: bool = false
var _long_fired: bool = false


func _ready() -> void:
	add_theme_font_size_override("font_size", 39)
	button_down.connect(_on_button_down)
	button_up.connect(_on_button_up)
	pressed.connect(_on_pressed)


func _process(delta: float) -> void:
	if not _holding or _long_fired:
		return
	_hold_timer += delta
	if _hold_timer >= LONGPRESS_TIME:
		_long_fired = true
		long_pressed_slot.emit(slot_index)


func _on_button_down() -> void:
	_holding = true
	_long_fired = false
	_hold_timer = 0.0


func _on_button_up() -> void:
	_holding = false
	_hold_timer = 0.0


func _on_pressed() -> void:
	# `pressed` fires after button_up — suppress the tap emit if a long-press
	# already consumed this hold.
	if _long_fired:
		_long_fired = false
		return
	pressed_slot.emit(slot_index)


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
