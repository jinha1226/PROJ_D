class_name SkillsDialog extends RefCounted

## Read-only skills viewer. Skills grow from use (CombatSystem grants
## weapon-category XP on hit; MagicSystem grants magic XP on cast) — no
## player-side manual training in the MVP.

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Skills")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	if player.skills.is_empty():
		player.init_skills()

	for id in Player.SKILL_IDS:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		body.add_child(_make_row(id, s))

static func _make_row(id: String, s: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 52)
	row.add_theme_constant_override("separation", 8)

	var name_lab := Label.new()
	name_lab.text = id.capitalize()
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", 24)
	row.add_child(name_lab)

	var level: int = int(s.get("level", 0))
	var xp: float = float(s.get("xp", 0.0))

	var lvl_lab := Label.new()
	var needed: int = 0
	if level < Player.SKILL_XP_DELTA.size():
		needed = Player.SKILL_XP_DELTA[level]
	var xp_text: String
	if level >= 20:
		xp_text = "MAX"
	elif needed == 0:
		xp_text = "(max)"
	else:
		xp_text = "(%d / %d xp)" % [int(xp), needed]
	lvl_lab.text = "Lv.%d  %s" % [level, xp_text]
	lvl_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lvl_lab.add_theme_font_size_override("font_size", 22)
	var col: Color = Color(0.9, 0.9, 0.75)
	if level >= 20:
		col = Color(1.0, 0.8, 0.35)
	elif level == 0:
		col = Color(0.6, 0.6, 0.65)
	lvl_lab.add_theme_color_override("font_color", col)
	row.add_child(lvl_lab)
	return row
