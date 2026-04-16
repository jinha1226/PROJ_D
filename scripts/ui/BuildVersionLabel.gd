extends CanvasLayer
## Bottom-right build version tag. Reads res://version.txt written by CI.
## Local plays (no CI) show "dev".

const VERSION_FILE := "res://version.txt"

var _label: Label


func _ready() -> void:
	layer = 200
	_label = Label.new()
	_label.text = _load_version()
	_label.modulate = Color(0.7, 0.7, 0.7, 0.8)
	_label.add_theme_font_size_override("font_size", 14)
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	_label.offset_left = -180
	_label.offset_top = -28
	_label.offset_right = -8
	_label.offset_bottom = -4
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_label)


func _load_version() -> String:
	if not FileAccess.file_exists(VERSION_FILE):
		return "dev"
	var f := FileAccess.open(VERSION_FILE, FileAccess.READ)
	if f == null:
		return "dev"
	var text := f.get_as_text().strip_edges()
	f.close()
	return text if text != "" else "dev"
