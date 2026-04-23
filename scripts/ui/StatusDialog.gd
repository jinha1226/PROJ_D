class_name StatusDialog extends RefCounted

## Full character sheet. Sections (per clean-room guide §6):
##   Header       — race / class / XL
##   Vitals       — HP / MP / XP progress
##   Stats        — STR / DEX / INT
##   Combat       — AC / EV / WL
##   Equipment    — weapon / armor summary
##   Resistances  — per-element level with +/- bar
##   Effects      — active statuses with turns remaining
##   Meta         — depth / gold / kills / turns

const _ELEMENTS: Array = ["fire", "cold", "electric", "poison", "necromancy"]

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Character")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	_build_header(body, player)
	body.add_child(HSeparator.new())
	_build_vitals(body, player)
	body.add_child(UICards.section_header("STATS"))
	_build_stats(body, player)
	body.add_child(UICards.section_header("COMBAT"))
	_build_combat(body, player)
	body.add_child(UICards.section_header("EQUIPMENT"))
	_build_equipment(body, player)
	body.add_child(UICards.section_header("RESISTANCES"))
	_build_resists(body, player)
	if not player.statuses.is_empty():
		body.add_child(UICards.section_header("ACTIVE EFFECTS"))
		_build_effects(body, player)
	body.add_child(UICards.section_header("RUN"))
	_build_meta(body, player)

static func _build_header(body: VBoxContainer, player: Player) -> void:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	var job: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	body.add_child(hb)
	# Paper-doll composite: race base + current body armor + hand1 weapon.
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(120, 130)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var base_path: String = \
		"res://assets/tiles/individual/player/base/human_m.png"
	if race != null and race.base_sprite_path != "" \
			and ResourceLoader.exists(race.base_sprite_path):
		base_path = race.base_sprite_path
	_add_portrait_layer(portrait, base_path)
	if player.equipped_armor_id != "" \
			and Player.DOLL_BODY_MAP.has(player.equipped_armor_id):
		_add_portrait_layer(portrait,
			String(Player.DOLL_BODY_MAP[player.equipped_armor_id]))
	if player.equipped_weapon_id != "" \
			and Player.DOLL_HAND1_MAP.has(player.equipped_weapon_id):
		_add_portrait_layer(portrait,
			String(Player.DOLL_HAND1_MAP[player.equipped_weapon_id]))
	hb.add_child(portrait)
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hb.add_child(vb)
	var title := Label.new()
	title.text = "%s %s" % [
			race.display_name if race != null else "?",
			job.display_name if job != null else "?"]
	title.add_theme_font_size_override("font_size", 34)
	title.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5, 1))
	vb.add_child(title)
	var sub := Label.new()
	sub.text = "Level %d  (%d / %d XP)" % [player.xl, player.xp,
			player.xp_to_next()]
	sub.add_theme_font_size_override("font_size", 22)
	vb.add_child(sub)

static func _build_vitals(body: VBoxContainer, player: Player) -> void:
	body.add_child(_kv_row("HP", "%d / %d" % [player.hp, player.hp_max],
		Color(1.0, 0.55, 0.55)))
	body.add_child(_kv_row("MP", "%d / %d" % [player.mp, player.mp_max],
		Color(0.55, 0.7, 1.0)))

static func _build_stats(body: VBoxContainer, player: Player) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_stat_block("STR", player.strength, Color(1.0, 0.7, 0.4)))
	row.add_child(_stat_block("DEX", player.dexterity, Color(0.5, 1.0, 0.6)))
	row.add_child(_stat_block("INT", player.intelligence, Color(0.6, 0.8, 1.0)))
	body.add_child(row)

static func _build_combat(body: VBoxContainer, player: Player) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.add_child(_stat_block("AC", player.ac, Color(0.85, 0.85, 0.9)))
	row.add_child(_stat_block("EV", player.ev, Color(0.7, 1.0, 0.7)))
	row.add_child(_stat_block("WL", player.wl, Color(0.85, 0.7, 1.0)))
	body.add_child(row)

static func _build_equipment(body: VBoxContainer, player: Player) -> void:
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	var a: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
	var w_plus: int = int(player.equipped_weapon_entry().get("plus", 0)) \
			if w != null else 0
	var a_plus: int = int(player.equipped_armor_entry().get("plus", 0)) \
			if a != null else 0
	var w_text: String = "(unarmed)"
	if w != null:
		w_text = "%s %s(d%d)" % [w.display_name,
				("+%d " % w_plus) if w_plus > 0 else "",
				w.damage + w_plus]
	var a_text: String = "(none)"
	if a != null:
		a_text = "%s %s(+%d AC" % [a.display_name,
				("+%d " % a_plus) if a_plus > 0 else "",
				a.ac_bonus + a_plus]
		if a.ev_penalty > 0:
			a_text += ", -%d EV" % a.ev_penalty
		a_text += ")"
	body.add_child(_kv_row("⚔ Weapon", w_text, Color(1.0, 0.75, 0.4)))
	body.add_child(_kv_row("🛡 Armor", a_text, Color(0.55, 0.8, 1.0)))

static func _build_resists(body: VBoxContainer, player: Player) -> void:
	var any: bool = false
	for elem in _ELEMENTS:
		var lvl: int = Status.resist_level(player.resists, elem)
		if lvl == 0:
			continue
		any = true
		body.add_child(_resist_row(elem, lvl))
	if not any:
		var lab := Label.new()
		lab.text = "(no resistances)"
		lab.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		body.add_child(lab)

static func _build_effects(body: VBoxContainer, player: Player) -> void:
	for id in player.statuses.keys():
		var turns: int = int(player.statuses[id])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lab := Label.new()
		name_lab.text = Status.display_name(id)
		name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lab.add_theme_font_size_override("font_size", 24)
		name_lab.add_theme_color_override("font_color", Status.color_of(id))
		row.add_child(name_lab)
		var turns_lab := Label.new()
		turns_lab.text = "%d turns" % turns
		turns_lab.add_theme_font_size_override("font_size", 22)
		turns_lab.add_theme_color_override("font_color", Color(0.75, 0.75, 0.8))
		row.add_child(turns_lab)
		body.add_child(row)

static func _build_meta(body: VBoxContainer, player: Player) -> void:
	body.add_child(_kv_row("Depth", "B%d" % GameManager.depth,
		Color(0.7, 0.95, 0.9)))
	body.add_child(_kv_row("Gold", "%d" % player.gold,
		Color(1.0, 0.88, 0.3)))
	body.add_child(_kv_row("Kills", "%d" % player.kills,
		Color(0.85, 0.65, 0.45)))
	body.add_child(_kv_row("Turn", "%d" % TurnManager.turn_number,
		Color(0.65, 0.75, 0.65)))

static func _add_portrait_layer(parent: Control, path: String) -> void:
	if not ResourceLoader.exists(path):
		return
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(rect)

# ── Helpers ───────────────────────────────────────────────────────────────
static func _kv_row(key: String, value: String, tint: Color) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(130, 0)
	k.add_theme_font_size_override("font_size", 22)
	k.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_font_size_override("font_size", 24)
	v.add_theme_color_override("font_color", tint)
	row.add_child(v)
	return row

static func _stat_block(label: String, value: int, tint: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.alignment = BoxContainer.ALIGNMENT_CENTER
	var lbl := Label.new()
	lbl.text = label
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	vb.add_child(lbl)
	var val := Label.new()
	val.text = str(value)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 34)
	val.add_theme_color_override("font_color", tint)
	vb.add_child(val)
	return vb

static func _resist_row(element: String, level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name := Label.new()
	name.text = element.capitalize()
	name.custom_minimum_size = Vector2(150, 0)
	name.add_theme_font_size_override("font_size", 24)
	name.add_theme_color_override("font_color", _element_color(element))
	row.add_child(name)
	var bar := Label.new()
	bar.text = _resist_bar(level)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_font_size_override("font_size", 24)
	var tint: Color = Color(0.55, 0.9, 0.55) if level > 0 \
			else Color(1.0, 0.55, 0.55)
	bar.add_theme_color_override("font_color", tint)
	row.add_child(bar)
	return row

static func _resist_bar(level: int) -> String:
	# Visual: "+++  " for +3, "-    " for -1, blank at 0.
	if level > 0:
		return "+".repeat(level) + " (" + str(level) + ")"
	if level < 0:
		return "-".repeat(-level) + " (" + str(level) + ")"
	return "—"

static func _element_color(element: String) -> Color:
	match element:
		"fire":       return Color(1.0, 0.55, 0.3)
		"cold":       return Color(0.55, 0.85, 1.0)
		"electric":   return Color(1.0, 0.95, 0.45)
		"poison":     return Color(0.5, 1.0, 0.5)
		"necromancy": return Color(0.75, 0.55, 0.9)
	return Color(0.8, 0.8, 0.85)
