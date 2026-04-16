extends CanvasLayer
class_name SkillLevelUpToast

## Singleton-ish helper: maintain a vertical stack of floating level-up toasts.
## Each call to `show_toast(text)` spawns a new label, animates in, holds, fades out.

const BASE_Y: float = 200.0
const SPACING: float = 56.0

var _active_labels: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40


func show_toast(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 32)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.offset_left = -300
	lbl.offset_right = 300
	add_child(lbl)

	# Compute current stacked y.
	_active_labels.append(lbl)
	_reflow()

	var target_y: float = lbl.offset_top
	lbl.offset_top = target_y - 40
	lbl.offset_bottom = target_y - 40 + 50
	lbl.modulate = Color(1, 1, 1, 0)

	var tw: Tween = create_tween()
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.2)
	tw.parallel().tween_property(lbl, "offset_top", target_y, 0.2)
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate", Color(1, 1, 1, 0), 0.3)
	tw.tween_callback(func():
		if _active_labels.has(lbl):
			_active_labels.erase(lbl)
		if is_instance_valid(lbl):
			lbl.queue_free()
		_reflow())


func _reflow() -> void:
	for i in range(_active_labels.size()):
		var lbl: Label = _active_labels[i]
		if not is_instance_valid(lbl):
			continue
		var y: float = BASE_Y + float(i) * SPACING
		lbl.offset_top = y
		lbl.offset_bottom = y + 50
