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
@onready var _gain_label: Label = $Dim/Panel/VBox/ShardsGained
@onready var _total_label: Label = $Dim/Panel/VBox/ShardsTotal
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
	var shards_gained: int = int(data.get("shards_gained", 0))
	var shards_total: int = int(data.get("shards_total", 0))
	var killer: String = String(data.get("killer", ""))

	if victory:
		_title.text = "Dungeon Cleared!"
		_killer_label.visible = false
	else:
		_title.text = "Defeated on B%dF" % depth
		if killer != "":
			_killer_label.text = "Killer: %s" % killer
			_killer_label.visible = true
		else:
			_killer_label.visible = false

	_depth_label.text = "Depth: B%dF" % depth
	_kills_label.text = "Kills: %d" % kills
	_turns_label.text = "Turns: %d" % turns
	_gain_label.text = "Rune Shards +%d" % shards_gained
	_total_label.text = "Total: %d" % shards_total
	visible = true


func _on_meta_pressed() -> void:
	print("meta TODO")
	meta_pressed.emit()


func _on_retry_pressed() -> void:
	retry_pressed.emit()
	# Fresh run — depth/identified/pseudonyms reset. Class selection is held in
	# GameManager across the reload (Menu sets it before this screen shows).
	if GameManager != null:
		GameManager.start_new_run()
	get_tree().reload_current_scene()
