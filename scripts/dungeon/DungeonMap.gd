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
const CELL_SIZE: int = 32

const TEX_WALL: Texture2D = preload(
	"res://assets/tiles/individual/dngn/wall/catacombs0.png")
const TEX_FLOOR: Texture2D = preload(
	"res://assets/tiles/individual/dngn/floor/limestone0.png")
const TEX_STAIRS_UP: Texture2D = preload(
	"res://assets/tiles/individual/dngn/gateways/metal_stairs_up.png")
const TEX_STAIRS_DOWN: Texture2D = preload(
	"res://assets/tiles/individual/dngn/gateways/metal_stairs_down.png")

var tiles: PackedByteArray = PackedByteArray()
var visible_tiles: Dictionary = {}
var explored: Dictionary = {}
var reveal_all: bool = false

var spawn_pos: Vector2i = Vector2i(1, 1)
var stairs_down_pos: Vector2i = Vector2i(1, 1)
var stairs_up_pos: Vector2i = Vector2i(1, 1)
var rooms: Array[Rect2i] = []

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

func generate(map_seed: int = -1) -> void:
	var result: Dictionary = MapGen.generate(GRID_W, GRID_H, map_seed)
	tiles = result["tiles"]
	spawn_pos = result["spawn"]
	stairs_down_pos = result["stairs_down"]
	stairs_up_pos = result["stairs_up"]
	rooms = result["rooms"]
	visible_tiles.clear()
	explored.clear()
	queue_redraw()

func find_spawn() -> Vector2i:
	return spawn_pos

func random_floor_tile(rng: RandomNumberGenerator = null) -> Vector2i:
	if rooms.is_empty():
		return spawn_pos
	var room_idx: int
	if rng != null:
		room_idx = rng.randi_range(0, rooms.size() - 1)
	else:
		room_idx = randi_range(0, rooms.size() - 1)
	var room: Rect2i = rooms[room_idx]
	var x: int
	var y: int
	if rng != null:
		x = rng.randi_range(room.position.x, room.position.x + room.size.x - 1)
		y = rng.randi_range(room.position.y, room.position.y + room.size.y - 1)
	else:
		x = randi_range(room.position.x, room.position.x + room.size.x - 1)
		y = randi_range(room.position.y, room.position.y + room.size.y - 1)
	return Vector2i(x, y)

func set_fov(new_visible: Dictionary) -> void:
	visible_tiles = new_visible
	for pos in new_visible.keys():
		explored[pos] = true
	queue_redraw()

func _draw() -> void:
	var dim: Color = Color(0.45, 0.45, 0.55, 1.0)
	var bright: Color = Color.WHITE
	var use_tiles: bool = GameManager.use_tiles
	var bg: Color = Color(0.06, 0.06, 0.08, 1.0)
	for y in range(GRID_H):
		for x in range(GRID_W):
			var pos := Vector2i(x, y)
			var is_vis: bool = reveal_all or visible_tiles.has(pos)
			var was_explored: bool = reveal_all or explored.has(pos)
			if not is_vis and not was_explored:
				continue
			var t: int = tiles[y * GRID_W + x]
			var mod: Color = bright if is_vis else dim
			var rect := Rect2(Vector2(x * CELL_SIZE, y * CELL_SIZE),
					Vector2(CELL_SIZE, CELL_SIZE))
			if use_tiles:
				var tex: Texture2D = _texture_for(t)
				if tex != null:
					draw_texture_rect(tex, rect, false, mod)
					continue
				# Fall through to glyph render for tiles without a texture.
			draw_rect(rect, bg)
			var glyph: String = _glyph_for(t)
			var glyph_color: Color = _glyph_color_for(t) * mod
			glyph_color.a = 1.0
			draw_string(ThemeDB.fallback_font,
				Vector2(x * CELL_SIZE + 6, y * CELL_SIZE + CELL_SIZE - 6),
				glyph, HORIZONTAL_ALIGNMENT_LEFT, -1, CELL_SIZE - 6, glyph_color)

func _texture_for(t: int) -> Texture2D:
	match t:
		Tile.WALL:
			return TEX_WALL
		Tile.FLOOR:
			return TEX_FLOOR
		Tile.STAIRS_UP:
			return TEX_STAIRS_UP
		Tile.STAIRS_DOWN:
			return TEX_STAIRS_DOWN
	return null

func _glyph_for(t: int) -> String:
	match t:
		Tile.WALL:
			return "#"
		Tile.FLOOR:
			return "."
		Tile.STAIRS_UP:
			return "<"
		Tile.STAIRS_DOWN:
			return ">"
		Tile.DOOR_CLOSED:
			return "+"
		Tile.DOOR_OPEN:
			return "'"
	return "?"

func _glyph_color_for(t: int) -> Color:
	match t:
		Tile.WALL:
			return Color(0.65, 0.55, 0.38)
		Tile.FLOOR:
			return Color(0.45, 0.42, 0.35)
		Tile.STAIRS_UP:
			return Color(1.0, 1.0, 0.6)
		Tile.STAIRS_DOWN:
			return Color(0.6, 1.0, 1.0)
		Tile.DOOR_CLOSED:
			return Color(0.75, 0.55, 0.3)
		Tile.DOOR_OPEN:
			return Color(0.55, 0.4, 0.25)
	return Color.WHITE
