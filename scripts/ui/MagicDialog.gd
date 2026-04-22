class_name MagicDialog
extends RefCounted
## Magic menu dialog, extracted from GameBootstrap. Shows MP + memory
## readouts at the top and then the known-spell list grouped by
## primary school so the player can read "Fire / Cold / Hexes / …"
## at a glance instead of one flat scroll.
##
## Row actions (Cast / QSlot) still hand off to GameBootstrap because
## targeting mode + quickslot assignment touch player state + the
## targeting cursor pipeline. The module only owns the layout.

## Open the menu. `host` is GameBootstrap (scene-tree parent + cast
## callbacks); `player` is passed separately since we read skill /
## memory / MP off it.
static func open(host: Node, player) -> GameDialog:
	if player == null:
		return null
	var dlg := GameDialog.create("Magic", Vector2i(960, 1800))
	host.add_child(dlg)
	var vb: VBoxContainer = dlg.body()

	_build_header(vb, player)
	vb.add_child(UICards.section_header("Known Spells"))

	var skill_sys = host.skill_system if "skill_system" in host else null
	var known: Array[String] = SpellRegistry.get_known_for_player(player, skill_sys)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 6)

	var present_schools: Array = _collect_present_schools(known)
	if known.size() > 0 and present_schools.size() >= 2:
		vb.add_child(_build_school_tabs(host, player, known, rows, dlg, present_schools))
	vb.add_child(rows)

	if known.is_empty():
		var hint := UICards.dim_hint(
				"No spells known.\nRead spellbooks or pick a magic job to learn spells.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(hint)
	else:
		_populate_rows("all", rows, host, player, known, dlg)
	return dlg


## Returns the distinct set of primary schools present in `known`, in SpellRegistry.SCHOOL_SPELLS order with any extras appended.
static func _collect_present_schools(known: Array[String]) -> Array:
	var present: Dictionary = {}
	for sp in known:
		var schools: Array = SpellRegistry.get_schools(sp)
		var primary: String = String(schools[0]) if not schools.is_empty() else "misc"
		present[primary] = true
	var ordered: Array = []
	for s in SpellRegistry.SCHOOL_SPELLS.keys():
		if present.has(String(s)):
			ordered.append(String(s))
	for s in present.keys():
		if not ordered.has(String(s)):
			ordered.append(String(s))
	return ordered


## Builds the horizontal tab strip ("All" + one button per present school) that swaps the rows VBox contents on press.
static func _build_school_tabs(host: Node, player, known: Array[String],
		rows: VBoxContainer, dlg: GameDialog, present_schools: Array) -> HBoxContainer:
	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	tabs_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var selected: String = "all"
	var all_btn := Button.new()
	all_btn.text = "All"
	all_btn.custom_minimum_size = Vector2(0, 80)
	all_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	all_btn.clip_contents = true
	all_btn.toggle_mode = true
	all_btn.button_pressed = true
	all_btn.add_theme_font_size_override("font_size", 32)
	tabs_hbox.add_child(all_btn)

	var buttons: Array = [all_btn]
	var ids: Array = ["all"]
	for school in present_schools:
		var b := Button.new()
		b.text = String(school).capitalize()
		b.custom_minimum_size = Vector2(0, 80)
		b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		b.clip_contents = true
		b.toggle_mode = true
		b.button_pressed = false
		b.add_theme_font_size_override("font_size", 32)
		b.modulate = UICards.school_colour(String(school))
		tabs_hbox.add_child(b)
		buttons.append(b)
		ids.append(String(school))

	for i in buttons.size():
		var idx: int = i
		buttons[i].pressed.connect(func():
			for j in buttons.size():
				buttons[j].button_pressed = (j == idx)
			_populate_rows(String(ids[idx]), rows, host, player, known, dlg))
	return tabs_hbox


## Clears `rows` and rebuilds it for the selected school ("all" = full grouped view; else only that school's spells, no sub-header).
static func _populate_rows(selected_school: String, rows: VBoxContainer,
		host: Node, player, known: Array[String], dlg: GameDialog) -> void:
	for child in rows.get_children():
		rows.remove_child(child)
		child.queue_free()
	if selected_school == "all":
		_build_school_grouped_rows(rows, host, player, known, dlg)
		return
	for sp in known:
		var schools: Array = SpellRegistry.get_schools(sp)
		var primary: String = String(schools[0]) if not schools.is_empty() else "misc"
		if primary == selected_school:
			rows.add_child(_build_row(host, player, String(sp), dlg))


## MP + memorisation readouts the player checks before every cast.
## Layout mirrors DCSS's traditional "MP: N/M" + "spell levels used"
## pair so both constraints are visible above the spell list.
static func _build_header(vb: VBoxContainer, player) -> void:
	var cur_mp: int = player.stats.MP if player.stats != null else 0
	var max_mp: int = player.stats.mp_max if player.stats != null else 0
	var mp_lab := Label.new()
	mp_lab.text = "MP  %d / %d" % [cur_mp, max_mp]
	mp_lab.add_theme_font_size_override("font_size", 48)
	mp_lab.modulate = Color(0.45, 0.7, 1.0)
	vb.add_child(mp_lab)

	var used_lv: int = player.used_spell_levels() \
			if player.has_method("used_spell_levels") else 0
	var cap_lv: int = player.max_spell_levels() \
			if player.has_method("max_spell_levels") else 0
	var mem_lab := Label.new()
	mem_lab.text = "Memory  %d / %d spell levels" % [used_lv, cap_lv]
	mem_lab.add_theme_font_size_override("font_size", 40)
	mem_lab.modulate = Color(0.85, 0.80, 0.35) if used_lv < cap_lv \
			else Color(0.95, 0.45, 0.35)
	vb.add_child(mem_lab)


## Group the known-spell list by primary school, emit a section
## header per non-empty group, then render each spell's row under
## its header. School order comes from SpellRegistry.SCHOOL_SPELLS
## keys (stable dict ordering) so the Magic menu reads the same
## across sessions: Conjurations → Fire → Cold → Earth → Air →
## Necromancy → Alchemy → Hexes → Translocations → Summonings.
static func _build_school_grouped_rows(rows: VBoxContainer, host: Node,
		player, known: Array[String], dlg: GameDialog) -> void:
	var groups: Dictionary = {}
	for sp in known:
		var schools: Array = SpellRegistry.get_schools(sp)
		var primary: String = String(schools[0]) if not schools.is_empty() else "misc"
		if not groups.has(primary):
			groups[primary] = []
		groups[primary].append(sp)
	var school_order: Array = SpellRegistry.SCHOOL_SPELLS.keys()
	# Append any groups whose school didn't show up in SCHOOL_SPELLS
	# (DCSS-only schools loaded from JSON) so nothing drops silently.
	for g in groups.keys():
		if not school_order.has(g):
			school_order.append(g)
	for school_name in school_order:
		if not groups.has(school_name):
			continue
		var list: Array = groups[school_name]
		if list.is_empty():
			continue
		var header := UICards.accent_value(
				String(school_name).capitalize(), 36)
		header.modulate = UICards.school_colour(String(school_name))
		rows.add_child(header)
		for spell_id in list:
			rows.add_child(_build_row(host, player, String(spell_id), dlg))


## Per-spell row: school pills + name/cost button + Pow/Fail accent +
## Cast/QSlot column. Matches the pre-extraction layout pixel-for-
## pixel so the extracted menu reads the same as what shipped.
static func _build_row(host: Node, player, spell_id: String,
		dlg: GameDialog) -> Control:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return Control.new()

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 4)

	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 4)
	for school in SpellRegistry.get_schools(spell_id):
		var tag: String = String(school).substr(0, 3).to_upper()
		pill_row.add_child(UICards.pill(tag, UICards.school_colour(String(school))))
	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	pill_row.add_child(spacer)
	outer.add_child(pill_row)

	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 120)
	row.add_theme_constant_override("separation", 8)

	var name_btn := Button.new()
	name_btn.flat = true
	name_btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	name_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_btn.clip_contents = true
	var spell_name: String = String(info.get("name", spell_id))
	var range_txt: String = ""
	if int(info.get("range", 0)) > 0:
		range_txt = "  r%d" % int(info.get("range", 0))
	name_btn.text = "%s  [%d MP]%s" % [spell_name, int(info.get("mp", 0)), range_txt]
	name_btn.add_theme_font_size_override("font_size", 36)
	name_btn.add_theme_color_override("font_color", info.get("color", Color.WHITE))
	name_btn.pressed.connect(Callable(host, "_show_spell_info").bind(spell_id))
	row.add_child(name_btn)

	var spell_pow: int = SpellRegistry.calc_spell_power(spell_id, player)
	var fail_p: int = SpellRegistry.failure_rate(spell_id, player)
	var stats_col := VBoxContainer.new()
	stats_col.add_theme_constant_override("separation", 2)
	stats_col.custom_minimum_size = Vector2(110, 0)
	stats_col.add_child(UICards.accent_value("Pow %d" % spell_pow, 28))
	if fail_p > 0:
		stats_col.add_child(UICards.accent_value("Fail %d%%" % fail_p, 28))
	row.add_child(stats_col)

	var btns := VBoxContainer.new()
	btns.add_theme_constant_override("separation", 4)

	var cast_btn := Button.new()
	cast_btn.text = "Cast"
	cast_btn.custom_minimum_size = Vector2(110, 58)
	cast_btn.add_theme_font_size_override("font_size", 32)
	cast_btn.disabled = (player.stats == null \
			or player.stats.MP < int(info.get("mp", 1)))
	var targeting_type: String = String(info.get("targeting", "single"))
	if targeting_type == "self":
		cast_btn.pressed.connect(Callable(host, "_on_cast_pressed").bind(spell_id, dlg))
	else:
		cast_btn.pressed.connect(Callable(host, "_on_cast_with_targeting").bind(spell_id, dlg))
	btns.add_child(cast_btn)

	var qs_btn := Button.new()
	qs_btn.text = "QSlot"
	qs_btn.custom_minimum_size = Vector2(110, 48)
	qs_btn.add_theme_font_size_override("font_size", 30)
	qs_btn.pressed.connect(Callable(host, "_assign_spell_quickslot").bind(spell_id, dlg))
	btns.add_child(qs_btn)

	row.add_child(btns)
	outer.add_child(row)
	return outer


## Spell info popup — long-press / name-tap target. Builds the stat
## block fresh; GameBootstrap's `_spell_info_text` already paraphrases
## the same data for the quickslot-manage popup.
static func open_spell_info(host: Node, player, spell_id: String) -> void:
	var info: Dictionary = SpellRegistry.get_spell(spell_id)
	if info.is_empty():
		return
	var dlg := GameDialog.create(String(info.get("name", spell_id)),
			Vector2i(960, 1100))
	host.add_child(dlg)
	var vb: VBoxContainer = dlg.body()
	vb.add_theme_constant_override("separation", 12)
	var skill_sys = host.skill_system if "skill_system" in host else null
	var schools_list: Array = SpellRegistry.get_schools(spell_id)
	var schools_txt: String = ""
	if schools_list.size() > 0:
		var parts: Array = []
		for sname in schools_list:
			var lv: int = skill_sys.get_level(player, String(sname)) \
					if skill_sys != null and player != null else 0
			parts.append("%s Lv.%d" % [String(sname).capitalize(), lv])
		schools_txt = ", ".join(PackedStringArray(parts))
	var fail_pct: int = SpellRegistry.failure_rate(spell_id, player)
	var spell_pow: int = SpellRegistry.calc_spell_power(spell_id, player)
	var text: String = "%s\n\nMP Cost: %d\nSchools: %s\nDifficulty: %d\nPower: %d\nFailure: %d%%\nRange: %d" % [
		String(info.get("desc", "")),
		int(info.get("mp", 0)),
		schools_txt,
		int(info.get("difficulty", 1)),
		spell_pow,
		fail_pct,
		int(info.get("range", 6)),
	]
	if info.has("min_dmg") and int(info.get("min_dmg", 0)) > 0:
		text += "\nDamage: %d-%d + power" % [
				int(info.get("min_dmg", 0)), int(info.get("max_dmg", 0))]
	var lab := Label.new()
	lab.text = text
	lab.add_theme_font_size_override("font_size", 48)
	lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(lab)
