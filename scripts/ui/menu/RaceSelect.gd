extends Control
## Race-selection screen. Loads all resources/races/*.tres, renders a
## 2-column scrollable card grid with live LPC-composited previews.

const CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const RACE_IDS: Array[String] = [
	"human", "hill_orc", "minotaur", "deep_elf",
	"troll", "spriggan", "catfolk", "draconian",
]

var _selected_id: String = ""
var _cards: Dictionary = {}  # race_id -> Button


func _ready() -> void:
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/NextButton.pressed.connect(_on_next)
	$Footer/NextButton.disabled = true
	_build_cards()


func _build_cards() -> void:
	var grid: GridContainer = $Scroll/Grid
	for rid in RACE_IDS:
		var res: RaceData = load("res://resources/races/%s.tres" % rid) as RaceData
		if res == null:
			continue
		var card := _make_card(res)
		grid.add_child(card)
		_cards[rid] = card


func _make_card(r: RaceData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(540, 520)
	btn.pressed.connect(_on_card_pressed.bind(r.id))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.offset_left = 20
	hbox.offset_top = 20
	hbox.offset_right = -20
	hbox.offset_bottom = -20
	btn.add_child(hbox)

	# Live-rendered character preview via SubViewport.
	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = Vector2(200, 300)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vpc)

	var vp := SubViewport.new()
	vp.size = Vector2i(200, 300)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	var cs: CharacterSprite = CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	vp.add_child(cs)
	cs.load_character(_race_to_preset(r))
	cs.set_direction("down")
	cs.play_anim("idle", true)
	cs.position = Vector2(100, 190)  # viewport-local, feet near bottom
	cs.scale = Vector2(2.4, 2.4)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 36)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.text = "%s\n\nSTR %d  DEX %d  INT %d\nHP/lv %d  MP/lv %d\n\n%s" % [
		r.display_name, r.base_str, r.base_dex, r.base_int,
		r.hp_per_level, r.mp_per_level, r.description,
	]
	hbox.add_child(label)
	return btn


## Race-only preset (no job equipment) for the preview sprite.
func _race_to_preset(r: RaceData) -> Dictionary:
	var equipment: Array = []
	if r.hair_def != "":
		equipment.append({"def": r.hair_def, "variant": r.hair_color})
	if r.beard_def != "":
		equipment.append({"def": r.beard_def, "variant": r.beard_color})
	if r.horns_def != "":
		equipment.append({"def": r.horns_def, "variant": r.horns_color})
	if r.ears_def != "":
		equipment.append({"def": r.ears_def, "variant": r.ears_color})
	return {
		"id": r.id,
		"body_def": r.body_def,
		"body_variant": "",
		"skin_tint": r.skin_tint,
		"equipment": equipment,
	}


func _on_card_pressed(race_id: String) -> void:
	_selected_id = race_id
	for rid in _cards.keys():
		var b: Button = _cards[rid]
		if b != null:
			b.button_pressed = (rid == race_id)
	$Footer/NextButton.disabled = false


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_next() -> void:
	if _selected_id == "":
		return
	GameManager.selected_race_id = _selected_id
	get_tree().change_scene_to_file(JOB_SELECT_PATH)
