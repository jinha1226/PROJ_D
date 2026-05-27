extends Control
class_name PortalReturnEffect

signal finished

const _PHASE_SWIRL  := 0
const _PHASE_EXPAND := 1
const _PHASE_FLASH  := 2

const _DUR_SWIRL  := 0.40
const _DUR_EXPAND := 0.30
const _DUR_FLASH  := 0.20

var _phase: int = _PHASE_SWIRL
var _t: float = 0.0
var _origin: Vector2 = Vector2.ZERO
var _max_r: float = 0.0

func start(screen_origin: Vector2) -> void:
	_origin = screen_origin
	_t = 0.0
	_phase = _PHASE_SWIRL
	var s: Vector2 = get_viewport_rect().size
	_max_r = max(
		_origin.distance_to(Vector2.ZERO),
		_origin.distance_to(Vector2(s.x, 0.0)),
		_origin.distance_to(Vector2(0.0, s.y)),
		_origin.distance_to(s)
	) + 16.0
	set_process(true)

func _process(delta: float) -> void:
	_t += delta
	var dur: float
	match _phase:
		_PHASE_SWIRL:  dur = _DUR_SWIRL
		_PHASE_EXPAND: dur = _DUR_EXPAND
		_:             dur = _DUR_FLASH
	if _t >= dur:
		_t -= dur
		_phase += 1
		if _phase > _PHASE_FLASH:
			set_process(false)
			finished.emit()
			return
	queue_redraw()

func _draw() -> void:
	var s: Vector2 = get_viewport_rect().size
	match _phase:
		_PHASE_SWIRL:  _draw_swirl(s)
		_PHASE_EXPAND: _draw_expand(s)
		_PHASE_FLASH:  _draw_flash(s)

func _draw_swirl(s: Vector2) -> void:
	var t: float = _t / _DUR_SWIRL
	# Darkening background
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.02, 0.18, t * 0.55))
	# 6 rotating arcs — staggered in time, spiraling outward
	for i in 6:
		var arc_t: float = clamp(t * 1.5 - i * 0.10, 0.0, 1.0)
		if arc_t <= 0.0:
			continue
		var r: float = arc_t * _max_r * 0.48
		var alpha: float = (1.0 - arc_t * 0.7) * 0.75
		var spin: float = _t * TAU * (1.1 + i * 0.18)
		var arc_span: float = TAU * (0.50 + i * 0.03)
		var col := Color(0.25 + i * 0.07, 0.50 + i * 0.05, 1.0, alpha)
		draw_arc(_origin, r, spin, spin + arc_span, 72, col, 2.5 + i * 0.6)

func _draw_expand(s: Vector2) -> void:
	var t: float = _t / _DUR_EXPAND
	# Ease-in²: slow open → fast swallow
	var et: float = t * t
	var r: float = et * _max_r
	# Dark backdrop (constant)
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.0, 0.02, 0.18, 0.55))
	# Portal disk
	draw_circle(_origin, r, Color(0.05, 0.07, 0.30, 0.97))
	# Bright rim on the expanding edge
	if r > 4.0:
		draw_arc(_origin, r, 0.0, TAU, 128, Color(0.55, 0.78, 1.0, 0.80 * (1.0 - t * 0.4)), 5.0)
		draw_arc(_origin, r - 6.0, 0.0, TAU, 128, Color(0.8, 0.92, 1.0, 0.40 * (1.0 - t * 0.6)), 3.0)

func _draw_flash(s: Vector2) -> void:
	var t: float = _t / _DUR_FLASH
	# Full navy cover carries over from expand
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.05, 0.07, 0.30, 1.0))
	# White-blue flash fades out
	draw_rect(Rect2(Vector2.ZERO, s), Color(0.80, 0.92, 1.0, (1.0 - t) * 0.90))
