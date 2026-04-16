class_name DungeonMap extends Node2D

const TILE_SIZE: int = 32

var generator: DungeonGenerator = null

func render(gen: DungeonGenerator) -> void:
	generator = gen
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
