extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const TALENT_SELECT_PATH: String = "res://scenes/menu/TalentSelect.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

enum SpotId { GATE, SHOP, GUILD, INN, BOARD, GRAVEYARD }

const SPOT_DATA := {
	SpotId.GATE: {
		"title": "Expedition Gate",
		"desc": "Start the next run and step out into the dungeon.",
	},
	SpotId.SHOP: {
		"title": "Market Stall",
		"desc": "Buy, sell, and prepare your loadout.",
	},
	SpotId.GUILD: {
		"title": "Guild Hall",
		"desc": "Check the current character, records, and status.",
	},
	SpotId.INN: {
		"title": "Purification Altar",
		"desc": "Remove an equipped essence for a fee. The essence returns to your inventory.",
	},
	SpotId.BOARD: {
		"title": "Recruit Board",
		"desc": "Create a new survivor or start a fresh roster entry.",
	},
	SpotId.GRAVEYARD: {
		"title": "Graveyard",
		"desc": "Those who fell before you rest here.",
	},
}

@onready var _subtitle: Label = $Header/TitleBox/Subtitle
@onready var _menu_btn: Button = $Header/MenuButton
@onready var _char_status: Label = $Footer/FooterHBox/StatusBox/CharacterStatus
@onready var _expedition_count: Label = $Footer/FooterHBox/StatusBox/ExpeditionCount
@onready var _spot_title: Label = $Footer/FooterHBox/SpotBox/SpotTitle
@onready var _spot_desc: Label = $Footer/FooterHBox/SpotBox/SpotDesc

var _spot_buttons: Dictionary = {}
var _hovered_spot: int = SpotId.GATE
var _spot_default_desc: String = "Choose a building to open its screen."

func _ready() -> void:
	if ResourceLoader.exists("res://scripts/ui/GameTheme.gd"):
		theme = load("res://scripts/ui/GameTheme.gd").create()
	_menu_btn.pressed.connect(_on_menu)
	_build_hotspots()
	_update_ui()

func _build_hotspots() -> void:
	_register_spot(SpotId.GATE, $Hotspots/GateButton, Callable(self, "_on_gate"))
	_register_spot(SpotId.SHOP, $Hotspots/ShopButton, Callable(self, "_on_shop"))
	_register_spot(SpotId.GUILD, $Hotspots/GuildButton, Callable(self, "_on_guild"))
	_register_spot(SpotId.INN, $Hotspots/InnButton, Callable(self, "_on_inn"))
	_register_spot(SpotId.BOARD, $Hotspots/BoardButton, Callable(self, "_on_board"))
	if has_node("Hotspots/GraveyardButton"):
		_register_spot(SpotId.GRAVEYARD, $Hotspots/GraveyardButton, Callable(self, "_on_graveyard"))

func _register_spot(id: int, button: Button, action: Callable) -> void:
	if button == null:
		return
	_spot_buttons[id] = button
	button.flat = true
	button.text = ""
	button.focus_mode = Control.FOCUS_NONE
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.tooltip_text = String(SPOT_DATA[id]["title"])
	_apply_hotspot_style(button)
	button.mouse_entered.connect(_on_spot_hover.bind(id))
	button.mouse_exited.connect(_on_spot_exit.bind(id))
	button.pressed.connect(_on_spot_hover.bind(id))  # touch: update name on tap
	button.pressed.connect(action)
	_add_spot_label(button, String(SPOT_DATA[id]["title"]))

func _add_spot_label(button: Button, title: String) -> void:
	var lbl := Label.new()
	lbl.text = title
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	lbl.anchor_left = 0.0
	lbl.anchor_top = 0.0
	lbl.anchor_right = 1.0
	lbl.anchor_bottom = 1.0
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7, 1.0))
	# Shadow for readability over dark backgrounds
	lbl.add_theme_constant_override("shadow_offset_x", 1)
	lbl.add_theme_constant_override("shadow_offset_y", 1)
	lbl.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.85))
	lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	button.add_child(lbl)

func _apply_hotspot_style(button: Button) -> void:
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(0.95, 0.82, 0.45, 0.02)
	normal.border_width_left = 2
	normal.border_width_top = 2
	normal.border_width_right = 2
	normal.border_width_bottom = 2
	normal.border_color = Color(0.95, 0.82, 0.45, 0.18)
	normal.content_margin_left = 0
	normal.content_margin_top = 0
	normal.content_margin_right = 0
	normal.content_margin_bottom = 0

	var hover := normal.duplicate() as StyleBoxFlat
	hover.border_color = Color(0.95, 0.82, 0.45, 0.7)
	hover.bg_color = Color(0.95, 0.82, 0.45, 0.08)

	var pressed := normal.duplicate() as StyleBoxFlat
	pressed.border_color = Color(0.95, 0.82, 0.45, 0.95)
	pressed.bg_color = Color(0.95, 0.82, 0.45, 0.14)

	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("focus", hover)

func _update_ui() -> void:
	_expedition_count.text = LocaleManager.t("UI_TOWN_EXPEDITION_COUNT") % TownState.expedition_count
	_subtitle.text = _build_subtitle()
	_update_character_status()
	_show_spot(_hovered_spot)

func _update_character_status() -> void:
	if TownState.current_character_alive:
		var race_name: String = TownState.current_character_race.capitalize()
		if RaceRegistry != null:
			var race_data = RaceRegistry.get_by_id(TownState.current_character_race)
			if race_data != null and race_data.display_name != "":
				race_name = race_data.display_name
		var talent_name: String = _talent_display_name(TownState.current_character_talent)
		var last_line: String = ""
		var has_safe_return: bool = false
		if not TownState.last_character_summary.is_empty():
			var s: Dictionary = TownState.last_character_summary
			if bool(s.get("safe_return", false)):
				has_safe_return = true
				last_line = LocaleManager.t("UI_TOWN_STATUS_ACTIVE_RETURNED") % int(s.get("depth_reached", 0))
		if has_safe_return:
			_char_status.text = LocaleManager.t("UI_TOWN_STATUS_ACTIVE_MEMORIAL") % [race_name, last_line]
		elif GameManager.starter_shop_gold > 0:
			_char_status.text = "%s\nTalent: %s\n초기 지원금 %dg — 상점에서 장비를 구매하세요" % [race_name, talent_name, GameManager.starter_shop_gold]
		else:
			_char_status.text = "%s\nTalent: %s" % [LocaleManager.t("UI_TOWN_STATUS_ACTIVE_READY") % race_name, talent_name]
	else:
		if TownState.has_last_summary():
			var s: Dictionary = TownState.last_character_summary
			var race := String(s.get("race", "?"))
			var depth := int(s.get("depth_reached", 0))
			var killer := String(s.get("death_cause", "unknown"))
			var victory := bool(s.get("victory", false))
			if victory:
				_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_VICTORY") % race.capitalize()
			else:
				_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_DEATH") % [race.capitalize(), depth, killer]
		else:
			_char_status.text = LocaleManager.t("UI_TOWN_STATUS_NO_CHAR_FIRST")

func _build_subtitle() -> String:
	if TownState.current_character_alive:
		return "Camp hub ready for the next expedition"
	if TownState.has_last_summary():
		return "A quiet estate between deaths and returns"
	return "Build the first survivor and open the gate"

func _show_spot(id: int) -> void:
	_hovered_spot = id
	var data: Dictionary = SPOT_DATA.get(id, {})
	_spot_title.text = String(data.get("title", "Town"))
	_spot_desc.text = String(data.get("desc", _spot_default_desc))

func _on_spot_hover(id: int) -> void:
	_show_spot(id)

func _on_spot_exit(_id: int) -> void:
	_show_spot(SpotId.GATE)

func _on_gate() -> void:
	GameManager.load_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_shop() -> void:
	var shop_scene: PackedScene = load("res://scenes/town/TownShop.tscn")
	if shop_scene == null:
		return
	var shop_node: Node = shop_scene.instantiate()
	add_child(shop_node)
	if shop_node.has_signal("closed"):
		shop_node.closed.connect(_update_ui)

func _on_guild() -> void:
	var scene: PackedScene = load("res://scenes/town/TownCharacterDialog.tscn")
	if scene == null:
		return
	var node: Node = scene.instantiate()
	add_child(node)
	if node.has_signal("closed"):
		node.closed.connect(_update_ui)

func _on_inn() -> void:
	var dlg := GameDialog.create("정수 정화")
	add_child(dlg)
	_build_purge_dialog(dlg)

const PURGE_COST: int = 150

func _build_purge_dialog(dlg: GameDialog) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()

	if not SaveManager.has_save():
		var no_save := Label.new()
		no_save.text = "활성 캐릭터가 없습니다."
		no_save.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		body.add_child(no_save)
		return

	var save_data: Dictionary = SaveManager.load_save()
	var p: Dictionary = save_data.get("player", {})
	var gold: int = int(p.get("gold", 0))
	var slots: Array = p.get("essence_slots", [])

	var gold_lbl := Label.new()
	gold_lbl.text = "보유 골드: %dg" % gold
	gold_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	gold_lbl.add_theme_color_override("font_color", Color(0.95, 0.85, 0.45))
	body.add_child(gold_lbl)

	var hint_lbl := Label.new()
	hint_lbl.text = "슬롯당 제거 비용: %dg  ·  정수는 인벤토리로 반환됩니다." % PURGE_COST
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	hint_lbl.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
	body.add_child(hint_lbl)

	var has_any := false
	for i in slots.size():
		var eid: String = String(slots[i])
		if eid == "":
			continue
		has_any = true

		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		body.add_child(row)

		var icon := TextureRect.new()
		icon.texture = EssenceSystem.icon_texture_of(eid)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		row.add_child(icon)

		var name_lbl := Label.new()
		name_lbl.text = "슬롯 %d: %s" % [i + 1, EssenceSystem.display_name(eid)]
		name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		name_lbl.add_theme_color_override("font_color", EssenceSystem.color_of(eid))
		row.add_child(name_lbl)

		var btn := Button.new()
		btn.text = "제거 (%dg)" % PURGE_COST
		btn.custom_minimum_size = Vector2(0, 48)
		btn.disabled = gold < PURGE_COST
		var slot_index := i
		btn.pressed.connect(func():
			var sd: Dictionary = SaveManager.load_save()
			var pp: Dictionary = sd.get("player", {})
			var g: int = int(pp.get("gold", 0))
			if g < PURGE_COST:
				return
			var slts: Array = pp.get("essence_slots", [])
			if slot_index >= slts.size():
				return
			var removed_id: String = String(slts[slot_index])
			slts[slot_index] = ""
			pp["essence_slots"] = slts
			var inv: Array = pp.get("essence_inventory", [])
			if typeof(inv) != TYPE_ARRAY:
				inv = []
			inv.append(removed_id)
			pp["essence_inventory"] = inv
			pp["gold"] = g - PURGE_COST
			sd["player"] = pp
			SaveManager.save(sd)
			_build_purge_dialog(dlg)
		)
		row.add_child(btn)

	if not has_any:
		var empty := Label.new()
		empty.text = "장착된 정수가 없습니다."
		empty.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		empty.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
		body.add_child(empty)

func _on_board() -> void:
	get_tree().change_scene_to_file(TALENT_SELECT_PATH)

func _talent_display_name(talent_id: String) -> String:
	if talent_id == "":
		return "—"
	return TalentSystem.display_name(talent_id)

func _on_graveyard() -> void:
	var records: Array = TownState.death_records
	var dlg := GameDialog.create("Graveyard")
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if records.is_empty():
		var lbl := Label.new()
		lbl.text = "No one has fallen yet."
		lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		body.add_child(lbl)
	else:
		for rec in records:
			var lbl := Label.new()
			var xl: int = int(rec.get("xl", 1))
			var depth: int = int(rec.get("depth_reached", 0))
			var killer: String = String(rec.get("death_cause", "unknown"))
			var talent: String = String(rec.get("talent", ""))
			var talent_str: String = (" · " + TalentSystem.display_name(talent)) if talent != "" else ""
			lbl.text = "XL%d%s  ·  %dF  ·  %s" % [xl, talent_str, depth, killer]
			lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
			lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 0.65))
			body.add_child(lbl)

func _on_menu() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
