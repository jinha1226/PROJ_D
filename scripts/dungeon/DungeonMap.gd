class_name DungeonMap extends Node2D

const TILE_SIZE: int = 32

var generator: DungeonGenerator = null
var _path_tiles: Array[Vector2i] = []

func render(gen: DungeonGenerator) -> void:
	generator = gen
	_path_tiles.clear()
	queue_redraw()

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
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var t: int = generator.map[x][y]
			var rect: Rect2 = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			match t:
				DungeonGenerator.TileType.WALL:
					draw_rect(rect, wall_color, true)
				DungeonGenerator.TileType.FLOOR:
					draw_rect(rect, floor_color, true)
				DungeonGenerator.TileType.STAIRS_DOWN:
					draw_rect(rect, stairs_color, true)
				DungeonGenerator.TileType.STAIRS_UP:
					draw_rect(rect, stairs_up_color, true)
				_:
					draw_rect(rect, floor_color, true)
	# Draw path overlay dots.
	var path_color: Color = Color(0.2, 0.85, 0.85, 0.55)
	var dot_size: float = TILE_SIZE * 0.35
	for tile in _path_tiles:
		var cx: float = tile.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy: float = tile.y * TILE_SIZE + TILE_SIZE * 0.5
		draw_circle(Vector2(cx, cy), dot_size, path_color)
