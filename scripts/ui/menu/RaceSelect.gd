extends Control
## Race-selection screen. Full-width row list — each row shows a dressed
## doll preview on the left, name / stats / description / trait on the
## right. Races sourced from resources/races/*.tres (DCSS roster).

const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"

# Canonical DCSS race roster. Order affects list presentation — grouped by
# archetype (combat → rogue/stealth → magic → undead/exotic).
const RACE_IDS: Array[String] = [
	# Baseline humans and kin
	"human", "halfling", "gnoll",
	# Heavy fighters
	"minotaur", "hill_orc", "troll", "oni", "formicid", "gargoyle", "coglin",
	# Rogues / stealth
	"kobold", "spriggan", "catfolk", "vine_stalker",
	# Dwarven / earthy
	"deep_dwarf",
	# Draconian / scaled
	"draconian", "naga",
	# Magical / elven
	"deep_elf", "tengu", "djinni",
	# Aquatic / outre
	"merfolk", "octopode", "barachi",
	# Undead
	"ghoul", "mummy", "vampire",
	# Divine / cosmic
	"demigod", "demonspawn", "meteoran",
]

const _ROW_HEIGHT: float = 320.0
const _DOLL_WIDTH: float = 260.0

var _selected_id: String = ""
var _rows: Dictionary = {}  # race_id -> Button


func _ready() -> void:
	theme = GameTheme.create()
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/NextButton.pressed.connect(_on_next)
	$Footer/NextButton.disabled = true
	_build_rows()


func _build_rows() -> void:
	var list: VBoxContainer = $Scroll/List
	for rid in RACE_IDS:
		var res: RaceData = load("res://resources/races/%s.tres" % rid) as RaceData
		if res == null:
			continue
		var row := _make_row(res)
		list.add_child(row)
		_rows[rid] = row


## Full-width row: dressed doll preview on the left, text stack on the
## right. All info is visible at once — selection just toggles a tint.
func _make_row(r: RaceData) -> Button:
	var btn := Button.new()
	btn.toggle_mode = true
	btn.custom_minimum_size = Vector2(0, _ROW_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_row_pressed.bind(r.id))

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_top = 14
	h.offset_right = -16
	h.offset_bottom = -14
	h.add_theme_constant_override("separation", 20)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)

	# --- Left: dressed doll preview ---
	var doll_tex: Texture2D = _compose_dressed_preview(r)
	var preview := TextureRect.new()
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(_DOLL_WIDTH, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if doll_tex != null:
		preview.texture = doll_tex
	h.add_child(preview)

	# --- Right: text stack ---
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vb)

	var name_lbl := Label.new()
	name_lbl.text = r.display_name
	name_lbl.add_theme_font_size_override("font_size", 60)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var stat_line: String = "STR %d   DEX %d   INT %d   HP/lv %d   MP/lv %d" % [
			r.base_str, r.base_dex, r.base_int, r.hp_per_level, r.mp_per_level]
	var stats_lbl := Label.new()
	stats_lbl.text = stat_line
	stats_lbl.add_theme_font_size_override("font_size", 32)
	stats_lbl.add_theme_color_override("font_color", Color(0.5, 0.85, 1.0))
	stats_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(stats_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = r.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 30)
	desc_lbl.modulate = Color(0.88, 0.88, 0.96)
	desc_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(desc_lbl)

	if r.racial_trait != "":
		var trait_lbl := Label.new()
		trait_lbl.text = "Trait: %s" % _format_trait(r.racial_trait)
		trait_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		trait_lbl.add_theme_font_size_override("font_size", 28)
		trait_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
		trait_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		vb.add_child(trait_lbl)

	return btn


## Wrap a raw trait_id like "naga_poison_spit" into a readable label.
func _format_trait(trait_id: String) -> String:
	return trait_id.replace("_", " ").capitalize()


## Compose a preview texture from the race body + a plain robe overlay so
## races aren't shown naked. When the race's base sprite doesn't have
## humanoid dimensions (felid cat, octopode), compose_doll still works
## because PLAYER_DOLL entries are 32×32 and blend onto the base rect.
func _compose_dressed_preview(r: RaceData) -> Texture2D:
	var armor_by_slot: Dictionary = {"chest": "robe"}
	var tex: Texture2D = TileRenderer.compose_doll(r.id, "", armor_by_slot)
	if tex == null:
		return TileRenderer.player_race(r.id)
	return tex


func _on_row_pressed(race_id: String) -> void:
	var toggling_off: bool = (_selected_id == race_id)
	if toggling_off:
		_selected_id = ""
		$Footer/NextButton.disabled = true
	else:
		_selected_id = race_id
		$Footer/NextButton.disabled = false

	for rid in _rows.keys():
		var b: Button = _rows[rid]
		if b == null:
			continue
		var is_sel: bool = (rid == _selected_id)
		b.button_pressed = is_sel
		b.modulate = Color(1.15, 1.1, 0.85) if is_sel else Color.WHITE


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)


func _on_next() -> void:
	if _selected_id == "":
		return
	GameManager.selected_race_id = _selected_id
	get_tree().change_scene_to_file(JOB_SELECT_PATH)
