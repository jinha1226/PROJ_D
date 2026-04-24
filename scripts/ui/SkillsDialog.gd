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
	"shield":        "Block incoming attacks. Trains when hit while a shield is equipped.",
	"dodge":         "+1 EV per level. Trains when dodging enemy attacks.",
	"stealth":       "Delays enemy detection. Passive growth over time.",
	"magic":         "General spellcasting. Powers school-less spells (blink, fog, etc.).",
	"evocation":     "Channelled force spells. Spell power = INT + skill × INT/8.",
	"necromancy":    "Death and undeath magic. Spell power = INT + skill × INT/8.",
	"transmutation": "Body and form magic. Spell power = INT + skill × INT/8.",
	"enchantment":   "Mind and charm magic. Spell power = INT + skill × INT/8.",
	"conjuration":   "Summoning magic. Spell power = INT + skill × INT/8.",
	"abjuration":    "Protective ward magic. Enhances spell power. Trains on casting.",
}

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Skills", 0.92, 0.92)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	if player.skills.is_empty():
		player.init_skills()

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(tab_bar)

	# Content container — swap visibility on tab switch
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)

	# Build all 4 tab contents
	var tab_contents: Array = [
		_build_learned_tab(player, parent),
		_build_combat_tab(player, parent),
		_build_defense_tab(player, parent),
		_build_magic_tab(player, parent),
	]
	for tc in tab_contents:
		tc.visible = false
		content.add_child(tc)
	tab_contents[0].visible = true  # LEARNED shown first

	# Tab buttons
	var tab_labels: Array = ["LEARNED", "COMBAT", "DEFENSE", "MAGIC"]
	var tab_btns: Array = []
	for i in range(tab_labels.size()):
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		var idx: int = i
		btn.pressed.connect(func():
			for j in range(tab_contents.size()):
				tab_contents[j].visible = (j == idx)
			for j in range(tab_btns.size()):
				tab_btns[j].disabled = (j == idx))
		tab_bar.add_child(btn)
		tab_btns.append(btn)
	tab_btns[0].disabled = true  # LEARNED active by default


static func _build_learned_tab(player: Player, parent: Node) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	# Collect all skills with level > 0, sort by level desc
	var leveled: Array = []
	for id in Player.SKILL_IDS:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		var lv: int = int(s.get("level", 0))
		if lv > 0:
			leveled.append({"id": id, "s": s, "lv": lv})
	leveled.sort_custom(func(a, b): return a.lv > b.lv)
	if leveled.is_empty():
		var lbl := Label.new()
		lbl.text = "(No skills trained yet)"
		lbl.add_theme_font_size_override("font_size", 26)
		lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		vb.add_child(lbl)
	else:
		for entry in leveled:
			vb.add_child(_make_skill_row(entry.id, entry.s, player, parent))
	return vb


static func _build_combat_tab(player: Player, parent: Node) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	for id in ["blade", "blunt", "dagger", "polearm", "ranged", "fighting"]:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		vb.add_child(_make_skill_row(id, s, player, parent))
	return vb


static func _build_defense_tab(player: Player, parent: Node) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	for id in ["armor", "shield", "stealth", "dodge"]:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		vb.add_child(_make_skill_row(id, s, player, parent))
	return vb


static func _build_magic_tab(player: Player, parent: Node) -> VBoxContainer:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	# "magic" skill shown only if the player actually has XP in it (generalist / school-less spells)
	var s_magic: Dictionary = player.skills.get("magic", {"level": 0, "xp": 0.0})
	if s_magic.get("level", 0) > 0 or s_magic.get("xp", 0.0) > 0.0:
		vb.add_child(UICards.section_header("GENERAL"))
		vb.add_child(_make_skill_row("magic", s_magic, player, parent))
	vb.add_child(UICards.section_header("SCHOOLS"))
	for school in _SCHOOL_IDS:
		var s_school: Dictionary = player.skills.get(school, {"level": 0, "xp": 0.0})
		vb.add_child(_make_school_section(school, s_school, player, parent))
	return vb


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
		"shield":
			return "block chance +%d%%" % (level * 4)
		"dodge":
			return "+%d EV" % level
		"magic":
			var power_bonus: int = int(player.intelligence * level / 8.0)
			return "spell power +%d  (school-less spells only)" % power_bonus
		"stealth":
			return "detection delay +%d turns" % level
	# School skills — power = INT + skill * INT / 8
	if _SCHOOL_IDS.has(id):
		var power_bonus: int = int(player.intelligence * level / 8.0)
		return "spell power +%d  (INT %d × skill %d / 8)" % [power_bonus, player.intelligence, level]
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
