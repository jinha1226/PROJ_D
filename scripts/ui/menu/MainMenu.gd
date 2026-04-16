extends Control
## Title screen. Runs as the project's main_scene. Routes to RaceSelect
## for a new run, or shows the in-game Credits popup.

const RACE_SELECT_PATH := "res://scenes/menu/RaceSelect.tscn"
const CREDITS_LPC_PATH := "res://CREDITS_LPC.md"
const CREDITS_FONTS_PATH := "res://CREDITS_FONTS.md"


func _ready() -> void:
	$Buttons/NewRunButton.pressed.connect(_on_new_run)
	$Buttons/CreditsButton.pressed.connect(_on_credits)


func _on_new_run() -> void:
	# Reset any prior selection so we start the flow fresh.
	GameManager.selected_race_id = ""
	GameManager.selected_job_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_credits() -> void:
	var dlg := AcceptDialog.new()
	dlg.title = "Credits"
	dlg.ok_button_text = "Close"
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(700, 1400)
	dlg.add_child(scroll)
	var lab := Label.new()
	lab.text = _load_credits_text()
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.add_theme_font_size_override("font_size", 18)
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(lab)
	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(800, 1500))


func _load_credits_text() -> String:
	var out: String = ""
	for path in [CREDITS_LPC_PATH, CREDITS_FONTS_PATH]:
		if FileAccess.file_exists(path):
			var f := FileAccess.open(path, FileAccess.READ)
			if f != null:
				out += f.get_as_text() + "\n\n"
				f.close()
	if out == "":
		out = "(credits files not bundled)"
	return out
