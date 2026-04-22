class_name MagicDialog extends RefCounted

## Programmatic spell picker. Lists the player's known_spells, each
## with MP cost and a Cast button. Cast routes through MagicSystem
## and ends the player's turn.

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

	var mp_lab := Label.new()
	mp_lab.text = "MP: %d / %d" % [player.mp, player.mp_max]
	mp_lab.add_theme_font_size_override("font_size", 30)
	mp_lab.add_theme_color_override("font_color", Color(0.55, 0.75, 1.0))
	body.add_child(mp_lab)
	body.add_child(HSeparator.new())

	if player.known_spells.is_empty():
		var empty := Label.new()
		empty.text = "You know no spells."
		empty.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		body.add_child(empty)
		return

	for spell_id in player.known_spells:
		var spell: SpellData = SpellRegistry.get_by_id(spell_id)
		if spell == null:
			continue
		body.add_child(_make_row(spell, player, dlg, game))

static func _make_row(spell: SpellData, player: Player,
		dlg: GameDialog, game: Node) -> Control:
	var row := HBoxContainer.new()
	row.custom_minimum_size = Vector2(0, 68)
	row.add_theme_constant_override("separation", 8)

	var vb := VBoxContainer.new()
	vb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(vb)

	var name_lab := Label.new()
	name_lab.text = "%s   (%d MP)" % [spell.display_name, spell.mp_cost]
	name_lab.add_theme_font_size_override("font_size", 26)
	vb.add_child(name_lab)

	var desc_lab := Label.new()
	desc_lab.text = spell.description
	desc_lab.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc_lab.add_theme_font_size_override("font_size", 18)
	desc_lab.add_theme_color_override("font_color", Color(0.68, 0.68, 0.72))
	vb.add_child(desc_lab)

	var btn := Button.new()
	btn.custom_minimum_size = Vector2(140, 56)
	btn.add_theme_font_size_override("font_size", 24)
	btn.text = "Cast"
	btn.disabled = player.mp < spell.mp_cost
	if not btn.disabled:
		btn.pressed.connect(func(): _on_cast(spell.id, player, dlg, game))
	row.add_child(btn)
	return row

static func _on_cast(spell_id: String, player: Player,
		dlg: GameDialog, game: Node) -> void:
	var ok: bool = MagicSystem.cast(spell_id, player, game)
	dlg.close()
	if ok:
		TurnManager.end_player_turn()
