class_name PauseMenuDialog extends RefCounted
static var GameManager = Engine.get_main_loop().root.get_node_or_null("/root/GameManager") if Engine.get_main_loop() is SceneTree else null
static var SaveManager = Engine.get_main_loop().root.get_node_or_null("/root/SaveManager") if Engine.get_main_loop() is SceneTree else null

static func open(game: Node) -> void:
	var dlg: GameDialog = GameDialog.create("Menu")
	game.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 16)

	_add_btn(body, "도감 (Bestiary)", func() -> void:
		dlg.close()
		BestiaryDialog.open(game)
	)

	var tile_label: String = "Display: %s" % ("Tiles" if GameManager.use_tiles else "ASCII")
	var tile_btn: Button = _make_btn(tile_label)
	body.add_child(tile_btn)
	tile_btn.pressed.connect(func() -> void:
		GameManager.toggle_tiles()
		tile_btn.text = "Display: %s" % ("Tiles" if GameManager.use_tiles else "ASCII")
		_refresh_display(game)
	)

	_add_btn(body, "저장 후 종료", func() -> void:
		dlg.close()
		if game.get("player") != null and (game.player as Object).get("hp") > 0:
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
	btn.add_theme_font_size_override("font_size", 30)
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
