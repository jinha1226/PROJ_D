class_name MagicDialog extends RefCounted

const _SCHOOL_ORDER: Array = [
	"evocation", "conjuration", "transmutation",
	"necromancy", "abjuration", "enchantment",
]

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create_ratio("Magic", 0.96, 0.96)
	parent.add_child(dlg)
	_populate(dlg, player, parent)


static func _populate(dlg: GameDialog, player: Player, game: Node) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 6)

	var mp_lbl := Label.new()
	mp_lbl.text = "MP  %d / %d" % [player.mp, player.mp_max]
	mp_lbl.add_theme_font_size_override("font_size", 30)
	mp_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	body.add_child(mp_lbl)

	if player.known_spells.is_empty():
		var empty := Label.new()
		empty.text = "You know no spells."
		empty.add_theme_color_override("font_color", Color(0.55, 0.55, 0.6))
		body.add_child(empty)
		return

	# Group known spells by school
	var by_school: Dictionary = {}
	for spell_id in player.known_spells:
		var spell: SpellData = SpellRegistry.get_by_id(String(spell_id))
		if spell == null:
			continue
		var s: String = spell.school if spell.school != "" else "other"
		if not by_school.has(s):
			by_school[s] = []
		by_school[s].append(spell)

	# Sort each school's spells by level
	for school in by_school:
		by_school[school].sort_custom(func(a, b): return a.spell_level < b.spell_level)

	# Render in defined order
	for school in _SCHOOL_ORDER:
		if not by_school.has(school):
			continue
		var hdr := UICards.section_header(school.to_upper(), 26)
		var hdr_lbl: Label = _find_label(hdr)
		if hdr_lbl:
			hdr_lbl.add_theme_color_override("font_color", _school_color(school))
		body.add_child(hdr)
		for spell in by_school[school]:
			body.add_child(_make_spell_row(spell, player, dlg, game))

	# Any school not in the defined order
	for school in by_school:
		if _SCHOOL_ORDER.has(school):
			continue
		body.add_child(UICards.section_header(school.to_upper(), 26))
		for spell in by_school[school]:
			body.add_child(_make_spell_row(spell, player, dlg, game))


static func _make_spell_row(spell: SpellData, player: Player,
		dlg: GameDialog, game: Node) -> Control:
	var skill_id: String = spell.school if spell.school != "" else "magic"
	var locked: bool = spell.spell_level > player.get_skill_level(skill_id)
	var no_mp: bool = player.mp < spell.mp_cost

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	# Level badge
	var lv_lbl := Label.new()
	lv_lbl.text = "Lv%d" % spell.spell_level
	lv_lbl.custom_minimum_size = Vector2(44, 0)
	lv_lbl.add_theme_font_size_override("font_size", 18)
	lv_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lv_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv_lbl.add_theme_color_override("font_color",
			Color(0.5, 0.5, 0.55) if locked else Color(0.75, 0.85, 0.75))
	row.add_child(lv_lbl)

	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = spell.display_name
	name_lbl.add_theme_font_size_override("font_size", 26)
	var name_color: Color
	if locked:
		name_color = Color(0.45, 0.45, 0.5)
	else:
		name_color = _school_color(spell.school)
	name_lbl.add_theme_color_override("font_color", name_color)
	info.add_child(name_lbl)

	var stat_lbl := Label.new()
	if locked:
		var sk: String = spell.school.capitalize() if spell.school != "" else "Magic"
		stat_lbl.text = "%s skill %d required" % [sk, spell.spell_level]
		stat_lbl.add_theme_color_override("font_color", Color(0.55, 0.45, 0.45))
	else:
		var range_str: String = "%d tiles" % spell.max_range if spell.max_range > 0 else "self"
		var armor_mult: float = _armor_spell_mult(player)
		var armor_note: String = ""
		if armor_mult < 1.0:
			armor_note = "  ⚠-%d%%" % int(round((1.0 - armor_mult) * 100.0))
		stat_lbl.text = "MP:%d  %s  %s%s" % [
			spell.mp_cost, range_str, _describe(player, spell), armor_note]
		var stat_color: Color = Color(0.85, 0.55, 0.35) if armor_mult < 1.0 else Color(0.6, 0.62, 0.68)
		stat_lbl.add_theme_color_override("font_color", stat_color)
	stat_lbl.add_theme_font_size_override("font_size", 19)
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(stat_lbl)

	if not locked and spell.description != "":
		var desc_lbl := Label.new()
		desc_lbl.text = spell.description
		desc_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc_lbl.add_theme_font_size_override("font_size", 18)
		desc_lbl.add_theme_color_override("font_color", Color(0.65, 0.68, 0.78))
		info.add_child(desc_lbl)

	# Cast button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(110, 52)
	btn.add_theme_font_size_override("font_size", 22)
	if locked:
		btn.text = "Locked"
		btn.disabled = true
	elif no_mp:
		btn.text = "No MP"
		btn.disabled = true
	else:
		btn.text = "Cast"
		btn.pressed.connect(func(): _on_cast(spell.id, player, dlg, game))
	row.add_child(btn)

	return row


static func _describe(player: Player, spell: SpellData) -> String:
	var power: int = _compute_power(player, spell)
	match spell.effect:
		"damage", "drain":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 2 + power / 3
			return "%d-%d dmg" % [lo, hi]
		"multi_damage", "chain_damage":
			var lo: int = spell.base_damage + power / 4
			var hi: int = spell.base_damage + 2 + power / 4
			return "×3  %d-%d" % [lo, hi]
		"aoe_damage":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 3 + power / 3
			return "AoE %d-%d" % [lo, hi]
		"heal":
			return "+%d HP" % (12 + power / 2)
		"blink":        return "Teleport"
		"fog":          return "Block vision"
		"sleep":        return "Sleep (5d8 HP)"
		"hold":         return "Paralyze"
		"fear":         return "Frighten"
		"confusion":    return "Confuse"
		"buff_ac":      return "AC 13+DEX"
		"buff_speed":   return "Speed ×2"
		"buff_haste":   return "Extra action"
		"buff_damage":  return "+1d4 dmg"
		"buff_resist":  return "Elem resist"
		"buff_blur":    return "Dodge bonus"
		"buff_stoneskin": return "Phys resist"
		"buff_magic_ward": return "Spell ward"
		"buff_invulnerable": return "Immune dmg"
		"instant_kill": return "HP≤100 dies"
		"power_word_pain": return "HP≤100 pain"
		"power_word_stun": return "HP≤150 stun"
		"debuff_str":   return "Halve dmg"
		"polymorph":    return "Beastform"
		"summon":       return "Summon ally"
		"disease":      return "Disease"
		"floor_travel": return "Floor warp"
		"banish":       return "Remove foe"
		"aoe_status":   return "AoE status"
		"time_stop":    return "Extra turns"
		"earthquake":   return "Stun all"
		"stun":         return "Stun area"
		"prismatic":    return "Random effect"
		"astral":       return "Ethereal form"
	return spell.description.left(28)


static func _armor_spell_mult(player: Player) -> float:
	match player.equipped_armor_id:
		"robe", "": return 1.0
		"leather_armor": return 0.85
		"chain_mail": return 0.65
		_: return 0.5


static func _compute_power(player: Player, spell: SpellData) -> int:
	var skill_id: String = spell.school if spell.school != "" else "magic"
	var skill: int = player.get_skill_level(skill_id)
	return int(float(player.intelligence) * (1.0 + float(skill) * 0.06) * _armor_spell_mult(player))


static func _school_color(school: String) -> Color:
	match school:
		"evocation":    return Color(1.0, 0.55, 0.25)
		"conjuration":  return Color(0.3, 0.9, 0.85)
		"transmutation": return Color(0.4, 0.95, 0.5)
		"necromancy":   return Color(0.75, 0.45, 0.9)
		"abjuration":   return Color(0.5, 0.7, 1.0)
		"enchantment":  return Color(1.0, 0.65, 0.85)
	return Color(0.8, 0.8, 0.85)


static func _find_label(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var result := _find_label(child)
		if result:
			return result
	return null


static func _on_cast(spell_id: String, player: Player,
		dlg: GameDialog, game: Node) -> void:
	var spell: SpellData = SpellRegistry.get_by_id(spell_id)
	if spell == null:
		return
	# Auto-cast: self, nearest (auto-target), aoe/area (all visible).
	# "single" opens the targeting UI for explicit tile selection.
	if spell.targeting != "single":
		var ok: bool = MagicSystem.cast(spell_id, player, game)
		dlg.close()
		if ok:
			TurnManager.end_player_turn()
		return
	dlg.close()
	if game != null and game.has_method("begin_spell_targeting"):
		game.begin_spell_targeting(spell, player)
