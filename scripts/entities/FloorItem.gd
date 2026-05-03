class_name FloorItem extends Node2D

var GameManager = null

var data: ItemData
var entry: Dictionary = {}
var grid_pos: Vector2i = Vector2i.ZERO
var plus: int = 0

var _map: DungeonMap
var _base_tex: Texture2D = null
var _overlay_tex: Texture2D = null
var _font: Font

func _ready() -> void:
	GameManager = get_node_or_null("/root/GameManager")
	_font = ThemeDB.fallback_font
	add_to_group("floor_items")

func setup(item_data: ItemData, map: DungeonMap, pos: Vector2i, plus_val: int = 0, entry_dict: Dictionary = {}) -> void:
	data = item_data
	entry = entry_dict.duplicate(true) if not entry_dict.is_empty() else {"id": item_data.id, "plus": plus_val}
	_map = map
	grid_pos = pos
	plus = plus_val
	position = map.grid_to_world(pos)
	if data.kind == "essence":
		var essence_id: String = String(entry.get("essence_id", ""))
		if essence_id != "":
			_base_tex = EssenceSystem.icon_texture_of(essence_id)
	elif data.tile_path != "":
		_base_tex = load(data.tile_path) as Texture2D
	if data.identified_tile_path != "":
		_overlay_tex = load(data.identified_tile_path) as Texture2D
	queue_redraw()

func _draw() -> void:
	if data == null:
		return
	var rect := Rect2(Vector2.ZERO, Vector2(DungeonMap.CELL_SIZE, DungeonMap.CELL_SIZE))
	if GameManager.use_tiles and _base_tex != null:
		draw_texture_rect(_base_tex, rect, false)
		# Overlay stamped on identified consumables only.
		if _overlay_tex != null and GameManager.is_identified(data.id):
			draw_texture_rect(_overlay_tex, rect, false)
	else:
		draw_string(_font, Vector2(6, DungeonMap.CELL_SIZE - 6),
			data.glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, DungeonMap.CELL_SIZE - 6,
			data.glyph_color)
