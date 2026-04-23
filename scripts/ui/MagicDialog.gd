class_name MagicDialog extends RefCounted

static func open(player: Player, parent: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Magic")
	parent.add_child(dlg)
	_populate(dlg, player, parent)

static func _populate(dlg: GameDialog, player: Player, game: Node) -> void:
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	for child in body.get_children():
		child.queue_free()
	body.add_theme_constant_override("separation", 8)

	# MP status
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

	body.add_child(UICards.section_header("SPELLS"))

	for spell_id in player.known_spells:
		var spell: SpellData = SpellRegistry.get_by_id(String(spell_id))
		if spell == null:
			continue
		body.add_child(_make_spell_row(spell, player, dlg, game))


static func _make_spell_row(spell: SpellData, player: Player,
		dlg: GameDialog, game: Node) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	row.add_child(info)

	var name_lbl := Label.new()
	name_lbl.text = spell.display_name
	name_lbl.add_theme_font_size_override("font_size", 28)
	name_lbl.add_theme_color_override("font_color", _effect_color(spell.effect))
	info.add_child(name_lbl)

	var fail_pct: int = _fail_pct(player, spell)
	var stat_lbl := Label.new()
	stat_lbl.text = "MP:%d  Fail:%d%%  %s  %s" % [
		spell.mp_cost, fail_pct,
		("%d tiles" % spell.max_range) if spell.max_range > 0 else "self",
		_describe(player, spell)]
	stat_lbl.add_theme_font_size_override("font_size", 20)
	stat_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.7))
	stat_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.add_child(stat_lbl)

	var btn := Button.new()
	btn.text = "Cast"
	btn.custom_minimum_size = Vector2(110, 52)
	btn.add_theme_font_size_override("font_size", 24)
	btn.disabled = player.mp < spell.mp_cost
	if not btn.disabled:
		btn.pressed.connect(func(): _on_cast(spell.id, player, dlg, game))
	row.add_child(btn)

	return row


static func _describe(player: Player, spell: SpellData) -> String:
	var power: int = _compute_power(player)
	match spell.effect:
		"damage":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 2 + power / 3
			return "%d-%d dmg" % [lo, hi]
		"multi_damage":
			var lo: int = spell.base_damage + power / 4
			var hi: int = spell.base_damage + 2 + power / 4
			return "3×%d-%d" % [lo, hi]
		"aoe_damage":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 3 + power / 3
			return "AoE %d-%d" % [lo, hi]
		"heal":
			return "+%dHP" % (12 + power / 2)
		"blink":
			return "Teleport"
	return ""


static func _compute_power(player: Player) -> int:
	var skill: int = player.get_skill_level("magic")
	return int(player.intelligence + skill * player.intelligence / 10.0)


static func _fail_pct(player: Player, spell: SpellData) -> int:
	var skill: int = player.get_skill_level("magic")
	return max(0, 25 + spell.difficulty * 5 - skill * 3 - player.intelligence / 2)


static func _effect_color(effect: String) -> Color:
	match effect:
		"damage":       return Color(0.5, 0.7, 1.0)
		"multi_damage": return Color(0.75, 0.55, 1.0)
		"aoe_damage":   return Color(1.0, 0.55, 0.25)
		"heal":         return Color(0.4, 1.0, 0.6)
		"blink":        return Color(0.4, 0.9, 0.9)
	return Color(0.7, 0.7, 0.7)


static func _on_cast(spell_id: String, player: Player,
		dlg: GameDialog, game: Node) -> void:
	var spell: SpellData = SpellRegistry.get_by_id(spell_id)
	if spell == null:
		return
	if spell.effect == "heal" or spell.effect == "blink":
		var ok: bool = MagicSystem.cast(spell_id, player, game)
		dlg.close()
		if ok:
			TurnManager.end_player_turn()
		return
	dlg.close()
	if game != null and game.has_method("begin_spell_targeting"):
		game.begin_spell_targeting(spell, player)
