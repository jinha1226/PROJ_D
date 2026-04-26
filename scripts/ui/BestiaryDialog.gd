class_name BestiaryDialog extends RefCounted

static var MonsterRegistry = Engine.get_main_loop().root.get_node_or_null("/root/MonsterRegistry") if Engine.get_main_loop() is SceneTree else null
static var GameManager = Engine.get_main_loop().root.get_node_or_null("/root/GameManager") if Engine.get_main_loop() is SceneTree else null

static func open(parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Bestiary", 0.92, 0.92)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 8)

	var all_monsters: Array = MonsterRegistry.all
	if all_monsters.is_empty():
		var lbl := Label.new()
		lbl.text = "No monsters in registry."
		body.add_child(lbl)
		return

	# Sort by min_depth
	var sorted: Array = all_monsters.duplicate()
	sorted.sort_custom(func(a, b): return a.min_depth < b.min_depth)

	var kill_counts: Dictionary = GameManager.kill_counts
	var killed_count: int = 0
	var total: int = sorted.size()

	for data: MonsterData in sorted:
		var kills: int = kill_counts.get(data.id, 0)
		body.add_child(_make_monster_card(data, kills))
		if kills > 0:
			killed_count += 1

	# Summary header — add at start
	var summary := Label.new()
	summary.text = "Slain: %d / %d species" % [killed_count, total]
	summary.add_theme_font_size_override("font_size", 26)
	summary.add_theme_color_override("font_color", Color(0.75, 0.9, 0.75))
	body.add_child(summary)
	body.move_child(summary, 0)


static func _make_monster_card(data: MonsterData, kills: int) -> Control:
	var panel := PanelContainer.new()
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 10)
	margin.add_theme_constant_override("margin_right", 10)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	margin.add_child(vb)

	if kills == 0:
		# Unknown — show glyph + "???" name
		var name_lbl := Label.new()
		name_lbl.text = "%s ???   (B%d–B%d)" % [data.glyph, data.min_depth, data.max_depth]
		name_lbl.add_theme_font_size_override("font_size", 26)
		name_lbl.add_theme_color_override("font_color", Color(0.4, 0.4, 0.45))
		vb.add_child(name_lbl)
		return panel

	# Known — full entry
	var header_row := HBoxContainer.new()
	header_row.add_theme_constant_override("separation", 10)
	vb.add_child(header_row)

	var glyph_lbl := Label.new()
	glyph_lbl.text = data.glyph
	glyph_lbl.add_theme_font_size_override("font_size", 36)
	glyph_lbl.add_theme_color_override("font_color", data.glyph_color)
	glyph_lbl.custom_minimum_size = Vector2(36, 0)
	header_row.add_child(glyph_lbl)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header_row.add_child(name_col)

	var name_lbl := Label.new()
	name_lbl.text = data.display_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.55))
	name_col.add_child(name_lbl)

	var depth_lbl := Label.new()
	depth_lbl.text = "B%d–B%d" % [data.min_depth, data.max_depth]
	depth_lbl.add_theme_font_size_override("font_size", 20)
	depth_lbl.add_theme_color_override("font_color", Color(0.6, 0.65, 0.75))
	name_col.add_child(depth_lbl)

	var kills_lbl := Label.new()
	kills_lbl.text = "×%d" % kills
	kills_lbl.add_theme_font_size_override("font_size", 28)
	kills_lbl.add_theme_color_override("font_color", Color(0.65, 1.0, 0.65))
	kills_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header_row.add_child(kills_lbl)

	# Stats row
	var stat_lbl := Label.new()
	stat_lbl.text = "HP %d  HD %d  AC %d  EV %d" % [data.hp, data.hd, data.ac, data.ev]
	stat_lbl.add_theme_font_size_override("font_size", 20)
	stat_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	vb.add_child(stat_lbl)

	# Description
	if data.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = data.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 22)
		desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
		vb.add_child(desc_lbl)

	# Essence drop info
	var eid: String = String(data.essence_id)
	if eid != "":
		var ess_lbl := Label.new()
		ess_lbl.text = "Essence: %s — %s" % [
			EssenceSystem.display_name(eid), EssenceSystem.description(eid)]
		ess_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		ess_lbl.add_theme_font_size_override("font_size", 20)
		ess_lbl.add_theme_color_override("font_color", EssenceSystem.color_of(eid))
		vb.add_child(ess_lbl)
	elif kills > 0:
		var ess_lbl := Label.new()
		ess_lbl.text = "Essence: random drop"
		ess_lbl.add_theme_font_size_override("font_size", 20)
		ess_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		vb.add_child(ess_lbl)

	return panel
