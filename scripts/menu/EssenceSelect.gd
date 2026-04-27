extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _title: Label = $Title
@onready var _back_btn: Button = $BackButton


func _ready() -> void:
	theme = GameTheme.create()
	if has_node("RuneLabel"):
		$RuneLabel.hide()
	if has_node("SkipButton"):
		$SkipButton.hide()
	_title.text = "신앙 선택"
	_back_btn.pressed.connect(_on_back)
	TouchScrollHelper.install(_scroll)
	_build_list()


func _build_list() -> void:
	for child in _container.get_children():
		child.queue_free()
	for faith_id in FaithSystem.FAITHS.keys():
		_container.add_child(_make_card(faith_id))


func _make_card(faith_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 130)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	margin.add_child(hb)

	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var color: Color = faith.get("color", Color.WHITE)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 0)
	swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swatch.color = color
	hb.add_child(swatch)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 3)
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = String(faith.get("name", faith_id))
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", color)
	vb.add_child(name_lbl)

	var short_lbl := Label.new()
	short_lbl.text = String(faith.get("short", ""))
	short_lbl.add_theme_font_size_override("font_size", 21)
	short_lbl.add_theme_color_override("font_color", Color(0.88, 0.88, 0.9))
	vb.add_child(short_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(faith.get("desc", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 18)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	vb.add_child(desc_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 52)
	btn.add_theme_font_size_override("font_size", 24)
	btn.text = "선택"
	btn.pressed.connect(_on_pick.bind(faith_id))
	hb.add_child(btn)

	return panel


func _on_pick(faith_id: String) -> void:
	GameManager.selected_faith_id = faith_id
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
