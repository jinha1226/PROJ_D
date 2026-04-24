class_name SkillsDialog extends RefCounted

const _SCHOOL_IDS: Array = [
	"evocation", "necromancy", "transmutation", "enchantment", "conjuration", "abjuration"
]

const _DESCRIPTIONS: Dictionary = {
	"blade":         "Sword, axe, long blade. +damage & accuracy. Trains on hit.",
	"blunt":         "Mace, flail, hammer. +damage & accuracy. Trains on hit.",
	"dagger":        "Dagger & short blade. Bonus stab damage vs unaware enemies.",
	"polearm":       "Spear, halberd. Reach: attack from 2 tiles away. Trains on hit.",
	"ranged":        "Bow, sling. Reduces long-range accuracy penalty. Trains on hit.",
	"fighting":      "General combat. +5 max HP and +1 damage per 2 levels. Trains on every melee hit.",
	"armor":         "Reduces EV penalty from heavy armour. Trains when taking hits.",
	"magic":         "General spellcasting. Lowers fizzle chance. Trains on every cast.",
	"evocation":     "Channelled force spells. Enhances spell power. Trains on casting.",
	"necromancy":    "Death and undeath magic. Enhances spell power. Trains on casting.",
	"transmutation": "Body and form magic. Enhances spell power. Trains on casting.",
	"enchantment":   "Mind and charm magic. Enhances spell power. Trains on casting.",
	"conjuration":   "Summoning magic. Enhances spell power. Trains on casting.",
	"abjuration":    "Protective ward magic. Enhances spell power. Trains on casting.",
	"stealth":       "Delays enemy detection. Passive growth over time.",
}

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Skills  (hold for info)", 0.92, 0.92)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	if player.skills.is_empty():
		player.init_skills()

	# COMBAT
	body.add_child(UICards.section_header("COMBAT"))
	for id in ["blade", "blunt", "dagger", "polearm", "ranged", "fighting"]:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		body.add_child(_make_skill_row(id, s, player, parent))

	# DEFENSE
	body.add_child(UICards.section_header("DEFENSE"))
	var s_armor: Dictionary = player.skills.get("armor", {"level": 0, "xp": 0.0})
	body.add_child(_make_skill_row("armor", s_armor, player, parent))

	# SPELLCASTING
	body.add_child(UICards.section_header("SPELLCASTING"))
	var s_magic: Dictionary = player.skills.get("magic", {"level": 0, "xp": 0.0})
	body.add_child(_make_skill_row("magic", s_magic, player, parent))

	# MAGIC SCHOOLS — each with known spells listed
	body.add_child(UICards.section_header("MAGIC SCHOOLS"))
	for school in _SCHOOL_IDS:
		var s_school: Dictionary = player.skills.get(school, {"level": 0, "xp": 0.0})
		body.add_child(_make_school_section(school, s_school, player, parent))

	# STEALTH
	body.add_child(UICards.section_header("STEALTH"))
	var s_stealth: Dictionary = player.skills.get("stealth", {"level": 0, "xp": 0.0})
	body.add_child(_make_skill_row("stealth", s_stealth, player, parent))


static func _bonus_text(id: String, level: int, player: Player) -> String:
	if level == 0:
		return "(no bonus yet)"
	match id:
		"blade", "blunt", "polearm", "ranged":
			return "+%d to-hit  ·  +%d%% dmg" % [level, level * 5]
		"dagger":
			return "+%d to-hit  ·  +%d%% dmg  ·  stab vs unaware" % [level, level * 5]
		"fighting":
			return "+%d max HP  ·  +%d melee dmg" % [level * 5, level / 2]
		"armor":
			var pct: int = min(level * 10, 100)
			return "EV penalty -%d%% reduced" % pct
		"magic":
			var fizzle_cut: int = level * 3
			return "fizzle -%d%%  ·  base power +%d%%" % [fizzle_cut, level * 10]
		"stealth":
			return "detection delay +%d turns" % level
	# School skills
	if _SCHOOL_IDS.has(id):
		var bonus: int = int(player.intelligence * level / 20.0)
		return "spell power +%d  ·  +%d%% base" % [bonus, level * 5]
	return ""


static func _make_school_section(school: String, s: Dictionary,
		player: Player, parent: Node) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	vb.add_child(_make_skill_row(school, s, player, parent))

	var known_spells: Array = SpellRegistry.get_by_school(school).filter(
		func(sp: SpellData) -> bool: return player.known_spells.has(sp.id))
	if not known_spells.is_empty():
		var spell_list := VBoxContainer.new()
		spell_list.add_theme_constant_override("separation", 2)
		var indent := HBoxContainer.new()
		indent.add_theme_constant_override("separation", 0)
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(16, 0)
		indent.add_child(spacer)
		indent.add_child(spell_list)
		vb.add_child(indent)
		for sp: SpellData in known_spells:
			var row := HBoxContainer.new()
			row.add_theme_constant_override("separation", 8)
			var lv_lbl := Label.new()
			lv_lbl.text = "L%d" % sp.spell_level
			lv_lbl.custom_minimum_size = Vector2(36, 0)
			lv_lbl.add_theme_font_size_override("font_size", 20)
			lv_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.9))
			row.add_child(lv_lbl)
			var name_lbl := Label.new()
			name_lbl.text = sp.display_name
			name_lbl.add_theme_font_size_override("font_size", 22)
			name_lbl.add_theme_color_override("font_color", Color(0.8, 0.8, 0.9))
			row.add_child(name_lbl)
			var mp_lbl := Label.new()
			mp_lbl.text = "%dMP" % sp.mp_cost
			mp_lbl.add_theme_font_size_override("font_size", 20)
			mp_lbl.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
			mp_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			mp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
			row.add_child(mp_lbl)
			spell_list.add_child(row)

	return vb


static func _make_skill_row(id: String, s: Dictionary, player: Player, parent: Node) -> Control:
	var level: int = int(s.get("level", 0))
	var xp: float = float(s.get("xp", 0.0))
	var needed: int = 0
	if level < Player.SKILL_XP_DELTA.size():
		needed = Player.SKILL_XP_DELTA[level]

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP

	var hold_timer := Timer.new()
	hold_timer.wait_time = 0.5
	hold_timer.one_shot = true
	vb.add_child(hold_timer)
	var desc: String = String(_DESCRIPTIONS.get(id, ""))
	hold_timer.timeout.connect(func(): _show_desc(id, desc, parent))

	vb.gui_input.connect(func(ev: InputEvent) -> void:
		var pressed: bool = false
		var released: bool = false
		if ev is InputEventScreenTouch:
			pressed = ev.pressed
			released = not ev.pressed
		elif ev is InputEventMouseButton and ev.button_index == MOUSE_BUTTON_LEFT:
			pressed = ev.pressed
			released = not ev.pressed
		if pressed:
			hold_timer.start()
		elif released:
			hold_timer.stop())

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	row.add_child(name_col)

	var name_lbl := Label.new()
	name_lbl.text = id.capitalize()
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_col.add_child(name_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.text = _bonus_text(id, level, player)
	bonus_lbl.add_theme_font_size_override("font_size", 18)
	bonus_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	name_col.add_child(bonus_lbl)

	var lv_color: Color
	if level >= 20:
		lv_color = Color(1.0, 0.85, 0.2)
	elif level >= 10:
		lv_color = Color(0.7, 1.0, 0.6)
	elif level == 0:
		lv_color = Color(0.55, 0.55, 0.6)
	else:
		lv_color = Color(0.85, 0.85, 0.85)

	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if level >= 20 else "Lv.%d" % level
	lv_lbl.add_theme_font_size_override("font_size", 24)
	lv_lbl.add_theme_color_override("font_color", lv_color)
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lv_lbl)

	if level < 20 and needed > 0:
		var xp_row := HBoxContainer.new()
		xp_row.add_theme_constant_override("separation", 6)
		vb.add_child(xp_row)

		var xp_bar := ProgressBar.new()
		xp_bar.max_value = needed
		xp_bar.value = xp
		xp_bar.show_percentage = false
		xp_bar.custom_minimum_size = Vector2(0, 10)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_row.add_child(xp_bar)

		var xp_lbl := Label.new()
		xp_lbl.text = "%d/%d" % [int(xp), needed]
		xp_lbl.add_theme_font_size_override("font_size", 18)
		xp_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		xp_row.add_child(xp_lbl)

	return vb


static func _show_desc(skill_id: String, desc: String, parent: Node) -> void:
	if desc == "":
		return
	var dlg: GameDialog = GameDialog.create(skill_id.capitalize())
	parent.add_child(dlg)
	var body := dlg.body()
	if body == null:
		return
	var lbl := Label.new()
	lbl.text = desc
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lbl)
