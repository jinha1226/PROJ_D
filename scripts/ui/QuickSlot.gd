extends Button
class_name QuickSlot

signal pressed_slot(slot_index: int)
signal long_pressed_slot(slot_index: int)
## Emitted when a quickslot's press → release ended after the finger
## travelled more than DRAG_THRESHOLD_PX. BottomHUD resolves the
## release position against sibling slots to drive drag-swap.
signal drag_released(from_index: int, release_pos: Vector2)

@export var slot_index: int = 0

const LONGPRESS_TIME: float = 0.45
const DRAG_THRESHOLD_PX: float = 22.0

@onready var icon_rect: TextureRect = $Icon
@onready var label: Label = $Label

var _hold_timer: float = 0.0
var _holding: bool = false
var _long_fired: bool = false
var _press_pos: Vector2 = Vector2.ZERO
var _dragged: bool = false


func _ready() -> void:
	add_theme_font_size_override("font_size", 22)
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
	_press_pos = get_global_mouse_position()
	_dragged = false


func _on_button_up() -> void:
	_holding = false
	_hold_timer = 0.0
	# If the finger travelled far enough between press and release, treat
	# the gesture as a drag instead of a tap. BottomHUD turns the release
	# position into a target-slot index and emits a swap request.
	var release_pos: Vector2 = get_global_mouse_position()
	if release_pos.distance_to(_press_pos) > DRAG_THRESHOLD_PX:
		_dragged = true
		drag_released.emit(slot_index, release_pos)


func _on_pressed() -> void:
	# `pressed` fires after button_up — suppress the tap emit if a long-press
	# already consumed this hold, or if the finger travelled far enough to
	# count as a drag (drag_released handled it).
	if _long_fired:
		_long_fired = false
		return
	if _dragged:
		_dragged = false
		return
	pressed_slot.emit(slot_index)


func set_item(icon: Texture2D, text: String) -> void:
	if icon_rect:
		icon_rect.texture = icon
		icon_rect.visible = icon != null
	if label:
		label.text = text
	self.text = "" if icon != null else "+"


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
