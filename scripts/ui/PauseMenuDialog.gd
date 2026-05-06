class_name PauseMenuDialog extends RefCounted

static func open(game: Node) -> void:
	var dlg: GameDialog = GameDialog.create(TranslationServer.translate("PAUSEMENU_TITLE"))
	game.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", GameTheme.PAD_XL)

	_add_btn(body, TranslationServer.translate("PAUSEMENU_BESTIARY"), func() -> void:
		dlg.close()
		BestiaryDialog.open(game)
	)

	_add_btn(body, TranslationServer.translate("PAUSEMENU_OPTIONS"), func() -> void:
		OptionsDialog.open(game)
	)

	var _tile_text := func() -> String:
		var key: String = "OPTIONS_DISPLAY_TILES" if GameManager.use_tiles else "OPTIONS_DISPLAY_ASCII"
		return "%s: %s" % [TranslationServer.translate("OPTIONS_DISPLAY"), TranslationServer.translate(key)]
	var tile_btn: Button = _make_btn(_tile_text.call())
	body.add_child(tile_btn)
	tile_btn.pressed.connect(func() -> void:
		GameManager.toggle_tiles()
		tile_btn.text = _tile_text.call()
		_refresh_display(game)
	)

	_add_btn(body, TranslationServer.translate("PAUSEMENU_SAVE_QUIT"), func() -> void:
		dlg.close()
		if game.get("player") != null and (game.player as Object).get("hp") > 0:
			if game.has_method("save_with_cache"):
				game.save_with_cache()
			else:
				SaveManager.save_run(game.player, GameManager)
		GameManager.run_in_progress = false
		game.get_tree().change_scene_to_file("res://scenes/menu/MainMenu.tscn")
	)


static func _add_btn(parent: Node, label: String, cb: Callable) -> void:
	var btn: Button = _make_btn(label)
	parent.add_child(btn)
	btn.pressed.connect(cb)


static func _make_btn(label: String) -> Button:
	var btn := Button.new()
	btn.text = label
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btn.custom_minimum_size = Vector2(0, 72)
	btn.add_theme_font_size_override("font_size", GameTheme.TYPO_TITLE)
	return btn


static func _refresh_display(game: Node) -> void:
	if game.get("map") != null:
		game.map.queue_redraw()
	for n in game.get_tree().get_nodes_in_group("monsters"):
		n.queue_redraw()
	for n in game.get_tree().get_nodes_in_group("floor_items"):
		n.queue_redraw()
	if game.get("player") != null:
		game.player.queue_redraw()
