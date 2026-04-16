extends Control
## Background (job) selection. Loads all 20 job tres files, renders a
## 2-column scrollable card grid with live previews of the picked race
## wearing each job's starting equipment.

const CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")
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
var _preview_race: RaceData = null  # race chosen on prior screen; default human


func _ready() -> void:
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/StartButton.pressed.connect(_on_start)
	$Footer/StartButton.disabled = true
	var rid: String = GameManager.selected_race_id if GameManager.selected_race_id != "" else "human"
	_preview_race = load("res://resources/races/%s.tres" % rid) as RaceData
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
	btn.custom_minimum_size = Vector2(540, 540)
	btn.pressed.connect(_on_card_pressed.bind(j.id))

	var hbox := HBoxContainer.new()
	hbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hbox.add_theme_constant_override("separation", 16)
	hbox.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.offset_left = 20
	hbox.offset_top = 20
	hbox.offset_right = -20
	hbox.offset_bottom = -20
	btn.add_child(hbox)

	# Live preview: race body + job equipment.
	var vpc := SubViewportContainer.new()
	vpc.custom_minimum_size = Vector2(200, 320)
	vpc.stretch = true
	vpc.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hbox.add_child(vpc)

	var vp := SubViewport.new()
	vp.size = Vector2i(200, 320)
	vp.transparent_bg = true
	vp.disable_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	vpc.add_child(vp)

	var cs: CharacterSprite = CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	vp.add_child(cs)
	cs.load_character(_compose_preset(j))
	cs.set_direction("down")
	cs.play_anim("idle", true)
	cs.position = Vector2(100, 210)
	cs.scale = Vector2(2.4, 2.4)

	var label := Label.new()
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	label.add_theme_font_size_override("font_size", 32)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	label.text = "%s\n\n%s\n%s\n%s\n\n%s" % [
		j.display_name, stat_line, eq_line, skill_line, j.description,
	]
	hbox.add_child(label)
	return btn


## Build a preset combining the selected race with this job's starting gear.
func _compose_preset(j: JobData) -> Dictionary:
	var equipment: Array = []
	if _preview_race != null:
		if _preview_race.hair_def != "":
			equipment.append({"def": _preview_race.hair_def, "variant": _preview_race.hair_color})
		if _preview_race.beard_def != "":
			equipment.append({"def": _preview_race.beard_def, "variant": _preview_race.beard_color})
		if _preview_race.horns_def != "":
			equipment.append({"def": _preview_race.horns_def, "variant": _preview_race.horns_color})
		if _preview_race.ears_def != "":
			equipment.append({"def": _preview_race.ears_def, "variant": _preview_race.ears_color})
	for item_id in j.starting_equipment:
		var sid: String = String(item_id)
		if WeaponRegistry.is_weapon(sid):
			equipment.append({"def": sid, "variant": ""})
		elif "|" in sid:
			var parts: PackedStringArray = sid.split("|")
			equipment.append({"def": parts[0], "variant": parts[1]})
		else:
			equipment.append({"def": sid, "variant": "brown"})
	return {
		"id": j.id,
		"body_def": _preview_race.body_def if _preview_race else "body_male",
		"body_variant": "",
		"skin_tint": _preview_race.skin_tint if _preview_race else "peach",
		"equipment": equipment,
	}


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
	# start_new_run resets depth, identified items, pseudonyms, etc.
	GameManager.start_new_run(_selected_id, GameManager.selected_race_id)
	get_tree().change_scene_to_file(GAME_PATH)
