extends Control
class_name RTControlOverlay

const JOY_BASE_R: float  = 80.0   # outer ring radius
const JOY_KNOB_R: float  = 32.0   # draggable knob radius
const JOY_DEAD: float    = 14.0   # dead zone
const ACTION_W: int      = 110
const ACTION_H: int      = 88
const ACTION_GAP: int    = 14
const HUD_H: int         = 148
const PAD: int           = 20

var _rt: RealTimeController
var _dodge_btn: Button
var _parry_btn: Button

# Joystick touch state
var _joy_active: bool   = false
var _joy_finger: int    = -1
var _joy_base: Vector2  = Vector2.ZERO
var _joy_knob: Vector2  = Vector2.ZERO

# ── Setup ─────────────────────────────────────────────────────────────────────

func setup(rt_controller: RealTimeController) -> void:
	_rt = rt_controller
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_build_action_buttons()

func _vp_size() -> Vector2:
	return get_viewport().get_visible_rect().size

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED or what == NOTIFICATION_VISIBILITY_CHANGED:
		call_deferred("_reposition")   # deferred so viewport size is ready

func _reposition() -> void:
	var sz := _vp_size()
	if sz == Vector2.ZERO:
		return
	if _dodge_btn:
		_dodge_btn.position = Vector2(sz.x - PAD - ACTION_W,
				sz.y - HUD_H - ACTION_GAP - ACTION_H * 2)
		_dodge_btn.size = Vector2(ACTION_W, ACTION_H)
	if _parry_btn:
		_parry_btn.position = Vector2(sz.x - PAD - ACTION_W,
				sz.y - HUD_H - ACTION_H)
		_parry_btn.size = Vector2(ACTION_W, ACTION_H)

# ── Action buttons ────────────────────────────────────────────────────────────

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

# ── Joystick input ────────────────────────────────────────────────────────────

func _input(event: InputEvent) -> void:
	if not visible or _rt == null:
		return
	var left_edge: float = _vp_size().x * 0.5

	if event is InputEventScreenTouch:
		if event.pressed and event.position.x < left_edge:
			_joy_active = true
			_joy_finger = event.index
			_joy_base   = event.position
			_joy_knob   = event.position
			_rt.touch_dir = Vector2i.ZERO
			queue_redraw()
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == _joy_finger:
			_joy_end()

	elif event is InputEventScreenDrag and event.index == _joy_finger and _joy_active:
		_joy_update(event.position)

	# ── Mouse fallback (desktop F5 test) ──────────────────────────────────
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and event.position.x < left_edge:
			_joy_active = true
			_joy_finger = 0
			_joy_base   = event.position
			_joy_knob   = event.position
			_rt.touch_dir = Vector2i.ZERO
			queue_redraw()
		elif not event.pressed:
			_joy_end()

	elif event is InputEventMouseMotion and _joy_active and _joy_finger == 0:
		_joy_update(event.position)

func _joy_update(pos: Vector2) -> void:
	var offset: Vector2 = pos - _joy_base
	_joy_knob = _joy_base + offset.limit_length(JOY_BASE_R)
	if offset.length() > JOY_DEAD:
		_rt.touch_dir = _angle_to_dir(offset.angle())
	else:
		_rt.touch_dir = Vector2i.ZERO
	queue_redraw()
	get_viewport().set_input_as_handled()

func _joy_end() -> void:
	_joy_active = false
	_joy_finger = -1
	_rt.touch_dir = Vector2i.ZERO
	queue_redraw()

func _angle_to_dir(angle: float) -> Vector2i:
	# Map continuous angle to nearest of 8 tile directions.
	# fposmod normalises to [0, 2PI) so sector arithmetic is always positive.
	var sector: int = int(round(fposmod(angle, TAU) / (PI / 4.0))) % 8
	match sector:
		0: return Vector2i( 1,  0)
		1: return Vector2i( 1,  1)
		2: return Vector2i( 0,  1)
		3: return Vector2i(-1,  1)
		4: return Vector2i(-1,  0)
		5: return Vector2i(-1, -1)
		6: return Vector2i( 0, -1)
		7: return Vector2i( 1, -1)
	return Vector2i( 1,  0)

# ── Visual ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	if not _joy_active:
		return
	# Outer ring
	draw_arc(_joy_base, JOY_BASE_R, 0.0, TAU, 40, Color(1, 1, 1, 0.28), 3.0)
	# Knob fill
	draw_circle(_joy_knob, JOY_KNOB_R, Color(1, 1, 1, 0.42))
	# Knob ring
	draw_arc(_joy_knob, JOY_KNOB_R, 0.0, TAU, 24, Color(1, 1, 1, 0.70), 2.0)
