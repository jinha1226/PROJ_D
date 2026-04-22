class_name MinimapRenderer extends RefCounted

## Renders the DungeonMap into a small ImageTexture for the TopHUD
## minimap button. Explored tiles show base color, tiles currently in
## FOV are brighter. Player and visible monsters plot as single
## bright pixels.

const SCALE: int = 2

static func render(map: DungeonMap, player: Player, game: Node,
		scale_override: int = -1) -> ImageTexture:
	var scale: int = scale_override if scale_override > 0 else SCALE
	var w: int = DungeonMap.GRID_W * scale
	var h: int = DungeonMap.GRID_H * scale
	var img: Image = Image.create(w, h, false, Image.FORMAT_RGBA8)
	img.fill(Color(0, 0, 0, 0))

	for y in range(DungeonMap.GRID_H):
		for x in range(DungeonMap.GRID_W):
			var pos := Vector2i(x, y)
			if not map.explored.has(pos):
				continue
			var t: int = map.tile_at(pos)
			var is_vis: bool = map.visible_tiles.has(pos)
			_plot(img, x * scale, y * scale, scale, _tile_color(t, is_vis))

	if player != null:
		var ppos: Vector2i = player.grid_pos
		_plot(img, ppos.x * scale, ppos.y * scale, scale,
			Color(1.0, 0.45, 0.45))

	if game != null:
		for n in game.get_tree().get_nodes_in_group("monsters"):
			if not (n is Monster):
				continue
			if not map.visible_tiles.has(n.grid_pos):
				continue
			_plot(img, n.grid_pos.x * scale, n.grid_pos.y * scale, scale,
				Color(1.0, 0.65, 0.3))

	return ImageTexture.create_from_image(img)

static func _plot(img: Image, px: int, py: int, size: int,
		color: Color) -> void:
	var w: int = img.get_width()
	var h: int = img.get_height()
	for dy in range(size):
		for dx in range(size):
			var x: int = px + dx
			var y: int = py + dy
			if x >= 0 and x < w and y >= 0 and y < h:
				img.set_pixel(x, y, color)

static func _tile_color(t: int, visible: bool) -> Color:
	var base: Color
	match t:
		DungeonMap.Tile.WALL:
			base = Color(0.28, 0.24, 0.2)
		DungeonMap.Tile.FLOOR:
			base = Color(0.48, 0.44, 0.38)
		DungeonMap.Tile.STAIRS_UP:
			base = Color(1.0, 1.0, 0.55)
		DungeonMap.Tile.STAIRS_DOWN:
			base = Color(0.55, 1.0, 1.0)
		DungeonMap.Tile.DOOR_CLOSED:
			base = Color(0.7, 0.5, 0.3)
		DungeonMap.Tile.DOOR_OPEN:
			base = Color(0.55, 0.4, 0.25)
		_:
			base = Color(0.35, 0.3, 0.3)
	if not visible:
		base = base.darkened(0.4)
	return base
