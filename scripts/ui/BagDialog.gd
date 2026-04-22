class_name BagDialog extends RefCounted

## Programmatic bag screen — built on top of the GameDialog chrome.
## Open with BagDialog.open(player, parent). Closes on its own when an
## action that ends the player's turn is taken (use/equip).

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

	var gold_lab := Label.new()
	gold_lab.text = "Gold: %d$" % player.gold
	gold_lab.add_theme_font_size_override("font_size", 32)
	gold_lab.add_theme_color_override("font_color", Color(1, 0.92, 0.3))
	body.add_child(gold_lab)

	var eq_header := Label.new()
	eq_header.text = "── Equipped ──"
	eq_header.add_theme_font_size_override("font_size", 26)
	eq_header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	body.add_child(eq_header)

	var weapon_lab := Label.new()
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
	weapon_lab.text = "Weapon: %s" % (w.display_name if w != null else "(none)")
	weapon_lab.add_theme_font_size_override("font_size", 22)
	body.add_child(weapon_lab)

	var armor_lab := Label.new()
	var a: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
	armor_lab.text = "Armor: %s" % (a.display_name if a != null else "(none)")
	armor_lab.add_theme_font_size_override("font_size", 22)
	body.add_child(armor_lab)

	body.add_child(HSeparator.new())

	var inv_header := Label.new()
	inv_header.text = "── Inventory (%d) ──" % player.items.size()
	inv_header.add_theme_font_size_override("font_size", 26)
	inv_header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	body.add_child(inv_header)

	if player.items.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.modulate = Color(0.6, 0.6, 0.6)
		body.add_child(empty)
		return

	for i in range(player.items.size()):
		var entry: Dictionary = player.items[i]
		var data: ItemData = ItemRegistry.get_by_id(entry.get("id", ""))
		if data == null:
			continue
		body.add_child(_build_row(data, i, player, dlg))

static func _build_row(data: ItemData, index: int, player: Player,
		dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 64)
	row.add_theme_constant_override("separation", 8)

	var name_lab := Label.new()
	var label_text: String = data.display_name
	if data.kind == "weapon" and data.damage > 0:
		label_text += "  (d%d)" % data.damage
	elif data.kind == "armor" and data.ac_bonus > 0:
		label_text += "  (+%d AC)" % data.ac_bonus
	name_lab.text = label_text
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", 24)
	row.add_child(name_lab)

	match data.kind:
		"weapon":
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(150, 56)
			btn.add_theme_font_size_override("font_size", 22)
			if player.equipped_weapon_id == data.id:
				btn.text = "Equipped"
				btn.disabled = true
			else:
				btn.text = "Equip"
				btn.pressed.connect(
					func(): _equip_weapon(index, player, dlg))
			row.add_child(btn)
		"armor":
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(150, 56)
			btn.add_theme_font_size_override("font_size", 22)
			if player.equipped_armor_id == data.id:
				btn.text = "Equipped"
				btn.disabled = true
			else:
				btn.text = "Equip"
				btn.pressed.connect(
					func(): _equip_armor(index, player, dlg))
			row.add_child(btn)
		"potion", "scroll":
			var btn := Button.new()
			btn.custom_minimum_size = Vector2(150, 56)
			btn.add_theme_font_size_override("font_size", 22)
			btn.text = "Use"
			btn.pressed.connect(func(): _use_item(index, player, dlg))
			row.add_child(btn)

	var drop_btn := Button.new()
	drop_btn.custom_minimum_size = Vector2(100, 56)
	drop_btn.add_theme_font_size_override("font_size", 22)
	drop_btn.text = "Drop"
	drop_btn.pressed.connect(func(): _drop_item(index, player, dlg))
	row.add_child(drop_btn)

	return row

static func _equip_weapon(index: int, player: Player, dlg: GameDialog) -> void:
	if index < 0 or index >= player.items.size():
		return
	var entry: Dictionary = player.items[index]
	player.equipped_weapon_id = String(entry.get("id", ""))
	player.emit_signal("stats_changed")
	CombatLog.post("You equip %s." % _name_of(entry))
	dlg.close()
	TurnManager.end_player_turn()

static func _equip_armor(index: int, player: Player, dlg: GameDialog) -> void:
	if index < 0 or index >= player.items.size():
		return
	var entry: Dictionary = player.items[index]
	player.equipped_armor_id = String(entry.get("id", ""))
	player.refresh_ac_from_equipment()
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
