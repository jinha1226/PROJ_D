extends Control

const GAME_PATH := "res://scenes/main/Game.tscn"
const RACE_SELECT_PATH := "res://scenes/menu/RaceSelect.tscn"
const JOB_IDS: Array[String] = [
	# Warriors
	"fighter", "gladiator", "berserker", "barbarian", "monk",
	# Adventurers
	"ranger", "hunter", "arcane_marksman",
	# Rogues
	"rogue", "assassin", "brigand",
	# Hybrid / Skald
	"skald",
	# Divine
	"cleric",
	# Mages
	"mage", "warlock", "wizard", "conjurer", "necromancer",
	"fire_elementalist", "ice_elementalist", "earth_elementalist",
	"air_elementalist", "enchanter", "summoner",
	# Transmuters / Warpers
	"transmuter", "warper",
]

const _CARD_W: float = 380.0
const _CARD_H_COMPACT: float = 480.0
const _CARD_H_EXPANDED: float = 780.0

var _selected_id: String = ""
var _cards: Dictionary = {}
var _detail_nodes: Dictionary = {}  # job_id -> {sep, detail}


func _ready() -> void:
	theme = GameTheme.create()
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
	btn.custom_minimum_size = Vector2(_CARD_W, _CARD_H_COMPACT)
	btn.pressed.connect(_on_card_pressed.bind(j.id))

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 10)
	vbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.offset_left = 16
	vbox.offset_top = 16
	vbox.offset_right = -16
	vbox.offset_bottom = -16
	btn.add_child(vbox)

	# Job preview icon: base body (race-or-job) + starting equipment stacked
	# as paper-doll overlays so the card shows what the character actually
	# looks like when the game begins.
	var tex: Texture2D = _compose_job_preview(j)
	if tex != null:
		var preview := TextureRect.new()
		preview.texture = tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		preview.custom_minimum_size = Vector2(0, 280)
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vbox.add_child(preview)

	# Name — always visible.
	var name_lbl := Label.new()
	name_lbl.text = j.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 52)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Stat bonuses — always visible.
	var stat_line: String = "STR%+d  DEX%+d  INT%+d" % [j.str_bonus, j.dex_bonus, j.int_bonus]
	var stats_lbl := Label.new()
	stats_lbl.text = stat_line
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 34)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(stats_lbl)

	# --- Detail section (hidden until card selected) ---
	var sep := HSeparator.new()
	sep.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sep.visible = false
	vbox.add_child(sep)

	var detail := VBoxContainer.new()
	detail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.visible = false
	detail.add_theme_constant_override("separation", 6)
	vbox.add_child(detail)

	var desc_lbl := Label.new()
	desc_lbl.text = j.description
	desc_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.modulate = Color(0.85, 0.85, 0.95)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(desc_lbl)

	if not j.starting_equipment.is_empty():
		var equip_lbl := Label.new()
		var equip_names: Array = []
		for eid in j.starting_equipment:
			equip_names.append(String(eid).replace("_", " ").capitalize())
		equip_lbl.text = "Starts with: " + ", ".join(PackedStringArray(equip_names))
		equip_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		equip_lbl.add_theme_font_size_override("font_size", 28)
		equip_lbl.modulate = Color(0.75, 0.90, 0.75)
		equip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		detail.add_child(equip_lbl)

	_detail_nodes[j.id] = {"sep": sep, "detail": detail}
	return btn


## Build the preview texture for this job's card by stacking their starting
## gear as doll overlays on top of the selected race body (or the job's own
## default sprite when no race has been picked yet).
func _compose_job_preview(j: JobData) -> Texture2D:
	var base_id: String = String(GameManager.selected_race_id)
	if base_id == "":
		base_id = j.id
	var weapon_id: String = ""
	var armor_by_slot: Dictionary = {}
	for eid_v in j.starting_equipment:
		var eid: String = String(eid_v)
		if WeaponRegistry.is_weapon(eid):
			if weapon_id == "":
				weapon_id = eid
		elif ArmorRegistry.is_armor(eid):
			var slot: String = ArmorRegistry.slot_for(eid)
			if slot != "" and not armor_by_slot.has(slot):
				armor_by_slot[slot] = eid
	return TileRenderer.compose_doll(base_id, weapon_id, armor_by_slot)


func _on_card_pressed(job_id: String) -> void:
	var toggling_off: bool = (_selected_id == job_id)
	if toggling_off:
		_selected_id = ""
		$Footer/StartButton.disabled = true
	else:
		_selected_id = job_id
		$Footer/StartButton.disabled = false

	for jid in _cards.keys():
		var b: Button = _cards[jid]
		if b == null:
			continue
		var is_sel: bool = (jid == _selected_id)
		b.button_pressed = is_sel
		b.custom_minimum_size = Vector2(_CARD_W, _CARD_H_EXPANDED if is_sel else _CARD_H_COMPACT)
		if _detail_nodes.has(jid):
			var d: Dictionary = _detail_nodes[jid]
			d["sep"].visible = is_sel
			d["detail"].visible = is_sel


func _on_back() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_job_id = _selected_id
	get_tree().change_scene_to_file(GAME_PATH)
