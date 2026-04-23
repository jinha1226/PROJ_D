extends Node2D
class_name PathOverlay

## Draws a translucent trail on the current _auto_path tiles.

var path: Array = []
const CELL := DungeonMap.CELL_SIZE
const DOT_COLOR := Color(1.0, 0.88, 0.25, 0.30)
const DOT_INSET := 6.0

func set_path(new_path: Array) -> void:
	path = new_path
	queue_redraw()

func _draw() -> void:
	if path.is_empty():
		return
	for tile in path:
		var wx: float = tile.x * CELL + DOT_INSET
		var wy: float = tile.y * CELL + DOT_INSET
		var sz: float = CELL - DOT_INSET * 2
		draw_rect(Rect2(wx, wy, sz, sz), DOT_COLOR, true)
