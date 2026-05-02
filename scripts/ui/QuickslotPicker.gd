class_name QuickslotPicker extends RefCounted

static var SpellRegistry = Engine.get_main_loop().root.get_node_or_null("/root/SpellRegistry") if Engine.get_main_loop() is SceneTree else null
static var ItemRegistry = Engine.get_main_loop().root.get_node_or_null("/root/ItemRegistry") if Engine.get_main_loop() is SceneTree else null

## Bind-to-quickslot picker. Lists consumable items AND known spells.
## Prefix "spell:" is NOT used — spell ids are stored raw (e.g. "magic_dart").
## Game.gd detects a spell slot by checking SpellRegistry first.

static func open(player: Player, parent: Node, slot_index: int,
		on_change: Callable = Callable()) -> void:
	var dlg: GameDialog = GameDialog.create("Bind Quickslot %d" % (slot_index + 1))
	parent.add_child(dlg)
	_populate(dlg, player, slot_index, on_change)

static func _populate(dlg: GameDialog, player: Player, slot_index: int,
		on_change: Callable) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	var current_id: String = String(player.quickslots[slot_index])
	var header := Label.new()
	if current_id != "":
		header.text = "Currently: %s" % _name_of(current_id)
	else:
		header.text = "Slot %d is empty." % (slot_index + 1)
	header.add_theme_font_size_override("font_size", 26)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	body.add_child(header)
	body.add_child(HSeparator.new())

	# ── Spells ───────────────────────────────────────────────────────────────
	if not player.known_spells.is_empty():
		var spell_hdr := Label.new()
		spell_hdr.text = "SPELLS"
		spell_hdr.add_theme_font_size_override("font_size", 28)
		spell_hdr.add_theme_color_override("font_color", Color(0.7, 0.6, 1.0))
		body.add_child(spell_hdr)
		for spell_id in player.known_spells:
			var spell: SpellData = SpellRegistry.get_by_id(String(spell_id))
			if spell == null:
				continue
			body.add_child(_make_spell_row(spell, player, slot_index, dlg, on_change))

	# ── Consumables ──────────────────────────────────────────────────────────
	var seen_ids: Dictionary = {}
	var found_items: bool = false
	for entry in player.items:
		var id: String = String(entry.get("id", ""))
		if id == "" or seen_ids.has(id):
			continue
		var data: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null and id != "" else null
		if data == null:
			continue
		if data.kind != "potion" and data.kind != "scroll":
			continue
		seen_ids[id] = true
		if not found_items:
			var item_hdr := Label.new()
			item_hdr.text = "CONSUMABLES"
			item_hdr.add_theme_font_size_override("font_size", 28)
			item_hdr.add_theme_color_override("font_color", Color(0.8, 0.75, 0.4))
			body.add_child(item_hdr)
			found_items = true
		body.add_child(_make_item_row(data, player, slot_index, dlg, on_change))

	if player.known_spells.is_empty() and not found_items:
		var empty := Label.new()
		empty.text = "(nothing to bind)"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		body.add_child(empty)

	if current_id != "":
		body.add_child(HSeparator.new())
		var clear_btn := Button.new()
		clear_btn.custom_minimum_size = Vector2(0, 60)
		clear_btn.add_theme_font_size_override("font_size", 24)
		clear_btn.text = "Clear slot %d" % (slot_index + 1)
		clear_btn.pressed.connect(
			func(): _set_binding(player, slot_index, "", dlg, on_change))
		body.add_child(clear_btn)


static func _make_spell_row(spell: SpellData, player: Player, slot_index: int,
		dlg: GameDialog, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 8)

	var icon_rect := TextureRect.new()
	icon_rect.custom_minimum_size = Vector2(40, 40)
	icon_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon_rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	if spell.icon_path != "" and ResourceLoader.exists(spell.icon_path):
		icon_rect.texture = load(spell.icon_path)
	row.add_child(icon_rect)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vb)
	var name_lab := Label.new()
	name_lab.text = spell.display_name
	name_lab.add_theme_font_size_override("font_size", 26)
	name_lab.add_theme_color_override("font_color", Color(0.8, 0.7, 1.0))
	vb.add_child(name_lab)
	var cost_lab := Label.new()
	cost_lab.text = "%d MP" % spell.mp_cost
	cost_lab.add_theme_font_size_override("font_size", 20)
	cost_lab.modulate = Color(0.7, 0.7, 0.9)
	vb.add_child(cost_lab)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 52)
	btn.add_theme_font_size_override("font_size", 22)
	btn.text = "Bind"
	btn.pressed.connect(
		func(): _set_binding(player, slot_index, spell.id, dlg, on_change))
	row.add_child(btn)
	return row


static func _make_item_row(data: ItemData, player: Player, slot_index: int,
		dlg: GameDialog, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override("separation", 8)

	var name_lab := Label.new()
	var count: int = player.count_item(data.id)
	name_lab.text = "%s  ×%d" % [GameManager.display_name_of(data.id), count]
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", 24)
	row.add_child(name_lab)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(130, 50)
	btn.add_theme_font_size_override("font_size", 22)
	btn.text = "Bind"
	btn.pressed.connect(
		func(): _set_binding(player, slot_index, data.id, dlg, on_change))
	row.add_child(btn)
	return row


static func _set_binding(player: Player, slot_index: int, id: String,
		dlg: GameDialog, on_change: Callable) -> void:
	if id != "":
		for i in range(player.quickslots.size()):
			if i != slot_index and String(player.quickslots[i]) == id:
				player.quickslots[i] = ""
	player.quickslots[slot_index] = id
	player.emit_signal("stats_changed")
	if on_change.is_valid():
		on_change.call()
	dlg.close()


static func _name_of(id: String) -> String:
	var spell: SpellData = SpellRegistry.get_by_id(id)
	if spell != null:
		return spell.display_name
	return GameManager.display_name_of(id)
