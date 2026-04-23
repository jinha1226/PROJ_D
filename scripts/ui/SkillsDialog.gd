class_name SkillsDialog extends RefCounted

const _CATEGORIES: Array = [
	["WEAPON SKILLS", ["blade", "blunt", "dagger", "polearm", "ranged"]],
	["DEFENSE",       ["armor"]],
	["MAGIC",         ["magic"]],
	["STEALTH",       ["stealth"]],
]

const _DESCRIPTIONS: Dictionary = {
	"blade":   "Sword, axe, long blade. +damage & accuracy. Trains on hit.",
	"blunt":   "Mace, flail, hammer. +damage & accuracy. Trains on hit.",
	"dagger":  "Dagger & short blade. Bonus stab damage vs unaware enemies.",
	"polearm": "Spear, halberd. Reach: attack from 2 tiles away. Trains on hit.",
	"ranged":  "Bow, sling. Reduces long-range accuracy penalty. Trains on hit.",
	"armor":   "Reduces EV penalty from heavy armour. Trains when taking hits.",
	"magic":   "Power = INT + skill×INT/10. Lowers spell fizzle chance. Trains on cast.",
	"stealth": "Delays enemy detection. Passive growth over time.",
}

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Skills  (hold to see description)")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	if player.skills.is_empty():
		player.init_skills()

	for cat_entry in _CATEGORIES:
		body.add_child(UICards.section_header(String(cat_entry[0])))
		for id: String in cat_entry[1]:
			var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
			body.add_child(_make_skill_row(id, s, parent))


static func _make_skill_row(id: String, s: Dictionary, parent: Node) -> Control:
	var level: int = int(s.get("level", 0))
	var xp: float = float(s.get("xp", 0.0))
	var needed: int = 0
	if level < Player.SKILL_XP_DELTA.size():
		needed = Player.SKILL_XP_DELTA[level]

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	vb.mouse_filter = Control.MOUSE_FILTER_STOP

	# Long-press timer
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

	# Name + level row
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.custom_minimum_size = Vector2(0, 44)
	vb.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = id.capitalize()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(name_lbl)

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

	# Thin XP bar
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
