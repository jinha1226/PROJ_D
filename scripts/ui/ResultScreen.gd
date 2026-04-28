extends CanvasLayer
## Run-end result screen. Shown on player death or dungeon clear.
## M1: no meta-upgrade UI yet; the [메타 업그레이드] button just logs.

signal meta_pressed
signal retry_pressed

@onready var _title: Label = $Dim/Panel/VBox/Title
@onready var _depth_label: Label = $Dim/Panel/VBox/Stats/DepthLabel
@onready var _kills_label: Label = $Dim/Panel/VBox/Stats/KillsLabel
@onready var _turns_label: Label = $Dim/Panel/VBox/Stats/TurnsLabel
@onready var _killer_label: Label = $Dim/Panel/VBox/Stats/KillerLabel
@onready var _runes_label: Label = $Dim/Panel/VBox/ShardsGained
@onready var _gain_label: Label = $Dim/Panel/VBox/ShardsTotal
@onready var _meta_btn: Button = $Dim/Panel/VBox/Buttons/MetaButton
@onready var _retry_btn: Button = $Dim/Panel/VBox/Buttons/RetryButton


func _ready() -> void:
	layer = 100
	_meta_btn.pressed.connect(_on_meta_pressed)
	_retry_btn.pressed.connect(_on_retry_pressed)


func show_result(data: Dictionary) -> void:
	var victory: bool = bool(data.get("victory", false))
	var depth: int = int(data.get("depth", 1))
	var kills: int = int(data.get("kills", 0))
	var turns: int = int(data.get("turns", 0))
	var runes: int = int(data.get("runes", 0))
	var killer: String = String(data.get("killer", ""))

	if victory:
		_title.text = "Dungeon Cleared!"
		_killer_label.visible = false
	else:
		_title.text = "YOU DIED"
		_title.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
		var fv := FontVariation.new()
		fv.base_font = load("res://assets/fonts/Pretendard-Regular.otf")
		fv.variation_embolden = 0.8
		_title.add_theme_font_override("font", fv)
		if killer != "":
			_killer_label.text = "Killer: %s" % killer
			_killer_label.visible = true
		else:
			_killer_label.visible = false

	_depth_label.text = "Depth: B%dF" % depth
	_kills_label.text = "Kills: %d" % kills
	_turns_label.text = "Turns: %d" % turns
	if _runes_label != null:
		_runes_label.text = "Runes: %d / 4" % runes
	if _gain_label != null:
		_gain_label.visible = false
	visible = true


func _on_meta_pressed() -> void:
	print("meta TODO")
	meta_pressed.emit()


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	# Fresh run — depth/identified/pseudonyms reset. Class selection is held in
	# GameManager across the reload (Menu sets it before this screen shows).
	var gm = get_node_or_null("/root/GameManager")
	if gm != null:
		gm.start_new_run()
	get_tree().reload_current_scene()
