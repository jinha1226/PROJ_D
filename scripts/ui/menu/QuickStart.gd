extends Control
## One-tap start for popular DCSS race/job combos. First-tier options are
## the community's well-known beginner-friendly builds (MiBe, GrFi, GrEE,
## …); if the player has previously launched a run, their last combo
## pins itself to the very top. "Custom Build" drops into the full
## Race → Job pick flow.

const GAME_PATH := "res://scenes/main/Game.tscn"
const RACE_SELECT_PATH := "res://scenes/menu/RaceSelect.tscn"
const MAIN_MENU_PATH := "res://scenes/menu/MainMenu.tscn"

# (race_id, job_id, tagline, tier)
# tier: "easy" → top of the recommended list, "mid" → middle, "hard" →
# bottom but still surfaced for curious players.
const COMBOS: Array = [
	{"race": "minotaur",   "job": "berserker",         "tag": "MiBe — charge, rage, flatten. The iconic easy win.",           "tier": "easy"},
	{"race": "gargoyle",   "job": "fighter",           "tag": "GrFi — stone skin + heavy armour. The tankiest start.",         "tier": "easy"},
	{"race": "gargoyle",   "job": "earth_elementalist","tag": "GrEE — gargoyle-법: rock-throwing stone wall.",                  "tier": "easy"},
	{"race": "minotaur",   "job": "fighter",           "tag": "MiFi — huge STR + headbutts, but safer than a Berserker.",      "tier": "easy"},
	{"race": "minotaur",   "job": "fighter",           "tag": "MiFi — bullish fighter with natural headbutt.",                 "tier": "easy"},
	{"race": "troll",      "job": "berserker",         "tag": "TrBe — claws, regen, rage. A slow start and a brutal end.",     "tier": "easy"},
	{"race": "deep_elf",   "job": "conjurer",          "tag": "DECj — glass cannon blaster. Conjurations every turn.",         "tier": "mid"},
	{"race": "deep_elf",   "job": "fire_elementalist", "tag": "DEFE — fireball-first, ask-questions-never.",                   "tier": "mid"},
	{"race": "mummy",      "job": "necromancer",       "tag": "MuNe — undead necromancer with strong death magic.",            "tier": "mid"},
	{"race": "spriggan",   "job": "enchanter",         "tag": "SpEn — tiny hexmage, stealth + speed.",                         "tier": "mid"},
	{"race": "formicid",   "job": "hunter",            "tag": "FoHu — four-armed archer + heavy shield.",                      "tier": "mid"},
	{"race": "naga",       "job": "shapeshifter",      "tag": "NaSh — slow serpent shapeshifter, forms over weapons.",         "tier": "hard"},
	{"race": "merfolk",    "job": "ice_elementalist",  "tag": "MfIE — cold mage who rules the dungeon's waterways.",           "tier": "hard"},
	{"race": "demonspawn", "job": "fighter",           "tag": "DsFi — bulky fighter who gains mutations as you level.",        "tier": "hard"},
]

const _ROW_HEIGHT: float = 220.0
const _DOLL_WIDTH: float = 200.0


func _ready() -> void:
	theme = GameTheme.create()
	$Footer/BackButton.pressed.connect(_on_back)
	$Footer/CustomButton.pressed.connect(_on_custom)
	_build_list()


func _build_list() -> void:
	var list: VBoxContainer = $Scroll/List
	var meta: MetaProgression = _ensure_meta()

	# Last-played combo pinned at top when available.
	if meta != null and meta.last_race != "" and meta.last_job != "":
		var last_tag: String = "Continue the same build you last played"
		list.add_child(_make_section_header("Last Run"))
		list.add_child(_make_combo_row(meta.last_race, meta.last_job, last_tag, true))

	# Recommended combos, grouped by difficulty tier.
	list.add_child(_make_section_header("Recommended — Easy"))
	for combo in COMBOS:
		if String(combo["tier"]) == "easy":
			list.add_child(_make_combo_row(String(combo["race"]), String(combo["job"]),
					String(combo["tag"]), false))

	list.add_child(_make_section_header("Caster Builds"))
	for combo in COMBOS:
		if String(combo["tier"]) == "mid":
			list.add_child(_make_combo_row(String(combo["race"]), String(combo["job"]),
					String(combo["tag"]), false))

	list.add_child(_make_section_header("Niche / Challenge"))
	for combo in COMBOS:
		if String(combo["tier"]) == "hard":
			list.add_child(_make_combo_row(String(combo["race"]), String(combo["job"]),
					String(combo["tag"]), false))


func _ensure_meta() -> MetaProgression:
	var m: Node = get_tree().root.get_node_or_null("MetaProgression")
	return m as MetaProgression if m != null else null


func _make_section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 44)
	lbl.add_theme_color_override("font_color", Color(1.0, 0.85, 0.4))
	lbl.custom_minimum_size = Vector2(0, 64)
	return lbl


## Row layout mirrors Race/JobSelect rows: doll on the left, name + tag on
## the right. `highlighted` tints the row gold (used for "Last Run").
func _make_combo_row(race_id: String, job_id: String, tagline: String,
		highlighted: bool) -> Button:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(0, _ROW_HEIGHT)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.pressed.connect(_on_combo_pressed.bind(race_id, job_id))
	if highlighted:
		btn.modulate = Color(1.15, 1.1, 0.75)

	var h := HBoxContainer.new()
	h.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	h.offset_left = 16
	h.offset_top = 14
	h.offset_right = -16
	h.offset_bottom = -14
	h.add_theme_constant_override("separation", 20)
	h.mouse_filter = Control.MOUSE_FILTER_IGNORE
	btn.add_child(h)

	# Doll preview — race body + job's starting gear.
	var preview := TextureRect.new()
	preview.texture = _compose_preview(race_id, job_id)
	preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	preview.custom_minimum_size = Vector2(_DOLL_WIDTH, 0)
	preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	preview.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(preview)

	# Text stack.
	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	vb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	vb.add_theme_constant_override("separation", 8)
	vb.mouse_filter = Control.MOUSE_FILTER_IGNORE
	h.add_child(vb)

	var race_name: String = _race_display_name(race_id)
	var job_name: String = _job_display_name(job_id)
	var name_lbl := Label.new()
	name_lbl.text = "%s %s" % [race_name, job_name]
	name_lbl.add_theme_font_size_override("font_size", 54)
	name_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(name_lbl)

	var tag_lbl := Label.new()
	tag_lbl.text = tagline
	tag_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tag_lbl.add_theme_font_size_override("font_size", 30)
	tag_lbl.modulate = Color(0.85, 0.85, 0.95)
	tag_lbl.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	vb.add_child(tag_lbl)

	return btn


func _compose_preview(race_id: String, job_id: String) -> Texture2D:
	var res: JobData = load("res://resources/jobs/%s.tres" % job_id) as JobData
	if res == null:
		return TileRenderer.player_race(race_id)
	var weapon_id: String = ""
	var armor_by_slot: Dictionary = {}
	for eid_v in res.starting_equipment:
		var eid: String = String(eid_v)
		if WeaponRegistry.is_weapon(eid):
			if weapon_id == "":
				weapon_id = eid
		elif ArmorRegistry.is_armor(eid):
			var slot: String = ArmorRegistry.slot_for(eid)
			if slot != "" and not armor_by_slot.has(slot):
				armor_by_slot[slot] = eid
	return TileRenderer.compose_doll(race_id, weapon_id, armor_by_slot)


func _race_display_name(race_id: String) -> String:
	var r: RaceData = RaceRegistry.fetch(race_id)
	return String(r.display_name) if r != null else race_id.capitalize().replace("_", " ")


func _job_display_name(job_id: String) -> String:
	var j: JobData = load("res://resources/jobs/%s.tres" % job_id) as JobData
	return String(j.display_name) if j != null else job_id.capitalize().replace("_", " ")


func _on_combo_pressed(race_id: String, job_id: String) -> void:
	GameManager.selected_race_id = race_id
	GameManager.selected_job_id = job_id
	get_tree().change_scene_to_file(GAME_PATH)


func _on_custom() -> void:
	# Wipe any prior auto-selection so the Race → Job flow starts clean.
	GameManager.selected_race_id = ""
	GameManager.selected_job_id = ""
	get_tree().change_scene_to_file(RACE_SELECT_PATH)


func _on_back() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_PATH)
