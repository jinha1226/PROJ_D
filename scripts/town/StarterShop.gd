extends Control

const TOWN_SCENE_PATH: String = "res://scenes/town/Town.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"

# 6 fixed bundles. Each bundle = one full 120g spend.
# Items must exist in resources/items/ — verified at write time.
# `name_key` / `desc_key` are i18n keys resolved via LocaleManager.t() at render time.
const BUNDLES: Array = [
	{
		"id": "sword_shield",
		"name_key": "UI_BUNDLE_NAME_SWORD_SHIELD",
		"desc_key": "UI_BUNDLE_DESC_SWORD_SHIELD",
		"items": ["short_sword", "leather_armor", "buckler", "potion_healing", "potion_healing", "scroll_identify"],
	},
	{
		"id": "heavy_striker",
		"name_key": "UI_BUNDLE_NAME_HEAVY_STRIKER",
		"desc_key": "UI_BUNDLE_DESC_HEAVY_STRIKER",
		"items": ["mace", "leather_armor", "bandage", "bandage", "bandage", "potion_healing"],
	},
	{
		"id": "archer",
		"name_key": "UI_BUNDLE_NAME_ARCHER",
		"desc_key": "UI_BUNDLE_DESC_ARCHER",
		"items": ["shortbow", "leather_armor", "dagger", "potion_healing", "potion_healing", "scroll_identify"],
	},
	{
		"id": "magic_initiate",
		"name_key": "UI_BUNDLE_NAME_MAGIC_INITIATE",
		"desc_key": "UI_BUNDLE_DESC_MAGIC_INITIATE",
		"items": ["staff", "book_conjuration", "dagger", "potion_magic", "potion_healing", "scroll_identify"],
	},
	{
		"id": "skirmisher",
		"name_key": "UI_BUNDLE_NAME_SKIRMISHER",
		"desc_key": "UI_BUNDLE_DESC_SKIRMISHER",
		"items": ["dagger", "dirk", "leather_armor", "scroll_identify", "scroll_identify", "potion_healing"],
	},
	{
		"id": "survivalist",
		"name_key": "UI_BUNDLE_NAME_SURVIVALIST",
		"desc_key": "UI_BUNDLE_DESC_SURVIVALIST",
		"items": ["shortbow", "leather_armor", "bandage", "bandage", "bandage", "bandage"],
	},
]

@onready var _title: Label = $Title
@onready var _race_info: Label = $RaceInfo
@onready var _grid: VBoxContainer = $ScrollContainer/Grid
@onready var _back_btn: Button = $BackButton

func _ready() -> void:
	if ResourceLoader.exists("res://scripts/ui/GameTheme.gd"):
		theme = load("res://scripts/ui/GameTheme.gd").create()
	_title.text = LocaleManager.t("UI_STARTER_TITLE")
	if RaceRegistry != null:
		var race_data = RaceRegistry.get_by_id(TownState.current_character_race)
		var race_name: String = race_data.display_name if race_data != null else TownState.current_character_race.capitalize()
		_race_info.text = LocaleManager.t("UI_STARTER_CHOOSING_FOR") % race_name
	else:
		_race_info.text = LocaleManager.t("UI_STARTER_PICK_FALLBACK")
	_back_btn.text = LocaleManager.t("UI_STARTER_BTN_BACK")
	_back_btn.pressed.connect(_on_back)
	_build_cards()

func _build_cards() -> void:
	for child in _grid.get_children():
		child.queue_free()
	for bundle in BUNDLES:
		_grid.add_child(_make_card(bundle))

func _make_card(bundle: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	card.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	margin.add_child(vb)
	var name_lbl := Label.new()
	name_lbl.text = LocaleManager.t(String(bundle["name_key"]))
	name_lbl.add_theme_font_size_override("font_size", 24)
	vb.add_child(name_lbl)
	var desc_lbl := Label.new()
	desc_lbl.text = LocaleManager.t(String(bundle["desc_key"]))
	desc_lbl.add_theme_font_size_override("font_size", 16)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(desc_lbl)
	var items_lbl := Label.new()
	items_lbl.text = _format_items(bundle["items"])
	items_lbl.add_theme_font_size_override("font_size", 14)
	items_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.9))
	items_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	vb.add_child(items_lbl)
	var btn := Button.new()
	btn.text = LocaleManager.t("UI_STARTER_BTN_CHOOSE")
	btn.custom_minimum_size = Vector2(0, 48)
	btn.pressed.connect(_on_pick.bind(String(bundle["id"])))
	vb.add_child(btn)
	return card

func _format_items(item_ids: Array) -> String:
	# Group identical ids: "potion_healing × 2"
	var counts: Dictionary = {}
	for id in item_ids:
		counts[id] = int(counts.get(id, 0)) + 1
	var parts: Array = []
	for id in counts.keys():
		var item_name: String = id
		if ItemRegistry != null:
			var data = ItemRegistry.get_by_id(id)
			if data != null:
				item_name = data.display_name
		var count: int = counts[id]
		if count > 1:
			parts.append("%s × %d" % [item_name, count])
		else:
			parts.append(item_name)
	return LocaleManager.t("UI_STARTER_ITEMS_PREFIX") + ", ".join(parts)

func _on_pick(bundle_id: String) -> void:
	for bundle in BUNDLES:
		if String(bundle["id"]) == bundle_id:
			GameManager.pending_starter_items = bundle["items"].duplicate()
			break
	get_tree().change_scene_to_file(TOWN_SCENE_PATH)

func _on_back() -> void:
	# Back to RaceSelect; clear the in-progress character creation.
	TownState.current_character_alive = false
	TownState.current_character_race = ""
	TownState.save_state()
	get_tree().change_scene_to_file(RACE_SELECT_PATH)
