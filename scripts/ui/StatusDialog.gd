class_name StatusDialog extends RefCounted

## Full character sheet. Sections:
##   Header       — race / class / XL
##   Vitals       — HP / MP / XP progress
##   Stats        — STR / DEX / INT
##   Combat       — AC / EV / WL
##   Equipment    — all body slots
##   Resistances  — every element with +++/--- bar
##   Essence      — 3 equipped slots + inventory swap
##   Effects      — active statuses with turns remaining
##   Run          — depth / gold / kills / turns

const _ELEMENTS: Array = ["fire", "cold", "electric", "poison", "necromancy"]

const _EQUIP_SLOTS: Array = [
	["⚔ Weapon",  "weapon"],
	["🛡 Body",    "body"],
	["🪖 Head",    "head"],
	["🧥 Cloak",   "cloak"],
	["🧤 Gloves",  "gloves"],
	["👢 Boots",   "boots"],
	["📿 Amulet",  "amulet"],
	["💍 Ring L",  "ring_l"],
	["💍 Ring R",  "ring_r"],
]

const _HDR := 28  # section header font size

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
	body.add_child(UICards.section_header("STATS", _HDR))
	_build_stats(body, player)
	body.add_child(UICards.section_header("COMBAT", _HDR))
	_build_combat(body, player)
	body.add_child(UICards.section_header("EQUIPMENT", _HDR))
	_build_equipment(body, player)
	body.add_child(UICards.section_header("RESISTANCES", _HDR))
	_build_resists(body, player)
	body.add_child(UICards.section_header("ESSENCE", _HDR))
	_build_essence(body, player)
	if not player.statuses.is_empty():
		body.add_child(UICards.section_header("ACTIVE EFFECTS", _HDR))
		_build_effects(body, player)
	body.add_child(UICards.section_header("RUN", _HDR))
	_build_meta(body, player)

static func _build_header(body: VBoxContainer, player: Player) -> void:
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	var job: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 12)
	body.add_child(hb)
	var portrait := Control.new()
	portrait.custom_minimum_size = Vector2(120, 130)
	portrait.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var base_path: String = "res://assets/tiles/individual/player/base/human_m.png"
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
	var w_plus: int = int(player.equipped_weapon_entry().get("plus", 0)) if w != null else 0
	var a_plus: int = int(player.equipped_armor_entry().get("plus", 0)) if a != null else 0

	for slot_entry in _EQUIP_SLOTS:
		var label: String = slot_entry[0]
		var slot_id: String = slot_entry[1]
		var value: String = "—"
		var tint: Color = Color(0.45, 0.45, 0.5)
		match slot_id:
			"weapon":
				if w != null:
					value = "%s%s (d%d)" % [w.display_name,
							" +%d" % w_plus if w_plus > 0 else "",
							w.damage + w_plus]
					tint = Color(1.0, 0.75, 0.4)
				else:
					value = "(unarmed)"
					tint = Color(0.6, 0.6, 0.65)
			"body":
				if a != null:
					value = "%s%s (+%d AC" % [a.display_name,
							" +%d" % a_plus if a_plus > 0 else "",
							a.ac_bonus + a_plus]
					if a.ev_penalty > 0:
						value += ", -%d EV" % a.ev_penalty
					value += ")"
					tint = Color(0.55, 0.8, 1.0)
		body.add_child(_kv_row(label, value, tint))

static func _build_resists(body: VBoxContainer, player: Player) -> void:
	for elem in _ELEMENTS:
		var lvl: int = Status.resist_level(player.resists, elem)
		body.add_child(_resist_row(elem, lvl))

static func _build_essence(body: VBoxContainer, player: Player) -> void:
	for i in range(EssenceSystem.SLOT_COUNT):
		var slot_id: String = String(player.essence_slots[i]) if i < player.essence_slots.size() else ""
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)

		var slot_lbl := Label.new()
		slot_lbl.text = "Slot %d" % (i + 1)
		slot_lbl.custom_minimum_size = Vector2(60, 0)
		slot_lbl.add_theme_font_size_override("font_size", 20)
		slot_lbl.add_theme_color_override("font_color", Color(0.55, 0.6, 0.65))
		slot_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(slot_lbl)

		var name_lbl := Label.new()
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_lbl.add_theme_font_size_override("font_size", 24)
		if slot_id != "":
			name_lbl.text = EssenceSystem.display_name(slot_id)
			name_lbl.add_theme_color_override("font_color", EssenceSystem.color_of(slot_id))
		else:
			name_lbl.text = "(empty)"
			name_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.5))
		row.add_child(name_lbl)

		var swap_btn := Button.new()
		swap_btn.text = "Swap"
		swap_btn.custom_minimum_size = Vector2(90, 44)
		swap_btn.add_theme_font_size_override("font_size", 20)
		var slot_idx := i
		swap_btn.pressed.connect(func(): _open_essence_swap(slot_idx, player, body))
		row.add_child(swap_btn)
		body.add_child(row)

	if player.essence_inventory.is_empty():
		var inv_lbl := Label.new()
		inv_lbl.text = "Inventory: (none)"
		inv_lbl.add_theme_font_size_override("font_size", 20)
		inv_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		body.add_child(inv_lbl)
	else:
		var names: Array = player.essence_inventory.map(
			func(id): return EssenceSystem.display_name(id))
		var inv_lbl := Label.new()
		inv_lbl.text = "Inventory: " + ", ".join(names)
		inv_lbl.add_theme_font_size_override("font_size", 20)
		inv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		inv_lbl.add_theme_color_override("font_color", Color(0.7, 0.75, 0.8))
		body.add_child(inv_lbl)


static func _open_essence_swap(slot: int, player: Player, body: VBoxContainer) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Swap Essence Slot %d" % (slot + 1), 0.75, 0.85)
	body.get_tree().current_scene.add_child(dlg)
	var swap_body: VBoxContainer = dlg.body()
	if swap_body == null:
		return

	var cur_id: String = String(player.essence_slots[slot]) if slot < player.essence_slots.size() else ""

	var cur_lbl := Label.new()
	cur_lbl.add_theme_font_size_override("font_size", 22)
	cur_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	if cur_id != "":
		cur_lbl.text = "Equipped: %s" % EssenceSystem.display_name(cur_id)
	else:
		cur_lbl.text = "Slot is empty"
	swap_body.add_child(cur_lbl)
	swap_body.add_child(HSeparator.new())

	for ess_id in player.essence_inventory:
		var btn := Button.new()
		btn.text = "%s\n%s" % [EssenceSystem.display_name(ess_id), EssenceSystem.description(ess_id)]
		btn.custom_minimum_size = Vector2(0, 64)
		btn.add_theme_font_size_override("font_size", 20)
		var eid: String = ess_id
		btn.pressed.connect(func():
			player.equip_essence(slot, eid)
			dlg.close())
		swap_body.add_child(btn)

	if cur_id != "":
		var clear_btn := Button.new()
		clear_btn.text = "[Remove essence]"
		clear_btn.add_theme_font_size_override("font_size", 20)
		clear_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
		clear_btn.pressed.connect(func():
			player.equip_essence(slot, "")
			dlg.close())
		swap_body.add_child(clear_btn)

	if player.essence_inventory.is_empty() and cur_id == "":
		var empty_lbl := Label.new()
		empty_lbl.text = "No essences in inventory."
		empty_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		swap_body.add_child(empty_lbl)

static func _build_effects(body: VBoxContainer, player: Player) -> void:
	for id in player.statuses.keys():
		var turns: int = int(player.statuses[id])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var name_lab := Label.new()
		name_lab.text = Status.display_name(id)
		name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lab.add_theme_font_size_override("font_size", 22)
		name_lab.add_theme_color_override("font_color", Status.color_of(id))
		row.add_child(name_lab)
		var turns_lab := Label.new()
		turns_lab.text = "%d turns" % turns
		turns_lab.add_theme_font_size_override("font_size", 20)
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
	k.add_theme_font_size_override("font_size", 20)
	k.add_theme_color_override("font_color", Color(0.7, 0.72, 0.78))
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_theme_font_size_override("font_size", 22)
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
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.72))
	vb.add_child(lbl)
	var val := Label.new()
	val.text = str(value)
	val.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	val.add_theme_font_size_override("font_size", 30)
	val.add_theme_color_override("font_color", tint)
	vb.add_child(val)
	return vb

static func _resist_row(element: String, level: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var name_lbl := Label.new()
	name_lbl.text = element.capitalize()
	name_lbl.custom_minimum_size = Vector2(130, 0)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", _element_color(element))
	row.add_child(name_lbl)
	var bar_lbl := Label.new()
	bar_lbl.text = _resist_bar(level)
	bar_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar_lbl.add_theme_font_size_override("font_size", 22)
	var tint: Color
	if level > 0:
		tint = Color(0.4, 0.95, 0.5)
	elif level < 0:
		tint = Color(1.0, 0.4, 0.4)
	else:
		tint = Color(0.45, 0.45, 0.5)
	bar_lbl.add_theme_color_override("font_color", tint)
	row.add_child(bar_lbl)
	return row

static func _resist_bar(level: int) -> String:
	if level >= 3:  return "+++"
	if level == 2:  return "++"
	if level == 1:  return "+"
	if level == 0:  return "·"
	if level == -1: return "-"
	if level == -2: return "--"
	return "---"

static func _element_color(element: String) -> Color:
	match element:
		"fire":       return Color(1.0, 0.55, 0.3)
		"cold":       return Color(0.55, 0.85, 1.0)
		"electric":   return Color(1.0, 0.95, 0.45)
		"poison":     return Color(0.5, 1.0, 0.5)
		"necromancy": return Color(0.75, 0.55, 0.9)
	return Color(0.8, 0.8, 0.85)
