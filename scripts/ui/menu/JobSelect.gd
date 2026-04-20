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

const _ROW_HEIGHT: float = 320.0
const _DOLL_WIDTH: float = 260.0

var _selected_id: String = ""
var _rows: Dictionary = {}  # job_id -> Button


func _ready() -> void:
	theme = GameTheme.create()
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/StartButton.pressed.connect(_on_start)
	$Footer/StartButton.disabled = true
	_build_rows()


func _build_rows() -> void:
	var list: VBoxContainer = $Scroll/List
	for jid in JOB_IDS:
		var res: JobData = load("res://resources/jobs/%s.tres" % jid) as JobData
		if res == null:
			continue
		var row := _make_row(res)
		list.add_child(row)
		_rows[jid] = row


## Full-width horizontal row: doll preview on the left, job name / stats /
## description / starting gear stacked on the right. All info is visible
## at once — selection just toggles a highlight tint.
func _make_row(j: JobData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, _ROW_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_row_pressed.bind(j.id))

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_top = 14
	h.offset_right = -16
	h.offset_bottom = -14
	h.add_theme_constant_override("separation", 20)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)

	# --- Left column: doll preview ---
	var doll_tex: Texture2D = _compose_job_preview(j)
	if doll_tex != null:
		var preview := TextureRect.new()
		preview.texture = doll_tex
		preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.custom_minimum_size = Vector2(_DOLL_WIDTH, 0)
		preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
		preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(preview)
	else:
		# Reserve the same width so text column alignment stays consistent.
		var spacer := Control.new()
		spacer.custom_minimum_size = Vector2(_DOLL_WIDTH, 0)
		spacer.mouse_filter = Control.MOUSE_FILTER_IGNORE
		h.add_child(spacer)

	# --- Right column: text stack ---
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 10)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = j.display_name
	name_lbl.add_theme_font_size_override("font_size", 60)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var stat_line: String = "STR%+d  DEX%+d  INT%+d" % [j.str_bonus, j.dex_bonus, j.int_bonus]
	var stats_lbl := Label.new()
	stats_lbl.text = stat_line
	stats_lbl.add_theme_font_size_override("font_size", 40)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = j.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 32)
	desc_lbl.modulate = Color(0.88, 0.88, 0.96)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc_lbl)

	if not j.starting_equipment.is_empty():
		var equip_names: Array = []
		for eid in j.starting_equipment:
			equip_names.append(String(eid).replace("_", " ").capitalize())
		var equip_lbl := Label.new()
		equip_lbl.text = "Starts with: " + ", ".join(PackedStringArray(equip_names))
		equip_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		equip_lbl.add_theme_font_size_override("font_size", 28)
		equip_lbl.modulate = Color(0.75, 0.90, 0.75)
		equip_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(equip_lbl)

	return btn


## Compose the preview texture from the selected race body + this job's
## starting equipment as paper-doll overlays.
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


func _on_row_pressed(job_id: String) -> void:
	var toggling_off: bool = (_selected_id == job_id)
	if toggling_off:
		_selected_id = ""
		$Footer/StartButton.disabled = true
	else:
		_selected_id = job_id
		$Footer/StartButton.disabled = false

	for jid in _rows.keys():
		var b: Button = _rows[jid]
		if b == null:
			continue
		var is_sel: bool = (jid == _selected_id)
		b.button_pressed = is_sel
		# Warm tint on the selected row so the highlight reads at a glance.
		b.modulate = Color(1.15, 1.1, 0.85) if is_sel else Color.WHITE


func _on_back() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_job_id = _selected_id
	get_tree().change_scene_to_file(GAME_PATH)
