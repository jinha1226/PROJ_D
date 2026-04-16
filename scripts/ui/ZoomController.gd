extends Node
class_name ZoomController
## Handles pinch/magnify gestures and exposes step-zoom for UI buttons.
## Modifies a target Camera2D's zoom uniformly. Persists to user://settings.json
## via SaveManager autoload.

const MIN_ZOOM: float = 0.5
const MAX_ZOOM: float = 4.0
const STEP_IN: float = 1.25
const STEP_OUT: float = 0.8
const DEFAULT_ZOOM: float = 2.0

@export var camera: Camera2D

var _current_zoom: float = DEFAULT_ZOOM
# Two-finger drag fallback state (if the platform doesn't deliver magnify events).
var _active_touches: Dictionary = {} # index -> Vector2 position
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


func zoom_in() -> void:
	_set_zoom(_current_zoom * STEP_IN)


func zoom_out() -> void:
	_set_zoom(_current_zoom * STEP_OUT)


func _set_zoom(z: float) -> void:
	_current_zoom = clamp(z, MIN_ZOOM, MAX_ZOOM)
	_apply_zoom()
	_persist_zoom()


func _unhandled_input(event: InputEvent) -> void:
	# Native pinch/magnify (desktop trackpads / some mobile setups).
	if event is InputEventMagnifyGesture:
		var mg: InputEventMagnifyGesture = event
		_set_zoom(_current_zoom * mg.factor)
		get_viewport().set_input_as_handled()
		return

	# Two-finger drag fallback using ScreenTouch + ScreenDrag.
	if event is InputEventScreenTouch:
		var st: InputEventScreenTouch = event
		if st.pressed:
			_active_touches[st.index] = st.position
		else:
			_active_touches.erase(st.index)
			if _active_touches.size() < 2:
				_last_pinch_dist = -1.0
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
				var factor: float = dist / _last_pinch_dist
				_set_zoom(_current_zoom * factor)
				get_viewport().set_input_as_handled()
			_last_pinch_dist = dist
