class_name NPCInfoDialog extends RefCounted

## Opens a GameDialog showing an NPC's name, HP, and equipped items.
## Call NPCInfoDialog.show_for(npc, game_node) from _handle_tap.

static func show_for(npc: NPCActor, game_node: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio(npc.npc_name, 0.75, 0.55)
	game_node.add_child(dlg)
	var body: VBoxContainer = dlg.body()

	# HP bar row
	var hp_label := Label.new()
	hp_label.text = "HP  %d / %d" % [npc.hp, npc.hp_max]
	hp_label.add_theme_font_size_override("font_size", 22)
	body.add_child(hp_label)

	var bar := ProgressBar.new()
	bar.min_value = 0
	bar.max_value = npc.hp_max
	bar.value = npc.hp
	bar.custom_minimum_size = Vector2(0, 18)
	bar.show_percentage = false
	body.add_child(bar)

	# Separator
	body.add_child(HSeparator.new())

	# Equipment rows
	var slots: Array = [
		["weapon",  "Weapon",  npc.equipped_weapon_id],
		["armor",   "Armor",   npc.equipped_armor_id],
		["shield",  "Shield",  npc.equipped_shield_id],
		["helmet",  "Helmet",  npc.equipped_helmet_id],
		["gloves",  "Gloves",  npc.equipped_gloves_id],
		["boots",   "Boots",   npc.equipped_boots_id],
		["ring",    "Ring",    npc.equipped_ring_id],
		["amulet",  "Amulet",  npc.equipped_amulet_id],
	]
	var any_equip := false
	for slot_info in slots:
		var item_id: String = slot_info[2]
		if item_id == "":
			continue
		any_equip = true
		var item_data = null
		if npc.ItemRegistry != null:
			item_data = npc.ItemRegistry.get_by_id(item_id)
		var row := Label.new()
		var item_name: String = item_data.display_name if item_data != null else item_id
		row.text = "%s:  %s" % [slot_info[1], item_name]
		row.add_theme_font_size_override("font_size", 20)
		body.add_child(row)

	if not any_equip:
		var empty := Label.new()
		empty.text = "No equipment"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		empty.add_theme_font_size_override("font_size", 20)
		body.add_child(empty)

	dlg.set_close_text("Close")
