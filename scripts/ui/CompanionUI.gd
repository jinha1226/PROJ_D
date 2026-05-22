class_name CompanionUI extends RefCounted

## Companion detail dialog. Shows stats, equipment, and loyalty info.
## Future: item-transfer between player and companion.

static func open(companion_data: CompanionData, player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio(companion_data.display_name, 0.9, 0.9)
	parent.add_child(dlg)
	_rebuild(dlg, companion_data, player, parent)


static func _rebuild(dlg: GameDialog, data: CompanionData, player: Player, parent: Node) -> void:
	var body: VBoxContainer = dlg.get_body()
	for c in body.get_children():
		c.queue_free()

	body.add_child(_loyalty_card(data))
	body.add_child(_vitals_card(data))
	body.add_child(_stats_card(data))
	body.add_child(_equipment_card(data))
	body.add_child(_actions_card(dlg, data, player, parent))


# ── Cards ─────────────────────────────────────────────────────────────────────

static func _loyalty_card(data: CompanionData) -> Control:
	var card := _make_card()
	var star_text: String = "★".repeat(data.loyalty_runs) + "☆".repeat(
		max(0, CompanionData.LONG_TERM_THRESHOLD - data.loyalty_runs))
	_add_row(card, "종족", _race_label(data.race_id))
	_add_row(card, "직업", _job_label(data.job_id))
	_add_row(card, "레벨", "XL " + str(data.xl))
	_add_row(card, "충성도", star_text + ("  [장기 동료]" if data.is_long_term else ""))
	return card


static func _vitals_card(data: CompanionData) -> Control:
	var card := _make_card()
	_add_row(card, "HP", str(data.hp_max) + " / " + str(data.hp_max))
	if data.mp_max > 0:
		_add_row(card, "MP", str(data.mp_max) + " / " + str(data.mp_max))
	_add_row(card, "AC", str(data.ac))
	_add_row(card, "EV", str(data.ev))
	return card


static func _stats_card(data: CompanionData) -> Control:
	var card := _make_card()
	_add_row(card, "힘", str(data.strength))
	_add_row(card, "민첩", str(data.dexterity))
	_add_row(card, "지능", str(data.intelligence))
	return card


static func _equipment_card(data: CompanionData) -> Control:
	var card := _make_card()
	var slots: Array = [
		["무기", data.equipped_weapon_id],
		["갑옷", data.equipped_armor_id],
		["방패", data.equipped_shield_id],
		["투구", data.equipped_helmet_id],
		["장갑", data.equipped_gloves_id],
		["신발", data.equipped_boots_id],
		["반지", data.equipped_ring_id],
		["부적", data.equipped_amulet_id],
	]
	for slot_pair in slots:
		var slot_name: String = slot_pair[0]
		var item_id: String = slot_pair[1]
		if item_id != "":
			var label: String = _item_display_name(item_id)
			_add_row(card, slot_name, label)
	if card.get_child_count() == 0:
		_add_row(card, "장비", "없음")
	return card


static func _actions_card(dlg: GameDialog, data: CompanionData,
		_player: Player, _parent: Node) -> Control:
	var card := _make_card()
	var dismiss_btn := Button.new()
	dismiss_btn.text = "해고"
	dismiss_btn.pressed.connect(func() -> void:
		var pm = Engine.get_main_loop().get_root().get_node_or_null("/root/PartyManager")
		if pm != null:
			pm.dismiss(data.id)
		dlg.close())
	card.add_child(dismiss_btn)
	return card


# ── Helpers ───────────────────────────────────────────────────────────────────

static func _make_card() -> VBoxContainer:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	return v


static func _add_row(parent: Control, label: String, value: String) -> void:
	var h := HBoxContainer.new()
	var lbl := Label.new()
	lbl.text = label
	lbl.custom_minimum_size.x = 80
	lbl.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	var val := Label.new()
	val.text = value
	val.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	h.add_child(lbl)
	h.add_child(val)
	parent.add_child(h)


static func _race_label(race_id: String) -> String:
	var map: Dictionary = {
		"human": "인간", "elf": "엘프", "dwarf": "드워프",
		"hill_orc": "힐 오크", "troll": "트롤", "vampire": "뱀파이어",
		"minotaur": "미노타우르", "kobold": "코볼드",
		"spriggan": "스프리간", "gargoyle": "가고일",
	}
	return str(map.get(race_id, race_id))


static func _job_label(job_id: String) -> String:
	var map: Dictionary = {
		"fighter": "전사", "ranger": "궁수", "mage": "마법사",
	}
	return str(map.get(job_id, job_id))


static func _item_display_name(item_id: String) -> String:
	if ItemRegistry == null:
		return item_id
	var data: ItemData = ItemRegistry.get_by_id(item_id)
	if data == null:
		return item_id
	return data.display_name if data.display_name != "" else item_id
