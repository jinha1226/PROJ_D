class_name BagDialog extends RefCounted

const THUMB_SIZE := 48
static var ItemRegistry = Engine.get_main_loop().root.get_node_or_null("/root/ItemRegistry") if Engine.get_main_loop() is SceneTree else null

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Bag", 0.92, 0.92)
	parent.add_child(dlg)
	_populate(dlg, player)

static func _populate(dlg: GameDialog, player: Player) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	# Gold
	var gold_lbl := Label.new()
	gold_lbl.text = "%d Gold" % player.gold
	gold_lbl.add_theme_font_size_override("font_size", 30)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	body.add_child(gold_lbl)

	# Equipped section
	body.add_child(UICards.section_header("EQUIPPED"))
	var w: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
	var a: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id) if ItemRegistry != null and player.equipped_armor_id != "" else null
	var r: ItemData = ItemRegistry.get_by_id(player.equipped_ring_id) if ItemRegistry != null and player.equipped_ring_id != "" else null
	var am: ItemData = ItemRegistry.get_by_id(player.equipped_amulet_id) if ItemRegistry != null and player.equipped_amulet_id != "" else null
	var sh: ItemData = ItemRegistry.get_by_id(player.equipped_shield_id) if ItemRegistry != null and player.equipped_shield_id != "" else null
	var w_plus: int = int(player.equipped_weapon_entry().get("plus", 0)) if w != null else 0
	var a_plus: int = int(player.equipped_armor_entry().get("plus", 0)) if a != null else 0
	body.add_child(_equipped_row("무기",
			w.display_name if w != null else "(맨손)",
			"d%d" % ((w.damage + w_plus) if w != null else 2)))
	body.add_child(_equipped_row("방어구",
			a.display_name if a != null else "(없음)",
			"+%d AC" % ((a.ac_bonus + a_plus) if a != null else 0)))
	body.add_child(_equipped_row("방패",
			sh.display_name if sh != null else "(없음)",
			"%d%% 차단" % (sh.effect_value if sh != null else 0)))
	body.add_child(_equipped_row("반지",
			r.display_name if r != null else "(없음)",
			_accessory_stat_text(r)))
	body.add_child(_equipped_row("목걸이",
			am.display_name if am != null else "(없음)",
			_accessory_stat_text(am)))

	# Inventory sub-tabs
	body.add_child(UICards.section_header("INVENTORY  (%d)" % player.items.size()))
	if player.items.is_empty():
		var empty := Label.new()
		empty.text = "(empty)"
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		body.add_child(empty)
		return

	# Tab bar
	var tab_bar := HBoxContainer.new()
	tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(tab_bar)

	var content_container := VBoxContainer.new()
	content_container.add_theme_constant_override("separation", 4)
	body.add_child(content_container)

	var tab_labels: Array = ["전체", "무기", "방어구", "장신구", "소모품"]
	var tab_filters: Array = [[], ["weapon"], ["armor"], ["ring", "amulet"],
		["potion", "scroll", "book"]]
	var tab_btns: Array = []

	for i in range(tab_labels.size()):
		var btn := Button.new()
		btn.text = tab_labels[i]
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 20)
		var idx: int = i
		btn.pressed.connect(func():
			for child in content_container.get_children():
				child.queue_free()
			_fill_inventory(content_container, player, dlg, tab_filters[idx])
			for j in range(tab_btns.size()):
				tab_btns[j].disabled = (j == idx))
		tab_bar.add_child(btn)
		tab_btns.append(btn)
	tab_btns[0].disabled = true
	_fill_inventory(content_container, player, dlg, [])


static func _fill_inventory(container: VBoxContainer, player: Player,
		dlg: GameDialog, kind_filter: Array) -> void:
	# Build stacks, equipped items first
	var stacks: Dictionary = {}
	var equipped_keys: Array = []
	var other_keys: Array = []

	for i in range(player.items.size()):
		var entry: Dictionary = player.items[i]
		var id: String = entry.get("id", "")
		var plus: int = entry.get("plus", 0)
		var data: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null and id != "" else null
		if data == null:
			continue
		if kind_filter.size() > 0 and not kind_filter.has(data.kind):
			continue
		var key: String = "%s|%d" % [id, plus]
		if not stacks.has(key):
			stacks[key] = {"id": id, "plus": plus, "indices": []}
		stacks[key].indices.append(i)

	# Sort: equipped first, then rest
	for key in stacks.keys():
		var sid: String = stacks[key].id
		var is_eq: bool = sid == player.equipped_weapon_id \
			or sid == player.equipped_armor_id \
			or sid == player.equipped_ring_id \
			or sid == player.equipped_amulet_id \
			or sid == player.equipped_shield_id
		if is_eq:
			equipped_keys.append(key)
		else:
			other_keys.append(key)

	for key in (equipped_keys + other_keys):
		var stack: Dictionary = stacks[key]
		var data: ItemData = ItemRegistry.get_by_id(String(stack.id)) if ItemRegistry != null and String(stack.id) != "" else null
		if data == null:
			continue
		container.add_child(_build_item_row(data, stack.indices, stack.plus, player, dlg))

	if stacks.is_empty():
		var empty := Label.new()
		empty.text = "(없음)"
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		empty.add_theme_font_size_override("font_size", 24)
		container.add_child(empty)


static func _accessory_stat_text(data: ItemData) -> String:
	if data == null:
		return ""
	match data.effect:
		"stat_str": return "+%d STR" % data.effect_value
		"stat_int": return "+%d INT" % data.effect_value
		"stat_dex": return "+%d DEX" % data.effect_value
		"hp_bonus": return "+%d HP" % data.effect_value
		"ac_bonus": return "+%d AC" % data.effect_value
		"mp_bonus": return "+%d MP" % data.effect_value
	return ""


static func _equipped_row(slot: String, name_s: String, stat: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var slot_lbl := Label.new()
	slot_lbl.text = slot
	slot_lbl.custom_minimum_size = Vector2(72, 0)
	slot_lbl.add_theme_font_size_override("font_size", 22)
	slot_lbl.add_theme_color_override("font_color", Color(0.65, 0.7, 0.65))
	row.add_child(slot_lbl)
	var name_lbl := Label.new()
	name_lbl.text = name_s
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 24)
	row.add_child(name_lbl)
	if stat != "":
		var stat_lbl := Label.new()
		stat_lbl.text = stat
		stat_lbl.add_theme_font_size_override("font_size", 22)
		stat_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
		row.add_child(stat_lbl)
	return row


static func _make_thumbnail(data: ItemData) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var base_path: String = data.tile_path if data.tile_path != "" else ""
	var show_identified: bool = GameManager.is_identified(data.id)
	if base_path != "" and ResourceLoader.exists(base_path):
		var rect := TextureRect.new()
		rect.texture = load(base_path) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)
	if show_identified and data.identified_tile_path != "" \
			and ResourceLoader.exists(data.identified_tile_path):
		var overlay := TextureRect.new()
		overlay.texture = load(data.identified_tile_path) as Texture2D
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(overlay)
	return container


static func _build_item_row(data: ItemData, indices: Array, plus: int,
		player: Player, dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	row.add_child(_make_thumbnail(data))

	var name_lbl := Label.new()
	var label_text: String = GameManager.display_name_of(data.id)
	if plus > 0:
		label_text += " +%d" % plus
	if data.kind == "weapon" and data.damage > 0:
		label_text += "  (d%d)" % (data.damage + plus)
	elif data.kind == "armor" and data.ac_bonus > 0:
		label_text += "  (+%d AC)" % (data.ac_bonus + plus)
	if indices.size() > 1:
		label_text += "  x%d" % indices.size()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", _item_color(data.kind))
	row.add_child(name_lbl)

	var is_equipped: bool = data.id == player.equipped_weapon_id \
		or data.id == player.equipped_armor_id \
		or data.id == player.equipped_ring_id \
		or data.id == player.equipped_amulet_id \
		or data.id == player.equipped_shield_id
	if is_equipped:
		var eq_lbl := Label.new()
		eq_lbl.text = "장착중"
		eq_lbl.add_theme_font_size_override("font_size", 20)
		eq_lbl.add_theme_color_override("font_color", Color(0.4, 0.9, 0.55))
		eq_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(eq_lbl)
	else:
		var hint := Label.new()
		hint.text = "›"
		hint.add_theme_font_size_override("font_size", 36)
		hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		row.add_child(hint)

	var first: int = indices[0]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	var touch_start_y: float = -9999.0
	row.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed:
				touch_start_y = ev.position.y
			elif not ev.pressed:
				var moved: float = abs(ev.position.y - touch_start_y)
				touch_start_y = -9999.0
				if moved < TouchScrollHelper.DRAG_THRESHOLD_PX:
					ItemDetailDialog.open(first, player, dlg, dlg.get_parent())
		elif ev is InputEventMouseButton \
				and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			ItemDetailDialog.open(first, player, dlg, dlg.get_parent()))

	return row


static func _item_color(kind: String) -> Color:
	match kind:
		"weapon": return Color(1.0, 0.75, 0.4)
		"armor":  return Color(0.55, 0.8, 1.0)
		"potion": return Color(0.5, 1.0, 0.6)
		"scroll": return Color(1.0, 0.95, 0.55)
		"book":   return Color(0.7, 0.55, 1.0)
		"ring":   return Color(1.0, 0.7, 0.9)
		"amulet": return Color(0.9, 0.75, 0.5)
		"shield": return Color(0.6, 0.75, 0.65)
		_:        return Color(0.85, 0.85, 0.85)
