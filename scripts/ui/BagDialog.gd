class_name BagDialog extends RefCounted

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Bag")
	parent.add_child(dlg)
	_populate(dlg, player)

static func _populate(dlg: GameDialog, player: Player) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 8)

	# Gold
	var gold_lbl := Label.new()
	gold_lbl.text = "%d Gold" % player.gold
	gold_lbl.add_theme_font_size_override("font_size", 32)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	body.add_child(gold_lbl)

	# Equipped
	body.add_child(UICards.section_header("EQUIPPED"))
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	var a: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
	body.add_child(_equipped_row("Weapon",
			w.display_name if w != null else "(unarmed)",
			"d%d" % (w.damage if w != null else 2)))
	body.add_child(_equipped_row("Armor",
			a.display_name if a != null else "(none)",
			"+%d AC" % (a.ac_bonus if a != null else 0)))

	# Inventory
	body.add_child(UICards.section_header("INVENTORY  (%d)" % player.items.size()))
	if player.items.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		body.add_child(empty)
		return

	for i in range(player.items.size()):
		var entry: Dictionary = player.items[i]
		var data: ItemData = ItemRegistry.get_by_id(entry.get("id", ""))
		if data == null:
			continue
		body.add_child(_build_item_row(data, i, player, dlg))


static func _equipped_row(slot: String, name_s: String, stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var slot_lbl := Label.new()
	slot_lbl.text = slot
	slot_lbl.custom_minimum_size = Vector2(100, 0)
	slot_lbl.add_theme_font_size_override("font_size", 24)
	slot_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.65))
	row.add_child(slot_lbl)
	var name_lbl := Label.new()
	name_lbl.text = name_s
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 26)
	row.add_child(name_lbl)
	var stat_lbl := Label.new()
	stat_lbl.text = stat
	stat_lbl.add_theme_font_size_override("font_size", 24)
	stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	row.add_child(stat_lbl)
	return row


static func _build_item_row(data: ItemData, index: int, player: Player,
		dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var name_lbl := Label.new()
	var label_text: String = data.display_name
	if data.kind == "weapon" and data.damage > 0:
		label_text += "  (d%d)" % data.damage
	elif data.kind == "armor" and data.ac_bonus > 0:
		label_text += "  (+%d AC)" % data.ac_bonus
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", _item_color(data.kind))
	row.add_child(name_lbl)

	var btn_row := HBoxContainer.new()
	btn_row.add_theme_constant_override("separation", 4)
	row.add_child(btn_row)

	match data.kind:
		"weapon":
			var btn := _action_btn(
					"Equipped" if player.equipped_weapon_id == data.id else "Equip")
			btn.disabled = (player.equipped_weapon_id == data.id)
			if not btn.disabled:
				btn.pressed.connect(func(): _equip_weapon(index, player, dlg))
			btn_row.add_child(btn)
		"armor":
			var btn := _action_btn(
					"Equipped" if player.equipped_armor_id == data.id else "Equip")
			btn.disabled = (player.equipped_armor_id == data.id)
			if not btn.disabled:
				btn.pressed.connect(func(): _equip_armor(index, player, dlg))
			btn_row.add_child(btn)
		"potion", "scroll":
			var btn := _action_btn("Use")
			btn.pressed.connect(func(): _use_item(index, player, dlg))
			btn_row.add_child(btn)

	var drop_btn := _action_btn("Drop")
	drop_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	drop_btn.pressed.connect(func(): _drop_item(index, player, dlg))
	btn_row.add_child(drop_btn)

	return row


static func _action_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.custom_minimum_size = Vector2(120, 52)
	btn.add_theme_font_size_override("font_size", 22)
	return btn


static func _item_color(kind: String) -> Color:
	match kind:
		"weapon": return Color(1.0, 0.75, 0.4)
		"armor":  return Color(0.55, 0.8, 1.0)
		"potion": return Color(0.5, 1.0, 0.6)
		"scroll": return Color(1.0, 0.95, 0.55)
		_:        return Color(0.85, 0.85, 0.85)


static func _equip_weapon(index: int, player: Player, dlg: GameDialog) -> void:
	if index < 0 or index >= player.items.size():
		return
	var entry: Dictionary = player.items[index]
	player.set_equipped_weapon(String(entry.get("id", "")))
	CombatLog.post("You equip %s." % _name_of(entry))
	dlg.close()
	TurnManager.end_player_turn()

static func _equip_armor(index: int, player: Player, dlg: GameDialog) -> void:
	if index < 0 or index >= player.items.size():
		return
	var entry: Dictionary = player.items[index]
	player.set_equipped_armor(String(entry.get("id", "")))
	CombatLog.post("You don %s." % _name_of(entry))
	dlg.close()
	TurnManager.end_player_turn()

static func _use_item(index: int, player: Player, dlg: GameDialog) -> void:
	player.use_item(index)
	dlg.close()
	TurnManager.end_player_turn()

static func _drop_item(index: int, player: Player, dlg: GameDialog) -> void:
	player.drop_item(index)
	_populate(dlg, player)

static func _name_of(entry: Dictionary) -> String:
	var data: ItemData = ItemRegistry.get_by_id(entry.get("id", ""))
	return data.display_name if data != null else "something"
