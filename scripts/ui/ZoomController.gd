extends Node
class_name ZoomController
## Pinch-zoom + mouse-wheel camera zoom for the dungeon view.
## Mobile: two-finger pinch (with ScreenDrag fallback since browsers
## don't always deliver InputEventMagnifyGesture). While 2+ fingers are
## down we mark ALL touch input as handled so TouchInput doesn't get
## confused and fire taps/auto-move mid-pinch.
## Desktop: mouse wheel or trackpad magnify gesture.
## Persists to user://settings.json via SaveManager autoload.

const MIN_ZOOM: float = 0.25
const MAX_ZOOM: float = 8.0
const WHEEL_STEP_IN: float = 1.20
const WHEEL_STEP_OUT: float = 0.83
const DEFAULT_ZOOM: float = 6.5

@export var camera: Camera2D

var _current_zoom: float = DEFAULT_ZOOM
# Two-finger drag fallback state.
var _active_touches: Dictionary = {}  # index -> Vector2 position
var _last_pinch_dist: float = -1.0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_load_saved_zoom()
	_apply_zoom()


func _load_saved_zoom() -> void:
	var sm: Object = _get_save_manager()
	if sm == null:
		return
	var data: Dictionary = sm.load_json("user://settings.json")
	if data.has("zoom"):
		_current_zoom = clamp(float(data["zoom"]), MIN_ZOOM, MAX_ZOOM)


func _persist_zoom() -> void:
	var sm: Object = _get_save_manager()
	if sm == null:
		return
	var data: Dictionary = sm.load_json("user://settings.json")
	data["zoom"] = _current_zoom
	sm.save_json("user://settings.json", data)


func _get_save_manager() -> Object:
	return get_tree().root.get_node_or_null("SaveManager")


func _apply_zoom() -> void:
	if camera == null:
		return
	camera.zoom = Vector2(_current_zoom, _current_zoom)


func _set_zoom(z: float) -> void:
	var clamped: float = clamp(z, MIN_ZOOM, MAX_ZOOM)
	if abs(clamped - _current_zoom) < 0.001:
		return
	_current_zoom = clamped
	_apply_zoom()
	_persist_zoom()


func _unhandled_input(event: InputEvent) -> void:
	# Desktop trackpad magnify gesture.
	if event is InputEventMagnifyGesture:
		_set_zoom(_current_zoom * event.factor)
		get_viewport().set_input_as_handled()
		return

	# Desktop mouse wheel.
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_set_zoom(_current_zoom * WHEEL_STEP_IN)
			get_viewport().set_input_as_handled()
			return
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_set_zoom(_current_zoom * WHEEL_STEP_OUT)
			get_viewport().set_input_as_handled()
			return

	# Mobile: track touches; when 2+ fingers are down, consume events so
	# the tap/auto-move handler stays out of the way.
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_active_touches[st.index] = st.position
		else:
			_active_touches.erase(st.index)
			if _active_touches.size() < 2:
				_last_pinch_dist = -1.0
		if _active_touches.size() >= 2:
			get_viewport().set_input_as_handled()
		return

	if event is InputEventScreenDrag:
		var sd: InputEventScreenDrag = event
		_active_touches[sd.index] = sd.position
		if _active_touches.size() >= 2:
			var positions: Array = _active_touches.values()
			var a: Vector2 = positions[0]
			var b: Vector2 = positions[1]
			var dist: float = a.distance_to(b)
			if _last_pinch_dist > 0.0 and dist > 0.0:
				# Raw ratio — zoom range clamp in _set_zoom already prevents
				# runaway. Damping felt sluggish, especially on pinch-in.
				var factor: float = dist / _last_pinch_dist
				_set_zoom(_current_zoom * factor)
			_last_pinch_dist = dist
			get_viewport().set_input_as_handled()
