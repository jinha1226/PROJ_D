extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _char_status: Label = $StatusBox/CharacterStatus
@onready var _expedition_count: Label = $StatusBox/ExpeditionCount
@onready var _start_btn: Button = $ButtonBox/StartButton
@onready var _shop_btn: Button = $ButtonBox/ShopButton
@onready var _char_btn: Button = $ButtonBox/CharacterButton
@onready var _new_char_btn: Button = $ButtonBox/NewCharButton
@onready var _menu_btn: Button = $ButtonBox/MenuButton

func _ready() -> void:
	if ResourceLoader.exists("res://scripts/ui/GameTheme.gd"):
		theme = load("res://scripts/ui/GameTheme.gd").create()
	_start_btn.text = LocaleManager.t("UI_TOWN_BTN_START_EXPEDITION")
	_new_char_btn.text = LocaleManager.t("UI_TOWN_BTN_NEW_CHAR")
	_menu_btn.text = LocaleManager.t("UI_TOWN_BTN_BACK_MENU")
	_shop_btn.text = LocaleManager.t("UI_TOWN_BTN_SHOP")
	_char_btn.text = LocaleManager.t("UI_TOWN_BTN_CHARACTER")
	_start_btn.pressed.connect(_on_start)
	_new_char_btn.pressed.connect(_on_new_char)
	_menu_btn.pressed.connect(_on_menu)
	_shop_btn.pressed.connect(_on_shop)
	_char_btn.pressed.connect(_on_character)
	_refresh()

func _refresh() -> void:
	_expedition_count.text = LocaleManager.t("UI_TOWN_EXPEDITION_COUNT") % TownState.expedition_count
	if TownState.current_character_alive:
		var race_name: String = TownState.current_character_race.capitalize()
		if RaceRegistry != null:
			var race_data = RaceRegistry.get_by_id(TownState.current_character_race)
			if race_data != null and race_data.display_name != "":
				race_name = race_data.display_name
		var last_line: String = ""
		var has_safe_return: bool = false
		if not TownState.last_character_summary.is_empty():
			var s: Dictionary = TownState.last_character_summary
			if bool(s.get("safe_return", false)):
				has_safe_return = true
				last_line = LocaleManager.t("UI_TOWN_STATUS_ACTIVE_RETURNED") % int(s.get("depth_reached", 0))
		if has_safe_return:
			_char_status.text = LocaleManager.t("UI_TOWN_STATUS_ACTIVE_MEMORIAL") % [race_name, last_line]
		else:
			_char_status.text = LocaleManager.t("UI_TOWN_STATUS_ACTIVE_READY") % race_name
		_start_btn.visible = true
		_new_char_btn.visible = false
		_shop_btn.visible = SaveManager.has_save()
		_char_btn.visible = SaveManager.has_save()
	else:
		if TownState.has_last_summary():
			var s: Dictionary = TownState.last_character_summary
			var race := String(s.get("race", "?"))
			var depth := int(s.get("depth_reached", 0))
			var killer := String(s.get("death_cause", "unknown"))
			var victory := bool(s.get("victory", false))
			if victory:
				_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_VICTORY") % race.capitalize()
			else:
				_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_DEATH") % [race.capitalize(), depth, killer]
		else:
			_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_FIRST")
		_start_btn.visible = false
		_new_char_btn.visible = true
		_shop_btn.visible = false
		_char_btn.visible = false

func _on_start() -> void:
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_new_char() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_PATH)

func _on_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)

func _on_shop() -> void:
	var shop_scene: PackedScene = load("res://scenes/town/TownShop.tscn")
	if shop_scene == null:
		return
	var shop_node: Node = shop_scene.instantiate()
	add_child(shop_node)
	if shop_node.has_signal("closed"):
		shop_node.closed.connect(_refresh)

func _on_character() -> void:
	var scene: PackedScene = load("res://scenes/town/TownCharacterDialog.tscn")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	add_child(node)
	if node.has_signal("closed"):
		node.closed.connect(_refresh)
