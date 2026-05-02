class_name SkillsDialog extends RefCounted

const _DESCRIPTIONS: Dictionary = {
	"fighting": "Increases max HP by 5 each level.

Fighting is the primary way to grow your HP pool. It has no effect on accuracy or damage, only survivability.",
	"unarmed": "Improves bare-handed combat and bestial melee.

Use this if you plan to fight without a weapon or rely on natural attacks.",
	"blade": "Improves daggers, swords, and light arcane staves.

Blade covers precise close combat, fast weapons, and most finesse-driven melee builds.",
	"hafted": "Improves maces, clubs, and axes.

Hafted weapons are heavier and hit harder, favoring sturdy front-line fighters.",
	"polearm": "Improves spears and other reach weapons.

Polearms reward spacing and safer melee positioning.",
	"ranged": "Improves bows and other dedicated ranged weapons.

Ranged improves attacks made from a distance and rewards line-of-sight control.",
	"spellcasting": "Improves MP efficiency, magical fundamentals, and universal spell power.

Every serious caster benefits from Spellcasting, regardless of school.",
	"elemental": "Improves fire, cold, air, earth, and alchemical elemental spells.

This is the main school for direct elemental offense.",
	"arcane": "Improves conjurations, movement magic, wards, evocations, and pure arcane utility.

Arcane covers force, control of space, and general magical technique.",
	"hex": "Improves disabling, confusion, fear, sleep, and other hostile control magic.

Hexes are about making enemies fail rather than killing them outright.",
	"necromancy": "Improves pain, drain, death, and undead magic.

Necromancy is the school of life theft, corruption, and dark momentum.",
	"summoning": "Improves creature-calling and gateway magic.

Summoning builds win by creating allies and battlefield pressure.",
	"armor": "Improves armor handling and reduces armor penalties.

Armor is the main defensive skill for heavy gear and long attrition fights.",
	"shield": "Improves blocking with shields.

Shield is the dedicated skill for off-hand defense and reliable protection.",
	"agility": "Improves evasion, mobility, and opportunistic fighting.

Agility helps evasive builds survive without heavy armor.",
	"tool": "Improves wands, thrown tools, and trick-based combat.

Tool governs practical combat devices and flexible problem-solving.",
}

const TABS: Array = [
	{"id": "active",  "label": "ACTIVE"},
	{"id": "weapon",  "label": "WEAPON"},
	{"id": "magic",   "label": "MAGIC"},
	{"id": "defense", "label": "DEFENSE"},
]

const TAB_SKILLS: Dictionary = {
	"weapon":  ["fighting", "unarmed", "blade", "hafted", "polearm", "ranged", "tool"],
	"magic":   ["spellcasting", "elemental", "arcane", "hex", "necromancy", "summoning"],
	"defense": ["armor", "shield", "agility"],
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

	# ── tip ──────────────────────────────────────────────────────────────────
	var tip := Label.new()
	tip.text = "Kill XP is split between ACTIVE skills. Tap to toggle. Long-press for details."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.7, 0.78, 0.85))
	body.add_child(tip)

	# ── tab bar ───────────────────────────────────────────────────────────────
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(tab_bar)

	# ── content area ─────────────────────────────────────────────────────────
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 6)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)

	# ── tab button refs for highlight swap ───────────────────────────────────
	var tab_btns: Array = []

	var _switch_tab := func(tab_id: String) -> void:
		for child in content.get_children():
			child.queue_free()
		var ids: Array = []
		if tab_id == "active":
			for id in Player.SKILL_IDS:
				var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
				if player.is_skill_active(id) or int(s.get("level", 0)) > 0:
					ids.append(id)
			if ids.is_empty():
				var empty := Label.new()
				empty.text = "No active or learned skills yet."
				empty.add_theme_font_size_override("font_size", 22)
				empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
				content.add_child(empty)
		else:
			ids = Array(TAB_SKILLS.get(tab_id, []))
		for id in ids:
			var s: Dictionary = player.skills.get(id, {"level": 0, "xp": 0.0})
			content.add_child(_make_skill_row(id, s, player, parent))
		# highlight active tab button
		for i in tab_btns.size():
			var btn: Button = tab_btns[i]
			var is_sel: bool = (TABS[i]["id"] == tab_id)
			btn.modulate = Color(1.0, 1.0, 1.0) if is_sel else Color(0.55, 0.55, 0.6)

	# build tab buttons
	for tab in TABS:
		var btn := Button.new()
		btn.text = tab["label"]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 22)
		btn.custom_minimum_size = Vector2(0, 48)
		var tid: String = tab["id"]
		btn.pressed.connect(func(): _switch_tab.call(tid))
		tab_bar.add_child(btn)
		tab_btns.append(btn)

	_switch_tab.call("active")

static func _bonus_text(id: String, level: int, player: Player) -> String:
	if level == 0:
		return "(no bonus yet)"
	match id:
		"fighting":
			return "+%d max HP" % [level * 5]
		"unarmed":
			return "+%d to-hit / +%d%% dmg" % [level, level * 5]
		"blade":
			return "+%d to-hit / +%d%% dmg / +%d%% finesse" % [level, level * 4, level * 3]
		"hafted":
			return "+%d to-hit / +%d%% dmg" % [level, level * 5]
		"polearm":
			return "+%d to-hit / +%d%% dmg / safer reach" % [level, level * 4]
		"ranged":
			return "+%d to-hit / +%d%% dmg" % [level, level * 4]
		"tool":
			return "+%d to-hit / +%d%% dmg" % [level, level * 4]
		"spellcasting":
			var power: int = int(float(player.intelligence) * (1.0 + float(level) * 0.04))
			return "core spell power %d / mana efficiency" % [power]
		"elemental", "arcane", "hex", "necromancy", "summoning":
			var power: int = int(float(player.intelligence) * (1.0 + float(level) * 0.07))
			return "school power %d" % [power]
		"armor":
			var pct: int = min(level * 10, 90)
			return "armor penalty -%d%% / attrition resist" % [pct]
		"shield":
			return "block +%d%%" % [level * 3]
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

	var _long_pressed := [false]
	var hold_timer := Timer.new()
	hold_timer.wait_time = 0.6
	hold_timer.one_shot = true
	vb.add_child(hold_timer)
	var desc: String = String(_DESCRIPTIONS.get(id, ""))
	hold_timer.timeout.connect(func():
		_long_pressed[0] = true
		_show_desc(id, desc, parent)
	)

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

	var xp_pct_lbl := Label.new()
	xp_pct_lbl.add_theme_font_size_override("font_size", 20)
	xp_pct_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	xp_pct_lbl.custom_minimum_size = Vector2(52, 0)
	xp_pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(xp_pct_lbl)

	# 활성 상태 색상 갱신 함수
	var _refresh_active := func() -> void:
		var is_active: bool = player.is_skill_active(id)
		name_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.85, 0.35) if is_active else Color(0.45, 0.45, 0.5))
		vb.modulate = Color(1.0, 1.0, 1.0) if is_active else Color(0.7, 0.7, 0.75)
		var active_count: int = player.active_skills.size()
		if is_active and active_count > 0:
			var pct: int = int(round(100.0 / float(active_count)))
			xp_pct_lbl.text = "%d%%" % pct
			xp_pct_lbl.add_theme_color_override("font_color", Color(0.7, 0.95, 0.7))
		else:
			xp_pct_lbl.text = ""
	_refresh_active.call()

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
		xp_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(xp_row)

		var xp_bar := ProgressBar.new()
		xp_bar.max_value = needed
		xp_bar.value = xp
		xp_bar.show_percentage = false
		xp_bar.custom_minimum_size = Vector2(0, 10)
		xp_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		xp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		xp_row.add_child(xp_bar)

		var xp_lbl := Label.new()
		xp_lbl.text = "%d/%d" % [int(xp), needed]
		xp_lbl.add_theme_font_size_override("font_size", 18)
		xp_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		xp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
