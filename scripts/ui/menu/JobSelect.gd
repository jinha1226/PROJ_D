extends Control

const TRAIT_SELECT_PATH := "res://scenes/menu/TraitSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const JOB_IDS: Array[String] = [
	"fighter", "barbarian", "ranger", "rogue", "mage", "cleric",
]

const _CARD_W: float = 480.0
const _CARD_H: float = 600.0

var _selected_id: String = ""
var _cards: Dictionary = {}


func _ready() -> void:
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/StartButton.pressed.connect(_on_start)
	$Footer/StartButton.disabled = true
	_build_cards()


func _build_cards() -> void:
	var grid: GridContainer = $Scroll/Grid
	for jid in JOB_IDS:
		var res: JobData = load("res://resources/jobs/%s.tres" % jid) as JobData
		if res == null:
			continue
		var card := _make_card(res)
		grid.add_child(card)
		_cards[jid] = card


func _make_card(j: JobData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(_CARD_W, _CARD_H)
	btn.pressed.connect(_on_card_pressed.bind(j.id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	btn.add_child(vbox)

	var tex: Texture2D = TileRenderer.player_race(j.id)
	if tex != null:
		var preview := TextureRect.new()
		preview.texture = tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.custom_minimum_size = Vector2(0, 300)
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(preview)

	var name_lbl := Label.new()
	name_lbl.text = j.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 52)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stat_line := "STR%+d  DEX%+d  INT%+d" % [j.str_bonus, j.dex_bonus, j.int_bonus]
	var stats_lbl := Label.new()
	stats_lbl.text = stat_line
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 34)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = j.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 28)
	desc_lbl.modulate = Color(0.8, 0.8, 0.9)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	return btn


func _on_card_pressed(job_id: String) -> void:
	if _selected_id == job_id:
		_selected_id = ""
		$Footer/StartButton.disabled = true
	else:
		_selected_id = job_id
		$Footer/StartButton.disabled = false
	for jid in _cards.keys():
		var b: Button = _cards[jid]
		b.button_pressed = (jid == _selected_id)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_job_id = _selected_id
	get_tree().change_scene_to_file(TRAIT_SELECT_PATH)
