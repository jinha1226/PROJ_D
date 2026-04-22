class_name DungeonMap extends Node2D

enum Tile {
	WALL = 0,
	FLOOR = 1,
	STAIRS_UP = 2,
	STAIRS_DOWN = 3,
	DOOR_CLOSED = 4,
	DOOR_OPEN = 5,
}

const GRID_W: int = 35
const GRID_H: int = 50
const CELL_SIZE: int = 24

var tiles: PackedByteArray = PackedByteArray()
var visible_tiles: Dictionary = {}
var explored: Dictionary = {}
var reveal_all: bool = true  # Day 1: no FOV. Day 2 FieldOfView sets this false.

var _font: Font

func _ready() -> void:
	_font = ThemeDB.fallback_font
	if tiles.is_empty():
		generate_placeholder_room()
	queue_redraw()

func in_bounds(p: Vector2i) -> bool:
	return p.x >= 0 and p.y >= 0 and p.x < GRID_W and p.y < GRID_H

func tile_at(p: Vector2i) -> int:
	if not in_bounds(p):
		return Tile.WALL
	return tiles[p.y * GRID_W + p.x]

func set_tile(p: Vector2i, t: int) -> void:
	if not in_bounds(p):
		return
	tiles[p.y * GRID_W + p.x] = t
	queue_redraw()

func is_walkable(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t != Tile.WALL and t != Tile.DOOR_CLOSED

func is_opaque(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t == Tile.WALL or t == Tile.DOOR_CLOSED

func grid_to_world(p: Vector2i) -> Vector2:
	return Vector2(p.x * CELL_SIZE, p.y * CELL_SIZE)

func world_to_grid(w: Vector2) -> Vector2i:
	return Vector2i(int(floor(w.x / CELL_SIZE)), int(floor(w.y / CELL_SIZE)))

func generate_placeholder_room() -> void:
	tiles.resize(GRID_W * GRID_H)
	for y in range(GRID_H):
		for x in range(GRID_W):
			var edge := x == 0 or y == 0 or x == GRID_W - 1 or y == GRID_H - 1
			tiles[y * GRID_W + x] = Tile.WALL if edge else Tile.FLOOR
	# Scatter a few pillars so movement feels non-empty.
	for p in [Vector2i(8, 6), Vector2i(20, 10), Vector2i(12, 18),
			Vector2i(25, 22), Vector2i(6, 30), Vector2i(18, 35),
			Vector2i(28, 42)]:
		tiles[p.y * GRID_W + p.x] = Tile.WALL
	# Stairs down bottom-right-ish for later.
	tiles[45 * GRID_W + 30] = Tile.STAIRS_DOWN

func find_spawn() -> Vector2i:
	# Pick first walkable tile — fine for placeholder room.
	for y in range(GRID_H):
		for x in range(GRID_W):
			if is_walkable(Vector2i(x, y)):
				return Vector2i(x, y)
	return Vector2i(1, 1)

func set_fov(new_visible: Dictionary) -> void:
	visible_tiles = new_visible
	for pos in new_visible.keys():
		explored[pos] = true
	queue_redraw()

func _draw() -> void:
	for y in range(GRID_H):
		for x in range(GRID_W):
			var pos := Vector2i(x, y)
			var is_vis: bool = reveal_all or visible_tiles.has(pos)
			var was_explored: bool = reveal_all or explored.has(pos)
			if not is_vis and not was_explored:
				continue
			var t: int = tiles[y * GRID_W + x]
			var glyph: String = _glyph_for(t)
			var color: Color = _color_for(t)
			if not is_vis:
				color = Color(color.r * 0.4, color.g * 0.4, color.b * 0.4, 1.0)
			draw_string(_font,
				Vector2(x * CELL_SIZE + 2, y * CELL_SIZE + CELL_SIZE - 4),
				glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, CELL_SIZE - 2, color)

func _glyph_for(t: int) -> String:
	match t:
		Tile.WALL: return "#"
		Tile.FLOOR: return "."
		Tile.STAIRS_UP: return "<"
		Tile.STAIRS_DOWN: return ">"
		Tile.DOOR_CLOSED: return "+"
		Tile.DOOR_OPEN: return "'"
	return "?"

func _color_for(t: int) -> Color:
	match t:
		Tile.WALL: return Color(0.6, 0.5, 0.35)
		Tile.FLOOR: return Color(0.4, 0.38, 0.32)
		Tile.STAIRS_UP: return Color(1.0, 1.0, 0.6)
		Tile.STAIRS_DOWN: return Color(0.6, 1.0, 1.0)
		Tile.DOOR_CLOSED: return Color(0.7, 0.5, 0.3)
		Tile.DOOR_OPEN: return Color(0.55, 0.4, 0.25)
	return Color.WHITE
