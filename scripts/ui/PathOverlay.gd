extends Node2D
class_name PathOverlay

## Draws DCSS-style directional footprint tiles along the auto-travel path.

var path: Array = []
const CELL := DungeonMap.CELL_SIZE

# DCSS direction index: 1=N 2=NE 3=E 4=SE 5=S 6=SW 7=W 8=NW
const DIR_TO_IDX: Dictionary = {
	Vector2i( 0, -1): 1,
	Vector2i( 1, -1): 2,
	Vector2i( 1,  0): 3,
	Vector2i( 1,  1): 4,
	Vector2i( 0,  1): 5,
	Vector2i(-1,  1): 6,
	Vector2i(-1,  0): 7,
	Vector2i(-1, -1): 8,
}

const BASE := "res://assets/tiles/individual/dngn/path/"
const CURSOR_TEX := BASE + "cursor.png"

var _from_texs: Array = []
var _cursor_tex: Texture2D = null

func _ready() -> void:
	for i in range(1, 9):
		_from_texs.append(load(BASE + "travel_path_from%d.png" % i) as Texture2D)
	_cursor_tex = load(CURSOR_TEX) as Texture2D

func set_path(new_path: Array) -> void:
	path = new_path
	queue_redraw()

func _draw() -> void:
	if path.is_empty():
		return
	var rect_size := Vector2(CELL, CELL)
	for i in range(path.size()):
		var tile: Vector2i = path[i]
		var pos := Vector2(tile.x * CELL, tile.y * CELL)
		var tex: Texture2D = null
		if i < path.size() - 1:
			var dir: Vector2i = path[i + 1] - tile
			var idx: int = DIR_TO_IDX.get(dir, 0)
			if idx > 0:
				tex = _from_texs[idx - 1]
		else:
			# destination: draw cursor
			tex = _cursor_tex
		if tex != null:
			draw_texture_rect(tex, Rect2(pos, rect_size), false, Color(1.0, 1.0, 1.0, 0.75))
		else:
			# fallback dot
			draw_circle(pos + rect_size * 0.5, 4.0, Color(0.85, 0.85, 0.85, 0.5))
