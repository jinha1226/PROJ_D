class_name FloorItem extends Node2D
## Simple pickup-able dummy item for M1 inventory testing.

const TILE_SIZE: int = 32

var grid_pos: Vector2i = Vector2i.ZERO
var item_id: String = ""
var display_name: String = ""
var kind: String = "junk"  # "potion" | "scroll" | "junk"
var color: Color = Color(0.9, 0.9, 0.4)


func _ready() -> void:
	z_index = 5
	add_to_group("floor_items")


func setup(p_grid_pos: Vector2i, p_id: String, p_name: String, p_kind: String, p_color: Color) -> void:
	grid_pos = p_grid_pos
	item_id = p_id
	display_name = p_name
	kind = p_kind
	color = p_color
	position = Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0, grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	queue_redraw()


func _draw() -> void:
	# Diamond shape to distinguish from tiles and monsters.
	var r: float = 10.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, -r), Vector2(r, 0), Vector2(0, r), Vector2(-r, 0)
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), Color(0, 0, 0, 0.7), 1.5)


func as_dict() -> Dictionary:
	return {"id": item_id, "name": display_name, "kind": kind, "color": color}
