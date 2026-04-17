extends Control
## Background (job) selection. Loads all 20 job tres files, renders a
## 2-column scrollable card grid with live previews of the picked race
## wearing each job's starting equipment.
## Cards show compact info; tapping expands to reveal full details.

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

const _CARD_W: float = 540.0
const _CARD_H_COMPACT: float = 680.0
const _CARD_H_EXPANDED: float = 1060.0

var _selected_id: String = ""
var _cards: Dictionary = {}        # job_id -> Button
var _detail_nodes: Dictionary = {} # job_id -> {sep, detail}
var _preview_race: RaceData = null


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

	if TileRenderer.is_dcss():
		# Composited doll: race body + legs + chest + boots + gloves + helm
		# + weapon, all stacked at the same rect so it reads as one figure.
		var preview := Control.new()
		preview.custom_minimum_size = Vector2(504, 460)
		preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var race_id: String = _preview_race.id if _preview_race else "human"
		_add_doll_layer(preview, TileRenderer.player_race(race_id))
		for slot in ["legs", "chest", "boots", "gloves", "helm"]:
			var aid: String = _find_armor_in_slot(j, slot)
			if aid != "":
				_add_doll_layer(preview, TileRenderer.doll_layer(slot, aid))
		var weapon_id: String = _first_weapon_id(j)
		if weapon_id != "":
			_add_doll_layer(preview, TileRenderer.doll_layer("weapon", weapon_id))
		vbox.add_child(preview)
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
		cs.load_character(_compose_preset(j))
		cs.set_direction("down")
		cs.play_anim("idle", true)
		cs.position = Vector2(252, 400)
		cs.scale = Vector2(5.5, 5.5)

	# Job name — always visible.
	var name_lbl := Label.new()
	name_lbl.text = j.display_name
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 56)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vbox.add_child(name_lbl)

	# Stat bonuses — always visible.
	var stat_line := "STR%s%d   DEX%s%d   INT%s%d" % [
		"+" if j.str_bonus >= 0 else "", j.str_bonus,
		"+" if j.dex_bonus >= 0 else "", j.dex_bonus,
		"+" if j.int_bonus >= 0 else "", j.int_bonus,
	]
	var stats_lbl := Label.new()
	stats_lbl.text = stat_line
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.add_theme_font_size_override("font_size", 38)
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

	var eq_names: String = "(none)" if j.starting_equipment.is_empty() \
		else ", ".join(PackedStringArray(j.starting_equipment))
	var eq_lbl := Label.new()
	eq_lbl.text = "Starts with: %s" % eq_names
	eq_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	eq_lbl.add_theme_font_size_override("font_size", 32)
	eq_lbl.add_theme_color_override("font_color", Color(0.85, 0.85, 1.0))
	eq_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(eq_lbl)

	var skill_lines: Array = []
	for sk in j.starting_skills.keys():
		skill_lines.append("%s Lv.%d" % [sk, int(j.starting_skills[sk])])
	var skills_lbl := Label.new()
	skills_lbl.text = "Skills: %s" % (", ".join(PackedStringArray(skill_lines)) if skill_lines.size() > 0 else "(none)")
	skills_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	skills_lbl.add_theme_font_size_override("font_size", 32)
	skills_lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.3))
	skills_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(skills_lbl)

	var desc_lbl := Label.new()
	desc_lbl.text = j.description
	desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lbl.add_theme_font_size_override("font_size", 32)
	desc_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	detail.add_child(desc_lbl)

	_detail_nodes[j.id] = {"sep": sep, "detail": detail}
	return btn


## First weapon id in the job's starting equipment, or "" if none.
func _first_weapon_id(j: JobData) -> String:
	for it in j.starting_equipment:
		var sid: String = String(it)
		if WeaponRegistry.is_weapon(sid):
			return sid
	return ""


## First armor id in the given slot within starting_equipment, or "" if none.
func _find_armor_in_slot(j: JobData, slot: String) -> String:
	for it in j.starting_equipment:
		var sid: String = String(it)
		if ArmorRegistry.is_armor(sid) and ArmorRegistry.slot_for(sid) == slot:
			return sid
	return ""


## Add one layer TextureRect filling `parent` at its full rect, nearest-neighbour.
func _add_doll_layer(parent: Control, tex: Texture2D) -> void:
	if tex == null:
		return
	var tr := TextureRect.new()
	tr.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	tr.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	tr.texture = tex
	tr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(tr)


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
	GameManager.start_new_run(_selected_id, GameManager.selected_race_id)
	get_tree().change_scene_to_file(GAME_PATH)
