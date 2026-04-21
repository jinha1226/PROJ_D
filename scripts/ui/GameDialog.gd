class_name GameDialog
extends CanvasLayer

signal closed

## Default fraction of the viewport the dialog window occupies. Bigger
## looks better on phones (more tap area). 0.92 gives an 8% margin
## on each side so the Close button stays clear of the OS gesture bar.
const DEFAULT_RATIO: Vector2 = Vector2(0.92, 0.92)

## Per-dialog ratio override, used when `create_ratio(...)` is called
## with explicit width/height fractions.
var _ratio: Vector2 = DEFAULT_RATIO
var _on_close_cb: Callable = Callable()
var _closed: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _window: PanelContainer = $Dim/Window
@onready var _title_label: Label = $Dim/Window/Margin/VBox/TitleRow/TitleLabel
@onready var _body_vbox: VBoxContainer = $Dim/Window/Margin/VBox/Body/BodyVBox
@onready var _close_button: Button = $Dim/Window/Margin/VBox/CloseButton


## Primary factory — accepts a legacy Vector2i pixel size for backward
## compat with the 20+ existing call sites, but the actual window is
## sized from the viewport using DEFAULT_RATIO. Pixel size is ignored.
## Prefer create_ratio() for new call sites.
static func create(title: String, _size: Vector2i = Vector2i(960, 1800)) -> GameDialog:
	var scene: PackedScene = load("res://scenes/ui/GameDialog.tscn")
	var dlg: GameDialog = scene.instantiate()
	dlg.set_meta("_pending_title", title)
	return dlg


## Explicit-ratio factory. Pass (0.8, 0.8) for an 80%-of-screen dialog.
## Ratios are clamped to [0.2, 1.0]. Use this for popups that should
## look smaller (info tooltips etc.) or larger than the default.
static func create_ratio(title: String, width_ratio: float = 0.92,
		height_ratio: float = 0.92) -> GameDialog:
	var scene: PackedScene = load("res://scenes/ui/GameDialog.tscn")
	var dlg: GameDialog = scene.instantiate()
	dlg.set_meta("_pending_title", title)
	dlg.set_meta("_pending_ratio", Vector2(
			clampf(width_ratio, 0.2, 1.0),
			clampf(height_ratio, 0.2, 1.0)))
	return dlg


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)
	if has_meta("_pending_title"):
		_title_label.text = String(get_meta("_pending_title"))
		remove_meta("_pending_title")
	if has_meta("_pending_ratio"):
		_ratio = get_meta("_pending_ratio")
		remove_meta("_pending_ratio")
	_resize_from_viewport()
	# Re-fit on viewport changes (orientation flip, resize on desktop).
	var vp: Viewport = get_viewport()
	if vp != null and not vp.size_changed.is_connected(_resize_from_viewport):
		vp.size_changed.connect(_resize_from_viewport)


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
		get_viewport().set_input_as_handled()


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
		get_viewport().set_input_as_handled()


## Recompute window size from the current viewport. Fires once on
## _ready and again on every viewport size_changed signal, so rotating
## a phone or resizing the desktop window keeps the dialog centred
## and scaled to DEFAULT_RATIO (or the per-dialog override set via
## create_ratio).
func _resize_from_viewport() -> void:
	if _window == null:
		return
	var vp: Viewport = get_viewport()
	if vp == null:
		return
	var vps: Vector2 = vp.get_visible_rect().size
	var w: float = vps.x * _ratio.x
	var h: float = vps.y * _ratio.y
	_window.custom_minimum_size = Vector2(w, h)
	_window.offset_left = -w / 2.0
	_window.offset_top = -h / 2.0
	_window.offset_right = w / 2.0
	_window.offset_bottom = h / 2.0
