class_name SkillsDialog extends RefCounted

const _CATEGORIES: Array = [
	["WEAPON SKILLS",  ["blade", "blunt", "dagger", "polearm", "ranged"], Color(0.9, 0.65, 0.3)],
	["DEFENSE",        ["armor"],                                          Color(0.4, 0.7, 1.0)],
	["MAGIC",          ["magic"],                                          Color(0.75, 0.5, 1.0)],
	["STEALTH",        ["stealth"],                                        Color(0.5, 0.85, 0.55)],
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
	var dlg: GameDialog = GameDialog.create("Skills")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 14)

	if player.skills.is_empty():
		player.init_skills()

	for cat_entry in _CATEGORIES:
		var cat_name: String = String(cat_entry[0])
		var skill_ids: Array = cat_entry[1]
		var tint: Color = cat_entry[2]

		body.add_child(UICards.section_header(cat_name))

		for id in skill_ids:
			var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
			body.add_child(_make_skill_card(id, s, tint))


static func _make_skill_card(id: String, s: Dictionary, tint: Color) -> Control:
	var card := UICards.card(tint)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var level: int = int(s.get("level", 0))
	var xp: float = float(s.get("xp", 0.0))
	var needed: int = 0
	if level < Player.SKILL_XP_DELTA.size():
		needed = Player.SKILL_XP_DELTA[level]

	# Top: skill name + level
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = id.capitalize()
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 30)
	top_row.add_child(name_lbl)

	var lv_color: Color
	if level >= 20:
		lv_color = Color(1.0, 0.85, 0.2)
	elif level >= 10:
		lv_color = Color(0.7, 1.0, 0.6)
	elif level == 0:
		lv_color = Color(0.55, 0.55, 0.6)
	else:
		lv_color = tint

	var lv_lbl := Label.new()
	lv_lbl.text = ("MAX" if level >= 20 else "Lv.%d" % level)
	lv_lbl.add_theme_font_size_override("font_size", 30)
	lv_lbl.add_theme_color_override("font_color", lv_color)
	top_row.add_child(lv_lbl)

	# XP bar + hint
	if level < 20 and needed > 0:
		var xp_bar := ProgressBar.new()
		xp_bar.max_value = needed
		xp_bar.value = xp
		xp_bar.show_percentage = false
		xp_bar.custom_minimum_size = Vector2(0, 14)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(tint.r * 0.6, tint.g * 0.6, tint.b * 0.6, 0.9)
		xp_bar.add_theme_stylebox_override("fill", sb)
		vb.add_child(xp_bar)
		vb.add_child(UICards.dim_hint("%d / %d xp to Lv.%d" % [int(xp), needed, level + 1], 22))

	# Description
	var desc: String = String(_DESCRIPTIONS.get(id, ""))
	if desc != "":
		vb.add_child(UICards.dim_hint(desc, 24))

	return card
