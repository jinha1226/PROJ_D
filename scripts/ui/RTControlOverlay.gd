extends Control
class_name RTControlOverlay

const BTN: int = 90
const HUD_H: int = 148
const PAD: int = 20
const ACTION_W: int = 116
const ACTION_H: int = 90
const ACTION_GAP: int = 14

var _rt: RealTimeController
var _dpad_root: Control
var _dodge_btn: Button
var _parry_btn: Button

func setup(rt_controller: RealTimeController) -> void:
	_rt = rt_controller
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dpad()
	_build_action_buttons()
	_reposition()

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		_reposition()

func _reposition() -> void:
	if size == Vector2.ZERO:
		return
	if _dpad_root:
		_dpad_root.position = Vector2(PAD, size.y - HUD_H - BTN * 3 - PAD)
	if _dodge_btn:
		_dodge_btn.position = Vector2(size.x - PAD - ACTION_W,
				size.y - HUD_H - ACTION_GAP - ACTION_H * 2)
		_dodge_btn.size = Vector2(ACTION_W, ACTION_H)
	if _parry_btn:
		_parry_btn.position = Vector2(size.x - PAD - ACTION_W,
				size.y - HUD_H - ACTION_H)
		_parry_btn.size = Vector2(ACTION_W, ACTION_H)

func _build_dpad() -> void:
	_dpad_root = Control.new()
	_dpad_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dpad_root.custom_minimum_size = Vector2(BTN * 3, BTN * 3)
	_dpad_root.size = Vector2(BTN * 3, BTN * 3)
	add_child(_dpad_root)

	var dirs: Array = [
		[1, 0, Vector2i( 0, -1), "▲"],
		[0, 1, Vector2i(-1,  0), "◀"],
		[2, 1, Vector2i( 1,  0), "▶"],
		[1, 2, Vector2i( 0,  1), "▼"],
	]
	for d in dirs:
		var col: int = d[0]; var row: int = d[1]
		var dir: Vector2i = d[2]; var sym: String = d[3]
		var btn := _make_dpad_btn(sym)
		btn.position = Vector2(col * BTN, row * BTN)
		btn.size = Vector2(BTN, BTN)
		_dpad_root.add_child(btn)
		btn.button_down.connect(func(): _rt.touch_dir = dir)
		btn.button_up.connect(func():
			if _rt.touch_dir == dir:
				_rt.touch_dir = Vector2i.ZERO)

func _make_dpad_btn(sym: String) -> Button:
	var btn := Button.new()
	btn.text = sym
	btn.add_theme_font_size_override("font_size", 28)
	btn.modulate = Color(1, 1, 1, 0.72)
	return btn

func _build_action_buttons() -> void:
	_dodge_btn = _make_action_btn("회피", Color(0.3, 0.85, 1.0))
	add_child(_dodge_btn)
	_dodge_btn.pressed.connect(func(): _rt.trigger_dodge())

	_parry_btn = _make_action_btn("막기", Color(1.0, 0.82, 0.25))
	add_child(_parry_btn)
	_parry_btn.pressed.connect(func(): _rt.trigger_parry())

func _make_action_btn(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 24)
	btn.add_theme_color_override("font_color", col)
	btn.modulate = Color(1, 1, 1, 0.82)
	return btn
