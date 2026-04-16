extends CanvasLayer
class_name SkillsScreen

const SKILL_ROW_SCENE: PackedScene = preload("res://scenes/ui/SkillRow.tscn")

const CATEGORIES: Array = ["all", "weapon", "defense", "magic", "misc"]
const CATEGORY_LABELS: Dictionary = {
	"all": "ALL",
	"weapon": "WEAPON",
	"defense": "DEFENSE",
	"magic": "MAGIC",
	"misc": "MISC",
}

var _player: Node = null
var _current_category: String = "all"
var _rows: Dictionary = {} # skill_id -> SkillRow
var _skill_system: SkillSystem = null

@onready var _bg: ColorRect = $Dim
@onready var _panel: Panel = $Dim/Panel
@onready var _tabs_box: HBoxContainer = $Dim/Panel/Margin/VBox/Tabs
@onready var _rows_vbox: VBoxContainer = $Dim/Panel/Margin/VBox/Scroll/Rows
@onready var _close_button: Button = $Dim/Panel/Margin/VBox/Header/CloseButton


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_bg.gui_input.connect(_on_bg_input)
	_close_button.pressed.connect(_force_close)
	_build_tabs()
	_bg.modulate = Color(1, 1, 1, 0)


func _force_close() -> void:
	# Defensive: free immediately, don't rely on tween callback which may
	# not fire if the scene is torn down mid-animation.
	queue_free()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		_force_close()
		accept_event()


func show_for_player(player: Node) -> void:
	_player = player
	_skill_system = get_tree().root.get_node_or_null("Game/SkillSystem") as SkillSystem
	if _skill_system == null:
		var cs: Node = get_tree().current_scene
		if cs != null:
			_skill_system = cs.get_node_or_null("SkillSystem") as SkillSystem
	if _skill_system == null:
		# Broad fallback: search the whole tree for any SkillSystem node.
		for n in get_tree().get_nodes_in_group("skill_system"):
			if n is SkillSystem:
				_skill_system = n
				break
	if _skill_system != null:
		if not _skill_system.skill_leveled_up.is_connected(_on_skill_leveled_up):
			_skill_system.skill_leveled_up.connect(_on_skill_leveled_up)
		if not _skill_system.xp_gained.is_connected(_on_xp_gained):
			_skill_system.xp_gained.connect(_on_xp_gained)
	_rebuild_rows()
	visible = true
	var tw: Tween = create_tween()
	tw.tween_property(_bg, "modulate", Color(1, 1, 1, 1), 0.15)


func hide_screen() -> void:
	var tw: Tween = create_tween()
	tw.tween_property(_bg, "modulate", Color(1, 1, 1, 0), 0.15)
	tw.tween_callback(queue_free)


func _on_bg_input(event: InputEvent) -> void:
	var is_click: bool = false
	if event is InputEventMouseButton and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
	if not is_click:
		return
	var panel_rect: Rect2 = Rect2(_panel.global_position, _panel.size)
	var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
	if not panel_rect.has_point(pos):
		_force_close()
		accept_event()


func _build_tabs() -> void:
	for child in _tabs_box.get_children():
		child.queue_free()
	for cat in CATEGORIES:
		var b: Button = Button.new()
		b.text = CATEGORY_LABELS.get(cat, cat)
		b.toggle_mode = true
		b.button_pressed = (cat == _current_category)
		b.custom_minimum_size = Vector2(0, 56)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.pressed.connect(_on_tab_pressed.bind(cat))
		_tabs_box.add_child(b)


func _on_tab_pressed(cat: String) -> void:
	_current_category = cat
	# Refresh toggle state.
	for i in range(_tabs_box.get_child_count()):
		var b: Button = _tabs_box.get_child(i) as Button
		if b != null:
			b.button_pressed = (CATEGORIES[i] == cat)
	_rebuild_rows()


func _rebuild_rows() -> void:
	_rows.clear()
	for child in _rows_vbox.get_children():
		child.queue_free()
	if _player == null:
		return
	var state: Dictionary = {}
	if "skill_state" in _player and _player.skill_state is Dictionary:
		state = _player.skill_state
	elif _player.has_meta("skills"):
		state = _player.get_meta("skills")
	for skill_id in SkillSystem.SKILL_IDS:
		var cat: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
		if _current_category != "all" and cat != _current_category:
			continue
		var row: SkillRow = SKILL_ROW_SCENE.instantiate()
		_rows_vbox.add_child(row)
		var s_entry: Dictionary = state.get(skill_id, {"level": 0, "xp": 0.0, "training": false})
		row.bind(skill_id, s_entry, cat)
		row.training_toggled.connect(_on_row_training_toggled)
		_rows[skill_id] = row


func _on_row_training_toggled(skill_id: String, enabled: bool) -> void:
	if _skill_system == null or _player == null:
		return
	_skill_system.set_training(_player, skill_id, enabled)
	_refresh_row(skill_id)


func _refresh_row(skill_id: String) -> void:
	if not _rows.has(skill_id):
		return
	var row: SkillRow = _rows[skill_id]
	var state: Dictionary = {}
	if "skill_state" in _player and _player.skill_state is Dictionary:
		state = _player.skill_state
	elif _player.has_meta("skills"):
		state = _player.get_meta("skills")
	var entry: Dictionary = state.get(skill_id, {"level": 0, "xp": 0.0, "training": false})
	var cat: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
	row.bind(skill_id, entry, cat)


func _on_skill_leveled_up(player: Node, skill_id: String, _new_level: int) -> void:
	if player != _player:
		return
	_refresh_row(skill_id)


func _on_xp_gained(player: Node, skill_id: String, _amount: float) -> void:
	if player != _player:
		return
	_refresh_row(skill_id)
