class_name FloorItem extends Node2D

var data: ItemData
var grid_pos: Vector2i = Vector2i.ZERO
var plus: int = 0

var _map: DungeonMap
var _tex: Texture2D = null
var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	add_to_group("floor_items")

func setup(item_data: ItemData, map: DungeonMap, pos: Vector2i, plus_val: int = 0) -> void:
	data = item_data
	_map = map
	grid_pos = pos
	plus = plus_val
	position = map.grid_to_world(pos)
	if data.tile_path != "":
		_tex = load(data.tile_path) as Texture2D
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager.use_tiles and _tex != null:
		draw_texture_rect(_tex, rect, false)
	else:
		draw_string(_font, Vector2(6, DungeonMap.CELL_SIZE - 6),
			data.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			data.glyph_color)
