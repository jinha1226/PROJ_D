class_name SkillsDialog extends RefCounted

const _DESCRIPTIONS: Dictionary = {
	"endurance": "Increases max HP by 5 each level.\n\nEndurance is the primary way to grow your HP pool. It has no effect on accuracy or damage — just raw survivability. Worth activating for any build that expects to take hits.",
	"melee": "Improves accuracy, damage, and attack speed in close combat.\n\nMelee covers all weapon types at arm's reach — equivalent to DCSS weapon skills plus Fighting's combat contribution. Higher levels increase hit chance, damage, and reduce attack delay. Core skill for any fighter.",
	"ranged": "Improves bows and other dedicated ranged weapons.\n\nRanged improves attacks made from a distance. It rewards spacing and line-of-sight control. Rangers and cautious hybrids benefit from it most.",
	"tool": "Improves wands, thrown tools, and trick-based combat.\n\nTool governs practical combat devices such as wands and thrown utility items. It rewards timing, resource use, and flexible problem-solving. Trickery-aligned builds make the best use of it.",
	"magic": "Improves spellcasting and unlocks stronger spells.\n\nMagic governs spell power and determines which spell levels you can use. High Magic makes spells stronger, but Intelligence is still needed to learn advanced magic. Mages depend on it, but hybrids can use it for utility and support.",
	"defense": "Improves armor, shields, and durable front-line fighting.\n\nDefense strengthens armor use, blocking, and direct survival in melee. It is the core defensive skill for builds that expect to trade hits. Fighters depend on it most.",
	"agility": "Improves evasion, mobility, and opportunistic fighting.\n\nAgility improves your ability to avoid harm and exploit good positioning. It helps evasive builds survive without heavy armor. Rogues and mobile ranged builds value it most.",
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

	var tip := Label.new()
	tip.text = "Kill XP is split between ACTIVE skills. At least one skill must stay active."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	body.add_child(tip)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(vb)
	for id in Player.SKILL_IDS:
		var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
		vb.add_child(_make_skill_row(id, s, player, parent))

static func _bonus_text(id: String, level: int, player: Player) -> String:
	if level == 0:
		return "(no bonus yet)"
	match id:
		"endurance":
			return "+%d max HP" % [level * 5]
		"melee":
			return "+%d to-hit / +%d%% dmg / -%d%% delay" % [level * 2, level * 4, level * 3]
		"ranged":
			return "+%d to-hit / +%d%% dmg" % [level, level * 4]
		"tool":
			return "+%d to-hit / +%d%% dmg" % [level, level * 4]
		"magic":
			var power: int = int(float(player.intelligence) * (1.0 + float(level) * 0.06))
			return "spell power %d / up to spell level %d" % [power, level]
		"defense":
			var pct: int = min(level * 10, 90)
			return "armor penalty -%d%% / block +%d%%" % [pct, level * 3]
		"agility":
			return "+%d EV / ambush +%d%% / harder to detect" % [level, 50 + level * 5]
	return ""

static func _apt_for(id: String, player: Player) -> int:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id) \
			if GameManager != null and RaceRegistry != null else null
	if race == null:
		return 0
	return int(race.skill_aptitudes.get(id, 0))

static func _apt_label(apt: int) -> String:
	return "%+d" % apt

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

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	vb.add_child(row)

	var name_col := VBoxContainer.new()
	name_col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_col.add_theme_constant_override("separation", 0)
	row.add_child(name_col)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	name_col.add_child(name_row)

	var name_lbl := Label.new()
	name_lbl.text = id.capitalize()
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_row.add_child(name_lbl)

	var apt: int = _apt_for(id, player)
	if apt != 0:
		var apt_lbl := Label.new()
		apt_lbl.text = _apt_label(apt)
		apt_lbl.add_theme_font_size_override("font_size", 20)
		apt_lbl.add_theme_color_override("font_color",
			Color(0.45, 0.9, 0.5) if apt > 0 else Color(0.9, 0.45, 0.45))
		apt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_row.add_child(apt_lbl)

	var bonus_lbl := Label.new()
	bonus_lbl.text = _bonus_text(id, level, player)
	bonus_lbl.add_theme_font_size_override("font_size", 18)
	bonus_lbl.add_theme_color_override("font_color", Color(0.6, 0.75, 0.6))
	name_col.add_child(bonus_lbl)

	var lv_color: Color
	if level >= Player.MAX_SKILL_LEVEL:
		lv_color = Color(1.0, 0.85, 0.2)
	elif level >= Player.MAX_SKILL_LEVEL - 2:
		lv_color = Color(0.7, 1.0, 0.6)
	elif level == 0:
		lv_color = Color(0.55, 0.55, 0.6)
	else:
		lv_color = Color(0.85, 0.85, 0.85)

	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if level >= Player.MAX_SKILL_LEVEL else "Lv.%d" % level
	lv_lbl.add_theme_font_size_override("font_size", 24)
	lv_lbl.add_theme_color_override("font_color", lv_color)
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(lv_lbl)

	# 활성 상태 색상 갱신 함수
	var _refresh_active := func() -> void:
		var is_active: bool = player.is_skill_active(id)
		name_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.85, 0.35) if is_active else Color(0.45, 0.45, 0.5))
		vb.modulate = Color(1.0, 1.0, 1.0) if is_active else Color(0.7, 0.7, 0.75)
	_refresh_active.call()

	var _long_pressed := [false]
	hold_timer.timeout.connect(func(): _long_pressed[0] = true)
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
			_long_pressed[0] = false
			hold_timer.start()
		elif released:
			hold_timer.stop()
			if not _long_pressed[0]:
				if player.toggle_skill_active(id):
					_refresh_active.call()
			_long_pressed[0] = false)

	if level < Player.MAX_SKILL_LEVEL and needed > 0:
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
