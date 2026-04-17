extends Control

const GAME_PATH := "res://scenes/main/Game.tscn"
const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"

const JOB_TRAITS: Dictionary = {
	"fighter":   ["iron_will", "tough", "fierce", "armored"],
	"barbarian": ["war_cry", "fierce", "tough", "resilient"],
	"ranger":    ["eagle_eye", "swift", "clever", "armored"],
	"rogue":     ["backstab", "swift", "fierce", "clever"],
	"mage":      ["fire", "ice", "earth", "air"],
	"cleric":    ["holy_light", "necro", "arcane", "resilient"],
}

var _selected_id: String = ""
var _cards: Dictionary = {}


func _ready() -> void:
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/StartButton.pressed.connect(_on_start)
	$Footer/StartButton.disabled = true
	var job_id: String = GameManager.selected_job_id
	$Title.text = "Choose a Trait — %s" % job_id.capitalize()
	_build_cards(job_id)


func _build_cards(job_id: String) -> void:
	var grid: GridContainer = $Scroll/Grid
	var trait_ids: Array = JOB_TRAITS.get(job_id, ["tough", "fierce", "swift", "armored"])
	for tid in trait_ids:
		var path: String = "res://resources/traits/%s.tres" % tid
		if not ResourceLoader.exists(path):
			continue
		var tdata: TraitData = load(path)
		if tdata == null:
			continue
		var card := _make_card(tdata)
		grid.add_child(card)
		_cards[tid] = card


func _make_card(t: TraitData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(480, 400)
	btn.pressed.connect(_on_card_pressed.bind(t.id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 12)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	btn.add_child(vbox)

	var name_lbl := Label.new()
	name_lbl.text = t.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 48)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	var stats_parts: Array = []
	if t.str_bonus != 0: stats_parts.append("STR%+d" % t.str_bonus)
	if t.dex_bonus != 0: stats_parts.append("DEX%+d" % t.dex_bonus)
	if t.int_bonus != 0: stats_parts.append("INT%+d" % t.int_bonus)
	if t.hp_bonus_pct > 0: stats_parts.append("HP+%d%%" % int(t.hp_bonus_pct * 100))
	if t.mp_bonus_pct > 0: stats_parts.append("MP+%d%%" % int(t.mp_bonus_pct * 100))
	if t.ac_bonus > 0: stats_parts.append("AC+%d" % t.ac_bonus)
	if not stats_parts.is_empty():
		var stat_lbl := Label.new()
		stat_lbl.text = "  ".join(PackedStringArray(stats_parts))
		stat_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		stat_lbl.add_theme_font_size_override("font_size", 32)
		stat_lbl.add_theme_color_override("font_color", Color(0.4, 0.85, 1.0))
		stat_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(stat_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = t.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(desc_lbl)

	if not t.starting_spells.is_empty():
		var spell_lbl := Label.new()
		spell_lbl.text = "Spells: %s" % ", ".join(PackedStringArray(t.starting_spells))
		spell_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		spell_lbl.add_theme_font_size_override("font_size", 26)
		spell_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		spell_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(spell_lbl)

	return btn


func _on_card_pressed(trait_id: String) -> void:
	if _selected_id == trait_id:
		_selected_id = ""
		$Footer/StartButton.disabled = true
	else:
		_selected_id = trait_id
		$Footer/StartButton.disabled = false
	for tid in _cards.keys():
		var b: Button = _cards[tid]
		b.button_pressed = (tid == _selected_id)


func _on_back() -> void:
	get_tree().change_scene_to_file(JOB_SELECT_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_race_id = _selected_id
	get_tree().change_scene_to_file(GAME_PATH)
