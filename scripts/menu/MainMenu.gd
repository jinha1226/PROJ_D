extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"

@onready var _start_btn: Button = $VBox/StartButton
@onready var _display_btn: Button = $VBox/DisplayButton
@onready var _shards_btn: Button = $VBox/ShardsButton

func _ready() -> void:
	theme = GameTheme.create()
	_start_btn.pressed.connect(_on_start)
	_display_btn.pressed.connect(_on_toggle_display)
	_shards_btn.pressed.connect(_on_shards)
	_refresh_display_label()

func _on_start() -> void:
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_toggle_display() -> void:
	GameManager.toggle_tiles()
	_refresh_display_label()

func _refresh_display_label() -> void:
	_display_btn.text = "Display: %s" % ("Tiles" if GameManager.use_tiles else "ASCII")

func _on_shards() -> void:
	var dlg: GameDialog = GameDialog.create("룬샤드")
	add_child(dlg)
	var lab := Label.new()
	lab.text = "보유: %d\n\n던전을 돌파하고 쌓으세요.\n(메타 업그레이드는 다음 업데이트)" \
			% GameManager.rune_shards
	lab.add_theme_font_size_override("font_size", 36)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	dlg.body().add_child(lab)
