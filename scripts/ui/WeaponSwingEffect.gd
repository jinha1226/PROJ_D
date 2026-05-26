class_name WeaponSwingEffect extends Node2D

var _angle: float = 0.0
var _progress: float = 0.0
var _type: String = "slash"
var _color: Color = Color.WHITE

func start(from_world: Vector2, to_world: Vector2, weapon_skill: String) -> void:
	_angle = (to_world - from_world).angle()
	_type = _skill_to_type(weapon_skill)
	_color = _type_color(_type)
	var tw := create_tween()
	tw.tween_method(_set_progress, 0.0, 1.0, 0.20)
	tw.tween_callback(queue_free)

func _skill_to_type(skill: String) -> String:
	match skill:
		"polearms": return "thrust"
		"axes", "staves": return "swing"
		_: return "slash"

func _type_color(type: String) -> Color:
	match type:
		"thrust": return Color(1.0, 1.0, 0.6)
		"swing":  return Color(1.0, 0.72, 0.3)
		_:        return Color(0.82, 0.94, 1.0)

func _set_progress(v: float) -> void:
	_progress = v
	queue_redraw()

func _draw() -> void:
	var alpha := sin(_progress * PI)
	if alpha <= 0.01:
		return
	var c := Color(_color.r, _color.g, _color.b, alpha)
	match _type:
		"slash":  _draw_slash(c)
		"swing":  _draw_swing(c)
		"thrust": _draw_thrust(c)

func _draw_slash(c: Color) -> void:
	# 3 lines in a 60° fan facing attack direction
	for i in range(3):
		var a := _angle + deg_to_rad(-30.0 + i * 30.0)
		var p1 := Vector2(cos(a), sin(a)) * 5.0
		var p2 := Vector2(cos(a), sin(a)) * 18.0
		draw_line(p1, p2, c, 2.0, true)

func _draw_swing(c: Color) -> void:
	# 5 lines in a 100° arc — heavy chopping arc
	for i in range(5):
		var a := _angle + deg_to_rad(-50.0 + i * 25.0)
		var p1 := Vector2(cos(a), sin(a)) * 4.0
		var p2 := Vector2(cos(a), sin(a)) * 20.0
		draw_line(p1, p2, c, 2.5, true)

func _draw_thrust(c: Color) -> void:
	# Single spike extending toward target, retracts after peak
	var length := 22.0 * sin(_progress * PI)
	if length < 0.5:
		return
	var tip := Vector2(cos(_angle), sin(_angle)) * length
	draw_line(Vector2.ZERO, tip, c, 3.0, true)
	draw_circle(tip, 3.0, c)
