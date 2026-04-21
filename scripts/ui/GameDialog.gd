class_name GameDialog
extends CanvasLayer

signal closed

var _on_close_cb: Callable = Callable()
var _closed: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _window: PanelContainer = $Dim/Window
@onready var _title_label: Label = $Dim/Window/Margin/VBox/TitleRow/TitleLabel
@onready var _body_vbox: VBoxContainer = $Dim/Window/Margin/VBox/Body/BodyVBox
@onready var _close_button: Button = $Dim/Window/Margin/VBox/CloseButton


static func create(title: String, size: Vector2i) -> GameDialog:
	var scene: PackedScene = load("res://scenes/ui/GameDialog.tscn")
	var dlg: GameDialog = scene.instantiate()
	dlg.set_meta("_pending_title", title)
	dlg.set_meta("_pending_size", size)
	return dlg


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)
	if has_meta("_pending_title"):
		_title_label.text = String(get_meta("_pending_title"))
		remove_meta("_pending_title")
	if has_meta("_pending_size"):
		var sz: Vector2i = get_meta("_pending_size")
		_resize_window(sz)
		remove_meta("_pending_size")


func body() -> VBoxContainer:
	if _body_vbox == null:
		# @onready not yet resolved; happens if body() is called before
		# the node enters the tree. Walk the scene to resolve manually.
		return get_node("Dim/Window/Margin/VBox/Body/BodyVBox") as VBoxContainer
	return _body_vbox


func set_close_text(text: String) -> void:
	_close_button.text = text


func set_on_close(cb: Callable) -> void:
	_on_close_cb = cb


func close() -> void:
	if _closed:
		return
	_closed = true
	if _on_close_cb.is_valid():
		_on_close_cb.call()
	closed.emit()
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()


func _on_dim_input(event: InputEvent) -> void:
	var is_click := false
	if event is InputEventMouseButton and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
	if not is_click:
		return
	var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
	if not _window.get_global_rect().has_point(pos):
		close()
		accept_event()


func _resize_window(size: Vector2i) -> void:
	_window.custom_minimum_size = Vector2(size.x, size.y)
	_window.offset_left = -size.x / 2.0
	_window.offset_top = -size.y / 2.0
	_window.offset_right = size.x / 2.0
	_window.offset_bottom = size.y / 2.0
