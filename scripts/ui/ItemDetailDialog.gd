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
	var data: ItemData = ItemRegistry.get_by_id(String(entry.get("id", "")))
	if data == null:
		return
	var plus: int = int(entry.get("plus", 0))

	var title: String = GameManager.display_name_of(data.id)
	if plus > 0:
		title += "  +%d" % plus
	var dlg: GameDialog = GameDialog.create(title)
	parent.add_child(dlg)

	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 14)

	body.add_child(_build_header(data, plus))
	body.add_child(_build_description(data))
	body.add_child(_build_stats_card(data, plus))

	var cmp := _build_comparison(data, plus, player)
	if cmp != null:
		body.add_child(cmp)

	body.add_child(_build_buttons(item_index, data, player, dlg, bag_dlg))


# ── Header ────────────────────────────────────────────────────────────────────

static func _build_header(data: ItemData, plus: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Thumbnail 72×72
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if data.tile_path != "" and ResourceLoader.exists(data.tile_path):
		var rect := TextureRect.new()
		rect.texture = load(data.tile_path) as Texture2D
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
	right.add_theme_constant_override("separation", 6)

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
		text = "정체를 알 수 없다..."
	elif data.description != "":
		text = data.description
	else:
		text = _effect_desc(data)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	return lbl

static func _effect_desc(data: ItemData) -> String:
	if not GameManager.is_identified(data.id):
		return "정체를 알 수 없다..."
	match data.effect:
		"heal":           return "HP +%d 회복" % data.effect_value
		"restore_mp":     return "MP +%d 회복" % data.effect_value
		"map_reveal":     return "현재 층 맵 공개"
		"blink":          return "단거리 순간이동"
		"cure":           return "독 치료"
		"teleport":       return "랜덤 순간이동"
		"enchant_weapon": return "무기 +1 인챈트"
		"enchant_armor":  return "방어구 +1 인챈트"
		"berserk":        return "광란 상태 — 공격력 ↑, HP 소모"
		"identify":       return "아이템 감정"
		"study":          return "주문 습득 (마법책)"
		"might":          return "힘 일시 강화"
	return data.effect if data.effect != "" else "(설명 없음)"


# ── Stats card ────────────────────────────────────────────────────────────────

static func _build_stats_card(data: ItemData, plus: int) -> Control:
	var card := UICards.card(Color(0.5, 0.6, 0.8))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
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
		"potion", "scroll", "book":
			vbox.add_child(UICards.dim_hint("EFFECT", 22))
			vbox.add_child(UICards.accent_value(_effect_desc(data), 28))
		_:
			vbox.add_child(UICards.dim_hint("(기타 아이템)", 26))

	return card

static func _stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	return lbl


# ── Comparison card ───────────────────────────────────────────────────────────

static func _build_comparison(data: ItemData, plus: int, player: Player) -> Control:
	if data.kind == "weapon":
		if player.equipped_weapon_id == "" or player.equipped_weapon_id == data.id:
			return null
		var ew: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if ew == null:
			return null
		var ew_plus: int = int(player.equipped_weapon_entry().get("plus", 0))
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint("vs 장착: %s" % ew.display_name, 22))
		vbox.add_child(_delta_row("Damage",
				ew.damage + ew_plus, data.damage + plus, "d%d", "d%d"))
		return card

	elif data.kind == "armor":
		if player.equipped_armor_id == "" or player.equipped_armor_id == data.id:
			return null
		var ea: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
		if ea == null:
			return null
		var ea_plus: int = int(player.equipped_armor_entry().get("plus", 0))
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint("vs 장착: %s" % ea.display_name, 22))
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
	row.add_theme_constant_override("separation", 8)

	var key_lbl := Label.new()
	key_lbl.text = stat
	key_lbl.custom_minimum_size = Vector2(140, 0)
	key_lbl.add_theme_font_size_override("font_size", 26)
	key_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	row.add_child(key_lbl)

	var old_lbl := Label.new()
	old_lbl.text = old_fmt % old_val
	old_lbl.add_theme_font_size_override("font_size", 26)
	old_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	row.add_child(old_lbl)

	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 26)
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
	new_lbl.add_theme_font_size_override("font_size", 26)
	new_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if delta > 0
			else (Color(1.0, 0.4, 0.4) if delta < 0 else Color(0.7, 0.7, 0.7)))
	row.add_child(new_lbl)
	return row


# ── Action + Drop buttons ─────────────────────────────────────────────────────

static func _build_buttons(item_index: int, data: ItemData, player: Player,
		detail_dlg: GameDialog, bag_dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	var action_btn := Button.new()
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_btn.custom_minimum_size = Vector2(0, 72)
	action_btn.add_theme_font_size_override("font_size", 28)

	match data.kind:
		"weapon":
			if player.equipped_weapon_id == data.id:
				action_btn.text = "장착 해제"
				action_btn.pressed.connect(func():
					player.set_equipped_weapon("")
					CombatLog.post("You unequip %s." % data.display_name)
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = "장착"
				action_btn.pressed.connect(func():
					player.set_equipped_weapon(
							String(player.items[item_index].get("id", "")))
					CombatLog.post("You equip %s." % data.display_name)
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"armor":
			if player.equipped_armor_id == data.id:
				action_btn.text = "장착 해제"
				action_btn.pressed.connect(func():
					player.set_equipped_armor("")
					CombatLog.post("You unequip %s." % data.display_name)
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
			else:
				action_btn.text = "장착"
				action_btn.pressed.connect(func():
					player.set_equipped_armor(
							String(player.items[item_index].get("id", "")))
					CombatLog.post("You don %s." % data.display_name)
					detail_dlg.close()
					BagDialog._populate(bag_dlg, player)
					TurnManager.end_player_turn())
		"book":
			action_btn.text = "읽기"
			action_btn.pressed.connect(func():
				player.use_item(item_index)
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
		_:
			action_btn.text = "사용"
			action_btn.pressed.connect(func():
				player.use_item(item_index)
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
	row.add_child(action_btn)

	var drop_btn := Button.new()
	drop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_btn.custom_minimum_size = Vector2(0, 72)
	drop_btn.add_theme_font_size_override("font_size", 28)
	drop_btn.text = "버리기"
	drop_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	drop_btn.pressed.connect(func():
		player.drop_item(item_index)
		detail_dlg.close()
		BagDialog._populate(bag_dlg, player))
	row.add_child(drop_btn)

	return row


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _kind_label(kind: String) -> String:
	match kind:
		"weapon": return "무기"
		"armor":  return "방어구"
		"potion": return "포션"
		"scroll": return "스크롤"
		"book":   return "마법책"
		"gold":   return "골드"
		_:        return kind.capitalize()

static func _kind_color(kind: String) -> Color:
	match kind:
		"weapon": return Color(1.0, 0.75, 0.4)
		"armor":  return Color(0.55, 0.8, 1.0)
		"potion": return Color(0.5, 1.0, 0.6)
		"scroll": return Color(1.0, 0.95, 0.55)
		"book":   return Color(0.7, 0.55, 1.0)
		_:        return Color(0.75, 0.75, 0.75)
