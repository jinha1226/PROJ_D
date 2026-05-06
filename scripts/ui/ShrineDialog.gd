class_name ShrineDialog extends RefCounted

# Class-weighted first essence pools (Essence path only). DCSS-aligned —
# fighter/conjurer/hunter are the basic starters; advanced classes get
# specialized pools or fall through to _FALLBACK_POOL.
const _FIRST_ESSENCE_POOLS: Dictionary = {
	"fighter":  ["essence_stone", "essence_vitality", "essence_fury"],
	"conjurer": ["essence_arcana", "essence_fire", "essence_cold"],
	"hunter":   ["essence_swiftness", "essence_venom", "essence_arcana"],
	"brigand":  ["essence_swiftness", "essence_venom", "essence_warding"],
	"archmage": ["essence_arcana", "essence_cold", "essence_warding"],
}
const _FALLBACK_POOL: Array = ["essence_vitality", "essence_swiftness", "essence_warding"]

const _CONFIRM_TEXT: Dictionary = {
	"war":      ["Swear yourself to War?",
				 "You will strike harder and stand firmer, but magic will come slower."],
	"arcana":   ["Devote yourself to Arcana?",
				 "Your spells will sharpen, but your body will not be spared."],
	"trickery": ["Follow Trickery?",
				 "You will thrive through timing, distance, and unfair fights."],
	"death":    ["Accept the mark of Death?",
				 "Your victories will feed you, but peace will not."],
	"essence":  ["Walk the path of Essence?",
				 "Forsake divine favor and bind yourself to monster remnants instead."],
}

## Called when player steps on or re-examines an altar tile.
## Shows faith description first; offers "Choose" only when altar is active and faith not yet chosen.
static func open_altar_info(faith_id: String, altar_active: bool, player: Player, parent: Node) -> void:
	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var fcolor: Color = faith.get("color", Color.WHITE)
	var already_chosen: bool = FaithSystem.has_chosen_faith(player)
	var current_faith: String = FaithSystem.current_faith_id(player) if already_chosen else ""

	var dlg: GameDialog = GameDialog.create_ratio(String(faith.get("name", faith_id)), 0.92, 0.88)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	# Altar icon row
	var icon_path: String = String(DungeonMap.ALTAR_TEXTURES.get(faith_id, ""))
	if icon_path != "" and ResourceLoader.exists(icon_path):
		var icon_tex: Texture2D = load(icon_path) as Texture2D
		if icon_tex != null:
			var icon_rect := TextureRect.new()
			icon_rect.texture = icon_tex
			icon_rect.custom_minimum_size = Vector2(48, 48)
			icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			icon_rect.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
			body.add_child(icon_rect)

	# Short description
	var short_lbl := Label.new()
	short_lbl.text = String(faith.get("short", ""))
	short_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	short_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	short_lbl.add_theme_color_override("font_color", Color(0.75, 0.78, 0.85))
	body.add_child(short_lbl)

	body.add_child(HSeparator.new())

	var lines: Array = _CONFIRM_TEXT.get(faith_id, ["", ""])
	var effect_lbl := Label.new()
	effect_lbl.text = String(lines[1]) if lines.size() > 1 else ""
	effect_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	effect_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	effect_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	body.add_child(effect_lbl)

	# Status / action area
	if already_chosen:
		var status_lbl := Label.new()
		if current_faith == faith_id:
			status_lbl.text = "You already follow this path."
			status_lbl.add_theme_color_override("font_color", fcolor)
		else:
			status_lbl.text = "You have already sworn to another path."
			status_lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.65))
		status_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		body.add_child(status_lbl)
	elif not altar_active:
		var guard_lbl := Label.new()
		guard_lbl.text = "The guardian still lives. Defeat it to unlock the altars."
		guard_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		guard_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		guard_lbl.add_theme_color_override("font_color", Color(0.8, 0.65, 0.35))
		body.add_child(guard_lbl)
	else:
		var choose_btn := Button.new()
		choose_btn.text = "Choose this path"
		choose_btn.custom_minimum_size = Vector2(0, 56)
		choose_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
		choose_btn.add_theme_color_override("font_color", fcolor)
		var fid: String = faith_id
		choose_btn.pressed.connect(func():
			dlg.close()
			_open_confirm(fid, player, parent, null))
		body.add_child(choose_btn)

## Called when player steps on a specific altar.
static func open_single(faith_id: String, player: Player, parent: Node) -> void:
	_open_confirm(faith_id, player, parent, null)

## Called after the first shrine boss event to choose among all paths.
static func open_choice(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Choose Your Path", 0.92, 0.90)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	var sub_lbl := Label.new()
	sub_lbl.text = "The first descent leaves a mark upon you. Choose the power that will shape the rest of this run."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	body.add_child(sub_lbl)
	body.add_child(HSeparator.new())

	var order: Array[String] = ["war", "arcana", "trickery", "death", FaithSystem.ESSENCE_FAITH_ID]
	for faith_id in order:
		body.add_child(_make_choice_card(faith_id, player, parent, dlg))

static func _make_choice_card(faith_id: String, player: Player, parent: Node, dlg: GameDialog) -> Control:
	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var fcolor: Color = faith.get("color", Color.WHITE)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 92)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GameTheme.PAD_L)
	margin.add_theme_constant_override("margin_right", GameTheme.PAD_L)
	margin.add_theme_constant_override("margin_top", GameTheme.PAD_M)
	margin.add_theme_constant_override("margin_bottom", GameTheme.PAD_M)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", GameTheme.PAD_L)
	margin.add_child(hb)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = String(faith.get("name", faith_id))
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	name_lbl.add_theme_color_override("font_color", fcolor)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = String(faith.get("short", ""))
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	vb.add_child(desc_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 52)
	btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	btn.add_theme_color_override("font_color", fcolor)
	btn.text = "Choose"
	var selected_faith: String = faith_id
	btn.pressed.connect(func():
		dlg.close()
		_open_confirm(selected_faith, player, parent, null))
	hb.add_child(btn)

	return panel



static func _open_confirm(faith_id: String, player: Player, parent: Node, dlg: GameDialog) -> void:
	var lines: Array = _CONFIRM_TEXT.get(faith_id, ["Choose this path?", ""])
	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var fcolor: Color = faith.get("color", Color.WHITE)

	var conf: GameDialog = GameDialog.create("Choose This Path?")
	parent.add_child(conf)
	var body: VBoxContainer = conf.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	var q_lbl := Label.new()
	q_lbl.text = String(lines[0])
	q_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	q_lbl.add_theme_color_override("font_color", fcolor)
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(q_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = String(lines[1]) if lines.size() > 1 else ""
	sub_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", GameTheme.PAD_L)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(160, 56)
	confirm_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	confirm_btn.add_theme_color_override("font_color", fcolor)
	var fid: String = faith_id
	confirm_btn.pressed.connect(func():
		conf.close()
		if dlg != null and is_instance_valid(dlg):
			dlg.close()
		_apply_faith(fid, player, parent))
	btn_row.add_child(confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 56)
	back_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	back_btn.pressed.connect(func(): conf.close())
	btn_row.add_child(back_btn)


static func _apply_faith(faith_id: String, player: Player, parent: Node) -> void:
	if not FaithSystem.choose_faith(player, faith_id):
		return
	CombatLog.post(LocaleManager.t("LOG_YOU_FOLLOW_THE_PATH_OF") % FaithSystem.display_name(faith_id),
		FaithSystem.color_of(faith_id))

	if faith_id == FaithSystem.ESSENCE_FAITH_ID:
		_open_first_essence_choice(player, parent)


static func _open_first_essence_choice(player: Player, parent: Node) -> void:
	var pool: Array = _first_essence_pool_for(player)

	var dlg: GameDialog = GameDialog.create_ratio("Bind Your First Essence", 0.92, 0.88)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	var sub_lbl := Label.new()
	sub_lbl.text = "Monster remnants answer your call. Choose what form your path will take."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	sub_lbl.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	body.add_child(sub_lbl)
	body.add_child(HSeparator.new())

	for eid in pool:
		body.add_child(_make_essence_card(eid, player, parent, dlg))


static func _make_essence_card(eid: String, player: Player, parent: Node, dlg: GameDialog) -> Control:
	var ecolor: Color = EssenceSystem.color_of(eid)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 90)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", GameTheme.PAD_L)
	margin.add_theme_constant_override("margin_right", GameTheme.PAD_L)
	margin.add_theme_constant_override("margin_top", GameTheme.PAD_M)
	margin.add_theme_constant_override("margin_bottom", GameTheme.PAD_M)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", GameTheme.PAD_L)
	margin.add_child(hb)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(40, 40)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	icon.texture = EssenceSystem.icon_texture_of(eid)
	hb.add_child(icon)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = EssenceSystem.display_name(eid)
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	name_lbl.add_theme_color_override("font_color", ecolor)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = EssenceSystem.description(eid)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	vb.add_child(desc_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 50)
	btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	btn.text = "Take"
	var essence_id: String = eid
	btn.pressed.connect(func():
		dlg.close()
		_grant_first_essence(essence_id, player))
	hb.add_child(btn)

	return panel


static func _grant_first_essence(eid: String, player: Player) -> void:
	var slot_count: int = EssenceSystem.active_slot_count(player)
	if slot_count > 0 and String(player.essence_slots[0]) == "":
		player.equip_essence(0, eid)
		CombatLog.post(LocaleManager.t("LOG_YOU_BIND_TO_YOUR_FIRST") % EssenceSystem.display_name(eid),
			EssenceSystem.color_of(eid))
	else:
		player.add_essence(eid)
		CombatLog.post(LocaleManager.t("LOG_YOU_HOLD_IN_RESERVE") % EssenceSystem.display_name(eid),
			EssenceSystem.color_of(eid))


static func _first_essence_pool_for(_player: Player) -> Array:
	var class_id: String = String(GameManager.selected_class_id) if GameManager != null else ""
	return _FIRST_ESSENCE_POOLS.get(class_id, _FALLBACK_POOL)
