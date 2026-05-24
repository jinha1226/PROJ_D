extends Control
class_name RTControlOverlay

const BTN: int = 88           # D-pad button size (px)
const HUD_H: int = 148        # BottomHUD height to clear
const PAD: int = 16           # outer padding from edges
const ACTION_W: int = 110     # dodge/parry button width
const ACTION_H: int = 88      # dodge/parry button height
const ACTION_GAP: int = 12    # gap between dodge and parry

var _rt: RealTimeController

func setup(rt_controller: RealTimeController) -> void:
	_rt = rt_controller
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_dpad()
	_build_action_buttons()

func set_rt_visible(enabled: bool) -> void:
	visible = enabled

# ── D-pad ────────────────────────────────────────────────────────────────────

func _build_dpad() -> void:
	# Container: bottom-left corner, above HUD
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# anchor to bottom-left
	c.anchor_left = 0.0;  c.anchor_right  = 0.0
	c.anchor_top  = 1.0;  c.anchor_bottom = 1.0
	c.offset_left   = PAD
	c.offset_right  = PAD + BTN * 3
	c.offset_top    = -(HUD_H + BTN * 3 + PAD)
	c.offset_bottom = -(HUD_H)
	add_child(c)

	# col, row, dir, symbol
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
		c.add_child(btn)
		btn.button_down.connect(func(): _rt.touch_dir = dir)
		btn.button_up.connect(func():
			if _rt.touch_dir == dir:
				_rt.touch_dir = Vector2i.ZERO)

func _make_dpad_btn(sym: String) -> Button:
	var btn := Button.new()
	btn.text = sym
	btn.add_theme_font_size_override("font_size", 26)
	# Semi-transparent dark background
	btn.add_theme_color_override("font_color", Color(1, 1, 1, 0.85))
	btn.modulate = Color(1, 1, 1, 0.70)
	return btn

# ── Dodge / Parry ─────────────────────────────────────────────────────────────

func _build_action_buttons() -> void:
	var dodge_btn := _make_action_btn("회피", Color(0.3, 0.85, 1.0, 0.85))
	# anchor bottom-right
	dodge_btn.anchor_left   = 1.0; dodge_btn.anchor_right  = 1.0
	dodge_btn.anchor_top    = 1.0; dodge_btn.anchor_bottom = 1.0
	dodge_btn.offset_left   = -(PAD + ACTION_W)
	dodge_btn.offset_right  = -PAD
	dodge_btn.offset_top    = -(HUD_H + ACTION_GAP + ACTION_H * 2)
	dodge_btn.offset_bottom = -(HUD_H + ACTION_GAP + ACTION_H)
	add_child(dodge_btn)
	dodge_btn.pressed.connect(func(): _rt.trigger_dodge())

	var parry_btn := _make_action_btn("막기", Color(1.0, 0.85, 0.3, 0.85))
	parry_btn.anchor_left   = 1.0; parry_btn.anchor_right  = 1.0
	parry_btn.anchor_top    = 1.0; parry_btn.anchor_bottom = 1.0
	parry_btn.offset_left   = -(PAD + ACTION_W)
	parry_btn.offset_right  = -PAD
	parry_btn.offset_top    = -(HUD_H + ACTION_H)
	parry_btn.offset_bottom = -(HUD_H)
	add_child(parry_btn)
	parry_btn.pressed.connect(func(): _rt.trigger_parry())

func _make_action_btn(label: String, col: Color) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.add_theme_font_size_override("font_size", 22)
	btn.add_theme_color_override("font_color", col)
	btn.modulate = Color(1, 1, 1, 0.80)
	return btn
