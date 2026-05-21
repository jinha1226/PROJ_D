extends Control

const GAME_SCENE_PATH: String = "res://scenes/main/Game.tscn"
const MENU_SCENE_PATH: String = "res://scenes/menu/MainMenu.tscn"

@onready var _scroll: ScrollContainer = $ScrollContainer
@onready var _container: VBoxContainer = $ScrollContainer/VBox
@onready var _back_btn: Button = $BackButton

func _ready() -> void:
	theme = GameTheme.create()
	_back_btn.pressed.connect(_on_back)
	TouchScrollHelper.install(_scroll)
	_build_cards()

func _build_cards() -> void:
	for child in _container.get_children():
		child.queue_free()
	var ids: Array = RaceRegistry.ids_in_order()
	if ids.is_empty():
		var lab := Label.new()
		lab.text = LocaleManager.t("RACESELECT_EMPTY")
		_container.add_child(lab)
		return
	for id in ids:
		var data: RaceData = RaceRegistry.get_by_id(id)
		if data == null:
			continue
		_container.add_child(_make_card(data))

func _make_card(data: RaceData) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(0, 200)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 18)
	margin.add_theme_constant_override("margin_right", 18)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)

	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 16)
	margin.add_child(hb)

	var portrait := _make_portrait(data)
	hb.add_child(portrait)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 4)
	hb.add_child(vb)

	var name_lab := Label.new()
	name_lab.text = data.loc_name()
	name_lab.add_theme_font_size_override("font_size", 40)
	var name_col: Color = Color(0.95, 0.85, 0.5) if data.unlocked \
			else Color(0.55, 0.55, 0.6)
	name_lab.add_theme_color_override("font_color", name_col)
	vb.add_child(name_lab)

	var desc_lab := Label.new()
	desc_lab.text = data.loc_description()
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lab.add_theme_font_size_override("font_size", 20)
	desc_lab.add_theme_color_override("font_color", Color(0.68, 0.65, 0.6))
	desc_lab.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.add_child(desc_lab)

	var apt_row := _make_apt_row(data)
	if apt_row != null:
		vb.add_child(apt_row)

	var unlocked: bool = RaceRegistry.is_unlocked(data.id)
	if not unlocked:
		var hint_lab := Label.new()
		hint_lab.text = data.unlock_hint()
		hint_lab.add_theme_font_size_override("font_size", 20)
		hint_lab.add_theme_color_override("font_color", Color(1.0, 0.7, 0.45))
		hint_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		vb.add_child(hint_lab)

	if not unlocked:
		var locked_lbl := Label.new()
		locked_lbl.text = LocaleManager.t("COMMON_LOCKED")
		locked_lbl.add_theme_font_size_override("font_size", 22)
		locked_lbl.add_theme_color_override("font_color", Color(0.7, 0.55, 0.4))
		vb.add_child(locked_lbl)
		return panel

	# The whole card is the tap target — no separate Pick button.
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

const _DEFAULT_BODY: String = "res://assets/tiles/individual/player/body/leather_armour.png"

func _make_portrait(data: RaceData) -> Control:
	var cont := Control.new()
	cont.custom_minimum_size = Vector2(96, 120)
	cont.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var dim: bool = not RaceRegistry.is_unlocked(data.id)
	if data.menu_portrait_path != "" and ResourceLoader.exists(data.menu_portrait_path):
		_add_layer(cont, data.menu_portrait_path, dim)
	else:
		if data.base_sprite_path != "" and ResourceLoader.exists(data.base_sprite_path):
			_add_layer(cont, data.base_sprite_path, dim)
		_add_layer(cont, _DEFAULT_BODY, dim)
	return cont

func _add_layer(parent: Control, path: String, dim: bool) -> void:
	if not ResourceLoader.exists(path):
		return
	var rect := TextureRect.new()
	rect.texture = load(path)
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if dim:
		rect.modulate = Color(0.4, 0.4, 0.45, 1)
	parent.add_child(rect)

# 9-skill visible aptitude row. Each cell aggregates the race's
# sub-skill aptitudes into the canonical PROJ_G bucket — race .tres files
# still store DCSS sub-skill ids (short_blades, fire, dodging, ...) and
# we average those that map to the same visible skill.
const _APT_ORDER: Array = [
	"weapon_mastery", "archery", "tactics", "defense",
	"magery", "stealth", "lockpicking", "tracking", "survival",
]
const _APT_LABELS: Dictionary = {
	"weapon_mastery": "Melee", "archery": "Bow", "tactics": "Tac", "defense": "Def",
	"magery": "Mag", "stealth": "Sth", "lockpicking": "Lock", "tracking": "Trk", "survival": "Surv",
}

func _aggregate_aptitude(data: RaceData, visible_id: String) -> int:
	# Direct hit first (race file uses the visible id explicitly — rare).
	if data.skill_aptitudes.has(visible_id):
		return int(data.skill_aptitudes[visible_id])
	# Otherwise average all sub-skill aptitudes that remap to this visible id.
	var total: float = 0.0
	var count: int = 0
	for sub_id in Player.HIDDEN_SUBSKILL_IDS:
		if String(Player.SKILL_REMAP.get(sub_id, "")) != visible_id:
			continue
		if data.skill_aptitudes.has(sub_id):
			total += float(data.skill_aptitudes[sub_id])
			count += 1
	if count == 0:
		return 0
	return int(round(total / float(count)))

func _make_apt_row(data: RaceData) -> Control:
	if data.skill_aptitudes.is_empty():
		return null
	var flow := HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", 10)
	flow.add_theme_constant_override("v_separation", 4)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var any := false
	for sid in _APT_ORDER:
		var apt: int = _aggregate_aptitude(data, sid)
		if apt == 0:
			continue
		any = true
		var lbl := Label.new()
		lbl.text = "%s %+d" % [_APT_LABELS[sid], apt]
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color",
			Color(0.45, 0.9, 0.5) if apt > 0 else Color(0.9, 0.45, 0.45))
		flow.add_child(lbl)
	return flow if any else null

func _on_pick(race_id: String) -> void:
	GameManager.selected_race_id = race_id
	get_tree().change_scene_to_file(GAME_SCENE_PATH)

func _on_back() -> void:
	get_tree().change_scene_to_file(MENU_SCENE_PATH)
