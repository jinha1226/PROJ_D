extends CanvasLayer
## Bottom-right build version tag. Reads res://version.txt written by CI.
## Local plays (no CI) show "dev". Credits live on the MainMenu now.
##
## Hidden font-comparison toggle: tapping the label cycles the project theme's
## default_font through the bundled pixel-font candidates so the user can
## compare them in-context. Mutates the shared Theme resource — change
## reverts on next session restart.

const VERSION_FILE := "res://version.txt"

const _FONT_CHOICES: Array = [
	{"name": "Galmuri11", "path": "res://assets/fonts/Galmuri11.ttf"},
	{"name": "Galmuri9",  "path": "res://assets/fonts/Galmuri9.ttf"},
	{"name": "Galmuri7",  "path": "res://assets/fonts/Galmuri7.ttf"},
	{"name": "Neodgm",    "path": "res://assets/fonts/Neodgm.ttf"},
]

var _label: Label
var _btn: Button
var _font_idx: int = 0


func _ready() -> void:
	layer = 200
	# Wrap the label in an invisible Button so tapping cycles fonts but the
	# normal version text still reads naturally.
	_btn = Button.new()
	_btn.flat = true
	_btn.text = ""
	_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_btn.offset_left = -320
	_btn.offset_top = -40
	_btn.offset_right = -12
	_btn.offset_bottom = -8
	_btn.pressed.connect(_cycle_font)
	add_child(_btn)

	_label = Label.new()
	_label.text = _load_version()
	_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	_label.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_btn.add_child(_label)


func _cycle_font() -> void:
	_font_idx = (_font_idx + 1) % _FONT_CHOICES.size()
	var choice: Dictionary = _FONT_CHOICES[_font_idx]
	var font_res = load(choice.path)
	if font_res == null:
		return
	var theme: Theme = load("res://assets/theme.tres") as Theme
	if theme == null:
		return
	theme.default_font = font_res
	_label.text = "%s · %s" % [_load_version(), String(choice.name)]


func _load_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "dev"
	var f := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if f == null:
		return "dev"
	var text := f.get_as_text().strip_edges()
	f.close()
	return text if text != "" else "dev"
