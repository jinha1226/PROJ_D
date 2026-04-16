extends Control
## Background (job) selection. Loads all 20 job tres files, renders a
## 2-column scrollable card grid. Start Run launches Game.tscn.

const RACE_SELECT_PATH := "res://scenes/menu/RaceSelect.tscn"
const GAME_PATH := "res://scenes/main/Game.tscn"
const JOB_IDS: Array[String] = [
	"fighter", "gladiator", "monk", "berserker", "brigand", "skald",
	"hunter", "arcane_marksman",
	"fire_elementalist", "ice_elementalist", "earth_elementalist", "air_elementalist",
	"conjurer", "summoner", "necromancer", "enchanter", "transmuter",
	"assassin", "warper", "wizard",
]

var _selected_id: String = ""
var _cards: Dictionary = {}  # job_id -> Button


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
	btn.custom_minimum_size = Vector2(510, 360)
	btn.alignment = HORIZONTAL_ALIGNMENT_LEFT
	btn.pressed.connect(_on_card_pressed.bind(j.id))
	var stat_line := "STR%s%d  DEX%s%d  INT%s%d" % [
		"+" if j.str_bonus >= 0 else "", j.str_bonus,
		"+" if j.dex_bonus >= 0 else "", j.dex_bonus,
		"+" if j.int_bonus >= 0 else "", j.int_bonus,
	]
	var eq_line: String = "Starts with: " + ("(none)" if j.starting_equipment.is_empty()
			else ", ".join(PackedStringArray(j.starting_equipment)))
	var skill_lines: Array = []
	for sk in j.starting_skills.keys():
		skill_lines.append("%s Lv.%d" % [sk, int(j.starting_skills[sk])])
	var skill_line: String = "Skills: " + ", ".join(PackedStringArray(skill_lines))
	var body: String = "%s\n\n%s\n%s\n%s\n\n%s" % [
		j.display_name, stat_line, eq_line, skill_line, j.description,
	]
	btn.text = body
	btn.clip_text = false
	btn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	btn.add_theme_font_size_override("font_size", 20)
	return btn


func _on_card_pressed(job_id: String) -> void:
	_selected_id = job_id
	for jid in _cards.keys():
		var b: Button = _cards[jid]
		if b != null:
			b.button_pressed = (jid == job_id)
	$Footer/StartButton.disabled = false


func _on_back() -> void:
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_start() -> void:
	if _selected_id == "":
		return
	GameManager.selected_job_id = _selected_id
	GameManager.current_depth = 1
	get_tree().change_scene_to_file(GAME_PATH)
