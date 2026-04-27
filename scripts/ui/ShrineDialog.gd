class_name ShrineDialog extends RefCounted

# Class-weighted first essence pools (Essence path only)
const _FIRST_ESSENCE_POOLS: Dictionary = {
	"warrior":  ["essence_stone", "essence_vitality", "essence_fury"],
	"mage":     ["essence_arcana", "essence_fire", "essence_cold"],
	"rogue":    ["essence_swiftness", "essence_venom", "essence_warding"],
	"ranger":   ["essence_swiftness", "essence_venom", "essence_arcana"],
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

static func open(player: Player, parent: Node) -> void:
	CombatLog.post("A greater power stirs.", Color(0.9, 0.82, 0.55))
	CombatLog.post("The shrine awakens.", Color(0.85, 0.78, 0.5))

	var dlg: GameDialog = GameDialog.create_ratio("A Path Opens Before You", 0.92, 0.92)
	dlg.set_meta("shrine_blocker", true)
	parent.add_child(dlg)

	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	_build_faith_list(body, player, parent, dlg)


static func _build_faith_list(body: VBoxContainer, player: Player, parent: Node, dlg: GameDialog) -> void:
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 8)

	var intro := Label.new()
	intro.text = "Choose what kind of run this will become."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	intro.add_theme_font_size_override("font_size", 22)
	intro.add_theme_color_override("font_color", Color(0.68, 0.72, 0.78))
	body.add_child(intro)
	body.add_child(HSeparator.new())

	for faith_id in FaithSystem.FAITHS.keys():
		body.add_child(_make_faith_card(faith_id, player, parent, dlg))


static func _make_faith_card(faith_id: String, player: Player, parent: Node, dlg: GameDialog) -> Control:
	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var fcolor: Color = faith.get("color", Color.WHITE)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 110)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	margin.add_child(hb)

	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(6, 0)
	swatch.size_flags_vertical = Control.SIZE_EXPAND_FILL
	swatch.color = fcolor
	hb.add_child(swatch)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 2)
	hb.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = String(faith.get("name", faith_id))
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", fcolor)
	vb.add_child(name_lbl)

	var short_lbl := Label.new()
	short_lbl.text = String(faith.get("short", ""))
	short_lbl.add_theme_font_size_override("font_size", 19)
	short_lbl.add_theme_color_override("font_color", Color(0.78, 0.8, 0.88))
	vb.add_child(short_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = _build_hint(faith_id)
	hint_lbl.add_theme_font_size_override("font_size", 17)
	hint_lbl.add_theme_color_override("font_color", Color(0.55, 0.7, 0.55))
	vb.add_child(hint_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.text = "Choose"
	var fid: String = faith_id
	btn.pressed.connect(func(): _open_confirm(fid, player, parent, dlg))
	hb.add_child(btn)

	return panel


static func _build_hint(faith_id: String) -> String:
	match faith_id:
		"war":      return "Best for front-line melee and defense."
		"arcana":   return "Best for spellcasting and magical growth."
		"trickery": return "Best for agility, ranged utility, and ambushes."
		"death":    return "Best for kill-chains, sustain, and risky aggression."
		"essence":  return "Replaces divine favor with essence-based growth."
	return ""


static func _open_confirm(faith_id: String, player: Player, parent: Node, dlg: GameDialog) -> void:
	var lines: Array = _CONFIRM_TEXT.get(faith_id, ["Choose this path?", ""])
	var faith: Dictionary = FaithSystem.get_faith(faith_id)
	var fcolor: Color = faith.get("color", Color.WHITE)

	var conf: GameDialog = GameDialog.create("Choose This Path?")
	parent.add_child(conf)
	var body: VBoxContainer = conf.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 12)

	var q_lbl := Label.new()
	q_lbl.text = String(lines[0])
	q_lbl.add_theme_font_size_override("font_size", 28)
	q_lbl.add_theme_color_override("font_color", fcolor)
	q_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(q_lbl)

	var sub_lbl := Label.new()
	sub_lbl.text = String(lines[1]) if lines.size() > 1 else ""
	sub_lbl.add_theme_font_size_override("font_size", 22)
	sub_lbl.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(sub_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 12)
	btn_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(btn_row)

	var confirm_btn := Button.new()
	confirm_btn.text = "Confirm"
	confirm_btn.custom_minimum_size = Vector2(160, 56)
	confirm_btn.add_theme_font_size_override("font_size", 24)
	confirm_btn.add_theme_color_override("font_color", fcolor)
	var fid: String = faith_id
	confirm_btn.pressed.connect(func():
		conf.close()
		dlg.close()
		_apply_faith(fid, player, parent))
	btn_row.add_child(confirm_btn)

	var back_btn := Button.new()
	back_btn.text = "Back"
	back_btn.custom_minimum_size = Vector2(120, 56)
	back_btn.add_theme_font_size_override("font_size", 22)
	back_btn.pressed.connect(func(): conf.close())
	btn_row.add_child(back_btn)


static func _apply_faith(faith_id: String, player: Player, parent: Node) -> void:
	player.faith_id = faith_id
	player.first_shrine_choice_done = true

	var mp_bonus: int = FaithSystem.max_mp_bonus(player)
	if mp_bonus > 0:
		player.mp_max += mp_bonus
		player.mp = min(player.mp_max, player.mp + mp_bonus)
	if faith_id == "death":
		player.wl += 1

	CombatLog.post("You follow the path of %s." % FaithSystem.display_name(faith_id),
		FaithSystem.color_of(faith_id))

	if faith_id == "essence":
		_open_first_essence_choice(player, parent)


static func _open_first_essence_choice(player: Player, parent: Node) -> void:
	var pool: Array = _first_essence_pool_for(player)

	var dlg: GameDialog = GameDialog.create_ratio("Bind Your First Essence", 0.92, 0.88)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 10)

	var sub_lbl := Label.new()
	sub_lbl.text = "Monster remnants answer your call. Choose what form your path will take."
	sub_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub_lbl.add_theme_font_size_override("font_size", 20)
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
	margin.add_theme_constant_override("margin_left", 12)
	margin.add_theme_constant_override("margin_right", 12)
	margin.add_theme_constant_override("margin_top", 8)
	margin.add_theme_constant_override("margin_bottom", 8)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
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
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", ecolor)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = EssenceSystem.description(eid)
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 19)
	desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.75))
	vb.add_child(desc_lbl)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(100, 50)
	btn.add_theme_font_size_override("font_size", 22)
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
		CombatLog.post("You bind %s to your first essence slot." % EssenceSystem.display_name(eid),
			EssenceSystem.color_of(eid))
	else:
		player.add_essence_to_inventory(eid)
		CombatLog.post("You hold %s in reserve." % EssenceSystem.display_name(eid),
			EssenceSystem.color_of(eid))


static func _first_essence_pool_for(_player: Player) -> Array:
	var gm = Engine.get_main_loop().root.get_node_or_null("/root/GameManager")
	var class_id: String = String(gm.selected_class_id) if gm != null else ""
	return _FIRST_ESSENCE_POOLS.get(class_id, _FALLBACK_POOL)
