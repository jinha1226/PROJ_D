extends CanvasLayer
class_name SkillLevelUpToast

## Singleton-ish helper: maintain a vertical stack of floating level-up toasts.
## Each call to `show_toast(text)` spawns a new label, animates in, holds, fades out.

const BASE_Y: float = 240.0
const SPACING: float = 96.0
const FONT_SIZE: int = 56
const LABEL_H: float = 88.0


var _active_labels: Array = []


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 40


func show_toast(text: String) -> void:
	var lbl: Label = Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", FONT_SIZE)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.92, 0.4, 1.0))
	lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	lbl.add_theme_constant_override("outline_size", 8)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.anchor_left = 0.5
	lbl.anchor_right = 0.5
	lbl.offset_left = -520
	lbl.offset_right = 520
	lbl.pivot_offset = Vector2(520, LABEL_H * 0.5)
	add_child(lbl)

	_active_labels.append(lbl)
	_reflow()

	var target_y: float = lbl.offset_top
	# Drop in from above + scale-in pop, then hold, then drift up and fade.
	lbl.offset_top = target_y - 60
	lbl.offset_bottom = target_y - 60 + LABEL_H
	lbl.modulate = Color(1, 1, 1, 0)
	lbl.scale = Vector2(0.55, 0.55)

	var tw: Tween = create_tween()
	tw.parallel().tween_property(lbl, "modulate", Color(1, 1, 1, 1), 0.22)
	tw.parallel().tween_property(lbl, "offset_top", target_y, 0.24) \
			.set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "scale", Vector2(1.12, 1.12), 0.18) \
			.set_ease(Tween.EASE_OUT)
	tw.chain().tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.12)
	tw.tween_interval(2.0)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.45)
	tw.parallel().tween_property(lbl, "offset_top", target_y - 40, 0.45)
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
		lbl.offset_bottom = y + LABEL_H
