class_name TouchScrollHelper
extends Node
## Reliable touch-drag scroll on mobile web. Godot 4's built-in
## `ScrollContainer.scroll_deadzone` requires the child Control to
## propagate drag events to the container — Buttons with
## `MOUSE_FILTER_STOP` (the default) swallow them, and the mobile web
## export in particular drops the drag handoff. Behavior symptom:
## tapping on a row selects/highlights fine but finger-drag does not
## scroll the list.
##
## Install via `TouchScrollHelper.install(some_scroll_container)`. The
## helper parents itself to the scroll container and listens on
## `_input()` (event cone is the whole viewport) so it sees drags
## regardless of which child consumed the initial press. When the
## finger travels past a threshold inside the scroll's rect, it starts
## adjusting `scroll_vertical` directly and marks the event handled so
## child Buttons don't register the release as a click.

const DRAG_THRESHOLD_PX: float = 10.0

var _scroll: ScrollContainer = null
var _drag_start_y: float = -1.0
var _drag_start_scroll: int = 0
var _is_dragging: bool = false


static func install(scroll: ScrollContainer) -> TouchScrollHelper:
	if scroll == null:
		return null
	# Only install once per ScrollContainer.
	var existing: Node = scroll.get_node_or_null("TouchScrollHelper")
	if existing != null and existing is TouchScrollHelper:
		return existing
	var helper := TouchScrollHelper.new()
	helper.name = "TouchScrollHelper"
	helper._scroll = scroll
	scroll.add_child(helper)
	return helper


func _ready() -> void:
	# Make sure we receive events even when the parent stops propagation.
	process_mode = Node.PROCESS_MODE_ALWAYS


func _input(event: InputEvent) -> void:
	if _scroll == null or not is_instance_valid(_scroll):
		return
	if not _scroll.is_visible_in_tree():
		_reset()
		return

	var pos: Vector2
	var is_press: bool = false
	var is_release: bool = false
	var is_motion: bool = false

	if event is InputEventScreenTouch:
		pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT:
			return
		pos = event.position
		if event.pressed:
			is_press = true
		else:
			is_release = true
	elif event is InputEventScreenDrag:
		pos = event.position
		is_motion = true
	elif event is InputEventMouseMotion:
		# Mouse motion only counts when the left button is held; otherwise
		# a hover would accidentally start a drag.
		if not (event.button_mask & MOUSE_BUTTON_MASK_LEFT):
			return
		pos = event.position
		is_motion = true
	else:
		return

	var rect: Rect2 = _scroll.get_global_rect()

	if is_press:
		if rect.has_point(pos):
			_drag_start_y = pos.y
			_drag_start_scroll = _scroll.scroll_vertical
			_is_dragging = false
	elif is_motion and _drag_start_y >= 0.0:
		var dy: float = pos.y - _drag_start_y
		if not _is_dragging and abs(dy) > DRAG_THRESHOLD_PX:
			_is_dragging = true
		if _is_dragging:
			_scroll.scroll_vertical = _drag_start_scroll - int(dy)
			get_viewport().set_input_as_handled()
	elif is_release:
		if _is_dragging:
			# Tell any Button that already pressed itself not to fire a
			# click on release — clear button_pressed + release focus on
			# every BaseButton descendant. Toggle-mode buttons reset their
			# "selected" visual via button_pressed = false; non-toggle
			# buttons were never going to fire now that the release is
			# marked handled, but we still belt-and-suspenders clear.
			_cancel_button_presses(_scroll)
			get_viewport().set_input_as_handled()
		_reset()


func _reset() -> void:
	_drag_start_y = -1.0
	_drag_start_scroll = 0
	_is_dragging = false


func _cancel_button_presses(root: Node) -> void:
	for child in root.get_children():
		if child is BaseButton:
			if child.button_pressed and not child.toggle_mode:
				child.button_pressed = false
		if child.get_child_count() > 0:
			_cancel_button_presses(child)
