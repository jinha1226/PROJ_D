extends Control

signal closed

@onready var _title: Label = $Panel/VBox/Title
@onready var _content: VBoxContainer = $Panel/VBox/ScrollContainer/Content
@onready var _close_btn: Button = $Panel/VBox/CloseButton

var _save_data: Dictionary = {}

func _ready() -> void:
	_title.text = LocaleManager.t("UI_TOWN_CHAR_TITLE")
	_close_btn.text = LocaleManager.t("UI_SHOP_BTN_DONE")
	_close_btn.pressed.connect(_on_close)
	_load_save()
	_build_content()

func _load_save() -> void:
	if SaveManager.has_save():
		_save_data = SaveManager.load_save()
	else:
		_save_data = {}

func _build_content() -> void:
	for child in _content.get_children():
		child.queue_free()
	if _save_data.is_empty():
		var empty := Label.new()
		empty.text = LocaleManager.t("UI_TOWN_CHAR_NO_SAVE")
		_content.add_child(empty)
		return
	var p: Dictionary = _save_data.get("player", {})
	var race_id: String = String(_save_data.get("selected_race_id", ""))
	_add_section_header(LocaleManager.t("UI_TOWN_CHAR_SEC_IDENTITY"))
	_add_row("Race", _race_display_name(race_id))
	_add_row("XL", "%d" % int(p.get("xl", 1)))
	_add_row("XP", "%d" % int(p.get("xp", 0)))
	_add_row("Gold", "%d" % int(p.get("gold", 0)))
	_add_section_header(LocaleManager.t("UI_TOWN_CHAR_SEC_VITALS"))
	_add_row("HP", "%d / %d" % [int(p.get("hp", 0)), int(p.get("hp_max", 0))])
	_add_row("MP", "%d / %d" % [int(p.get("mp", 0)), int(p.get("mp_max", 0))])
	_add_row("STR", "%d" % int(p.get("str", 0)))
	_add_row("DEX", "%d" % int(p.get("dex", 0)))
	_add_row("INT", "%d" % int(p.get("int", 0)))
	_add_row("AC", "%d" % int(p.get("ac", 0)))
	_add_row("EV", "%d" % int(p.get("ev", 0)))
	_add_row("WL", "%d" % int(p.get("wl", 0)))
	_add_section_header(LocaleManager.t("UI_TOWN_CHAR_SEC_EQUIP"))
	for slot in ["weapon", "armor", "shield", "helmet", "gloves", "boots", "ring", "amulet"]:
		var id: String = String(p.get(slot, ""))
		var label: String = id if id != "" else "—"
		if id != "" and ItemRegistry != null:
			var data = ItemRegistry.get_by_id(id)
			if data != null:
				label = data.display_name
		_add_row(slot.capitalize(), label)
	_add_section_header(LocaleManager.t("UI_TOWN_CHAR_SEC_SKILLS"))
	var skills: Dictionary = p.get("skills", {})
	if typeof(skills) != TYPE_DICTIONARY:
		skills = {}
	for sid in Player.SKILL_IDS:
		var entry: Dictionary = skills.get(sid, {"level": 0, "xp": 0.0})
		var lv: int = int(entry.get("level", 0))
		_add_row(String(sid).capitalize(), "Lv.%d" % lv)
	_add_section_header(LocaleManager.t("UI_TOWN_CHAR_SEC_ESSENCES"))
	var es: Array = p.get("essence_slots", [])
	if typeof(es) != TYPE_ARRAY:
		es = []
	var slot_count: int = es.size()
	for i in slot_count:
		var essence_id: String = String(es[i])
		var lab: String = "Slot %d: %s" % [i + 1, essence_id if essence_id != "" else "—"]
		var lbl := Label.new()
		lbl.text = lab
		lbl.add_theme_font_size_override("font_size", 18)
		_content.add_child(lbl)
	var inv: Array = p.get("essence_inventory", [])
	if typeof(inv) == TYPE_ARRAY and not inv.is_empty():
		var inv_strs: Array = []
		for item in inv:
			inv_strs.append(String(item))
		var inv_lbl := Label.new()
		inv_lbl.text = LocaleManager.t("UI_TOWN_CHAR_ESSENCE_INV") + ": " + ", ".join(inv_strs)
		inv_lbl.add_theme_font_size_override("font_size", 16)
		inv_lbl.add_theme_color_override("font_color", Color(0.7, 0.85, 0.95))
		inv_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		_content.add_child(inv_lbl)

func _race_display_name(race_id: String) -> String:
	if race_id == "":
		return "—"
	if RaceRegistry != null:
		var data = RaceRegistry.get_by_id(race_id)
		if data != null and data.display_name != "":
			return data.display_name
	return race_id.capitalize()

func _add_section_header(text: String) -> void:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 22)
	lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	_content.add_child(lbl)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 4)
	_content.add_child(spacer)

func _add_row(key: String, val: String) -> void:
	var row := HBoxContainer.new()
	var k := Label.new()
	k.text = key
	k.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	k.add_theme_font_size_override("font_size", 18)
	row.add_child(k)
	var v := Label.new()
	v.text = val
	v.add_theme_font_size_override("font_size", 18)
	v.add_theme_color_override("font_color", Color(0.85, 0.9, 0.95))
	row.add_child(v)
	_content.add_child(row)

func _on_close() -> void:
	emit_signal("closed")
	queue_free()
