extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const RACE_SELECT_PATH: String = "res://scenes/menu/RaceSelect.tscn"
const BUILD_VERSION_LABEL: PackedScene = preload("res://scenes/ui/BuildVersionLabel.tscn")

@onready var _continue_btn: Button = $VBox/ContinueButton
@onready var _start_btn: Button = $VBox/StartButton
@onready var _display_btn: Button = $VBox/DisplayButton
@onready var _shards_btn: Button = $VBox/ShardsButton
@onready var _help_btn: Button = $VBox/HelpButton

func _ready() -> void:
	theme = GameTheme.create()
	if _continue_btn != null:
		_continue_btn.pressed.connect(_on_continue)
		_continue_btn.visible = SaveManager.has_save()
	_start_btn.pressed.connect(_on_start)
	_display_btn.pressed.connect(_on_toggle_display)
	_shards_btn.pressed.connect(_on_shards)
	if _help_btn != null:
		_help_btn.pressed.connect(_on_help)
	_refresh_display_label()
	add_child(BUILD_VERSION_LABEL.instantiate())

func _on_continue() -> void:
	if GameManager.load_run():
		get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_start() -> void:
	GameManager.selected_race_id = ""
	GameManager.selected_class_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)

func _on_toggle_display() -> void:
	GameManager.toggle_tiles()
	_refresh_display_label()

func _refresh_display_label() -> void:
	_display_btn.text = "[ DISPLAY: %s ]" % ("TILES" if GameManager.use_tiles else "ASCII")

func _on_shards() -> void:
	var dlg: GameDialog = GameDialog.create("Rune Shards")
	add_child(dlg)
	var lab := Label.new()
	lab.text = "You have %d rune shards.\n\nEarn more by descending further before dying.\n(Meta upgrades coming in a future update.)" \
			% GameManager.rune_shards
	lab.add_theme_font_size_override("font_size", 32)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg.body().add_child(lab)

func _on_help() -> void:
	var dlg: GameDialog = GameDialog.create("How to Play")
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	for line in _help_lines():
		var lab := Label.new()
		lab.text = line
		lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lab.add_theme_font_size_override("font_size", 22)
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
		"Display button toggles tile / ASCII rendering.",
		"Dying earns rune shards (meta upgrades to come).",
		"",
		"ASCII legend:",
		"@ you  # wall  . floor  < > stairs  + closed door",
		"r rat  b bat  K kobold  g goblin  o orc  O ogre ...",
		"( weapon  [ armor  ! potion  ? scroll  $ gold",
	]
