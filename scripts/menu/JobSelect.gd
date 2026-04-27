extends Control

const ESSENCE_SELECT_PATH: String = "res://scenes/menu/EssenceSelect.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"
const DEFAULT_BASE_PATH: String = "res://assets/tiles/individual/player/base/human_m.png"
const FIGHTER_START_WEAPONS: Array = ["short_sword", "mace", "battle_axe", "spear"]

const BASE_CLASSES: Array = ["warrior", "mage", "rogue"]
const TEST_CLASSES: Array = ["archmage"]

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton


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
	for id in BASE_CLASSES:
		var data: ClassData = ClassRegistry.get_by_id(id)
		if data != null:
			_container.add_child(_make_card(data))

	if not TEST_CLASSES.is_empty():
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(0, 16)
		_container.add_child(spacer)

		var hdr := Label.new()
		hdr.text = "TEST CLASSES"
		hdr.add_theme_font_size_override("font_size", 22)
		hdr.add_theme_color_override("font_color", Color(0.8, 0.72, 1.0))
		_container.add_child(hdr)

		for id in TEST_CLASSES:
			var tdata: ClassData = ClassRegistry.get_by_id(id)
			if tdata != null:
				_container.add_child(_make_card(tdata))


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
	name_lab.text = data.display_name
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
		data.starting_hp, data.starting_mp,
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

	var pick_btn := Button.new()
	pick_btn.custom_minimum_size = Vector2(0, 56)
	pick_btn.add_theme_font_size_override("font_size", 24)
	if unlocked:
		pick_btn.text = "Start as %s" % data.display_name
		pick_btn.pressed.connect(_on_pick.bind(data.id))
	else:
		pick_btn.text = "Locked"
		pick_btn.disabled = true
	vb.add_child(pick_btn)

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
	match class_id:
		"warrior":
			return ["healing x2"]
		"mage":
			return ["healing", "magic potion"]
		"rogue":
			return ["dagger", "healing", "invisibility", "shrouding"]
		"archmage":
			return ["healing", "magic potion", "identify", "blinking", "fire wand", "frost wand", "lightning wand"]
	return []


func _skills_line(data: ClassData) -> String:
	if data.starting_skills.is_empty():
		return "Skills: none"
	var parts: Array = []
	for key in data.starting_skills.keys():
		parts.append("%s %d" % [String(key).capitalize(), int(data.starting_skills[key])])
	return "Skills: " + " / ".join(parts)


func _item_name(id: String) -> String:
	var it: ItemData = ItemRegistry.get_by_id(id)
	return it.display_name if it != null else id


func _on_pick(class_id: String) -> void:
	if class_id == "warrior":
		_open_fighter_weapon_choice(class_id)
		return
	GameManager.selected_starting_weapon_id = ""
	GameManager.selected_class_id = class_id
	get_tree().change_scene_to_file(ESSENCE_SELECT_PATH)


func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)


func _open_fighter_weapon_choice(class_id: String) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Choose Fighter Weapon", 0.86, 0.72)
	add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 10)
	var intro := Label.new()
	intro.text = "Pick your starting weapon."
	intro.add_theme_font_size_override("font_size", 28)
	body.add_child(intro)
	for item_id in FIGHTER_START_WEAPONS:
		var choice_id: String = item_id
		var item: ItemData = ItemRegistry.get_by_id(choice_id)
		if item == null:
			continue
		var btn := Button.new()
		btn.text = "%s  (d%d)" % [item.display_name.capitalize(), item.damage]
		btn.custom_minimum_size = Vector2(0, 68)
		btn.add_theme_font_size_override("font_size", 26)
		btn.pressed.connect(func():
			GameManager.selected_starting_weapon_id = choice_id
			GameManager.selected_class_id = class_id
			get_tree().change_scene_to_file(ESSENCE_SELECT_PATH))
		body.add_child(btn)
		var desc := Label.new()
		desc.text = item.description
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", 18)
		desc.add_theme_color_override("font_color", Color(0.72, 0.75, 0.82))
		body.add_child(desc)
