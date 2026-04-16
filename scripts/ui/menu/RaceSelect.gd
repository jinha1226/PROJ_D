extends Control
## Race-selection screen. Loads all resources/races/*.tres, renders a
## 2-column scrollable card grid. Tap a card to select, tap Next to
## move to JobSelect.

const JOB_SELECT_PATH := "res://scenes/menu/JobSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"
const RACE_IDS: Array[String] = [
	"human", "hill_orc", "minotaur", "deep_elf",
	"troll", "spriggan", "demonspawn", "draconian",
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
	btn.custom_minimum_size = Vector2(510, 340)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_card_pressed.bind(r.id))
	var body: String = "%s\n\nSTR %d  DEX %d  INT %d\nHP/lv %d  MP/lv %d\n\n%s" % [
		r.display_name, r.base_str, r.base_dex, r.base_int,
		r.hp_per_level, r.mp_per_level,
		r.description,
	]
	btn.text = body
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 22)
	return btn


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
