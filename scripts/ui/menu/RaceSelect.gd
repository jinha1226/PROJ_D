extends Control
## Race-selection screen. Loads all resources/races/*.tres, renders a
## 2-column scrollable card grid with live LPC-composited previews.
## Cards show compact info; tapping expands to reveal full details.

const CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const RACE_IDS: Array[String] = [
	"human", "hill_orc", "minotaur", "deep_elf",
	"troll", "spriggan", "catfolk", "draconian",
]

const _CARD_W: float = 540.0
const _CARD_H_COMPACT: float = 680.0
const _CARD_H_EXPANDED: float = 980.0

var _selected_id: String = ""
var _cards: Dictionary = {}        # race_id -> Button
var _detail_nodes: Dictionary = {} # race_id -> {sep, detail}


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
	btn.custom_minimum_size = Vector2(_CARD_W, _CARD_H_COMPACT)
	btn.pressed.connect(_on_card_pressed.bind(r.id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	btn.add_child(vbox)

	# Preview: DCSS tile in DCSS mode, SubViewport+LPC otherwise.
	if TileRenderer.is_dcss():
		var trect := TextureRect.new()
		trect.custom_minimum_size = Vector2(504, 460)
		trect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		trect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		trect.texture = TileRenderer.player_race(r.id)
		trect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		trect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		vbox.add_child(trect)
	else:
		var vpc := SubViewportContainer.new()
		vpc.custom_minimum_size = Vector2(504, 460)
		vpc.stretch = true
		vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(vpc)
		var vp := SubViewport.new()
		vp.size = Vector2i(504, 460)
		vp.transparent_bg = true
		vp.disable_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		vpc.add_child(vp)
		var cs: CharacterSprite = CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
		vp.add_child(cs)
		cs.load_character(_race_to_preset(r))
		cs.set_direction("down")
		cs.play_anim("idle", true)
		cs.position = Vector2(252, 400)
		cs.scale = Vector2(5.5, 5.5)

	# Race name — always visible.
	var name_lbl := Label.new()
	name_lbl.text = r.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 44)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Core stats — always visible.
	var stats_lbl := Label.new()
	stats_lbl.text = "STR %d   DEX %d   INT %d" % [r.base_str, r.base_dex, r.base_int]
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 30)
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	# --- Detail section (hidden until card is selected) ---
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.visible = false
	vbox.add_child(sep)

	var detail := VBoxContainer.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.visible = false
	detail.add_theme_constant_override("separation", 6)
	vbox.add_child(detail)

	var hp_lbl := Label.new()
	hp_lbl.text = "HP/lv %d   MP/lv %d" % [r.hp_per_level, r.mp_per_level]
	hp_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hp_lbl.add_theme_font_size_override("font_size", 28)
	hp_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(hp_lbl)

	var trait_name: String = r.racial_trait if r.racial_trait != "" else "(no trait)"
	var trait_lbl := Label.new()
	trait_lbl.text = "Trait: %s" % trait_name
	trait_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	trait_lbl.add_theme_font_size_override("font_size", 28)
	trait_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	trait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(trait_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = r.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 26)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(desc_lbl)

	_detail_nodes[r.id] = {"sep": sep, "detail": detail}
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
	var toggling_off: bool = (_selected_id == race_id)
	if toggling_off:
		_selected_id = ""
		$Footer/NextButton.disabled = true
	else:
		_selected_id = race_id
		$Footer/NextButton.disabled = false

	for rid in _cards.keys():
		var b: Button = _cards[rid]
		if b == null:
			continue
		var is_sel: bool = (rid == _selected_id)
		b.button_pressed = is_sel
		b.custom_minimum_size = Vector2(_CARD_W, _CARD_H_EXPANDED if is_sel else _CARD_H_COMPACT)
		if _detail_nodes.has(rid):
			var d: Dictionary = _detail_nodes[rid]
			d["sep"].visible = is_sel
			d["detail"].visible = is_sel


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_next() -> void:
	if _selected_id == "":
		return
	GameManager.selected_race_id = _selected_id
	get_tree().change_scene_to_file(JOB_SELECT_PATH)
