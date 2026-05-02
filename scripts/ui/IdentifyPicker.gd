class_name IdentifyPicker extends RefCounted

## Scroll of Identify picker. Lists every unidentified potion / scroll /
## book in the player's inventory; tapping one identifies it and the
## scroll that triggered the picker is consumed by the caller.

static func open(player: Player, parent: Node,
		on_picked: Callable = Callable()) -> void:
	var dlg: GameDialog = GameDialog.create("Identify which?")
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	var seen: Dictionary = {}
	var found: bool = false
	for entry in player.items:
		var id: String = String(entry.get("id", ""))
		if id == "" or seen.has(id):
			continue
		var data: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null and id != "" else null
		if data == null:
			continue
		if data.kind != "potion" and data.kind != "scroll" \
				and data.kind != "book":
			continue
		if GameManager.is_identified(id):
			continue
		seen[id] = true
		body.add_child(_make_row(data, id, player, dlg, on_picked))
		found = true

	if not found:
		var empty := Label.new()
		empty.text = "(nothing unidentified to reveal)"
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		body.add_child(empty)
		var close_btn := Button.new()
		close_btn.text = "OK"
		close_btn.custom_minimum_size = Vector2(0, 56)
		close_btn.add_theme_font_size_override("font_size", 24)
		close_btn.pressed.connect(func(): dlg.close())
		body.add_child(close_btn)

static func _make_row(data: ItemData, id: String, player: Player,
		dlg: GameDialog, on_picked: Callable) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 60)
	row.add_theme_constant_override("separation", 8)
	var count: int = player.count_item(id)
	var name_lab := Label.new()
	name_lab.text = "%s ×%d" % [GameManager.display_name_of(id), count]
	name_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lab.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lab.add_theme_font_size_override("font_size", 24)
	row.add_child(name_lab)
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 54)
	btn.add_theme_font_size_override("font_size", 22)
	btn.text = "Reveal"
	btn.pressed.connect(func(): _on_pick(id, data, dlg, on_picked))
	row.add_child(btn)
	return row

static func _on_pick(id: String, data: ItemData, dlg: GameDialog,
		on_picked: Callable) -> void:
	GameManager.identify(id)
	CombatLog.post("You identify %s." % data.display_name,
		Color(0.85, 0.95, 1.0))
	dlg.close()
	if on_picked.is_valid():
		on_picked.call()
