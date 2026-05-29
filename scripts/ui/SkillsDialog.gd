class_name SkillsDialog extends RefCounted

## Skill system removed. This dialog now shows the player's talent build.
## Retained as a stub so any scene/code that calls SkillsDialog.open() still compiles.

static func open(player: Player, parent: Node) -> void:
	if player == null or parent == null:
		return
	var dlg: GameDialog = GameDialog.create_ratio("Talent Build", 0.92, 0.92)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_M)

	# Job
	var job_row := HBoxContainer.new()
	body.add_child(job_row)
	var jlbl := Label.new()
	jlbl.text = "Job: "
	jlbl.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	jlbl.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
	job_row.add_child(jlbl)
	var jval := Label.new()
	jval.text = TalentSystem.job_display_name(player.job_id) if player.job_id != "" else "(none)"
	jval.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	var jdata: Dictionary = TalentSystem.get_job(player.job_id)
	jval.add_theme_color_override("font_color", jdata.get("color", Color.WHITE) if not jdata.is_empty() else Color.WHITE)
	job_row.add_child(jval)

	# Talents
	if player.talent_ids.is_empty():
		var lbl := Label.new()
		lbl.text = "No talents yet.\nTalents unlock at XL 5 / 10 / 15 / 20."
		lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(lbl)
	else:
		for talent_id in player.talent_ids:
			var tdata: Dictionary = TalentSystem.get_talent(talent_id)
			var card := PanelContainer.new()
			body.add_child(card)
			var inner := VBoxContainer.new()
			inner.add_theme_constant_override("separation", GameTheme.PAD_S)
			card.add_child(inner)
			var name_lbl := Label.new()
			name_lbl.text = "[T%d %s] %s" % [
				int(tdata.get("tier", 0)),
				String(tdata.get("concept", "")).capitalize(),
				String(tdata.get("name", talent_id))
			]
			name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
			name_lbl.add_theme_color_override("font_color", tdata.get("color", Color.WHITE))
			inner.add_child(name_lbl)
			var desc_lbl := Label.new()
			desc_lbl.text = String(tdata.get("desc", ""))
			desc_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
			desc_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
			desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			inner.add_child(desc_lbl)
