extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton

func _ready() -> void:
	theme = GameTheme.create()
	_back_btn.pressed.connect(_on_back)
	# Defensive rescan: if autoload loaded before ClassData's script
	# was resolved, by_id can be empty on first run after a pull.
	if ClassRegistry.all.is_empty():
		ClassRegistry._scan()
	_build_cards()

func _build_cards() -> void:
	for child in _container.get_children():
		child.queue_free()
	var ids: Array = ClassRegistry.ids_in_order()
	if ids.is_empty():
		var lab := Label.new()
		lab.text = "No classes loaded.\n"\
			+ "Try re-opening the project in the Godot editor so that "\
			+ "resources/classes/*.tres gets imported, then run again."
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 26)
		lab.add_theme_color_override("font_color", Color(1.0, 0.6, 0.5))
		_container.add_child(lab)
		return
	for id in ids:
		var data: ClassData = ClassRegistry.get_by_id(id)
		if data == null:
			continue
		_container.add_child(_make_card(data))

func _make_card(data: ClassData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 280)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	panel.add_child(vb)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	vb.add_child(margin)

	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", 6)
	margin.add_child(inner)

	var name_lab := Label.new()
	name_lab.text = data.display_name
	name_lab.add_theme_font_size_override("font_size", 44)
	name_lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	inner.add_child(name_lab)

	var stat_lab := Label.new()
	stat_lab.text = "HP %d  MP %d   STR %d  DEX %d  INT %d" % [
		data.starting_hp, data.starting_mp,
		data.starting_str, data.starting_dex, data.starting_int]
	stat_lab.add_theme_font_size_override("font_size", 22)
	inner.add_child(stat_lab)

	if data.starting_weapon != "" or data.starting_armor != "":
		var eq_lab := Label.new()
		var parts: Array = []
		if data.starting_weapon != "":
			parts.append(_item_name(data.starting_weapon))
		if data.starting_armor != "":
			parts.append(_item_name(data.starting_armor))
		eq_lab.text = "Gear: " + ", ".join(parts)
		eq_lab.add_theme_font_size_override("font_size", 20)
		eq_lab.add_theme_color_override("font_color", Color(0.75, 0.72, 0.6))
		inner.add_child(eq_lab)

	var desc_lab := Label.new()
	desc_lab.text = data.description
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lab.add_theme_font_size_override("font_size", 20)
	desc_lab.add_theme_color_override("font_color", Color(0.68, 0.65, 0.6))
	desc_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	inner.add_child(desc_lab)

	var pick_btn := Button.new()
	pick_btn.custom_minimum_size = Vector2(0, 72)
	pick_btn.text = "Start as %s" % data.display_name
	pick_btn.add_theme_font_size_override("font_size", 28)
	pick_btn.pressed.connect(_on_pick.bind(data.id))
	inner.add_child(pick_btn)

	return panel

func _item_name(id: String) -> String:
	var it: ItemData = ItemRegistry.get_by_id(id)
	return it.display_name if it != null else id

func _on_pick(class_id: String) -> void:
	GameManager.selected_class_id = class_id
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_back() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_PATH)
