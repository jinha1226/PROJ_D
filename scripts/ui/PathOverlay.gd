extends Node2D
class_name PathOverlay

## Draws a translucent trail on the current _auto_path tiles.

var path: Array = []
const CELL := DungeonMap.CELL_SIZE
const DOT_COLOR := Color(0.85, 0.85, 0.85, 0.10)
const LINE_COLOR := Color(0.9, 0.9, 0.9, 0.30)
const HEAD_COLOR := Color(0.8, 0.9, 1.0, 0.55)
const GOAL_COLOR := Color(0.8, 0.9, 1.0, 0.55)
const DOT_INSET := 8.0
const LINE_WIDTH := 2.0

func _tile_center(tile: Vector2i) -> Vector2:
	return Vector2(
		tile.x * CELL + CELL * 0.5,
		tile.y * CELL + CELL * 0.5
	)

func set_path(new_path: Array) -> void:
	path = new_path
	queue_redraw()

func _draw() -> void:
	if path.is_empty():
		return
	var centers: PackedVector2Array = PackedVector2Array()
	for tile in path:
		var wx: float = tile.x * CELL + DOT_INSET
		var wy: float = tile.y * CELL + DOT_INSET
		var sz: float = CELL - DOT_INSET * 2
		draw_rect(Rect2(wx, wy, sz, sz), DOT_COLOR, true)
		centers.append(_tile_center(tile))
	if centers.size() >= 2:
		draw_polyline(centers, LINE_COLOR, LINE_WIDTH, true)
	if centers.size() >= 1:
		draw_circle(centers[0], 5.0, HEAD_COLOR)
		draw_circle(centers[centers.size() - 1], 6.0, GOAL_COLOR)
