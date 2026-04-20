extends Control
## Title screen. Runs as the project's main_scene. Routes to RaceSelect
## for a new run, or shows the in-game Credits popup.

const RACE_SELECT_PATH := "res://scenes/menu/RaceSelect.tscn"
const CREDITS_LPC_PATH := "res://CREDITS_LPC.md"
const CREDITS_FONTS_PATH := "res://CREDITS_FONTS.md"

# GameManager.render_mode: 0=LPC, 1=DCSS tiles, 2=ASCII. The toggle button
# cycles DCSS↔ASCII only — LPC mode is unfinished and not user-facing.
const _DISPLAY_LABELS: Array = ["DCSS Tiles", "DCSS Tiles", "ASCII"]
var _display_btn: Button = null


func _ready() -> void:
	$Buttons/NewRunButton.pressed.connect(_on_new_run)
	$Buttons/UpgradesButton.pressed.connect(_on_upgrades)
	$Buttons/CreditsButton.pressed.connect(_on_credits)
	theme = GameTheme.create()
	_ensure_meta()
	_add_display_toggle()


func _add_display_toggle() -> void:
	var buttons: VBoxContainer = $Buttons as VBoxContainer
	if buttons == null:
		return
	_display_btn = Button.new()
	_display_btn.custom_minimum_size = Vector2(0, 120)
	_display_btn.add_theme_font_size_override("font_size", 48)
	_display_btn.pressed.connect(_on_cycle_display)
	buttons.add_child(_display_btn)
	_refresh_display_label()


func _on_cycle_display() -> void:
	# Toggle between DCSS Tiles (1) and ASCII (2).
	if GameManager.render_mode == 2:
		GameManager.render_mode = 1
	else:
		GameManager.render_mode = 2
	_refresh_display_label()


func _refresh_display_label() -> void:
	if _display_btn == null:
		return
	var idx: int = clamp(int(GameManager.render_mode), 0, _DISPLAY_LABELS.size() - 1)
	_display_btn.text = "Display: %s" % String(_DISPLAY_LABELS[idx])


func _ensure_meta() -> MetaProgression:
	var meta: Node = get_tree().root.get_node_or_null("MetaProgression")
	if meta != null:
		return meta as MetaProgression
	var m := MetaProgression.new()
	m.name = "MetaProgression"
	get_tree().root.add_child(m)
	m.load_from_disk()
	return m


func _on_new_run() -> void:
	# Reset any prior selection so we start the flow fresh.
	GameManager.selected_race_id = ""
	GameManager.selected_job_id = ""
	GameManager.selected_trait_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_upgrades() -> void:
	var meta: MetaProgression = _ensure_meta()
	var dlg := AcceptDialog.new()
	dlg.exclusive = false
	dlg.title = "Upgrades"
	dlg.ok_button_text = "Close"

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	dlg.add_child(vb)

	var shard_lab := Label.new()
	shard_lab.text = "Rune Shards: %d" % meta.rune_shards
	shard_lab.add_theme_font_size_override("font_size", 36)
	shard_lab.modulate = Color(0.95, 0.82, 0.3)
	shard_lab.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vb.add_child(shard_lab)
	vb.add_child(HSeparator.new())

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(0, 1400)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(scroll)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 8)
	scroll.add_child(rows)

	var cats: Array = ["survival", "combat", "insight", "essence"]
	var cat_labels: Dictionary = {"survival": "SURVIVAL", "combat": "COMBAT", "insight": "INSIGHT", "essence": "ESSENCE"}
	for cat in cats:
		var header := Label.new()
		header.text = "--- %s ---" % cat_labels.get(cat, cat)
		header.add_theme_font_size_override("font_size", 28)
		header.modulate = Color(0.7, 0.75, 0.9)
		header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		rows.add_child(header)
		for uid in MetaProgression.UPGRADES.keys():
			var info: Dictionary = MetaProgression.UPGRADES[uid]
			if String(info.get("cat", "")) != cat:
				continue
			rows.add_child(_build_upgrade_row(uid, info, meta, shard_lab, dlg))

	var job_header := Label.new()
	job_header.text = "--- JOBS ---"
	job_header.add_theme_font_size_override("font_size", 28)
	job_header.modulate = Color(0.7, 0.75, 0.9)
	job_header.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	rows.add_child(job_header)
	for job_id in MetaProgression.JOB_UNLOCK_COST.keys():
		var cost: int = int(MetaProgression.JOB_UNLOCK_COST[job_id])
		var owned: bool = meta.is_job_unlocked(job_id)
		var row := HBoxContainer.new()
		row.custom_minimum_size = Vector2(0, 80)
		row.add_theme_constant_override("separation", 8)
		var name_lab := Label.new()
		name_lab.text = job_id.capitalize()
		name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lab.add_theme_font_size_override("font_size", 30)
		row.add_child(name_lab)
		var btn := Button.new()
		if owned:
			btn.text = "Owned"
			btn.disabled = true
		else:
			btn.text = "%d shards" % cost
			btn.disabled = meta.rune_shards < cost
		btn.custom_minimum_size = Vector2(200, 64)
		btn.add_theme_font_size_override("font_size", 26)
		if not owned:
			btn.pressed.connect(_on_buy_job.bind("job_" + job_id, meta, shard_lab, btn))
		row.add_child(btn)
		rows.add_child(row)

	add_child(dlg)
	dlg.confirmed.connect(dlg.queue_free)
	dlg.canceled.connect(dlg.queue_free)
	dlg.popup_centered(Vector2i(900, 1800))


func _build_upgrade_row(uid: String, info: Dictionary, meta: Node, shard_lab: Label, dlg: AcceptDialog) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 80)
	row.add_theme_constant_override("separation", 8)

	var name_lab := Label.new()
	name_lab.text = String(info.get("name", uid))
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.add_theme_font_size_override("font_size", 30)
	row.add_child(name_lab)

	var cost: int = int(info.get("cost", 0))
	var owned: bool = meta.is_unlocked(uid)
	var btn := Button.new()
	if owned:
		btn.text = "Owned"
		btn.disabled = true
	elif not meta.can_unlock(uid):
		var req: String = String(info.get("requires", ""))
		if req != "" and not meta.is_unlocked(req):
			btn.text = "Locked"
		else:
			btn.text = "%d shards" % cost
		btn.disabled = true
	else:
		btn.text = "%d shards" % cost
	btn.custom_minimum_size = Vector2(200, 64)
	btn.add_theme_font_size_override("font_size", 26)
	if not owned and meta.can_unlock(uid):
		btn.pressed.connect(_on_buy_upgrade.bind(uid, meta, shard_lab, btn))
	row.add_child(btn)
	return row


func _on_buy_upgrade(uid: String, meta: Node, shard_lab: Label, btn: Button) -> void:
	if meta.purchase(uid):
		btn.text = "Owned"
		btn.disabled = true
		shard_lab.text = "Rune Shards: %d" % meta.rune_shards


func _on_buy_job(uid: String, meta: Node, shard_lab: Label, btn: Button) -> void:
	if meta.purchase(uid):
		btn.text = "Owned"
		btn.disabled = true
		shard_lab.text = "Rune Shards: %d" % meta.rune_shards


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
