extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const DEFAULT_BASE_PATH: String = "res://assets/tiles/individual/player/base/human_m.png"

# Category-based grouping (replaces class_group). Maps to ClassData.category.
const CATEGORY_ORDER: Array = [
	{"id": "Melee",  "label": "MELEE"},
	{"id": "Ranged", "label": "RANGED"},
	{"id": "Magic",  "label": "MAGIC"},
	{"id": "Other",  "label": "OTHER"},
]

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton

# Default = starter classes only. Toggle button reveals advanced/unlocked.
var _show_advanced: bool = false


func _ready() -> void:
	theme = GameTheme.create()
	_back_btn.pressed.connect(_on_back)
	TouchScrollHelper.install(_scroll)
	if GameManager.selected_race_id == "":
		GameManager.selected_race_id = "human"
	if ClassRegistry.all.is_empty():
		ClassRegistry._scan()
	_build_class_list()


func _build_class_list() -> void:
	for child in _container.get_children():
		child.queue_free()

	# Toggle row at top: starter ↔ advanced
	_container.add_child(_make_toggle_button())

	# Bucket classes by category, filtered by view mode
	var by_cat: Dictionary = {}
	for entry in CATEGORY_ORDER:
		by_cat[entry["id"]] = []
	for data in ClassRegistry.all:
		if _show_advanced:
			# Advanced view hides starters AND debug classes
			if data.is_starter or data.is_debug:
				continue
		else:
			# Starter view shows starters + debug classes (archmage etc. for testing)
			if not (data.is_starter or data.is_debug):
				continue
		var c: String = String(data.category)
		if by_cat.has(c):
			by_cat[c].append(data)
		elif by_cat.has("Other"):
			by_cat["Other"].append(data)

	var first_group := true
	var any_shown := false
	for entry in CATEGORY_ORDER:
		var cat_id: String = entry["id"]
		var classes: Array = by_cat.get(cat_id, [])
		if classes.is_empty():
			continue
		any_shown = true
		if not first_group:
			var spacer := Control.new()
			spacer.custom_minimum_size = Vector2(0, 8)
			_container.add_child(spacer)
		first_group = false

		var hdr := Label.new()
		hdr.text = entry["label"]
		hdr.add_theme_font_size_override("font_size", 20)
		hdr.add_theme_color_override("font_color", Color(0.65, 0.72, 0.85))
		_container.add_child(hdr)

		for data in classes:
			_container.add_child(_make_card(data))

	# Empty-state message (e.g. advanced view with nothing unlocked yet)
	if not any_shown:
		var empty := Label.new()
		empty.text = LocaleManager.t("JOBSELECT_NO_ADVANCED") if _show_advanced \
			else LocaleManager.t("JOBSELECT_NO_BASIC")
		empty.add_theme_font_size_override("font_size", 18)
		empty.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
		_container.add_child(empty)


func _make_toggle_button() -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, GameTheme.TAP_MIN_HEIGHT)
	btn.add_theme_font_size_override("font_size", 22)
	if _show_advanced:
		btn.text = LocaleManager.t("JOBSELECT_STARTER")
	else:
		btn.text = LocaleManager.t("JOBSELECT_ADVANCED")
	btn.pressed.connect(_on_toggle_advanced)
	return btn


func _on_toggle_advanced() -> void:
	_show_advanced = not _show_advanced
	_build_class_list()
	_scroll.scroll_vertical = 0


func _make_card(data: ClassData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 200)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 14)
	margin.add_theme_constant_override("margin_right", 14)
	margin.add_theme_constant_override("margin_top", 12)
	margin.add_theme_constant_override("margin_bottom", 12)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	margin.add_child(hb)

	var unlocked: bool = ClassRegistry.is_unlocked(data.id)
	hb.add_child(_make_portrait(data, not unlocked))

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)

	var name_lab := Label.new()
	name_lab.text = data.loc_name()
	name_lab.add_theme_font_size_override("font_size", 36)
	name_lab.add_theme_color_override("font_color", Color(0.95, 0.85, 0.5))
	vb.add_child(name_lab)

	var gear_lab := Label.new()
	gear_lab.text = _gear_line(data)
	gear_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	gear_lab.add_theme_font_size_override("font_size", 20)
	gear_lab.add_theme_color_override("font_color", Color(0.78, 0.82, 0.9))
	vb.add_child(gear_lab)

	var skill_lab := Label.new()
	skill_lab.text = _skills_line(data)
	skill_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skill_lab.add_theme_font_size_override("font_size", 20)
	skill_lab.add_theme_color_override("font_color", Color(0.72, 0.9, 0.72))
	vb.add_child(skill_lab)

	var stat_lab := Label.new()
	stat_lab.text = "HP %d  MP %d   STR %d / DEX %d / INT %d" % [
		data.starting_hp + data.starting_str / 2, data.starting_mp,
		data.starting_str, data.starting_dex, data.starting_int
	]
	stat_lab.add_theme_font_size_override("font_size", 18)
	stat_lab.add_theme_color_override("font_color", Color(0.6, 0.62, 0.7))
	vb.add_child(stat_lab)

	if not unlocked:
		var hint_lab := Label.new()
		hint_lab.text = data.unlock_hint()
		hint_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hint_lab.add_theme_font_size_override("font_size", 18)
		hint_lab.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))
		vb.add_child(hint_lab)

	if not unlocked:
		return panel

	# Tap the whole card to pick — Pick button removed per UX feedback.
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var touch_y := [-9999.0]
	panel.gui_input.connect(func(ev: InputEvent) -> void:
		if ev is InputEventScreenTouch:
			if ev.pressed:
				touch_y[0] = ev.position.y
			elif touch_y[0] > -9000.0 and absf(ev.position.y - touch_y[0]) < 16.0:
				touch_y[0] = -9999.0
				_on_pick(data.id)
			else:
				touch_y[0] = -9999.0
		elif ev is InputEventMouseButton and not ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			_on_pick(data.id))

	return panel


func _make_portrait(data: ClassData, dim: bool) -> Control:
	var cont := Control.new()
	cont.custom_minimum_size = Vector2(120, 130)
	cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var race: RaceData = RaceRegistry.get_by_id(GameManager.selected_race_id)
	var base_path: String = DEFAULT_BASE_PATH
	if race != null and race.base_sprite_path != "" and ResourceLoader.exists(race.base_sprite_path):
		base_path = race.base_sprite_path
	_add_layer(cont, base_path, dim)
	if data != null:
		var body_path: String = ""
		if String(data.robe_path) != "":
			body_path = String(data.robe_path)
		elif data.starting_armor != "" and Player.DOLL_BODY_MAP.has(data.starting_armor):
			body_path = String(Player.DOLL_BODY_MAP[data.starting_armor])
		if body_path != "":
			_add_layer(cont, body_path, dim)
		if data.starting_weapon != "" and Player.DOLL_HAND1_MAP.has(data.starting_weapon):
			_add_layer(cont, String(Player.DOLL_HAND1_MAP[data.starting_weapon]), dim)
	return cont


func _add_layer(parent: Control, path: String, dim: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		rect.modulate = Color(0.4, 0.4, 0.45, 1)
	parent.add_child(rect)


func _gear_line(data: ClassData) -> String:
	var parts: Array = []
	if data.starting_weapon != "":
		parts.append(_item_name(data.starting_weapon))
	if data.starting_shield != "":
		parts.append(_item_name(data.starting_shield))
	if data.starting_armor != "":
		parts.append(_item_name(data.starting_armor))
	for extra in _starter_extras(data.id):
		parts.append(extra)
	if parts.is_empty():
		return "Gear: none"
	return "Gear: " + " / ".join(parts)


func _starter_extras(class_id: String) -> Array:
	# Read directly from ClassData.starter_items for display.
	# TODO: this could be moved to a shared formatter; left here as it formats item ids → display strings.
	if ClassRegistry == null or class_id == "":
		return []
	var data: ClassData = ClassRegistry.get_by_id(class_id)
	if data == null:
		return []
	var out: Array = []
	for item_id in data.starter_items:
		out.append(_item_name(String(item_id)))
	return out


func _skills_line(data: ClassData) -> String:
	if data.starting_skills.is_empty():
		return "Skills: none"
	var parts: Array = []
	for key in data.starting_skills.keys():
		parts.append("%s %d" % [String(key).capitalize(), int(data.starting_skills[key])])
	return "Skills: " + " / ".join(parts)


func _item_name(id: String) -> String:
	var it: ItemData = ItemRegistry.get_by_id(id) if ItemRegistry != null and id != "" else null
	return it.display_name if it != null else id


func _on_pick(class_id: String) -> void:
	GameManager.selected_starting_weapon_id = ""
	GameManager.selected_starting_school_id = ""
	GameManager.selected_class_id = class_id
	GameManager.start_new_run()
	get_tree().change_scene_to_file(GAME_SCENE_PATH)


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
