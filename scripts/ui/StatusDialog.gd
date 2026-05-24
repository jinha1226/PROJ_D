class_name StatusDialog extends RefCounted

const _VISIBLE_EQUIP_SLOTS: Array = [
	["EQUIP_WEAPON", "weapon"],
	["EQUIP_ARMOR", "body"],
	["EQUIP_SHIELD", "shield"],
	["EQUIP_HELMET", "helmet"],
	["EQUIP_GLOVES", "gloves"],
	["EQUIP_BOOTS", "boots"],
	["EQUIP_RING", "ring"],
	["EQUIP_AMULET", "amulet"],
]

const _RESIST_ELEMENTS: Array = ["fire", "cold", "poison", "necro"]
const _RESIST_LABELS: Dictionary = {
	"fire": "Fire",
	"cold": "Cold",
	"poison": "Poison",
	"necro": "Necro",
}

const _VISIBLE_SKILLS: Array = [
	"weapon_mastery", "archery", "tactics", "defense",
	"magery", "stealth", "tracking", "survival",
]

const _VISIBLE_SKILL_LABELS: Dictionary = {
	"weapon_mastery": "Weapon Mastery",
	"archery": "Archery",
	"tactics": "Tactics",
	"defense": "Defense",
	"magery": "Magery",
	"stealth": "Stealth",
	"tracking": "Tracking",
	"survival": "Survival",
}

const _HIDDEN_BY_VISIBLE: Dictionary = {
	"weapon_mastery": ["fighting", "unarmed", "short_blades", "long_blades",
		"maces", "axes", "staves", "polearms"],
	"archery": ["bows", "crossbows", "slings", "throwing"],
	"defense": ["armor", "shields"],
	"magery": ["spellcasting", "conjurations", "hexes", "summonings",
		"necromancy", "translocations", "transmutation",
		"fire", "ice", "air", "earth", "evocations"],
	"stealth": ["dodging"],
	"tactics": ["fighting"],
	"tracking": [],
	"survival": [],
}


static func open(player: Player, parent: Node) -> void:
	if player == null or parent == null:
		return
	var dlg: GameDialog = GameDialog.create_ratio("", 0.94, 0.94)
	parent.add_child(dlg)
	_rebuild_body(dlg, player, parent)

static func _rebuild_body(dlg: GameDialog, player: Player, parent: Node) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	body.add_child(_header_card(player))
	body.add_child(_vitals_card(player))
	body.add_child(_stats_card(player))
	body.add_child(_combat_card(player))
	body.add_child(_skills_card(player))
	body.add_child(_equipment_card(player))
	body.add_child(_resists_card(player))
	body.add_child(_essence_card(dlg, player, parent))
	body.add_child(_effects_card(player))
	body.add_child(_run_card(player))

static func _header_card(player: Player) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var portrait_card := UICards.card(Color(0.9, 0.8, 0.45))
	portrait_card.custom_minimum_size = Vector2(140, 140)
	row.add_child(portrait_card)
	portrait_card.add_child(_portrait_stack(player))

	var info_card := UICards.card(Color(0.55, 0.72, 1.0))
	info_card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(info_card)

	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_S)
	info_card.add_child(vb)

	var race_id: String = GameManager.selected_race_id if GameManager != null else ""
	var race_data: RaceData = RaceRegistry.get_by_id(race_id) if race_id != "" else null
	var race_name := race_data.display_name if race_data != null else race_id.capitalize()

	var title := Label.new()
	title.text = "%s" % [race_name]
	title.add_theme_font_size_override("font_size", GameTheme.TYPO_HEADER)
	title.add_theme_color_override("font_color", Color(0.95, 0.88, 0.55))
	vb.add_child(title)

	var sub := Label.new()
	sub.text = "XL %d   XP %d / %d" % [player.xl, player.xp, player.xp_to_next()]
	sub.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	sub.add_theme_color_override("font_color", Color(0.7, 0.74, 0.84))
	vb.add_child(sub)

	var tip := Label.new()
	tip.text = "A compact summary of your build, defenses, and active essence path."
	tip.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tip.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	tip.add_theme_color_override("font_color", Color(0.76, 0.76, 0.82))
	vb.add_child(tip)

	return row

static func _vitals_card(player: Player) -> Control:
	var card := UICards.card(Color(0.75, 0.3, 0.3))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Vitals", GameTheme.TYPO_SUBTITLE))

	vb.add_child(_resource_bar("HP", player.hp, player.hp_max, Color(0.85, 0.28, 0.28)))
	vb.add_child(_resource_bar("MP", player.mp, player.mp_max, Color(0.35, 0.55, 1.0)))

	var hint := Label.new()
	hint.text = "Max HP rises from level growth, race, Weapon Mastery, and gear. Max MP rises from magic growth and intellect."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	hint.add_theme_color_override("font_color", Color(0.75, 0.78, 0.82))
	vb.add_child(hint)
	return card

static func _stats_card(player: Player) -> Control:
	var card := UICards.card(Color(0.45, 0.85, 0.55))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Stats", GameTheme.TYPO_SUBTITLE))

	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", GameTheme.PAD_L)
	grid.add_theme_constant_override("v_separation", GameTheme.PAD_M)
	vb.add_child(grid)

	grid.add_child(_stat_block("STR", player.strength, "Melee power and carrying brute force."))
	grid.add_child(_stat_block("DEX", player.dexterity, "Accuracy, evasion, and agile fighting."))
	grid.add_child(_stat_block("INT", player.intelligence, "Spell study, power, and magical growth."))
	return card

static func _combat_card(player: Player) -> Control:
	var card := UICards.card(Color(0.9, 0.55, 0.25))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Combat", GameTheme.TYPO_SUBTITLE))

	var row := GridContainer.new()
	row.columns = 2
	row.add_theme_constant_override("h_separation", GameTheme.PAD_XL)
	row.add_theme_constant_override("v_separation", GameTheme.PAD_M)
	vb.add_child(row)

	row.add_child(_kv_row("AC", str(player.ac)))
	row.add_child(_kv_row("EV", str(player.ev)))
	row.add_child(_kv_row("Will", str(player.wl)))
	row.add_child(_kv_row("Sight", str(Player.SIGHT_RADIUS + player.fov_radius_bonus)))
	row.add_child(_kv_row("Weapon", str(player.get_skill_level("weapon_mastery"))))
	row.add_child(_kv_row("Magery", str(player.get_skill_level("magery"))))

	var notes := Label.new()
	notes.text = "Defense covers armor and shield handling. Stealth covers evasion-side growth. Hidden familiarity rows below show exact action training."
	notes.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notes.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	notes.add_theme_color_override("font_color", Color(0.78, 0.76, 0.7))
	vb.add_child(notes)
	return card

static func _skills_card(player: Player) -> Control:
	var card := UICards.card(Color(0.94, 0.84, 0.42))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Skills", GameTheme.TYPO_SUBTITLE))

	for skill_id in _VISIBLE_SKILLS:
		vb.add_child(_skill_status_block(String(skill_id), player))
	return card

static func _skill_status_block(skill_id: String, player: Player) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_M)
	vb.add_child(row)

	var name_lbl := Label.new()
	name_lbl.text = _skill_label(skill_id)
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	name_lbl.add_theme_color_override("font_color", Color(0.94, 0.84, 0.42))
	row.add_child(name_lbl)

	var lv: int = player.get_skill_level(skill_id)
	var lv_lbl := Label.new()
	lv_lbl.text = "MAX" if lv >= Player.MAX_SKILL_LEVEL else "Lv.%d" % lv
	lv_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	lv_lbl.add_theme_color_override("font_color",
		Color(1.0, 0.85, 0.2) if lv >= Player.MAX_SKILL_LEVEL else Color(0.85, 0.85, 0.85))
	row.add_child(lv_lbl)

	var xp: float = player.get_skill_xp(skill_id)
	var next_need: float = float(Player.SKILL_XP_DELTA[lv]) if lv < Player.SKILL_XP_DELTA.size() else 0.0
	if next_need > 0.0:
		var bar := ProgressBar.new()
		bar.max_value = next_need
		bar.value = clamp(xp, 0.0, next_need)
		bar.show_percentage = false
		bar.custom_minimum_size = Vector2(0, 4)
		bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		vb.add_child(bar)

	var hidden_ids: Array = _HIDDEN_BY_VISIBLE.get(skill_id, [])
	if not hidden_ids.is_empty():
		var hidden_line := Label.new()
		hidden_line.text = _hidden_summary(hidden_ids, player)
		hidden_line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		hidden_line.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		hidden_line.add_theme_color_override("font_color", Color(0.62, 0.64, 0.7))
		vb.add_child(hidden_line)
	return vb

static func _hidden_summary(hidden_ids: Array, player: Player) -> String:
	var parts: Array[String] = []
	for raw_id in hidden_ids:
		var sid: String = String(raw_id)
		var entry: Dictionary = player.hidden_skills.get(sid, {"level": 0, "xp": 0.0})
		var lv: int = int(entry.get("level", 0))
		var xp: int = int(float(entry.get("xp", 0.0)))
		parts.append("%s %d/%d" % [sid.replace("_", " "), lv, xp])
	return "Hidden: " + ", ".join(parts)

static func _skill_label(skill_id: String) -> String:
	var key: String = "SKILL_NAME_" + skill_id.to_upper()
	var translated: String = LocaleManager.t(key)
	if translated != key:
		return translated
	return String(_VISIBLE_SKILL_LABELS.get(skill_id, skill_id.capitalize().replace("_", " ")))

static func _equipment_card(player: Player) -> Control:
	var card := UICards.card(Color(0.7, 0.7, 0.82))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Equipment", GameTheme.TYPO_SUBTITLE))

	for pair in _VISIBLE_EQUIP_SLOTS:
		var key: String = String(pair[0])
		var slot: String = String(pair[1])
		var label: String = LocaleManager.t(key)
		vb.add_child(_equipment_row(label, slot, player))
	return card

static func _resists_card(player: Player) -> Control:
	var card := UICards.card(Color(0.45, 0.8, 0.95))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Resistances", GameTheme.TYPO_SUBTITLE))

	var flow := FlowContainer.new()
	flow.add_theme_constant_override("h_separation", GameTheme.PAD_M)
	flow.add_theme_constant_override("v_separation", GameTheme.PAD_M)
	vb.add_child(flow)

	for element in _RESIST_ELEMENTS:
		flow.add_child(_resist_card(element, Status.resist_level(player.resists, element)))
	return card

static func _essence_card(dlg: GameDialog, player: Player, parent: Node) -> Control:
	var tint := Color(0.8, 0.7, 1.0)
	var card := UICards.card(tint)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Essence", GameTheme.TYPO_SUBTITLE))

	var cap: int = EssenceSystem.inventory_capacity(player)
	var slots_open: int = EssenceSystem.active_slot_count(player)

	var summary := Label.new()
	summary.text = "Slots open: %d / %d   Carried: %d / %d" % [slots_open, EssenceSystem.SLOT_COUNT, player.essence_inventory.size(), cap]
	summary.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	summary.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	vb.add_child(summary)

	for i in range(EssenceSystem.SLOT_COUNT):
		vb.add_child(_essence_slot_row(dlg, player, parent, i))

	var inv_header := Label.new()
	inv_header.text = "Carried Essences"
	inv_header.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	inv_header.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
	vb.add_child(inv_header)

	if player.essence_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No spare essences carried."
		empty.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		empty.add_theme_color_override("font_color", Color(0.65, 0.65, 0.72))
		vb.add_child(empty)
	else:
		for eid in player.essence_inventory:
			vb.add_child(_essence_inventory_row(String(eid)))

	var synergies: Array = EssenceSystem.active_synergies(player)
	if not synergies.is_empty():
		var sync_header := Label.new()
		sync_header.text = "Active Resonance"
		sync_header.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		sync_header.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
		vb.add_child(sync_header)
		for line in synergies:
			var lbl := Label.new()
			lbl.text = "- %s" % String(line)
			lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
			lbl.add_theme_color_override("font_color", Color(0.8, 0.78, 0.92))
			vb.add_child(lbl)

	return card

static func _effects_card(player: Player) -> Control:
	var card := UICards.card(Color(0.7, 0.5, 0.95))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Effects", GameTheme.TYPO_SUBTITLE))

	if player.statuses.is_empty():
		var none := Label.new()
		none.text = "No active statuses."
		none.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		none.add_theme_color_override("font_color", Color(0.7, 0.7, 0.75))
		vb.add_child(none)
		return card

	for id in player.statuses.keys():
		var turns: int = int(player.statuses.get(id, 0))
		var line := Label.new()
		line.text = "%s (%d)" % [Status.display_name(String(id)), turns]
		line.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		line.add_theme_color_override("font_color", Status.color_of(String(id)))
		vb.add_child(line)
	return card

static func _run_card(player: Player) -> Control:
	var card := UICards.card(Color(0.6, 0.65, 0.75))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_M)
	card.add_child(vb)
	vb.add_child(UICards.section_header("Run", GameTheme.TYPO_SUBTITLE))

	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", GameTheme.PAD_XL)
	grid.add_theme_constant_override("v_separation", GameTheme.PAD_M)
	vb.add_child(grid)

	var depth_text := str(GameManager.depth) if GameManager != null else "?"
	grid.add_child(_kv_row("Depth", depth_text))
	grid.add_child(_kv_row("Gold", str(player.gold)))
	grid.add_child(_kv_row("Kills", str(player.kills)))
	grid.add_child(_kv_row("Items", str(player.items_collected)))

	# Rune section
	var collected_runes: Array = []
	for entry in player.items:
		var d: ItemData = ItemRegistry.get_by_id(String(entry.get("id", ""))) if ItemRegistry != null else null
		if d != null and d.kind == "rune":
			collected_runes.append(d.display_name)

	vb.add_child(UICards.section_header("Runes  %d / 4" % collected_runes.size(), GameTheme.TYPO_BODY_LARGE))
	if collected_runes.is_empty():
		var none_lbl := Label.new()
		none_lbl.text = "(none collected)"
		none_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
		none_lbl.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
		vb.add_child(none_lbl)
	else:
		for rname in collected_runes:
			var r_lbl := Label.new()
			r_lbl.text = "✦ %s" % rname
			r_lbl.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
			r_lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.35))
			vb.add_child(r_lbl)

	return card

const _EQUIP_LAYERS: Array[Array] = [
	["equipped_armor_id",   "armor"],
	["equipped_helmet_id",  "helmet"],
	["equipped_gloves_id",  "gloves"],
	["equipped_boots_id",   "boots"],
	["equipped_weapon_id",  "sword"],
	["equipped_shield_id",  "shield"],
]

static func _south_atlas(tex: Texture2D) -> Texture2D:
	if tex == null:
		return null
	var tw := tex.get_width()
	var th := tex.get_height()
	var a := AtlasTexture.new()
	a.atlas = tex
	if tw >= th * 4:
		# 8-dir horizontal: frame 4 (S)
		a.region = Rect2(4 * (tw / 8), 0, tw / 8, th)
	elif tw * 4 == th * 9 and th % 4 == 0:
		# ULPC 4-dir vertical: row 2 (S), frame 0
		var fw := tw / 9
		var fh := th / 4
		a.region = Rect2(0, 2 * fh, fw, fh)
	else:
		return tex
	return a

const _RACE_PORTRAIT_MAP: Dictionary = {
	"human":    "res://assets/tiles/individual/player/base/human_m.png",
	"elf":      "res://assets/tiles/individual/player/base/elf_m.png",
	"dwarf":    "res://assets/tiles/individual/player/base/dwarf_m.png",
	"hill_orc": "res://assets/tiles/individual/player/base/orc_m.png",
	"troll":    "res://assets/tiles/individual/player/base/troll_m.png",
	"vampire":  "res://assets/tiles/individual/player/base/vampire_m.png",
	"minotaur": "res://assets/tiles/individual/player/base/minotaur_m.png",
	"kobold":   "res://assets/tiles/individual/player/base/kobold_m.png",
	"spriggan": "res://assets/tiles/individual/player/base/spriggan_m.png",
	"gargoyle": "res://assets/tiles/individual/player/base/gargoyle_m.png",
}

static func _portrait_stack(player: Player) -> Control:
	var panel := CenterContainer.new()
	panel.custom_minimum_size = Vector2(180, 220)
	var race_id: String = GameManager.selected_race_id if GameManager != null else "human"
	var tile_path: String = String(_RACE_PORTRAIT_MAP.get(race_id, _RACE_PORTRAIT_MAP["human"]))
	if ResourceLoader.exists(tile_path):
		var rect := TextureRect.new()
		rect.texture = load(tile_path) as Texture2D
		rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(160, 200)
		panel.add_child(rect)
	if player != null and "body_wounds" in player:
		var dummy := Control.new()
		dummy.custom_minimum_size = Vector2(160, 200)
		panel.add_child(dummy)
		_add_wound_overlay(dummy, player.body_wounds)
	return panel

static func _add_portrait_layer(parent: Control, tex: Texture2D) -> void:
	if parent == null or tex == null:
		return
	var rect := TextureRect.new()
	rect.texture = _south_atlas(tex)
	rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	rect.anchor_right = 1.0
	rect.anchor_bottom = 1.0
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.custom_minimum_size = Vector2(160, 200)
	parent.add_child(rect)

static func _add_wound_overlay(parent: Control, body_wounds: Dictionary) -> void:
	const PART_RECTS: Dictionary = {
		"head":      Rect2(32,  0,  32, 22),
		"torso":     Rect2(24, 22,  48, 36),
		"left_arm":  Rect2( 0, 22,  24, 36),
		"right_arm": Rect2(72, 22,  24, 36),
		"left_leg":  Rect2(24, 58,  24, 38),
		"right_leg": Rect2(48, 58,  24, 38),
	}
	for part in body_wounds.keys():
		var lvl: int = int(body_wounds[part])
		if lvl <= 0 or not PART_RECTS.has(part):
			continue
		var r: Rect2 = PART_RECTS[part]
		var rect := ColorRect.new()
		rect.position = r.position
		rect.size = r.size
		rect.color = Color(0.9, 0.1, 0.1, 0.55) if lvl >= 2 else Color(1.0, 0.55, 0.1, 0.45)
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(rect)

static func _resource_bar(label_text: String, value: int, max_value: int, tint: Color) -> Control:
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_S)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)
	vb.add_child(row)

	var label := Label.new()
	label.text = label_text
	label.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	row.add_child(label)

	var num := Label.new()
	num.text = "%d / %d" % [value, max_value]
	num.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	num.add_theme_color_override("font_color", tint)
	row.add_child(num)

	var bar := ProgressBar.new()
	bar.max_value = max(1, max_value)
	bar.value = clampi(value, 0, max(1, max_value))
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 16)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_color_override("font_color", tint)
	var fill := StyleBoxFlat.new()
	fill.bg_color = tint
	fill.corner_radius_top_left = 4
	fill.corner_radius_top_right = 4
	fill.corner_radius_bottom_left = 4
	fill.corner_radius_bottom_right = 4
	bar.add_theme_stylebox_override("fill", fill)
	vb.add_child(bar)
	return vb

static func _stat_block(label_text: String, value: int, help: String) -> Control:
	var card := UICards.card(Color(0.45, 0.75, 0.48))
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", GameTheme.PAD_S)
	card.add_child(vb)

	var name := Label.new()
	name.text = label_text
	name.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	name.add_theme_color_override("font_color", Color(0.92, 0.88, 0.65))
	vb.add_child(name)

	var val := Label.new()
	val.text = str(value)
	val.add_theme_font_size_override("font_size", GameTheme.TYPO_SUBTITLE)
	val.add_theme_color_override("font_color", Color(0.95, 0.95, 0.98))
	vb.add_child(val)

	var desc := Label.new()
	desc.text = help
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	desc.add_theme_color_override("font_color", Color(0.72, 0.75, 0.8))
	vb.add_child(desc)
	return card

static func _kv_row(label_text: String, value_text: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)
	var label := Label.new()
	label.text = "%s:" % label_text
	label.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	label.add_theme_color_override("font_color", Color(0.82, 0.82, 0.88))
	row.add_child(label)
	var value := Label.new()
	value.text = value_text
	value.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	value.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6))
	row.add_child(value)
	return row

static func _equipment_row(label_text: String, slot: String, player: Player) -> Control:
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", 2)

	var item_id := _equip_id(slot, player)
	var entry := _equip_entry(item_id, player)
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null and item_id != "" else null
	var name_text := "(empty)"
	if data != null:
		name_text = data.loc_name()
		var plus_val: int = int(entry.get("plus", 0))
		if plus_val != 0:
			name_text += " %+d" % plus_val

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", GameTheme.PAD_M)
	row.add_child(top)

	var label := Label.new()
	label.text = "%s:" % label_text
	label.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	label.add_theme_color_override("font_color", Color(0.8, 0.82, 0.88))
	top.add_child(label)

	var value := Label.new()
	value.text = name_text
	value.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	value.add_theme_color_override("font_color", Color(0.95, 0.88, 0.6) if data != null else Color(0.6, 0.6, 0.68))
	top.add_child(value)

	if data != null and data.loc_description() != "":
		var desc := Label.new()
		desc.text = data.loc_description()
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		desc.add_theme_color_override("font_color", Color(0.72, 0.74, 0.8))
		row.add_child(desc)
	return row

static func _resist_card(element: String, level: int) -> Control:
	var tint := _element_color(element)
	var card := UICards.card(tint)
	card.custom_minimum_size = Vector2(132, 72)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 2)
	card.add_child(vb)

	var title := Label.new()
	title.text = String(_RESIST_LABELS.get(element, element.capitalize()))
	title.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	title.add_theme_color_override("font_color", tint)
	vb.add_child(title)

	var value := Label.new()
	value.text = _resist_bar(level)
	value.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY_LARGE)
	value.add_theme_color_override("font_color", Color(0.95, 0.92, 0.85))
	vb.add_child(value)
	return card

static func _resist_bar(level: int) -> String:
	if level > 0:
		return "+".repeat(level)
	if level < 0:
		return "-".repeat(abs(level))
	return "0"

static func _element_color(element: String) -> Color:
	match element:
		"fire":
			return Color(1.0, 0.48, 0.24)
		"cold":
			return Color(0.5, 0.82, 1.0)
		"poison":
			return Color(0.45, 0.95, 0.45)
		"necro":
			return Color(0.72, 0.48, 0.95)
	return Color(0.82, 0.82, 0.88)

static func _essence_slot_row(dlg: GameDialog, player: Player, parent: Node, slot_index: int) -> Control:
	var unlocked := EssenceSystem.slot_is_unlocked(player, slot_index)
	var current_id := String(player.essence_slots[slot_index])
	var row := VBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_S)

	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", GameTheme.PAD_L)
	row.add_child(top)

	var title := Label.new()
	title.text = "Slot %d" % (slot_index + 1)
	title.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	title.add_theme_color_override("font_color", Color(0.9, 0.86, 0.65))
	top.add_child(title)

	if not unlocked:
		var locked := Label.new()
		locked.text = "(locked)"
		locked.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		locked.add_theme_color_override("font_color", Color(0.76, 0.55, 0.55))
		top.add_child(locked)
		return row

	if current_id != "":
		var icon := TextureRect.new()
		icon.texture = EssenceSystem.icon_texture_of(current_id)
		icon.custom_minimum_size = Vector2(28, 28)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		top.add_child(icon)

	var name := Label.new()
	name.text = EssenceSystem.display_name(current_id) if current_id != "" else "(empty)"
	name.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	name.add_theme_color_override("font_color", EssenceSystem.color_of(current_id) if current_id != "" else Color(0.62, 0.62, 0.68))
	top.add_child(name)

	var action := Button.new()
	action.text = "Swap"
	action.custom_minimum_size = Vector2(0, 36)
	action.pressed.connect(func():
		_open_essence_slot_picker(dlg, player, parent, slot_index))
	top.add_child(action)

	if current_id != "":
		var desc := Label.new()
		desc.text = EssenceSystem.description(current_id)
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		desc.add_theme_color_override("font_color", Color(0.74, 0.74, 0.8))
		row.add_child(desc)
	return row

static func _essence_inventory_row(essence_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", GameTheme.PAD_L)
	var icon := TextureRect.new()
	icon.texture = EssenceSystem.icon_texture_of(essence_id)
	icon.custom_minimum_size = Vector2(28, 28)
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	row.add_child(icon)

	var label := Label.new()
	label.text = "%s - %s" % [EssenceSystem.display_name(essence_id), EssenceSystem.description(essence_id)]
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
	label.add_theme_color_override("font_color", EssenceSystem.color_of(essence_id))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	return row

static func _open_essence_slot_picker(dlg: GameDialog, player: Player, parent: Node, slot_index: int) -> void:
	var picker := GameDialog.create_ratio("Essence Slot %d" % (slot_index + 1), 0.82, 0.72)
	parent.add_child(picker)
	var body := picker.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_L)

	var current_id := String(player.essence_slots[slot_index])
	var current := Label.new()
	current.text = "Current: %s" % (EssenceSystem.display_name(current_id) if current_id != "" else "(empty)")
	current.add_theme_font_size_override("font_size", GameTheme.TYPO_BODY)
	body.add_child(current)

	if player.essence_inventory.is_empty():
		var empty := Label.new()
		empty.text = "No carried essences available."
		empty.add_theme_font_size_override("font_size", GameTheme.TYPO_CAPTION)
		empty.add_theme_color_override("font_color", Color(0.72, 0.72, 0.78))
		body.add_child(empty)
	else:
		for eid in player.essence_inventory:
			var essence_id := String(eid)
			var btn := Button.new()
			btn.text = EssenceSystem.display_name(essence_id)
			btn.icon = EssenceSystem.icon_texture_of(essence_id)
			btn.custom_minimum_size = Vector2(0, 54)
			btn.pressed.connect(func():
				player.equip_essence(slot_index, essence_id)
				picker.close()
				_rebuild_body(dlg, player, parent))
			body.add_child(btn)

	if current_id != "":
		var clear_btn := Button.new()
		clear_btn.text = "Unequip"
		clear_btn.custom_minimum_size = Vector2(0, 48)
		clear_btn.pressed.connect(func():
			player.equip_essence(slot_index, "")
			picker.close()
			_rebuild_body(dlg, player, parent))
		body.add_child(clear_btn)

static func _equip_id(slot: String, player: Player) -> String:
	match slot:
		"weapon":
			return player.equipped_weapon_id
		"body":
			return player.equipped_armor_id
		"shield":
			return player.equipped_shield_id
		"ring":
			return player.equipped_ring_id
		"amulet":
			return player.equipped_amulet_id
		"helmet":
			return player.equipped_helmet_id
		"gloves":
			return player.equipped_gloves_id
		"boots":
			return player.equipped_boots_id
	return ""

static func _equip_entry(item_id: String, player: Player) -> Dictionary:
	if item_id == "":
		return {}
	for entry in player.items:
		if String(entry.get("id", "")) == item_id:
			return entry
	return {}
