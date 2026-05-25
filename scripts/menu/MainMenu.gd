extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const TALENT_SELECT_PATH: String = "res://scenes/menu/TalentSelect.tscn"
const BUILD_VERSION_LABEL: PackedScene = preload("res://scenes/ui/BuildVersionLabel.tscn")

@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _start_btn: Button = $VBox/StartButton
@onready var _options_btn: Button = $VBox/OptionsButton
@onready var _help_btn: Button = $VBox/HelpButton
@onready var _title: TextureRect = $Title
@onready var _display_hint: Label = $DisplayHint

func _ready() -> void:
	theme = GameTheme.create()
	if _continue_btn != null:
		_continue_btn.pressed.connect(_on_continue)
		_continue_btn.visible = SaveManager.has_save()
	_start_btn.pressed.connect(_on_start)
	if _options_btn != null:
		_options_btn.pressed.connect(_on_options)
	if _help_btn != null:
		_help_btn.pressed.connect(_on_help)
	_refresh_button_labels()
	LocaleManager.locale_changed.connect(func(_l): _refresh_button_labels())
	# Easter egg: tap the PocketCrawl logo to toggle between tile and ASCII
	# rendering. No discoverable button — players find it by trying to interact
	# with the only image on screen.
	if _title != null:
		_title.gui_input.connect(_on_title_input)
	add_child(BUILD_VERSION_LABEL.instantiate())

func _on_continue() -> void:
	if GameManager.load_run():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_start() -> void:
	GameManager.selected_race_id = "human"
	GameManager.selected_talent_id = ""
	GameManager.selected_starting_weapon_id = ""
	GameManager.selected_starting_school_id = ""
	GameManager.selected_starting_essence_id = ""
	GameManager.selected_faith_id = ""
	get_tree().change_scene_to_file(TALENT_SELECT_PATH)

func _on_title_input(event: InputEvent) -> void:
	var clicked := false
	if event is InputEventScreenTouch and not event.pressed:
		clicked = true
	elif event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		clicked = true
	if clicked:
		GameManager.toggle_tiles()
		_show_display_hint()

func _show_display_hint() -> void:
	if _display_hint == null:
		return
	_display_hint.text = "▸ %s mode" % ("TILE" if GameManager.use_tiles else "ASCII")
	# Fade in then out — no Tween cleanup needed since the scene survives.
	var tw := create_tween()
	_display_hint.modulate.a = 0.0
	tw.tween_property(_display_hint, "modulate:a", 1.0, 0.15)
	tw.tween_interval(1.2)
	tw.tween_property(_display_hint, "modulate:a", 0.0, 0.6)

func _on_options() -> void:
	OptionsDialog.open(self, func(): _refresh_button_labels())

func _refresh_button_labels() -> void:
	if _continue_btn != null:
		_continue_btn.text = tr("MAINMENU_CONTINUE")
	if _start_btn != null:
		_start_btn.text = tr("MAINMENU_NEW_GAME")
	if _options_btn != null:
		_options_btn.text = tr("MAINMENU_OPTIONS")
	if _help_btn != null:
		_help_btn.text = tr("MAINMENU_HOW_TO_PLAY")

func _on_help() -> void:
	var dlg: GameDialog = GameDialog.create("How to Play")
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	for line in _help_lines():
		var lab := Label.new()
		lab.text = line
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		body.add_child(lab)

func _help_lines() -> Array:
	return [
		"Move: arrow keys / WASD / HJKL",
		"Attack: step into an adjacent enemy (bump).",
		"Descend: step on '>' to go to the next floor.",
		"",
		"BAG: inventory — equip / use / drop.",
		"MAGIC: cast a known spell (Mage only at start).",
		"SKILLS: view skill levels (grow from use).",
		"STATUS: HP / stats / gear summary.",
		"WAIT: pass a turn (+1 HP/MP regen).",
		"REST: auto-wait to full HP when no enemy is in sight.",
		"MENU: save and return to the title screen.",
		"",
		"Choose a Faith at the start of each run.",
		"",
		"ASCII legend:",
		"@ you  # wall  . floor  < > stairs  + closed door",
		"r rat  b bat  K kobold  g goblin  o orc  O ogre ...",
		"( weapon  [ armor  ! potion  ? scroll  $ gold",
	]
