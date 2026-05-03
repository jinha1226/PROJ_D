class_name StatusDialog extends RefCounted

const _VISIBLE_EQUIP_SLOTS: Array = [
	["Weapon", "weapon"],
	["Armor", "body"],
	["Shield", "shield"],
	["Ring", "ring"],
	["Amulet", "amulet"],
]

const _RESIST_ELEMENTS: Array = ["fire", "cold", "poison", "necro"]
const _RESIST_LABELS: Dictionary = {
	"fire": "Fire",
	"cold": "Cold",
	"poison": "Poison",
	"necro": "Necro",
}

static var GameManager = Engine.get_main_loop().root.get_node_or_null("/root/GameManager") if Engine.get_main_loop() is SceneTree else null
static var ItemRegistry = Engine.get_main_loop().root.get_node_or_null("/root/ItemRegistry") if Engine.get_main_loop() is SceneTree else null

static func open(player: Player, parent: Node) -> void:
	if player == null or parent == null:
		return
	var dlg: GameDialog = GameDialog.create_ratio("Status", 0.94, 0.94)
	parent.add_child(dlg)
	_rebuild_body(dlg, player, parent)

static func _rebuild_body(dlg: GameDialog, player: Player, parent: Node) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 12)

	body.add_child(_header_card(player))
	body.add_child(_vitals_card(player))
	body.add_child(_faith_card(player))
	body.add_child(_stats_card(player))
	body.add_child(_combat_card(player))
	body.add_child(_equipment_card(player))
	body.add_child(_resists_card(player))
	body.add_child(_essence_card(dlg, player, parent))
	body.add_child(_effects_card(player))
	body.add_child(_run_card(player))

static func _header_card(player: Player) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var portrait_card := UICards.card(Color(0.9, 0.8, 0.45))
	portrait_card.custom_minimum_size = Vector2(140, 140)
	row.add_child(portrait_card)
	portrait_card.add_child(_portrait_stack(player))

	var info_card := UICards.card(Color(0.55, 0.72, 1.0))
	info_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	info_card.add_child(vb)

	var class_id: String = GameManager.selected_class_id if GameManager != null else ""
	var race_id: String = GameManager.selected_race_id if GameManager != null else ""
	var class_data: ClassData = ClassRegistry.get_by_id(class_id) if ClassRegistry != null and class_id != "" else null
	var race_data: RaceData = RaceRegistry.get_by_id(race_id) if race_id != "" else null
	var cls_name := class_data.display_name if class_data != null else class_id.capitalize()
	var race_name := race_data.display_name if race_data != null else race_id.capitalize()

	var title := Label.new()
	title.text = "%s %s" % [race_name, cls_name]
	title.add_theme_font_size_override("font_size", 32)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "XL %d   XP %d / %d" % [player.xl, player.xp, player.xp_to_next()]
	sub.add_theme_font_size_override("font_size", 20)
	sub.add_theme_color_override("font_color", Color(0.7, 0.74, 0.84))
	vb.add_child(sub)

	var tip := Label.new()
	tip.text = "A compact summary of your build, defenses, faith, and active essence path."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", 18)
	tip.add_theme_color_override("font_color", Color(0.76, 0.76, 0.82))
	vb.add_child(tip)

	return row

static func _vitals_card(player: Player) -> Control:
	var card := UICards.card(Color(0.75, 0.3, 0.3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Vitals", 28))

	vb.add_child(_resource_bar("HP", player.hp, player.hp_max, Color(0.85, 0.28, 0.28)))
	vb.add_child(_resource_bar("MP", player.mp, player.mp_max, Color(0.35, 0.55, 1.0)))

	var hint := Label.new()
	hint.text = "Max HP rises from level growth, race, endurance, and gear. Max MP rises from magic growth and intellect."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	vb.add_child(hint)
	return card

static func _faith_card(player: Player) -> Control:
	var faith_id := FaithSystem.current_faith_id(player)
	var tint := FaithSystem.color_of(faith_id) if faith_id != "" else Color(0.6, 0.6, 0.7)
	var card := UICards.card(tint)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Faith", 28))

	var faith_name := "None"
	var faith_desc := "No path chosen yet."
	if faith_id != "":
		var info: Dictionary = FaithSystem.get_faith(faith_id)
		faith_name = String(info.get("name", faith_id.capitalize()))
		faith_desc = String(info.get("short", String(info.get("desc", ""))))

	var name_lbl := Label.new()
	name_lbl.text = faith_name
	name_lbl.add_theme_font_size_override("font_size", 30)
	name_lbl.add_theme_color_override("font_color", tint)
	vb.add_child(name_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = faith_desc
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 20)
	desc_lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	vb.add_child(desc_lbl)

	var mode_lbl := Label.new()
	mode_lbl.text = "Essences: enabled" if FaithSystem.allows_essence(player) else "Essences: disabled by current faith"
	mode_lbl.add_theme_font_size_override("font_size", 18)
	mode_lbl.add_theme_color_override("font_color", Color(0.8, 0.85, 0.92) if FaithSystem.allows_essence(player) else Color(0.72, 0.62, 0.62))
	vb.add_child(mode_lbl)
	return card

static func _stats_card(player: Player) -> Control:
	var card := UICards.card(Color(0.45, 0.85, 0.55))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Stats", 28))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 10)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)

	grid.add_child(_stat_block("STR", player.strength, "Melee power and carrying brute force."))
	grid.add_child(_stat_block("DEX", player.dexterity, "Accuracy, evasion, and agile fighting."))
	grid.add_child(_stat_block("INT", player.intelligence, "Spell study, power, and magical growth."))
	return card

static func _combat_card(player: Player) -> Control:
	var card := UICards.card(Color(0.9, 0.55, 0.25))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Combat", 28))

	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", 16)
	row.add_theme_constant_override("v_separation", 6)
	vb.add_child(row)

	row.add_child(_kv_row("AC", str(player.ac)))
	row.add_child(_kv_row("EV", str(player.ev)))
	row.add_child(_kv_row("Will", str(player.wl)))
	row.add_child(_kv_row("Sight", str(Player.SIGHT_RADIUS + player.fov_radius_bonus)))
	row.add_child(_kv_row("Endurance", str(player.get_skill_level("endurance"))))
	row.add_child(_kv_row("Spellcasting", str(player.get_skill_level("spellcasting"))))

	var notes := Label.new()
	notes.text = "Armor reduces gear penalties, Shield improves blocking, Agility improves evasion, and Endurance grows your maximum HP."
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.add_theme_font_size_override("font_size", 18)
	notes.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	vb.add_child(notes)
	return card

static func _equipment_card(player: Player) -> Control:
	var card := UICards.card(Color(0.7, 0.7, 0.82))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Equipment", 28))

	for pair in _VISIBLE_EQUIP_SLOTS:
		var label: String = String(pair[0])
		var slot: String = String(pair[1])
		vb.add_child(_equipment_row(label, slot, player))
	return card

static func _resists_card(player: Player) -> Control:
	var card := UICards.card(Color(0.45, 0.8, 0.95))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Resistances", 28))

	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", 8)
	flow.add_theme_constant_override("v_separation", 8)
	vb.add_child(flow)

	for element in _RESIST_ELEMENTS:
		flow.add_child(_resist_card(element, Status.resist_level(player.resists, element)))
	return card

static func _essence_card(dlg: GameDialog, player: Player, parent: Node) -> Control:
	var enabled: bool = FaithSystem.allows_essence(player)
	var tint := Color(0.8, 0.7, 1.0) if enabled else Color(0.5, 0.5, 0.58)
	var card := UICards.card(tint)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Essence", 28))

	var cap: int = EssenceSystem.inventory_capacity(player)
	var slots_open: int = EssenceSystem.active_slot_count(player)

	var summary := Label.new()
	summary.text = "Slots open: %d / %d   Carried: %d / %d" % [slots_open, EssenceSystem.SLOT_COUNT, player.essence_inventory.size(), cap]
	summary.add_theme_font_size_override("font_size", 20)
	summary.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	vb.add_child(summary)

	if not enabled:
		var disabled := Label.new()
		disabled.text = "Your current faith does not allow essence attunement."
		disabled.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		disabled.add_theme_font_size_override("font_size", 18)
		disabled.add_theme_color_override("font_color", Color(0.88, 0.7, 0.7))
		vb.add_child(disabled)
		return card

	for i in range(EssenceSystem.SLOT_COUNT):
		vb.add_child(_essence_slot_row(dlg, player, parent, i))

	var inv_header := Label.new()
	inv_header.text = "Carried Essences"
	inv_header.add_theme_font_size_override("font_size", 22)
	inv_header.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
	vb.add_child(inv_header)

	if player.essence_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No spare essences carried."
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
		vb.add_child(empty)
	else:
		for eid in player.essence_inventory:
			vb.add_child(_essence_inventory_row(String(eid)))

	var synergies: Array = EssenceSystem.active_synergies(player)
	if not synergies.is_empty():
		var sync_header := Label.new()
		sync_header.text = "Active Resonance"
		sync_header.add_theme_font_size_override("font_size", 22)
		sync_header.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
		vb.add_child(sync_header)
		for line in synergies:
			var lbl := Label.new()
			lbl.text = "- %s" % String(line)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", 18)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.92))
			vb.add_child(lbl)

	return card

static func _effects_card(player: Player) -> Control:
	var card := UICards.card(Color(0.7, 0.5, 0.95))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Effects", 28))

	if player.statuses.is_empty():
		var none := Label.new()
		none.text = "No active statuses."
		none.add_theme_font_size_override("font_size", 18)
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		vb.add_child(none)
		return card

	for id in player.statuses.keys():
		var turns: int = int(player.statuses.get(id, 0))
		var line := Label.new()
		line.text = "%s (%d)" % [Status.display_name(String(id)), turns]
		line.add_theme_font_size_override("font_size", 18)
		line.add_theme_color_override("font_color", Status.color_of(String(id)))
		vb.add_child(line)
	return card

static func _run_card(player: Player) -> Control:
	var card := UICards.card(Color(0.6, 0.65, 0.75))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Run", 28))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 6)
	vb.add_child(grid)

	var depth_text := str(GameManager.depth) if GameManager != null else "?"
	grid.add_child(_kv_row("Depth", depth_text))
	grid.add_child(_kv_row("Gold", str(player.gold)))
	grid.add_child(_kv_row("Kills", str(player.kills)))
	grid.add_child(_kv_row("Items", str(player.items_collected)))

	# Rune section
	var collected_runes: Array = []
	for entry in player.items:
		var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
		if d != null and d.kind == "rune":
			collected_runes.append(d.display_name)

	vb.add_child(UICards.section_header("Runes  %d / 4" % collected_runes.size(), 24))
	if collected_runes.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "(none collected)"
		none_lbl.add_theme_font_size_override("font_size", 20)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		vb.add_child(none_lbl)
	else:
		for rname in collected_runes:
			var r_lbl := Label.new()
			r_lbl.text = "✦ %s" % rname
			r_lbl.add_theme_font_size_override("font_size", 22)
			r_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
			vb.add_child(r_lbl)

	return card

static func _portrait_stack(player: Player) -> Control:
	var panel := CenterContainer.new()
	panel.custom_minimum_size = Vector2(120, 120)
	var layers := Control.new()
	layers.custom_minimum_size = Vector2(96, 96)
	panel.add_child(layers)
	_add_portrait_layer(layers, player._base_tex)
	_add_portrait_layer(layers, player._body_doll_tex)
	_add_portrait_layer(layers, player._hand1_doll_tex)
	_add_portrait_layer(layers, player._hand2_doll_tex)
	return panel

static func _add_portrait_layer(parent: Control, tex: Texture2D) -> void:
	if parent == null or tex == null:
		return
	var rect := TextureRect.new()
	rect.texture = tex
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(96, 96)
	parent.add_child(rect)

static func _resource_bar(label_text: String, value: int, max_value: int, tint: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	vb.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", 22)
	row.add_child(label)

	var num := Label.new()
	num.text = "%d / %d" % [value, max_value]
	num.add_theme_font_size_override("font_size", 22)
	num.add_theme_color_override("font_color", tint)
	row.add_child(num)

	var bar := ProgressBar.new()
	bar.max_value = max(1, max_value)
	bar.value = clampi(value, 0, max(1, max_value))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_color_override("font_color", tint)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	return vb

static func _stat_block(label_text: String, value: int, help: String) -> Control:
	var card := UICards.card(Color(0.45, 0.75, 0.48))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 4)
	card.add_child(vb)

	var name := Label.new()
	name.text = label_text
	name.add_theme_font_size_override("font_size", 22)
	name.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
	vb.add_child(name)

	var val := Label.new()
	val.text = str(value)
	val.add_theme_font_size_override("font_size", 28)
	val.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(val)

	var desc := Label.new()
	desc.text = help
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 16)
	desc.add_theme_color_override("font_color", Color(0.72, 0.75, 0.8))
	vb.add_child(desc)
	return card

static func _kv_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var label := Label.new()
	label.text = "%s:" % label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	row.add_child(value)
	return row

static func _equipment_row(label_text: String, slot: String, player: Player) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var item_id := _equip_id(slot, player)
	var entry := _equip_entry(item_id, player)
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null and item_id != "" else null
	var name_text := "(empty)"
	if data != null:
		name_text = data.display_name
		var plus_val: int = int(entry.get("plus", 0))
		if plus_val != 0:
			name_text += " %+d" % plus_val

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	row.add_child(top)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.add_theme_font_size_override("font_size", 20)
	label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	top.add_child(label)

	var value := Label.new()
	value.text = name_text
	value.add_theme_font_size_override("font_size", 20)
	value.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6) if data != null else Color(0.6, 0.6, 0.68))
	top.add_child(value)

	if data != null and data.description != "":
		var desc := Label.new()
		desc.text = data.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
		row.add_child(desc)
	return row

static func _resist_card(element: String, level: int) -> Control:
	var tint := _element_color(element)
	var card := UICards.card(tint)
	card.custom_minimum_size = Vector2(132, 72)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	var title := Label.new()
	title.text = String(_RESIST_LABELS.get(element, element.capitalize()))
	title.add_theme_font_size_override("font_size", 18)
	title.add_theme_color_override("font_color", tint)
	vb.add_child(title)

	var value := Label.new()
	value.text = _resist_bar(level)
	value.add_theme_font_size_override("font_size", 24)
	value.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vb.add_child(value)
	return card

static func _resist_bar(level: int) -> String:
	if level > 0:
		return "+".repeat(level)
	if level < 0:
		return "-".repeat(abs(level))
	return "0"

static func _element_color(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.48, 0.24)
		"cold":
			return Color(0.5, 0.82, 1.0)
		"poison":
			return Color(0.45, 0.95, 0.45)
		"necro":
			return Color(0.72, 0.48, 0.95)
	return Color(0.82, 0.82, 0.88)

static func _essence_slot_row(dlg: GameDialog, player: Player, parent: Node, slot_index: int) -> Control:
	var unlocked := EssenceSystem.slot_is_unlocked(player, slot_index)
	var current_id := String(player.essence_slots[slot_index])
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 4)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 10)
	row.add_child(top)

	var title := Label.new()
	title.text = "Slot %d" % (slot_index + 1)
	title.add_theme_font_size_override("font_size", 20)
	title.add_theme_color_override("font_color", Color(0.9, 0.86, 0.65))
	top.add_child(title)

	if not unlocked:
		var locked := Label.new()
		locked.text = "(locked)"
		locked.add_theme_font_size_override("font_size", 18)
		locked.add_theme_color_override("font_color", Color(0.76, 0.55, 0.55))
		top.add_child(locked)
		return row

	if current_id != "":
		var icon := TextureRect.new()
		icon.texture = EssenceSystem.icon_texture_of(current_id)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)

	var name := Label.new()
	name.text = EssenceSystem.display_name(current_id) if current_id != "" else "(empty)"
	name.add_theme_font_size_override("font_size", 20)
	name.add_theme_color_override("font_color", EssenceSystem.color_of(current_id) if current_id != "" else Color(0.62, 0.62, 0.68))
	top.add_child(name)

	var action := Button.new()
	action.text = "Swap"
	action.custom_minimum_size = Vector2(0, 36)
	action.pressed.connect(func():
		_open_essence_slot_picker(dlg, player, parent, slot_index))
	top.add_child(action)

	if current_id != "":
		var desc := Label.new()
		desc.text = EssenceSystem.description(current_id)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 16)
		desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.8))
		row.add_child(desc)
	return row

static func _essence_inventory_row(essence_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	var icon := TextureRect.new()
	icon.texture = EssenceSystem.icon_texture_of(essence_id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s - %s" % [EssenceSystem.display_name(essence_id), EssenceSystem.description(essence_id)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 18)
	label.add_theme_color_override("font_color", EssenceSystem.color_of(essence_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

static func _open_essence_slot_picker(dlg: GameDialog, player: Player, parent: Node, slot_index: int) -> void:
	var picker := GameDialog.create_ratio("Essence Slot %d" % (slot_index + 1), 0.82, 0.72)
	parent.add_child(picker)
	var body := picker.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 10)

	var current_id := String(player.essence_slots[slot_index])
	var current := Label.new()
	current.text = "Current: %s" % (EssenceSystem.display_name(current_id) if current_id != "" else "(empty)")
	current.add_theme_font_size_override("font_size", 22)
	body.add_child(current)

	if player.essence_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No carried essences available."
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		body.add_child(empty)
	else:
		for eid in player.essence_inventory:
			var essence_id := String(eid)
			var btn := Button.new()
			btn.text = EssenceSystem.display_name(essence_id)
			btn.icon = EssenceSystem.icon_texture_of(essence_id)
			btn.custom_minimum_size = Vector2(0, 54)
			btn.pressed.connect(func():
				player.equip_essence(slot_index, essence_id)
				picker.close()
				_rebuild_body(dlg, player, parent))
			body.add_child(btn)

	if current_id != "":
		var clear_btn := Button.new()
		clear_btn.text = "Unequip"
		clear_btn.custom_minimum_size = Vector2(0, 48)
		clear_btn.pressed.connect(func():
			player.equip_essence(slot_index, "")
			picker.close()
			_rebuild_body(dlg, player, parent))
		body.add_child(clear_btn)

static func _equip_id(slot: String, player: Player) -> String:
	match slot:
		"weapon":
			return player.equipped_weapon_id
		"body":
			return player.equipped_armor_id
		"shield":
			return player.equipped_shield_id
		"ring":
			return player.equipped_ring_id
		"amulet":
			return player.equipped_amulet_id
	return ""

static func _equip_entry(item_id: String, player: Player) -> Dictionary:
	if item_id == "":
		return {}
	for entry in player.items:
		if String(entry.get("id", "")) == item_id:
			return entry
	return {}
