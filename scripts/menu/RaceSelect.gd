extends Control

const JOB_SELECT_PATH: String = "res://scenes/menu/JobSelect.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton

func _ready() -> void:
	theme = GameTheme.create()
	_back_btn.pressed.connect(_on_back)
	_build_cards()

func _build_cards() -> void:
	for child in _container.get_children():
		child.queue_free()
	var ids: Array = RaceRegistry.ids_in_order()
	if ids.is_empty():
		var lab := Label.new()
		lab.text = "No races loaded."
		_container.add_child(lab)
		return
	for id in ids:
		var data: RaceData = RaceRegistry.get_by_id(id)
		if data == null:
			continue
		_container.add_child(_make_card(data))

func _make_card(data: RaceData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 200)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	margin.add_child(hb)

	var portrait := TextureRect.new()
	portrait.custom_minimum_size = Vector2(96, 96)
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	if data.base_sprite_path != "" \
			and ResourceLoader.exists(data.base_sprite_path):
		portrait.texture = load(data.base_sprite_path)
	if not data.unlocked:
		portrait.modulate = Color(0.35, 0.35, 0.4, 1)
	hb.add_child(portrait)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)

	var name_lab := Label.new()
	name_lab.text = data.display_name
	name_lab.add_theme_font_size_override("font_size", 40)
	var name_col: Color = Color(0.95, 0.85, 0.5) if data.unlocked \
			else Color(0.55, 0.55, 0.6)
	name_lab.add_theme_color_override("font_color", name_col)
	vb.add_child(name_lab)

	var desc_lab := Label.new()
	desc_lab.text = data.description
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lab.add_theme_font_size_override("font_size", 20)
	desc_lab.add_theme_color_override("font_color", Color(0.68, 0.65, 0.6))
	desc_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_lab)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, 60)
	btn.add_theme_font_size_override("font_size", 26)
	if data.unlocked:
		btn.text = "Pick %s" % data.display_name
		btn.pressed.connect(_on_pick.bind(data.id))
	else:
		btn.text = "Locked (%d shards)" % data.unlock_cost
		btn.disabled = true
	vb.add_child(btn)

	return panel

func _on_pick(race_id: String) -> void:
	GameManager.selected_race_id = race_id
	get_tree().change_scene_to_file(JOB_SELECT_PATH)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
