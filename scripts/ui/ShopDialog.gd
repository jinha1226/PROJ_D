class_name ShopDialog extends RefCounted

## ShopDialog — purchase UI for merchant encounters.
##
## shop_items format: Array[Dictionary]
##   { item_data: ItemData, price: int, sold: bool }
##
## Turn cost: none (shopping does not consume a turn).

const THUMB_SIZE := 48

## Open the shop dialog. shop_items is passed by reference so sold flags
## update in the caller's copy automatically.
static func open(shop_items: Array, player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio(LocaleManager.t("SHOP_TITLE"), 0.92, 0.92)
	parent.add_child(dlg)
	_populate(dlg, shop_items, player)


static func _populate(dlg: GameDialog, shop_items: Array, player: Player) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", GameTheme.PAD_M)

	# Gold display — stored in a Label so _refresh_gold can update it.
	var gold_lbl := Label.new()
	gold_lbl.name = "GoldLabel"
	_set_gold_text(gold_lbl, player.gold)
	gold_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	gold_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	body.add_child(gold_lbl)

	body.add_child(HSeparator.new())

	# "Not enough gold" flash label — hidden by default.
	var msg_lbl := Label.new()
	msg_lbl.name = "MsgLabel"
	msg_lbl.text = LocaleManager.t("SHOP_NOT_ENOUGH_GOLD")
	msg_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	msg_lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	msg_lbl.visible = false
	body.add_child(msg_lbl)

	if shop_items.is_empty():
		var empty := Label.new()
		empty.text = LocaleManager.t("SHOP_SOLD")
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		body.add_child(empty)
		return

	# Item rows
	for i in range(shop_items.size()):
		var slot: Dictionary = shop_items[i]
		body.add_child(_build_shop_row(i, slot, shop_items, player, body, gold_lbl, msg_lbl, dlg))


## Build a single shop row for shop_items[idx].
static func _build_shop_row(idx: int, slot: Dictionary, shop_items: Array,
		player: Player, body: VBoxContainer, gold_lbl: Label, msg_lbl: Label,
		_dlg: GameDialog) -> Control:

	var item_data: ItemData = slot.get("item_data", null) as ItemData
	var price: int = int(slot.get("price", 0))
	var sold: bool = bool(slot.get("sold", false))

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_M)
	row.custom_minimum_size = Vector2(0, GameTheme.ROW_MIN_HEIGHT)

	# Thumbnail
	if item_data != null:
		row.add_child(_make_thumbnail(item_data))
	else:
		var ph := Control.new()
		ph.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
		row.add_child(ph)

	# Item name — shop always shows the true name regardless of identification.
	var name_lbl := Label.new()
	var label_text: String = item_data.loc_name() if item_data != null else "???"
	if item_data != null:
		var plus: int = int(slot.get("plus", 0))
		if plus > 0:
			label_text += " +%d" % plus
		if item_data.kind == "weapon" and item_data.damage > 0:
			label_text += "  (d%d)" % (item_data.damage + plus)
		elif item_data.kind == "armor" and item_data.ac_bonus > 0:
			label_text += "  (+%d AC)" % (item_data.ac_bonus + plus)
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	# Blue for unidentified potions/scrolls; white otherwise (shop reveals identity).
	if item_data != null and (item_data.kind == "potion" or item_data.kind == "scroll") \
			and not (GameManager != null and GameManager.is_identified(item_data.id)):
		name_lbl.add_theme_color_override("font_color", Color(0.45, 0.75, 1.0))
	else:
		name_lbl.add_theme_color_override("font_color", BagDialog._item_color(
				item_data.kind if item_data != null else ""))
	if sold:
		name_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48))
	row.add_child(name_lbl)

	# Price label
	var price_lbl := Label.new()
	price_lbl.text = "%dg" % price
	price_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	price_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	if sold:
		price_lbl.add_theme_color_override("font_color", Color(0.45, 0.45, 0.48))
	else:
		price_lbl.add_theme_color_override("font_color", Color(1.0, 0.88, 0.3))
	row.add_child(price_lbl)

	# Buy button
	var buy_btn := Button.new()
	if sold:
		buy_btn.text = LocaleManager.t("SHOP_SOLD")
		buy_btn.disabled = true
	else:
		buy_btn.text = LocaleManager.t("SHOP_BUY")
	buy_btn.custom_minimum_size = Vector2(80, GameTheme.TAP_MIN_HEIGHT)
	buy_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)

	if not sold and item_data != null:
		var capture_idx: int = idx
		var capture_data: ItemData = item_data
		var capture_price: int = price
		buy_btn.pressed.connect(func() -> void:
			_on_buy_pressed(capture_idx, capture_data, capture_price,
					shop_items, player, body, gold_lbl, msg_lbl, _dlg))

	row.add_child(buy_btn)
	return row


static func _on_buy_pressed(idx: int, item_data: ItemData, price: int,
		shop_items: Array, player: Player, body: VBoxContainer,
		gold_lbl: Label, msg_lbl: Label, dlg: GameDialog) -> void:

	if player.gold < price:
		_flash_message(msg_lbl, body)
		return

	# Complete the purchase.
	player.gold -= price
	if GameManager != null:
		GameManager.identify(item_data.id)

	# Add to inventory — preserve any extra entry data stored in the shop slot.
	var base_entry: Dictionary = shop_items[idx].get("entry", {})
	var new_entry: Dictionary
	if base_entry.is_empty():
		new_entry = {"id": item_data.id, "plus": int(shop_items[idx].get("plus", 0))}
	else:
		new_entry = base_entry.duplicate(true)
	player.items.append(new_entry)
	player.emit_signal("stats_changed")

	# Mark sold.
	shop_items[idx]["sold"] = true

	# Refresh gold display.
	_set_gold_text(gold_lbl, player.gold)

	# Rebuild the body to reflect sold state.
	_populate(dlg, shop_items, player)


static func _flash_message(msg_lbl: Label, _body: VBoxContainer) -> void:
	if not is_instance_valid(msg_lbl):
		return
	msg_lbl.visible = true
	# Auto-hide after 1 second using a SceneTreeTimer.
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree != null:
		await tree.create_timer(1.0).timeout
		if is_instance_valid(msg_lbl):
			msg_lbl.visible = false


static func _set_gold_text(lbl: Label, amount: int) -> void:
	lbl.text = LocaleManager.t("SHOP_GOLD_LABEL") % amount


static func _make_thumbnail(data: ItemData) -> Control:
	var container := Control.new()
	container.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	container.size_flags_vertical = Control.SIZE_SHRINK_CENTER

	# Potions use per-run random color tile.
	var base_path: String
	if data.kind == "potion" and GameManager != null:
		base_path = GameManager.potion_color_tile(data.id)
	else:
		base_path = data.tile_path if data.tile_path != "" else ""

	if base_path != "" and ResourceLoader.exists(base_path):
		var rect := TextureRect.new()
		rect.texture = load(base_path) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		container.add_child(rect)

	# Show identified overlay if player has identified this item.
	var show_identified: bool = GameManager != null and GameManager.is_identified(data.id)
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
