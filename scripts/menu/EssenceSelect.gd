extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _rune_label: Label = $RuneLabel
@onready var _skip_btn: Button = $SkipButton
@onready var _back_btn: Button = $BackButton


func _ready() -> void:
	theme = GameTheme.create()
	_skip_btn.pressed.connect(_on_skip)
	_back_btn.pressed.connect(_on_back)
	TouchScrollHelper.install(_scroll)
	_refresh_rune_label()
	_build_list()


func _refresh_rune_label() -> void:
	_rune_label.text = "◆ %d 룬 보유" % GameManager.rune_shards


func _build_list() -> void:
	for child in _container.get_children():
		child.queue_free()

	# Sort essences by cost ascending
	var ids: Array = EssenceSystem.RUNE_COSTS.keys()
	ids.sort_custom(func(a, b): return EssenceSystem.rune_cost(a) < EssenceSystem.rune_cost(b))

	var last_cost: int = -1
	for id in ids:
		var cost: int = EssenceSystem.rune_cost(id)
		if cost != last_cost:
			last_cost = cost
			var sep := Label.new()
			sep.text = "── %d 룬 ──" % cost
			sep.add_theme_font_size_override("font_size", 20)
			sep.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
			sep.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
			_container.add_child(sep)
		_container.add_child(_make_card(id, cost))



func _make_card(id: String, cost: int) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 110)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 10)
	margin.add_theme_constant_override("margin_bottom", 10)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	margin.add_child(hb)

	# Color swatch
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(8, 0)
	swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swatch.color = EssenceSystem.color_of(id)
	hb.add_child(swatch)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 3)
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = EssenceSystem.display_name(id)
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", EssenceSystem.color_of(id))
	vb.add_child(name_lbl)

	var info: Dictionary = EssenceSystem.ESSENCES.get(id, {})
	var desc_text: String = String(info.get("desc", ""))
	if desc_text != "":
		var desc_lbl := Label.new()
		desc_lbl.text = desc_text
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 20)
		desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
		vb.add_child(desc_lbl)

	var can_afford: bool = GameManager.rune_shards >= cost
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 52)
	btn.add_theme_font_size_override("font_size", 22)
	if can_afford:
		btn.text = "◆ %d" % cost
		btn.pressed.connect(_on_pick.bind(id, cost))
	else:
		btn.text = "◆ %d  (부족)" % cost
		btn.disabled = true
	hb.add_child(btn)

	return panel


func _on_pick(essence_id: String, cost: int) -> void:
	if not GameManager.spend_runes(cost):
		return
	GameManager.selected_starting_essence_id = essence_id
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_skip() -> void:
	GameManager.selected_starting_essence_id = ""
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
