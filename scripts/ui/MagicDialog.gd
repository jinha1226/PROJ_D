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
	body.add_theme_constant_override("separation", 12)

	# MP status
	var mp_lbl := UICards.accent_value("MP  %d / %d" % [player.mp, player.mp_max])
	mp_lbl.add_theme_color_override("font_color", Color(0.5, 0.75, 1.0))
	body.add_child(mp_lbl)

	if player.known_spells.is_empty():
		body.add_child(UICards.dim_hint("You know no spells."))
		return

	for spell_id in player.known_spells:
		var spell: SpellData = SpellRegistry.get_by_id(String(spell_id))
		if spell == null:
			continue
		body.add_child(_make_spell_card(spell, player, dlg, game))


static func _make_spell_card(spell: SpellData, player: Player,
		dlg: GameDialog, game: Node) -> Control:
	var tint := _effect_color(spell.effect)
	var card := UICards.card(tint)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 6)
	card.add_child(vb)

	# Top row: name + cast button
	var top_row := HBoxContainer.new()
	top_row.add_theme_constant_override("separation", 8)
	vb.add_child(top_row)

	var name_lbl := Label.new()
	name_lbl.text = spell.display_name
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.add_theme_font_size_override("font_size", 32)
	name_lbl.add_theme_color_override("font_color", tint)
	top_row.add_child(name_lbl)

	var btn := Button.new()
	btn.text = "Cast"
	btn.custom_minimum_size = Vector2(130, 56)
	btn.add_theme_font_size_override("font_size", 26)
	btn.disabled = player.mp < spell.mp_cost
	if not btn.disabled:
		btn.pressed.connect(func(): _on_cast(spell.id, player, dlg, game))
	top_row.add_child(btn)

	# Stats row: MP + fail%
	var fail_pct: int = _fail_pct(player, spell)
	var stats_lbl := UICards.dim_hint(
		"MP: %d   Fail: %d%%   Range: %s" % [
			spell.mp_cost, fail_pct,
			("%d tiles" % spell.max_range) if spell.max_range > 0 else "self"])
	vb.add_child(stats_lbl)

	# Effect description
	vb.add_child(UICards.dim_hint(_describe(player, spell), 26))

	return card


static func _describe(player: Player, spell: SpellData) -> String:
	var power: int = _compute_power(player)
	match spell.effect:
		"damage":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 2 + power / 3
			return "Bolt — deals %d–%d damage to nearest enemy" % [lo, hi]
		"multi_damage":
			var lo: int = spell.base_damage + power / 4
			var hi: int = spell.base_damage + 2 + power / 4
			return "3 darts — %d–%d each, auto-targets nearest" % [lo, hi]
		"aoe_damage":
			var lo: int = spell.base_damage + power / 3
			var hi: int = spell.base_damage + 3 + power / 3
			return "AoE — %d–%d to all visible enemies in %d tiles" % [lo, hi, spell.max_range]
		"heal":
			var amt: int = 12 + power / 2
			return "Heals %d HP  (12 + power/2)" % amt
		"blink":
			return "Teleports you to a random tile ≥%d tiles away" % spell.max_range
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
	var ok: bool = MagicSystem.cast(spell_id, player, game)
	dlg.close()
	if ok:
		TurnManager.end_player_turn()
