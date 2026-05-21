class_name SkillsDialog extends RefCounted

## Per-sub-skill long-press descriptions. Keys are the post-30-split sub-skill ids.
const _DESCRIPTIONS: Dictionary = {
	"fighting": "Increases max HP by 5 each level.\n\nFighting is the universal melee foundation — every melee build wants it for HP and a small accuracy bonus.",
	"unarmed": "Improves bare-handed combat.\n\nFor builds without a weapon or with claw/bite natural attacks.",
	"short_blades": "Improves daggers and short swords.\n\nFavors stab/backstab playstyles and rewards positioning over raw damage.",
	"long_blades": "Improves long swords, scimitars, and other heavy blades.\n\nBalanced damage and accuracy for the standard melee fighter.",
	"maces": "Improves maces, clubs, and morningstars.\n\nHigh damage swings, slower than blades.",
	"axes": "Improves axes and cleavers.\n\nAxes can hit adjacent foes (cleave) — strong against grouped enemies.",
	"staves": "Improves quarterstaves and combat staves.\n\nReach without polearm bulk; pairs with magic staff users.",
	"polearms": "Improves spears, halberds, and glaives.\n\nReach attacks reward kiting and safer positioning.",
	"bows": "Improves longbows and shortbows.",
	"crossbows": "Improves crossbows and arbalests.",
	"slings": "Improves slings and stones.",
	"throwing": "Improves thrown weapons (javelins, darts, boomerangs).",
	"armor": "Reduces armor penalties and improves heavy armor handling.",
	"shields": "Improves shield blocking and reduces shield penalties.",
	"dodging": "Improves evasion and active dodging.",
	"stealth": "Improves staying unseen and ambush positioning.",
	"spellcasting": "Improves MP efficiency and universal spell power. Every caster wants it.",
	"conjurations": "Improves direct-damage arcane spells (force, magic missile, summons of energy).",
	"hexes": "Improves disabling magic — confusion, fear, sleep, slow.",
	"charms": "Improves buff and ward magic — haste, mage armor, repel.",
	"summonings": "Improves creature-calling and gateway magic.",
	"necromancy": "Improves pain, drain, death, and undead magic.",
	"translocations": "Improves blink, teleport, and gateway control.",
	"transmutation": "Improves shape-change, alteration, and physical-conversion magic.",
	"fire": "Improves fire-element spells and fire damage.",
	"ice": "Improves cold/ice spells and ice damage.",
	"air": "Improves lightning/wind spells and air damage.",
	"earth": "Improves earth/stone spells and earth damage.",
	"poison": "Improves poison/venom spells and poison damage.",
	"invocations": "Improves channelled magical invocations and ritual effects.",
	"evocations": "Improves wands, scrolls, and magical tools.",
}

const _VISIBLE_ORDER: Array = [
	"weapon_mastery", "archery", "tactics", "defense",
	"magery", "stealth", "lockpicking", "tracking", "survival",
]

const _VISIBLE_LABELS: Dictionary = {
	"weapon_mastery": "Weapon Mastery",
	"archery": "Archery",
	"tactics": "Tactics",
	"defense": "Defense",
	"magery": "Magery",
	"stealth": "Stealth",
	"lockpicking": "Lockpicking",
	"tracking": "Tracking",
	"survival": "Survival",
}

## Visible skill -> hidden familiarity rows. These rows read player.hidden_skills
## directly so the current dual-write behavior can be inspected in game.
const _HIDDEN_BY_VISIBLE: Dictionary = {
	"weapon_mastery": ["fighting", "unarmed", "short_blades", "long_blades",
		"maces", "axes", "staves", "polearms"],
	"archery": ["bows", "crossbows", "slings", "throwing"],
	"defense": ["armor", "shields"],
	"magery": ["spellcasting", "conjurations", "hexes", "charms", "summonings",
		"necromancy", "translocations", "transmutation",
		"fire", "ice", "air", "earth", "poison", "invocations", "evocations"],
	"stealth": ["dodging"],
	"tactics": [],
	"lockpicking": [],
	"tracking": [],
	"survival": [],
}

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("", 0.92, 0.92)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", GameTheme.PAD_M)

	if player.skills.is_empty():
		player.init_skills()

	# manual_mode is wrapped in a 1-element array so the closures can mutate it.
	var manual_mode: Array = [false]

	# ── mode banner ──────────────────────────────────────────────────────────
	var mode_lbl := Label.new()
	mode_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	mode_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	body.add_child(mode_lbl)

	# ── content (visible skill cards) ────────────────────────────────────────
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", GameTheme.PAD_M)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(content)

	# ── bottom toggle button ─────────────────────────────────────────────────
	var toggle_btn := Button.new()
	toggle_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	toggle_btn.custom_minimum_size = Vector2(0, GameTheme.TAP_MIN_HEIGHT)
	body.add_child(toggle_btn)

	var refresh_banner := func() -> void:
		var n: int = player.active_skills.size()
		if manual_mode[0]:
			if n == 0:
				mode_lbl.text = "Manual mode: tap a visible skill to mark it active."
			else:
				mode_lbl.text = "Manual mode: kill XP splits across %d active visible skill%s." \
					% [n, "" if n == 1 else "s"]
			mode_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))
		else:
			if n == 0:
				mode_lbl.text = "Auto: actions train visible skills and matching hidden familiarity."
				mode_lbl.add_theme_color_override("font_color", Color(0.6, 0.85, 0.95))
			else:
				mode_lbl.text = "Manual: %d active visible skill%s. Toggle Manual to edit." \
					% [n, "" if n == 1 else "s"]
				mode_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.35))

	var rebuild := func() -> void:
		for child in content.get_children():
			child.queue_free()
		var on_change := func() -> void:
			refresh_banner.call()
		for skill_id in _VISIBLE_ORDER:
			content.add_child(_make_visible_skill_card(skill_id, player, parent, manual_mode[0], on_change))
		toggle_btn.text = "Done" if manual_mode[0] else "Manual"
		refresh_banner.call()

	toggle_btn.pressed.connect(func():
		manual_mode[0] = not manual_mode[0]
		rebuild.call())
	rebuild.call()


static func _make_visible_skill_card(skill_id: String, player: Player, parent: Node,
		manual_mode: bool, on_change: Callable) -> Control:
	var card := PanelContainer.new()
	var inner := VBoxContainer.new()
	inner.add_theme_constant_override("separation", GameTheme.PAD_S)
	card.add_child(inner)

	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", GameTheme.PAD_M)
	inner.add_child(header)

	var active_lbl := Label.new()
	active_lbl.custom_minimum_size = Vector2(28, 0)
	active_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	active_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	header.add_child(active_lbl)

	var name_lbl := Label.new()
	name_lbl.text = _visible_name(skill_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.84, 0.42))
	header.add_child(name_lbl)

	var lv: int = player.get_skill_level(skill_id)
	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if lv >= Player.MAX_SKILL_LEVEL else "Lv.%d / %d" % [lv, Player.MAX_SKILL_LEVEL]
	lv_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	lv_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.2) if lv >= Player.MAX_SKILL_LEVEL else Color(0.85, 0.85, 0.85))
	header.add_child(lv_lbl)

	var xp: float = player.get_skill_xp(skill_id)
	var next_need: float = float(Player.SKILL_XP_DELTA[lv]) if lv < Player.SKILL_XP_DELTA.size() else 0.0
	if next_need > 0.0:
		var bar_row := HBoxContainer.new()
		bar_row.add_theme_constant_override("separation", GameTheme.PAD_S)
		inner.add_child(bar_row)
		var bar := ProgressBar.new()
		bar.max_value = next_need
		bar.value = clamp(xp, 0.0, next_need)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 10)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bar_row.add_child(bar)
		var bar_lbl := Label.new()
		bar_lbl.text = "%d/%d" % [int(xp), int(next_need)]
		bar_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		bar_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		bar_row.add_child(bar_lbl)

	var refresh_header := func() -> void:
		var is_active: bool = player.is_skill_active(skill_id)
		active_lbl.text = "X" if is_active else "-"
		active_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.85, 0.35) if is_active else Color(0.5, 0.5, 0.55))
		name_lbl.add_theme_color_override("font_color",
			Color(0.95, 0.9, 0.7) if is_active else Color(0.94, 0.84, 0.42))
	refresh_header.call()

	if manual_mode:
		card.gui_input.connect(func(event: InputEvent) -> void:
			if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				if player.toggle_skill_active(skill_id):
					refresh_header.call()
					if on_change.is_valid():
						on_change.call())

	var hidden_ids: Array = _HIDDEN_BY_VISIBLE.get(skill_id, [])
	if not hidden_ids.is_empty():
		var sep := HSeparator.new()
		inner.add_child(sep)
		var sub_list := VBoxContainer.new()
		sub_list.add_theme_constant_override("separation", 2)
		inner.add_child(sub_list)
		for hidden_id in hidden_ids:
			sub_list.add_child(_make_hidden_row(String(hidden_id), player, parent))

	return card


static func _make_hidden_row(skill_id: String, player: Player, parent: Node) -> Control:
	var s: Dictionary = player.hidden_skills.get(skill_id, {"level": 0, "xp": 0.0})
	var level: int = int(s.get("level", 0))
	var xp: float = float(s.get("xp", 0.0))
	var needed: int = 0
	if level < Player.SKILL_XP_DELTA.size():
		needed = Player.SKILL_XP_DELTA[level]

	var btn := Button.new()
	btn.flat = true
	btn.toggle_mode = false
	btn.custom_minimum_size = Vector2(0, GameTheme.TAP_MIN_HEIGHT)
	btn.add_theme_constant_override("h_separation", GameTheme.PAD_M)
	# We provide our own layout via children — clear the button's text/icon.
	btn.text = ""

	# Wrap content in HBox child (button supports children for custom layout).
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_M)
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE  # let button receive clicks
	btn.add_child(row)

	var name_lbl := Label.new()
	var sk_key: String = "SKILL_NAME_" + skill_id.to_upper()
	var sk_t: String = LocaleManager.t(sk_key)
	name_lbl.text = sk_t if sk_t != sk_key else skill_id.capitalize().replace("_", " ")
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(name_lbl)

	var apt: int = _apt_for(skill_id, player)
	if apt != 0:
		var apt_lbl := Label.new()
		apt_lbl.text = _apt_label(apt)
		apt_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		apt_lbl.add_theme_color_override("font_color",
			Color(0.45, 0.9, 0.5) if apt > 0 else Color(0.9, 0.45, 0.45))
		apt_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		apt_lbl.custom_minimum_size = Vector2(28, 0)
		apt_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(apt_lbl)

	var lv_color: Color
	if level >= Player.MAX_SKILL_LEVEL:
		lv_color = Color(1.0, 0.85, 0.2)
	elif level == 0:
		lv_color = Color(0.55, 0.55, 0.6)
	else:
		lv_color = Color(0.85, 0.85, 0.85)
	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if level >= Player.MAX_SKILL_LEVEL else "Lv.%d" % level
	lv_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	lv_lbl.add_theme_color_override("font_color", lv_color)
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(lv_lbl)

	var pct_lbl := Label.new()
	pct_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	pct_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	pct_lbl.custom_minimum_size = Vector2(40, 0)
	pct_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	pct_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pct_lbl.text = "%d/%d" % [int(xp), needed] if needed > 0 else ""
	row.add_child(pct_lbl)

	# Long-press → description popup. Set _long_pressed before any handler may
	# read it so the closure captures the same array reference.
	var _long_pressed := [false]
	var hold_timer := Timer.new()
	hold_timer.wait_time = 0.6
	hold_timer.one_shot = true
	btn.add_child(hold_timer)
	var key: String = "SKILL_DESC_" + skill_id.to_upper()
	var translated: String = LocaleManager.t(key)
	var desc: String = translated if translated != key else String(_DESCRIPTIONS.get(skill_id, ""))
	hold_timer.timeout.connect(func():
		_long_pressed[0] = true
		_show_desc(skill_id, desc, parent))
	btn.button_down.connect(func():
		_long_pressed[0] = false
		hold_timer.start())
	btn.button_up.connect(func():
		hold_timer.stop())
	btn.pressed.connect(func() -> void:
		if _long_pressed[0]:
			return
		_show_desc(skill_id, desc, parent))

	return btn


static func _visible_name(skill_id: String) -> String:
	var key: String = "SKILL_NAME_" + skill_id.to_upper()
	var translated: String = LocaleManager.t(key)
	if translated != key:
		return translated
	return String(_VISIBLE_LABELS.get(skill_id, skill_id.capitalize().replace("_", " ")))

static func _apt_for(id: String, _player: Player) -> int:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id) \
			if GameManager != null and RaceRegistry != null else null
	return Player.aptitude_for(race, id)

static func _apt_label(apt: int) -> String:
	return "%+d" % apt

static func _show_desc(skill_id: String, desc: String, parent: Node) -> void:
	if desc == "":
		return
	var title_key: String = "SKILL_NAME_" + skill_id.to_upper()
	var title_t: String = LocaleManager.t(title_key)
	var title: String = title_t if title_t != title_key else skill_id.capitalize().replace("_", " ")
	var dlg: GameDialog = GameDialog.create(title)
	parent.add_child(dlg)
	var body := dlg.body()
	if body == null:
		return
	var lbl := Label.new()
	lbl.text = desc
	lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(lbl)
