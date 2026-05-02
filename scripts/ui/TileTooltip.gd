class_name TileTooltip extends RefCounted

static func show_at(grid_pos: Vector2i, parent: Node) -> void:
	var text: Array = _gather(grid_pos)
	if text.is_empty():
		return
	var title: String = text[0]
	var body_lines: Array = text.slice(1)

	var dlg: GameDialog = GameDialog.create_ratio(title, 0.78, 0.40)
	parent.add_child(dlg)
	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 8)

	for line in body_lines:
		var lbl := Label.new()
		lbl.text = String(line)
		lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		lbl.add_theme_font_size_override("font_size", 22)
		lbl.add_theme_color_override("font_color", Color(0.78, 0.82, 0.88))
		body.add_child(lbl)


static func _gather(pos: Vector2i) -> Array:
	var tree: SceneTree = Engine.get_main_loop() as SceneTree
	if tree == null:
		return []

	# Monster check
	for n in tree.get_nodes_in_group("monsters"):
		if n is Monster and n.grid_pos == pos:
			return _monster_lines(n)

	# Floor item check
	for n in tree.get_nodes_in_group("floor_items"):
		if n is FloorItem and n.grid_pos == pos:
			return _item_lines(n.data)

	# Special tile / altar
	var game: Node = tree.current_scene
	if game == null:
		return []
	var map_node = game.get("map")
	if map_node == null:
		return []
	return _tile_lines(pos, map_node)


static func _monster_lines(m: Monster) -> Array:
	var data: MonsterData = m.data if "data" in m else null
	if data == null:
		return []
	var lines: Array = [data.display_name]
	lines.append("HP %d / %d" % [m.hp, data.hp])
	if data.ac > 0:
		lines.append("AC %d" % data.ac)
	if data.resists.size() > 0:
		lines.append("저항: %s" % ", ".join(data.resists))
	if data.description != "":
		lines.append(data.description)
	return lines


static func _item_lines(data: ItemData) -> Array:
	if data == null:
		return []
	var title: String = GameManager.display_name_of(data.id) if GameManager != null else data.display_name
	var lines: Array = [title]
	if data.description != "":
		lines.append(data.description)
	return lines


static func _tile_lines(pos: Vector2i, map) -> Array:
	var tile: int = map.tile_at(pos)
	match tile:
		DungeonMap.Tile.STAIRS_DOWN:
			return ["하강 계단", "더 깊은 층으로 이어진다."]
		DungeonMap.Tile.STAIRS_UP:
			return ["상승 계단", "위층으로 이어진다."]
		DungeonMap.Tile.DOOR_CLOSED:
			return ["닫힌 문", "통과하면 자동으로 열린다."]
		DungeonMap.Tile.DOOR_OPEN:
			return ["열린 문", ""]
		DungeonMap.Tile.WALL:
			return ["벽", "통행 불가."]
	# Check for altar
	if map.altar_map != null and map.altar_map.has(pos):
		var faith_id: String = String(map.altar_map[pos])
		var faith: Dictionary = FaithSystem.get_faith(faith_id)
		return [String(faith.get("name", faith_id)), String(faith.get("short", ""))]
	return []
