extends CanvasLayer
## Bottom-right build version + Credits button. Version tag reads
## res://version.txt written by CI (local plays show "dev"). Tapping the
## "Credits" button opens an AcceptDialog with CREDITS_LPC.md content.

const VERSION_FILE := "res://version.txt"
const CREDITS_LPC_PATH := "res://CREDITS_LPC.md"
const CREDITS_FONTS_PATH := "res://CREDITS_FONTS.md"

var _label: Label
var _credits_btn: Button


func _ready() -> void:
	layer = 200
	_label = Label.new()
	_label.text = _load_version()
	_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	_label.add_theme_font_size_override("font_size", 22)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -320
	_label.offset_top = -40
	_label.offset_right = -12
	_label.offset_bottom = -8
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)

	_credits_btn = Button.new()
	_credits_btn.text = "Credits"
	_credits_btn.flat = true
	_credits_btn.modulate = Color(0.7, 0.7, 0.7, 0.9)
	_credits_btn.add_theme_font_size_override("font_size", 20)
	_credits_btn.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_credits_btn.offset_left = -420
	_credits_btn.offset_top = -80
	_credits_btn.offset_right = -320
	_credits_btn.offset_bottom = -40
	_credits_btn.pressed.connect(_show_credits)
	add_child(_credits_btn)


func _show_credits() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Credits"
	dlg.ok_button_text = "Close"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 1400)
	dlg.add_child(scroll)
	var lab := Label.new()
	lab.text = _load_credits_text()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 18)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lab)
	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 1500))


func _load_credits_text() -> String:
	var out: String = ""
	for path in [CREDITS_LPC_PATH, CREDITS_FONTS_PATH]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				out += f.get_as_text() + "\n\n"
				f.close()
	if out == "":
		out = "(credits files not bundled in this build)"
	return out


func _load_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "dev"
	var f := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if f == null:
		return "dev"
	var text := f.get_as_text().strip_edges()
	f.close()
	return text if text != "" else "dev"
