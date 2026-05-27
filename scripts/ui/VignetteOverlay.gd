extends Control
class_name VignetteOverlay

var _alpha: float = 0.0
var _target_alpha: float = 0.0

func _process(delta: float) -> void:
	_alpha = move_toward(_alpha, _target_alpha, delta * 4.0)
	queue_redraw()

func set_hp_ratio(ratio: float) -> void:
	if ratio <= 0.15:
		_target_alpha = 0.7
	elif ratio <= 0.35:
		_target_alpha = remap(ratio, 0.15, 0.35, 0.7, 0.0)
	else:
		_target_alpha = 0.0

func _draw() -> void:
	if _alpha < 0.01:
		return
	var s: Vector2 = get_viewport_rect().size
	var max_thick: float = min(s.x, s.y) * 0.22
	# Draw 6 overlapping border strips — outermost is thickest and most opaque,
	# inner strips fade out to simulate a vignette gradient.
	for i in 6:
		var frac: float = float(6 - i) / 6.0
		var thick: float = max_thick * frac
		var a: float = _alpha * frac * 0.28
		var c := Color(0.9, 0.04, 0.04, a)
		draw_rect(Rect2(0, 0, s.x, thick), c)
		draw_rect(Rect2(0, s.y - thick, s.x, thick), c)
		draw_rect(Rect2(0, 0, thick, s.y), c)
		draw_rect(Rect2(s.x - thick, 0, thick, s.y), c)
