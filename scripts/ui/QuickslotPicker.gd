class_name QuickslotPicker extends RefCounted

## Bind-to-quickslot picker. Opens when the player taps an empty
## quickslot (or a slot whose item ran out). Lists every potion /
## scroll currently in inventory; tapping one binds that id to the
## tapped slot. A Clear row wipes the slot instead.

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

	var header := Label.new()
	var current_id: String = String(player.quickslots[slot_index])
	if current_id != "":
		header.text = "Currently: %s" % _name_of(current_id)
	else:
		header.text = "Slot %d is empty." % (slot_index + 1)
	header.add_theme_font_size_override("font_size", 22)
	header.add_theme_color_override("font_color", Color(0.7, 0.75, 0.9))
	body.add_child(header)
	body.add_child(HSeparator.new())

	var seen_ids: Dictionary = {}
	var found: bool = false
	for entry in player.items:
		var id: String = String(entry.get("id", ""))
		if id == "" or seen_ids.has(id):
			continue
		var data: ItemData = ItemRegistry.get_by_id(id)
		if data == null:
			continue
		if data.kind != "potion" and data.kind != "scroll":
			continue
		seen_ids[id] = true
		body.add_child(_make_row(data, player, slot_index, dlg, on_change))
		found = true

	if not found:
		var empty := Label.new()
		empty.text = "(no bindable consumables in inventory)"
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

static func _make_row(data: ItemData, player: Player, slot_index: int,
		dlg: GameDialog, on_change: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 56)
	row.add_theme_constant_override("separation", 8)

	var name_lab := Label.new()
	var count: int = player.count_item(data.id)
	name_lab.text = "%s ×%d" % [data.display_name, count]
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
	# Unbind the same id from any other slot so we don't duplicate it.
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
	var d: ItemData = ItemRegistry.get_by_id(id)
	return d.display_name if d != null else id
