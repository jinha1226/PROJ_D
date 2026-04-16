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


func render(gen: DungeonGenerator) -> void:
	generator = gen
	_path_tiles.clear()
	explored.resize(DungeonGenerator.MAP_WIDTH * DungeonGenerator.MAP_HEIGHT)
	explored.fill(0)
	_visible_tiles.clear()
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
			var c: Color = floor_color
			match t:
				DungeonGenerator.TileType.WALL: c = wall_color
				DungeonGenerator.TileType.FLOOR: c = floor_color
				DungeonGenerator.TileType.STAIRS_DOWN: c = stairs_color
				DungeonGenerator.TileType.STAIRS_UP: c = stairs_up_color
				_: c = floor_color
			if not is_tile_visible(tile):
				c = c.darkened(0.55)  # explored but outside current sight
			draw_rect(rect, c, true)
	# Path overlay dots (only draw on explored tiles so hidden paths aren't spoilery).
	var path_color: Color = Color(0.2, 0.85, 0.85, 0.55)
	var dot_size: float = TILE_SIZE * 0.35
	for tile in _path_tiles:
		if not is_explored(tile):
			continue
		var cx: float = tile.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy: float = tile.y * TILE_SIZE + TILE_SIZE * 0.5
		draw_circle(Vector2(cx, cy), dot_size, path_color)
