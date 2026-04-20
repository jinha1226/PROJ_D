class_name DungeonMap extends Node2D

const TILE_SIZE: int = 32
const EXPLORE_RADIUS: int = 6

var generator: DungeonGenerator = null
var _path_tiles: Array[Vector2i] = []
# Flat-indexed byte array: 1 = explored, 0 = unseen. Resized on render().
var explored: PackedByteArray = PackedByteArray()
# Current-frame visible set (tiles the player can see from their position
# with line-of-sight through walls blocked). Recomputed on update_fov().
var _visible_tiles: Dictionary = {}
var danger_tiles: Array[Vector2i] = []


func render(gen: DungeonGenerator) -> void:
	generator = gen
	_path_tiles.clear()
	explored.resize(DungeonGenerator.MAP_WIDTH * DungeonGenerator.MAP_HEIGHT)
	explored.fill(0)
	_visible_tiles.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Group membership lets sibling systems (MonsterAI wake check) fetch the
	# FOV data without threading a reference through every call site.
	if not is_in_group("dmap"):
		add_to_group("dmap")
	queue_redraw()


## Compute line-of-sight visibility from `center` with Chebyshev `radius`.
## Walls block sight. Visible tiles also get marked explored.
func update_fov(center: Vector2i, radius: int = EXPLORE_RADIUS) -> void:
	if generator == null:
		return
	_visible_tiles.clear()
	_visible_tiles[center] = true
	_mark_tile_explored(center)
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if max(abs(dx), abs(dy)) > radius:
				continue
			if dx == 0 and dy == 0:
				continue
			var target: Vector2i = Vector2i(center.x + dx, center.y + dy)
			if _has_los(center, target):
				_visible_tiles[target] = true
				_mark_tile_explored(target)
	queue_redraw()


## Renamed from is_visible() to avoid shadowing CanvasItem's zero-arg
## is_visible() getter — that conflict made every call resolve to the
## node's own .visible property (always true), leaking actors into
## unexplored tiles.
func is_tile_visible(tile: Vector2i) -> bool:
	return _visible_tiles.has(tile)


## Kept for backward compatibility — just forwards to update_fov.
func mark_explored(center: Vector2i, radius: int = EXPLORE_RADIUS) -> void:
	update_fov(center, radius)


## Mark every tile explored — used by the Magic Mapping scroll.
func reveal_all() -> void:
	if generator == null:
		return
	explored.fill(1)
	queue_redraw()


func is_explored(tile: Vector2i) -> bool:
	var mw: int = DungeonGenerator.MAP_WIDTH
	if tile.x < 0 or tile.x >= mw or tile.y < 0 or tile.y >= DungeonGenerator.MAP_HEIGHT:
		return false
	return explored[tile.y * mw + tile.x] == 1


func _mark_tile_explored(tile: Vector2i) -> void:
	var mw: int = DungeonGenerator.MAP_WIDTH
	if tile.x < 0 or tile.x >= mw or tile.y < 0 or tile.y >= DungeonGenerator.MAP_HEIGHT:
		return
	explored[tile.y * mw + tile.x] = 1


## Bresenham line-of-sight: true if no WALL lies between from and to (endpoints
## excluded so a wall on `to` is still visible — you can see the wall's face).
func _has_los(from: Vector2i, to: Vector2i) -> bool:
	var dx: int = abs(to.x - from.x)
	var dy: int = abs(to.y - from.y)
	var sx: int = 1 if from.x < to.x else -1
	var sy: int = 1 if from.y < to.y else -1
	var err: int = dx - dy
	var x: int = from.x
	var y: int = from.y
	while true:
		if x == to.x and y == to.y:
			return true
		if not (x == from.x and y == from.y):
			if x < 0 or x >= DungeonGenerator.MAP_WIDTH:
				return false
			if y < 0 or y >= DungeonGenerator.MAP_HEIGHT:
				return false
			if generator.map[x][y] == DungeonGenerator.TileType.WALL:
				return false
		var e2: int = 2 * err
		if e2 > -dy:
			err -= dy
			x += sx
		if e2 < dx:
			err += dx
			y += sy
	return true

## Show the planned auto-move path as blue-green dots.
func show_path(path: Array[Vector2i]) -> void:
	_path_tiles.assign(path)
	queue_redraw()

func clear_path() -> void:
	if _path_tiles.is_empty():
		return
	_path_tiles.clear()
	queue_redraw()

func _draw() -> void:
	if generator == null or generator.map.is_empty():
		return
	if TileRenderer.is_ascii():
		_draw_ascii()
	elif TileRenderer.is_dcss():
		_draw_dcss()
	else:
		_draw_lpc()
	# Danger tile overlay — red pulsing squares for boss telegraphed attacks.
	var danger_color: Color = Color(1.0, 0.15, 0.1, 0.35)
	for tile in danger_tiles:
		if not is_explored(tile):
			continue
		var rect := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, danger_color, true)
	# Path overlay dots — drawn on top in both modes.
	var path_color: Color = Color(0.2, 0.85, 0.85, 0.55)
	var dot_size: float = TILE_SIZE * 0.35
	for tile in _path_tiles:
		if not is_explored(tile):
			continue
		var cx: float = tile.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy: float = tile.y * TILE_SIZE + TILE_SIZE * 0.5
		draw_circle(Vector2(cx, cy), dot_size, path_color)


func _draw_dcss() -> void:
	var floor_tex: Texture2D = TileRenderer.feature("floor")
	var wall_tex: Texture2D = TileRenderer.feature("wall")
	var stairs_dn_tex: Texture2D = TileRenderer.feature("stairs_down")
	var stairs_up_tex: Texture2D = TileRenderer.feature("stairs_up")
	var water_tex: Texture2D = TileRenderer.feature("water")
	var lava_tex: Texture2D = TileRenderer.feature("lava")
	var tree_tex: Texture2D = TileRenderer.feature("tree")
	var door_open_tex: Texture2D = TileRenderer.feature("door_open")
	var door_closed_tex: Texture2D = TileRenderer.feature("door_closed")
	var unseen_color := Color(0.02, 0.02, 0.04)
	var dim := Color(0.45, 0.45, 0.45)  # mod for explored-but-not-visible
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			var t: int = generator.map[x][y]
			var modulate: Color = Color.WHITE if is_tile_visible(tile) else dim
			var tex: Texture2D = floor_tex
			match t:
				DungeonGenerator.TileType.WALL:
					# Rock filling between rooms stays black — only walls
					# that border a walkable tile (i.e. an actual room /
					# corridor edge) get a wall sprite drawn. DCSS-style
					# clean look instead of a carpet of rock_wall texture.
					if not _wall_borders_floor(tile):
						draw_rect(rect, unseen_color, true)
						continue
					tex = wall_tex
				DungeonGenerator.TileType.TREE:
					# Trees sit on a floor backdrop so edges read.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = tree_tex
				DungeonGenerator.TileType.STAIRS_DOWN:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = stairs_dn_tex
				DungeonGenerator.TileType.STAIRS_UP:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = stairs_up_tex
				DungeonGenerator.TileType.WATER:
					tex = water_tex
				DungeonGenerator.TileType.LAVA:
					tex = lava_tex
				DungeonGenerator.TileType.DOOR_OPEN:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = door_open_tex
				DungeonGenerator.TileType.DOOR_CLOSED:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = door_closed_tex
			if tex != null:
				draw_texture_rect(tex, rect, false, modulate)
			else:
				# Last-resort solid fill if the tile asset is missing.
				draw_rect(rect, Color(0.4, 0.4, 0.4) * modulate, true)


## Classic roguelike console view — every tile gets a character glyph.
## True iff any 8-neighbour of `tile` is a walkable feature — corridor
## or room interior. Used so rock walls deep in the dungeon bulk can
## render as empty black space instead of a wall sprite.
func _wall_borders_floor(tile: Vector2i) -> bool:
	if generator == null:
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n: Vector2i = Vector2i(tile.x + dx, tile.y + dy)
			if n.x < 0 or n.y < 0 \
					or n.x >= DungeonGenerator.MAP_WIDTH \
					or n.y >= DungeonGenerator.MAP_HEIGHT:
				continue
			var nt: int = generator.map[n.x][n.y]
			if nt == DungeonGenerator.TileType.FLOOR \
					or nt == DungeonGenerator.TileType.DOOR_OPEN \
					or nt == DungeonGenerator.TileType.DOOR_CLOSED \
					or nt == DungeonGenerator.TileType.STAIRS_UP \
					or nt == DungeonGenerator.TileType.STAIRS_DOWN \
					or nt == DungeonGenerator.TileType.WATER \
					or nt == DungeonGenerator.TileType.LAVA:
				return true
	return false


func _draw_ascii() -> void:
	var unseen_color := Color(0.02, 0.02, 0.04)
	var bg_color := Color(0.04, 0.04, 0.06)
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			# Solid background so glyphs pop.
			draw_rect(rect, bg_color, true)
			var t: int = generator.map[x][y]
			var entry: Array = TileRenderer.ascii_feature(t)
			var glyph: String = String(entry[0])
			var color: Color = entry[1]
			TileRenderer.draw_ascii_glyph(self,
					Vector2(x * TILE_SIZE + TILE_SIZE * 0.5,
							y * TILE_SIZE + TILE_SIZE * 0.5),
					TILE_SIZE, glyph, color, is_tile_visible(tile))


func _draw_lpc() -> void:
	var wall_color: Color = Color(0.18, 0.18, 0.2)
	var floor_color: Color = Color(0.55, 0.55, 0.58)
	var stairs_color: Color = Color(0.95, 0.82, 0.15)
	var stairs_up_color: Color = Color(0.55, 0.78, 0.95)
	var unseen_color: Color = Color(0.02, 0.02, 0.04)
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			var t: int = generator.map[x][y]
			var base: Color = floor_color
			match t:
				DungeonGenerator.TileType.STAIRS_DOWN: base = stairs_color
				DungeonGenerator.TileType.STAIRS_UP: base = stairs_up_color
				_: base = floor_color
			var dim_base: bool = not is_tile_visible(tile)
			if dim_base:
				base = base.darkened(0.55)
			if t == DungeonGenerator.TileType.WALL:
				var wc: Color = wall_color if not dim_base else wall_color.darkened(0.55)
				draw_rect(rect, wc, true)
			else:
				draw_rect(rect, base, true)
