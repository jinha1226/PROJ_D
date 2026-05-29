extends Control

const TOWN_SCENE_PATH: String = "res://scenes/town/Town.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton

func _ready() -> void:
	theme = GameTheme.create()
	_back_btn.pressed.connect(_on_back)
	TouchScrollHelper.install(_scroll)
	_build_cards()

func _build_cards() -> void:
	for child in _container.get_children():
		child.queue_free()
	var ids: Array = TalentSystem.job_ids_in_order()
	if ids.is_empty():
		var lab := Label.new()
		lab.text = "No jobs loaded."
		_container.add_child(lab)
		return
	for id in ids:
		_container.add_child(_make_card(id))

func _make_card(talent_id: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 190)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	margin.add_child(hb)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(10, 0)
	swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swatch.color = TalentSystem.color(talent_id)
	hb.add_child(swatch)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 5)
	hb.add_child(vb)

	var name_lab := Label.new()
	name_lab.text = TalentSystem.display_name(talent_id)
	name_lab.add_theme_font_size_override("font_size", 34)
	name_lab.add_theme_color_override("font_color", TalentSystem.color(talent_id))
	name_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(name_lab)

	var short_lab := Label.new()
	short_lab.text = TalentSystem.short_text(talent_id)
	short_lab.add_theme_font_size_override("font_size", 20)
	short_lab.add_theme_color_override("font_color", Color(0.9, 0.9, 0.93))
	short_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	short_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(short_lab)

	var desc_lab := Label.new()
	desc_lab.text = TalentSystem.description_text(talent_id)
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lab.add_theme_font_size_override("font_size", 18)
	desc_lab.add_theme_color_override("font_color", Color(0.68, 0.7, 0.76))
	vb.add_child(desc_lab)

	var bonus_line := Label.new()
	var _blines: PackedStringArray = TalentSystem.bonus_lines(talent_id)
	bonus_line.text = " / ".join(_blines)
	bonus_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	bonus_line.add_theme_font_size_override("font_size", 16)
	bonus_line.add_theme_color_override("font_color", Color(0.72, 0.88, 0.95))
	vb.add_child(bonus_line)

	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var touch_y := [-9999.0]
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed:
				touch_y[0] = ev.position.y
			elif touch_y[0] > -9000.0 and absf(ev.position.y - touch_y[0]) < 16.0:
				touch_y[0] = -9999.0
				_on_pick(talent_id)
			else:
				touch_y[0] = -9999.0
		elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_pick(talent_id)
	)

	return panel

func _on_pick(talent_id: String) -> void:
	GameManager.selected_race_id = "human"
	GameManager.selected_talent_id = talent_id  # legacy compat
	GameManager.selected_job_id = talent_id      # new talent system
	TownState.start_new_character(talent_id)
	GameManager.starter_shop_gold = GameManager.STARTING_GOLD
	GameManager.pending_starter_items = []
	get_tree().change_scene_to_file(TOWN_SCENE_PATH)

func _on_back() -> void:
	GameManager.selected_talent_id = ""
	GameManager.selected_job_id = ""
	TownState.current_character_alive = false
	TownState.current_character_race = ""
	TownState.current_character_talent = ""
	TownState.save_state()
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
