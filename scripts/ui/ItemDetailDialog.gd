class_name ItemDetailDialog extends RefCounted

const THUMB_SIZE := 72

## Opens the item detail popup.
## item_index: index into player.items[]
## bag_dlg: the BagDialog GameDialog (to close/repopulate after action)
## parent: node to add_child the new dialog to (typically the Game scene)
static func open(item_index: int, player: Player,
		bag_dlg: GameDialog, parent: Node) -> void:
	if item_index < 0 or item_index >= player.items.size():
		return
	var entry: Dictionary = player.items[item_index]
	var data: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null and String(entry.get("id", "")) != "" else null
	if data == null:
		return
	var plus: int = int(entry.get("plus", 0))

	var title: String = ItemRegistry.entry_display_name(entry) if ItemRegistry != null else GameManager.display_name_of(data.id)
	if plus > 0:
		title += "  +%d" % plus
	var dlg: GameDialog = GameDialog.create(title)
	parent.add_child(dlg)

	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	body.add_child(_build_header(data, plus))
	body.add_child(_build_description(data))
	body.add_child(_build_stats_card(data, plus))
	var artifact_card := _build_artifact_card(entry)
	if artifact_card != null:
		body.add_child(artifact_card)

	var cmp := _build_comparison(data, plus, player)
	if cmp != null:
		body.add_child(cmp)

	body.add_child(_build_buttons(entry, data, player, dlg, bag_dlg))


# ── Header ────────────────────────────────────────────────────────────────────

static func _build_header(data: ItemData, plus: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)

	# Thumbnail 72×72
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var base_path: String = data.tile_path
	if data.kind == "potion" and GameManager != null:
		base_path = GameManager.potion_color_tile(data.id)
	if base_path != "" and ResourceLoader.exists(base_path):
		var rect := TextureRect.new()
		rect.texture = load(base_path) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(rect)
	if GameManager.is_identified(data.id) and data.identified_tile_path != "" \
			and ResourceLoader.exists(data.identified_tile_path):
		var overlay := TextureRect.new()
		overlay.texture = load(data.identified_tile_path) as Texture2D
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(overlay)
	row.add_child(thumb)

	# Right: kind pill + category/slot hint
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", GameTheme.PAD_M)

	var pill_row := HBoxContainer.new()
	pill_row.add_child(UICards.pill(_kind_label(data.kind), _kind_color(data.kind)))
	right.add_child(pill_row)

	if data.kind == "weapon" and data.category != "":
		right.add_child(UICards.dim_hint(data.category.capitalize(), 26))
	elif data.kind == "armor" and data.slot != "":
		right.add_child(UICards.dim_hint(data.slot.capitalize(), 26))

	row.add_child(right)
	return row


# ── Description ───────────────────────────────────────────────────────────────

static func _build_description(data: ItemData) -> Control:
	var is_consumable: bool = data.kind in ["potion", "scroll", "book"]
	var text: String
	if is_consumable and not GameManager.is_identified(data.id):
		text = LocaleManager.t("COMMON_UNKNOWN")
	elif data.loc_description() != "":
		text = data.loc_description()
	else:
		text = _effect_desc(data)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	return lbl

static func _effect_desc(data: ItemData) -> String:
	if not GameManager.is_identified(data.id):
		return LocaleManager.t("COMMON_UNKNOWN")
	match data.effect:
		"heal":           return LocaleManager.t("ITEM_EFFECT_HEAL") % data.effect_value
		"restore_mp":     return LocaleManager.t("ITEM_EFFECT_RESTORE_MP") % data.effect_value
		"map_reveal":     return LocaleManager.t("ITEM_EFFECT_MAP_REVEAL")
		"blink":          return LocaleManager.t("ITEM_EFFECT_BLINK")
		"cure":           return LocaleManager.t("ITEM_EFFECT_CURE")
		"teleport":       return LocaleManager.t("ITEM_EFFECT_TELEPORT")
		"enchant_weapon": return LocaleManager.t("ITEM_EFFECT_ENCHANT_WEAPON")
		"enchant_armor":  return LocaleManager.t("ITEM_EFFECT_ENCHANT_ARMOR")
		"berserk":        return LocaleManager.t("ITEM_EFFECT_BERSERK")
		"identify":       return LocaleManager.t("ITEM_EFFECT_IDENTIFY")
		"study":          return LocaleManager.t("ITEM_EFFECT_STUDY")
		"might":          return LocaleManager.t("ITEM_EFFECT_MIGHT")
	return data.effect if data.effect != "" else LocaleManager.t("COMMON_NO_DESCRIPTION")


# ── Stats card ────────────────────────────────────────────────────────────────

static func _build_stats_card(data: ItemData, plus: int) -> Control:
	var card := UICards.card(Color(0.5, 0.6, 0.8))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vbox)

	match data.kind:
		"weapon":
			vbox.add_child(UICards.dim_hint("STATS", 22))
			var dmg_row := HBoxContainer.new()
			dmg_row.add_child(_stat_label("Damage"))
			dmg_row.add_child(UICards.accent_value("d%d" % (data.damage + plus), 30))
			vbox.add_child(dmg_row)
			if data.brand != "":
				var brand_row := HBoxContainer.new()
				brand_row.add_child(_stat_label("Brand"))
				brand_row.add_child(UICards.accent_value(data.brand.capitalize(), 30))
				vbox.add_child(brand_row)
		"armor":
			vbox.add_child(UICards.dim_hint("STATS", 22))
			var ac_row := HBoxContainer.new()
			ac_row.add_child(_stat_label("AC"))
			ac_row.add_child(UICards.accent_value("+%d" % (data.ac_bonus + plus), 30))
			vbox.add_child(ac_row)
			if data.ev_penalty > 0:
				var ev_row := HBoxContainer.new()
				ev_row.add_child(_stat_label("EV Penalty"))
				ev_row.add_child(UICards.accent_value("-%d" % data.ev_penalty, 30))
				vbox.add_child(ev_row)
		"shield":
			vbox.add_child(UICards.dim_hint("STATS", 22))
			var blk_row := HBoxContainer.new()
			blk_row.add_child(_stat_label(LocaleManager.t("ITEM_STAT_BLOCK")))
			blk_row.add_child(UICards.accent_value("%d%%" % data.effect_value, 30))
			vbox.add_child(blk_row)
			if data.ev_penalty > 0:
				var ev_row := HBoxContainer.new()
				ev_row.add_child(_stat_label(LocaleManager.t("ITEM_STAT_EV_PEN")))
				ev_row.add_child(UICards.accent_value("-%d" % data.ev_penalty, 30))
				vbox.add_child(ev_row)
		"ring", "amulet":
			vbox.add_child(UICards.dim_hint("BONUS", 22))
			vbox.add_child(UICards.accent_value(BagDialog._accessory_stat_text(data), 28))
		"potion", "scroll", "book":
			vbox.add_child(UICards.dim_hint("EFFECT", 22))
			vbox.add_child(UICards.accent_value(_effect_desc(data), 28))
		_:
			vbox.add_child(UICards.dim_hint(LocaleManager.t("COMMON_OTHER_ITEM"), 26))

	return card

static func _stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	return lbl


# ── Comparison card ───────────────────────────────────────────────────────────


static func _build_artifact_card(entry: Dictionary) -> Control:
	if ItemRegistry == null:
		return null
	var lines: PackedStringArray = ItemRegistry.entry_bonus_lines(entry)
	if lines.is_empty():
		return null
	var card := UICards.card(Color(0.75, 0.55, 0.2))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", GameTheme.PAD_S)
	card.add_child(vbox)
	vbox.add_child(UICards.dim_hint("ARTIFACT", 22))
	for line in lines:
		vbox.add_child(UICards.accent_value(line, 26))
	return card

static func _build_comparison(data: ItemData, plus: int, player: Player) -> Control:
	if data.kind == "weapon":
		if player.equipped_weapon_id == "" or player.equipped_weapon_id == data.id:
			return null
		var ew: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id) if ItemRegistry != null else null
		if ew == null:
			return null
		var ew_plus: int = int(player.equipped_weapon_entry().get("plus", 0))
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", GameTheme.PAD_M)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint(LocaleManager.t("COMMON_VS_EQUIPPED") % ew.loc_name(), 22))
		vbox.add_child(_delta_row("Damage",
				ew.damage + ew_plus, data.damage + plus, "d%d", "d%d"))
		return card

	elif data.kind == "armor":
		if player.equipped_armor_id == "" or player.equipped_armor_id == data.id:
			return null
		var ea: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id) if ItemRegistry != null and player.equipped_armor_id != "" else null
		if ea == null:
			return null
		var ea_plus: int = int(player.equipped_armor_entry().get("plus", 0))
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", GameTheme.PAD_M)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint(LocaleManager.t("COMMON_VS_EQUIPPED") % ea.loc_name(), 22))
		vbox.add_child(_delta_row("AC",
				ea.ac_bonus + ea_plus, data.ac_bonus + plus, "+%d", "+%d"))
		if data.ev_penalty != ea.ev_penalty:
			vbox.add_child(_delta_row("EV Penalty",
					ea.ev_penalty, data.ev_penalty, "-%d", "-%d"))
		return card

	return null

static func _delta_row(stat: String, old_val: int, new_val: int,
		old_fmt: String, new_fmt: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_M)

	var key_lbl := Label.new()
	key_lbl.text = stat
	key_lbl.custom_minimum_size = Vector2(140, 0)
	key_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	key_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	row.add_child(key_lbl)

	var old_lbl := Label.new()
	old_lbl.text = old_fmt % old_val
	old_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	old_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	row.add_child(old_lbl)

	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(arrow)

	var delta: int = new_val - old_val
	var suffix: String
	if delta > 0:
		suffix = "  (+%d ▲)" % delta
	elif delta < 0:
		suffix = "  (%d ▼)" % delta
	else:
		suffix = "  (=)"
	var new_lbl := Label.new()
	new_lbl.text = (new_fmt % new_val) + suffix
	new_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_LABEL)
	new_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if delta > 0
			else (Color(1.0, 0.4, 0.4) if delta < 0 else Color(0.7, 0.7, 0.7)))
	row.add_child(new_lbl)
	return row


# ── Action + Drop buttons ─────────────────────────────────────────────────────

## Action/drop buttons. Capture the entry dict (not the items[] index): the
## inventory mutates between dialog-open and button-press (auto-use,
## identification cascades, drops, stack consumption), so an index would point
## to a different stack or out of bounds. Player.*_by_entry locates the
## current slot at action time. Audit H4 fix.
static func _build_buttons(entry: Dictionary, data: ItemData, player: Player,
		detail_dlg: GameDialog, bag_dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)

	var action_btn := Button.new()
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_btn.custom_minimum_size = Vector2(0, 72)
	action_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)

	match data.kind:
		"weapon":
			if player.equipped_weapon_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_weapon("")
					CombatLog.post(LocaleManager.t("LOG_YOU_UNEQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_weapon(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_EQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"armor":
			if player.equipped_armor_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_armor("")
					CombatLog.post(LocaleManager.t("LOG_YOU_UNEQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_armor(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_DON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"shield":
			if player.equipped_shield_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_shield("")
					CombatLog.post(LocaleManager.t("LOG_YOU_LOWER") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					if player.has_two_handed_weapon():
						CombatLog.post(LocaleManager.t("LOG_2_HAND_WEAPON_CANNOT_USE"),
							Color(1.0, 0.6, 0.4))
						detail_dlg.close()
						return
					player.set_equipped_shield(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_RAISE") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"helmet":
			if player.equipped_helmet_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_helmet("")
					CombatLog.post(LocaleManager.t("LOG_YOU_UNEQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_helmet(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_DON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"gloves":
			if player.equipped_gloves_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_gloves("")
					CombatLog.post(LocaleManager.t("LOG_YOU_UNEQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_gloves(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_DON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"boots":
			if player.equipped_boots_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_boots("")
					CombatLog.post(LocaleManager.t("LOG_YOU_UNEQUIP") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_boots(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_DON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"ring":
			if player.equipped_ring_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_ring("")
					CombatLog.post(LocaleManager.t("LOG_YOU_REMOVE") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_ring(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_PUT_ON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"amulet":
			if player.equipped_amulet_id == data.id:
				action_btn.text = LocaleManager.t("EQUIP_UNEQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_amulet("")
					CombatLog.post(LocaleManager.t("LOG_YOU_REMOVE") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = LocaleManager.t("EQUIP_EQUIP")
				action_btn.pressed.connect(func():
					player.set_equipped_amulet(String(entry.get("id", "")))
					CombatLog.post(LocaleManager.t("LOG_YOU_PUT_ON") % data.loc_name())
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"book":
			action_btn.text = LocaleManager.t("ITEM_ACTION_READ")
			action_btn.pressed.connect(func():
				if not player.use_item_by_entry(entry):
					CombatLog.post(LocaleManager.t("ITEM_NOT_FOUND"), Color(0.7, 0.7, 0.7))
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
		_:
			action_btn.text = LocaleManager.t("ITEM_ACTION_USE")
			action_btn.pressed.connect(func():
				if not player.use_item_by_entry(entry):
					CombatLog.post(LocaleManager.t("ITEM_NOT_FOUND"), Color(0.7, 0.7, 0.7))
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
	row.add_child(action_btn)

	var drop_btn := Button.new()
	drop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_btn.custom_minimum_size = Vector2(0, 72)
	drop_btn.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	drop_btn.text = LocaleManager.t("ITEM_ACTION_DROP")
	drop_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	drop_btn.pressed.connect(func():
		player.drop_item_by_entry(entry)
		detail_dlg.close()
		BagDialog._populate(bag_dlg, player))
	row.add_child(drop_btn)

	return row


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _kind_label(kind: String) -> String:
	match kind:
		"weapon": return LocaleManager.t("ITEM_KIND_WEAPON")
		"armor":  return LocaleManager.t("ITEM_KIND_ARMOR")
		"potion": return LocaleManager.t("ITEM_KIND_POTION")
		"scroll": return LocaleManager.t("ITEM_KIND_SCROLL")
		"book":   return LocaleManager.t("ITEM_KIND_BOOK")
		"gold":   return LocaleManager.t("ITEM_KIND_GOLD")
		"ring":   return LocaleManager.t("ITEM_KIND_RING")
		"amulet": return LocaleManager.t("ITEM_KIND_AMULET")
		"shield": return LocaleManager.t("ITEM_KIND_SHIELD")
		_:        return kind.capitalize()

static func _kind_color(kind: String) -> Color:
	match kind:
		"weapon": return Color(1.0, 0.75, 0.4)
		"armor":  return Color(0.55, 0.8, 1.0)
		"potion": return Color(0.5, 1.0, 0.6)
		"scroll": return Color(1.0, 0.95, 0.55)
		"book":   return Color(0.7, 0.55, 1.0)
		"ring":   return Color(1.0, 0.7, 0.9)
		"amulet": return Color(0.9, 0.75, 0.5)
		"shield": return Color(0.6, 0.75, 0.65)
		_:        return Color(0.75, 0.75, 0.75)
