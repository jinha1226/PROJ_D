class_name CombatLogStrip extends Control

## On-screen rolling text of the last few CombatLog entries. Lives in
## the UI CanvasLayer between the map area and BottomHUD. Tap the
## strip to emit `tapped` — Game opens a full-history dialog on it.

signal tapped

const MAX_VISIBLE: int = 5

var _label: RichTextLabel
var _bg: ColorRect
var _messages: Array = []
var CombatLog = null

func _ready() -> void:
	CombatLog = get_node_or_null("/root/CombatLog")
	mouse_filter = Control.MOUSE_FILTER_STOP
	_bg = ColorRect.new()
	_bg.color = Color(0.05, 0.04, 0.08, 0.55)
	_bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bg.anchor_right = 1.0
	_bg.anchor_bottom = 1.0
	add_child(_bg)

	_label = RichTextLabel.new()
	_label.bbcode_enabled = true
	_label.scroll_active = false
	_label.fit_content = true
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.anchor_right = 1.0
	_label.anchor_bottom = 1.0
	_label.offset_left = 10
	_label.offset_right = -10
	_label.offset_top = 6
	_label.offset_bottom = -6
	_label.add_theme_font_size_override("normal_font_size", 22)
	add_child(_label)

	CombatLog.message_added.connect(_on_message)
	gui_input.connect(_on_gui_input)
	# Prime with any existing history so a scene reload doesn't show empty.
	for entry in CombatLog.history.slice(
			max(0, CombatLog.history.size() - MAX_VISIBLE)):
		_messages.append(entry)
	_rebuild()

func _on_gui_input(event: InputEvent) -> void:
	var is_press: bool = false
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		is_press = true
	elif event is InputEventScreenTouch and event.pressed:
		is_press = true
	if is_press:
		tapped.emit()
		accept_event()

func _on_message(text: String, color: Color) -> void:
	_messages.append({"text": text, "color": color})
	while _messages.size() > MAX_VISIBLE:
		_messages.pop_front()
	_rebuild()

func _rebuild() -> void:
	if _label == null:
		return
	var out: String = ""
	for i in range(_messages.size()):
		var msg: Dictionary = _messages[i]
		var age: int = _messages.size() - 1 - i
		var fade: float = lerp(1.0, 0.45,
			float(age) / float(max(1, MAX_VISIBLE - 1)))
		var c: Color = msg.get("color", Color.WHITE)
		var faded := Color(c.r, c.g, c.b, fade)
		out += "[color=#%s]%s[/color]" % [faded.to_html(true), msg.get("text", "")]
		if i < _messages.size() - 1:
			out += "\n"
	_label.text = out
