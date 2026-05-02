class_name DungeonMap extends Node2D

var GameManager = null

enum Tile {
	WALL = 0,
	FLOOR = 1,
	STAIRS_UP = 2,
	STAIRS_DOWN = 3,
	DOOR_CLOSED = 4,
	DOOR_OPEN = 5,
	BRANCH_DOWN = 6,
}

const GRID_W: int = 42
const GRID_H: int = 47
const CELL_SIZE: int = 32

const TEX_STAIRS_UP: Texture2D = preload(
	"res://assets/tiles/individual/dngn/gateways/metal_stairs_up.png")
const TEX_STAIRS_DOWN: Texture2D = preload(
	"res://assets/tiles/individual/dngn/gateways/metal_stairs_down.png")
var _tex_door_closed: Texture2D = null
var _tex_door_open: Texture2D = null

## Depth-banded terrain art. Each band declares its wall + floor tile
## paths; picked by pick_atmosphere_for_depth() on generate().
const TERRAIN_BANDS: Array = [
	{
		"until_depth": 3,
		"wall": "res://assets/tiles/individual/dngn/wall/catacombs0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/dirt0.png",
	},
	{
		"until_depth": 7,
		"wall": "res://assets/tiles/individual/dngn/wall/catacombs0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/limestone0.png",
	},
	{
		"until_depth": 12,
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown-vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/cobble_blood3.png",
	},
	{
		"until_depth": 99,
		"wall": "res://assets/tiles/individual/dngn/wall/brick_brown-vines0.png",
		"floor": "res://assets/tiles/individual/dngn/floor/crystal0.png",
	},
]

var _tex_wall: Texture2D = null
var _tex_floor: Texture2D = null
var _tex_branch_entrance: Texture2D = null
var _tex_stairs_down_override: Texture2D = null

var tiles: PackedByteArray = PackedByteArray()
var visible_tiles: Dictionary = {}
var explored: Dictionary = {}
var reveal_all: bool = false
var fog_tiles: Dictionary = {}  # Vector2i -> turns_remaining

var spawn_pos: Vector2i = Vector2i(1, 1)
var stairs_down_pos: Vector2i = Vector2i(1, 1)
var extra_stairs_down_positions: Array[Vector2i] = []
var stairs_up_pos: Vector2i = Vector2i(1, 1)
var rooms: Array[Rect2i] = []
## faith altar map: Vector2i → faith_id String (B3 ruined temple)
var altar_map: Dictionary = {}
## decorative broken DCSS altars on B3 (always dim, never interactive)
var broken_altar_positions: Array = []
## true after B3 unique boss dies — faith altars become interactive
var altar_active: bool = false
## preset faith altar positions from temple generator (used by Game._place_b3_altars)
var preset_faith_altar_positions: Array = []

## Warning tiles from telegraphed boss attacks: Vector2i -> Color
var warning_tiles: Dictionary = {}

## Corpses: Array of {pos:Vector2i, tile_path:String, glyph:String, turns_left:int}
var corpses: Array = []

## Cloud tiles: Vector2i → {type: String, turns: int}
## type: "fire" | "poison" | "cold" | "electricity" | "lava"
var cloud_tiles: Dictionary = {}

## Damaging floor tiles that persist forever: Vector2i → type String
## type: "lava" | "shallow_water"
var hazard_tiles: Dictionary = {}

const CLOUD_COLORS: Dictionary = {
	"fire":        Color(1.0,  0.45, 0.1,  0.55),
	"poison":      Color(0.35, 0.85, 0.25, 0.50),
	"cold":        Color(0.55, 0.85, 1.0,  0.50),
	"electricity": Color(1.0,  0.95, 0.3,  0.55),
	"lava":        Color(1.0,  0.3,  0.0,  0.65),
}

const CLOUD_TEXTURES: Dictionary = {
	"fire":        "res://assets/tiles/individual/effect/cloud/cloud_fire.png",
	"cold":        "res://assets/tiles/individual/effect/cloud/cloud_cold.png",
	"poison":      "res://assets/tiles/individual/effect/cloud/cloud_poison.png",
	"electricity": "res://assets/tiles/individual/effect/cloud/cloud_electricity.png",
}

const HAZARD_COLORS: Dictionary = {
	"lava":          Color(1.0,  0.25, 0.0,  0.70),
	"shallow_water": Color(0.3,  0.55, 1.0,  0.45),
}

func add_cloud(pos: Vector2i, type: String, turns: int) -> void:
	if not in_bounds(pos) or tile_at(pos) == Tile.WALL:
		return
	var existing: Dictionary = cloud_tiles.get(pos, {})
	# Refresh if same type, else replace only if new type is "stronger"
	if existing.is_empty() or int(existing.get("turns", 0)) < turns:
		cloud_tiles[pos] = {"type": type, "turns": turns}
	queue_redraw()

func tick_clouds() -> void:
	var expired: Array = []
	for pos: Vector2i in cloud_tiles.keys():
		cloud_tiles[pos]["turns"] -= 1
		if cloud_tiles[pos]["turns"] <= 0:
			expired.append(pos)
	for pos in expired:
		cloud_tiles.erase(pos)
	if not expired.is_empty():
		queue_redraw()

func set_warning(pos: Vector2i, color: Color) -> void:
	warning_tiles[pos] = color
	queue_redraw()

func clear_warnings() -> void:
	if warning_tiles.is_empty():
		return
	warning_tiles.clear()
	queue_redraw()

const ALTAR_TEXTURES: Dictionary = {
	"war":      "res://assets/tiles/individual/dngn/altars/trog.png",
	"arcana":   "res://assets/tiles/individual/dngn/altars/sif_muna1.png",
	"trickery": "res://assets/tiles/individual/dngn/altars/dithmenos1.png",
	"death":    "res://assets/tiles/individual/dngn/altars/yredelemnul.png",
	"essence":  "res://assets/tiles/individual/dngn/altars/gozag0.png",
}

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

func is_branch_entrance(p: Vector2i) -> bool:
	return tile_at(p) == Tile.BRANCH_DOWN

func all_stairs_down_positions() -> Array[Vector2i]:
	var out: Array[Vector2i] = [stairs_down_pos]
	for p in extra_stairs_down_positions:
		if not out.has(p):
			out.append(p)
	return out

func is_any_down_stairs(p: Vector2i) -> bool:
	return tile_at(p) == Tile.STAIRS_DOWN

func is_any_stairs(p: Vector2i) -> bool:
	var t: int = tile_at(p)
	return t == Tile.STAIRS_DOWN or t == Tile.STAIRS_UP

func is_reserved_feature_tile(p: Vector2i) -> bool:
	if p == spawn_pos or p == stairs_up_pos:
		return true
	return is_any_down_stairs(p)

func is_walkable(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t != Tile.WALL and t != Tile.DOOR_CLOSED

func is_opaque(p: Vector2i) -> bool:
	var t := tile_at(p)
	return t == Tile.WALL or t == Tile.DOOR_CLOSED or fog_tiles.has(p)


func add_fog(center: Vector2i, radius: int, turns: int) -> void:
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			var p := center + Vector2i(dx, dy)
			if in_bounds(p) and tile_at(p) == Tile.FLOOR:
				fog_tiles[p] = turns
	queue_redraw()


func tick_fog() -> bool:
	if fog_tiles.is_empty():
		return false
	var to_remove: Array = []
	for p in fog_tiles.keys():
		fog_tiles[p] -= 1
		if fog_tiles[p] <= 0:
			to_remove.append(p)
	for p in to_remove:
		fog_tiles.erase(p)
	queue_redraw()
	return true

func grid_to_world(p: Vector2i) -> Vector2:
	return Vector2(p.x * CELL_SIZE, p.y * CELL_SIZE)

func world_to_grid(w: Vector2) -> Vector2i:
	return Vector2i(int(floor(w.x / CELL_SIZE)), int(floor(w.y / CELL_SIZE)))

func generate(map_seed: int = -1, branch_entrance: bool = false, style: String = "bsp") -> void:
	var result: Dictionary = MapGen.generate_styled(GRID_W, GRID_H, map_seed, style, branch_entrance)
	tiles = result["tiles"]
	spawn_pos = result["spawn"]
	stairs_down_pos = result["stairs_down"]
	extra_stairs_down_positions.assign(result.get("extra_stairs_down", []))
	stairs_up_pos = result["stairs_up"]
	rooms = result["rooms"]
	altar_map.clear()
	broken_altar_positions.clear()
	preset_faith_altar_positions.clear()
	altar_active = false
	if result.has("preset_broken_altars"):
		broken_altar_positions = Array(result["preset_broken_altars"])
	if result.has("preset_faith_altars"):
		preset_faith_altar_positions = Array(result["preset_faith_altars"])
	visible_tiles.clear()
	explored.clear()
	fog_tiles.clear()
	_load_atmosphere(GameManager.depth)
	queue_redraw()

func activate_altars() -> void:
	altar_active = true
	queue_redraw()

func _ready() -> void:
	GameManager = get_node_or_null("/root/GameManager")
	_tex_door_closed = load("res://assets/tiles/individual/dngn/doors/closed_door.png") as Texture2D
	_tex_door_open = load("res://assets/tiles/individual/dngn/doors/open_door.png") as Texture2D
	add_to_group("dungeon_map")

func _load_atmosphere(depth: int) -> void:
	# B3 is a ruined temple — distinct marble/mosaic tileset
	if depth == 3:
		_tex_wall = load("res://assets/tiles/individual/dngn/wall/marble_wall1.png") as Texture2D
		_tex_floor = load("res://assets/tiles/individual/dngn/floor/mosaic0.png") as Texture2D
		return
	# Abyss zone (B14-15) — dark cracked stone
	if ZoneManager.zone_id_for_depth(depth) == "abyss":
		_tex_wall = load("res://assets/tiles/individual/dngn/wall/abyss/abyss0.png") as Texture2D
		_tex_floor = load("res://assets/tiles/individual/dngn/floor/depthstone_floor0.png") as Texture2D
		_tex_stairs_down_override = load("res://assets/tiles/individual/dngn/gateways/exit_abyss.png") as Texture2D
		return
	_tex_stairs_down_override = null
	for band in TERRAIN_BANDS:
		if depth <= int(band.get("until_depth", 0)):
			_tex_wall = load(band["wall"]) as Texture2D
			_tex_floor = load(band["floor"]) as Texture2D
			return
	var last: Dictionary = TERRAIN_BANDS[TERRAIN_BANDS.size() - 1]
	_tex_wall = load(last["wall"]) as Texture2D
	_tex_floor = load(last["floor"]) as Texture2D

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

	# Broken decorative altars — always dim regardless of altar_active
	for bpos in broken_altar_positions:
		var is_vis: bool = reveal_all or visible_tiles.has(bpos)
		var was_explored: bool = reveal_all or explored.has(bpos)
		if not is_vis and not was_explored:
			continue
		var btex: Texture2D = _broken_altar_tex_at(bpos)
		if btex == null:
			continue
		var bmod: Color = Color(0.38, 0.35, 0.32) if (reveal_all or visible_tiles.has(bpos)) else Color(0.22, 0.20, 0.18)
		var brect := Rect2(Vector2(bpos.x * CELL_SIZE, bpos.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		if use_tiles:
			draw_texture_rect(btex, brect, false, bmod)
		else:
			draw_string(ThemeDB.fallback_font,
				Vector2(bpos.x * CELL_SIZE + 6, bpos.y * CELL_SIZE + CELL_SIZE - 6),
				"_", HORIZONTAL_ALIGNMENT_LEFT, -1, CELL_SIZE - 6, bmod)

	# Warning tiles for telegraphed boss attacks
	for wpos in warning_tiles:
		if not (reveal_all or visible_tiles.has(wpos)):
			continue
		var wrect := Rect2(Vector2(wpos.x * CELL_SIZE, wpos.y * CELL_SIZE),
				Vector2(CELL_SIZE, CELL_SIZE))
		draw_rect(wrect, warning_tiles[wpos])

	# Hazard tiles (lava, shallow water) — permanent floor overlays
	for hpos: Vector2i in hazard_tiles.keys():
		if not (reveal_all or visible_tiles.has(hpos) or explored.has(hpos)):
			continue
		var hcol: Color = HAZARD_COLORS.get(hazard_tiles[hpos], Color(1, 0, 0, 0.5))
		draw_rect(Rect2(Vector2(hpos.x * CELL_SIZE, hpos.y * CELL_SIZE),
				Vector2(CELL_SIZE, CELL_SIZE)), hcol)

	# Cloud tiles — transient elemental hazards
	for cpos: Vector2i in cloud_tiles.keys():
		if not (reveal_all or visible_tiles.has(cpos)):
			continue
		var ctype: String = cloud_tiles[cpos].get("type", "fire")
		var crect := Rect2(Vector2(cpos.x * CELL_SIZE, cpos.y * CELL_SIZE),
				Vector2(CELL_SIZE, CELL_SIZE))
		var ctex_path: String = CLOUD_TEXTURES.get(ctype, "")
		if use_tiles and ctex_path != "":
			var ctex: Texture2D = load(ctex_path) as Texture2D
			if ctex != null:
				draw_texture_rect(ctex, crect, false)
				continue
		var ccol: Color = CLOUD_COLORS.get(ctype, Color(1, 1, 1, 0.4))
		draw_rect(Rect2(Vector2(cpos.x * CELL_SIZE + 1, cpos.y * CELL_SIZE + 1),
				Vector2(CELL_SIZE - 2, CELL_SIZE - 2)), ccol)

	# Corpses — drawn below entities, above floor
	for c in corpses:
		var cpos: Vector2i = c.get("pos", Vector2i.ZERO)
		if not (reveal_all or visible_tiles.has(cpos) or explored.has(cpos)):
			continue
		var crect := Rect2(Vector2(cpos.x * CELL_SIZE, cpos.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		var ctile: String = c.get("tile_path", "")
		if use_tiles and ctile != "":
			var ctex: Texture2D = load(ctile) as Texture2D
			if ctex != null:
				draw_texture_rect(ctex, crect, false, Color(0.7, 0.5, 0.5, 0.85))
				continue
		draw_string(ThemeDB.fallback_font,
			Vector2(cpos.x * CELL_SIZE + 6, cpos.y * CELL_SIZE + CELL_SIZE - 6),
			"%", HORIZONTAL_ALIGNMENT_LEFT, -1, CELL_SIZE - 6, Color(0.65, 0.25, 0.25))

	# Faith altars
	for apos in altar_map.keys():
		var in_los: bool = reveal_all or visible_tiles.has(apos)
		var was_explored: bool = reveal_all or explored.has(apos)
		if not in_los and not was_explored:
			continue
		var faith_id: String = String(altar_map[apos])
		var path: String = String(ALTAR_TEXTURES.get(faith_id, ""))
		var mod: Color = Color.WHITE if in_los else Color(0.45, 0.45, 0.55)
		var arect := Rect2(Vector2(apos.x * CELL_SIZE, apos.y * CELL_SIZE), Vector2(CELL_SIZE, CELL_SIZE))
		var atex: Texture2D = null
		if use_tiles and path != "":
			atex = load(path) as Texture2D
		if atex != null:
			draw_texture_rect(atex, arect, false, mod)
		else:
			var glyph_col: Color = FaithSystem.color_of(faith_id)
			if not in_los:
				glyph_col = glyph_col * Color(0.5, 0.5, 0.5)
			draw_rect(arect, glyph_col * Color(1, 1, 1, 0.35))
			draw_string(ThemeDB.fallback_font,
				Vector2(apos.x * CELL_SIZE + 4, apos.y * CELL_SIZE + CELL_SIZE - 4),
				"Ω", HORIZONTAL_ALIGNMENT_CENTER, CELL_SIZE - 8, CELL_SIZE - 6, glyph_col)

	# Fog overlay on visible fog tiles
	for fp in fog_tiles.keys():
		if reveal_all or visible_tiles.has(fp):
			var fr := Rect2(Vector2(fp.x * CELL_SIZE, fp.y * CELL_SIZE),
					Vector2(CELL_SIZE, CELL_SIZE))
			draw_rect(fr, Color(0.55, 0.65, 0.8, 0.55))

func _texture_for(t: int) -> Texture2D:
	match t:
		Tile.WALL:
			return _tex_wall
		Tile.FLOOR:
			return _tex_floor
		Tile.STAIRS_UP:
			return TEX_STAIRS_UP
		Tile.STAIRS_DOWN:
			return _tex_stairs_down_override if _tex_stairs_down_override != null else TEX_STAIRS_DOWN
		Tile.DOOR_CLOSED:
			return _tex_door_closed
		Tile.DOOR_OPEN:
			return _tex_door_open
		Tile.BRANCH_DOWN:
			return _tex_branch_entrance if _tex_branch_entrance != null else TEX_STAIRS_DOWN
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
		Tile.BRANCH_DOWN:
			return "B"
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
		Tile.BRANCH_DOWN:
			return Color(0.4, 1.0, 0.6)
	return Color.WHITE

const _BROKEN_ALTAR_PATHS: Array = [
	"res://assets/tiles/individual/dngn/altars/ashenzari.png",
	"res://assets/tiles/individual/dngn/altars/beogh.png",
	"res://assets/tiles/individual/dngn/altars/cheibriados.png",
	"res://assets/tiles/individual/dngn/altars/elyvilon.png",
	"res://assets/tiles/individual/dngn/altars/fedhas.png",
	"res://assets/tiles/individual/dngn/altars/gozag0.png",
	"res://assets/tiles/individual/dngn/altars/ru.png",
	"res://assets/tiles/individual/dngn/altars/shining_one.png",
	"res://assets/tiles/individual/dngn/altars/uskayaw.png",
	"res://assets/tiles/individual/dngn/altars/vehumet1.png",
	"res://assets/tiles/individual/dngn/altars/xom0.png",
	"res://assets/tiles/individual/dngn/altars/zin1.png",
]
var _broken_altar_tex_cache: Dictionary = {}

func _broken_altar_tex_at(pos: Vector2i) -> Texture2D:
	if _broken_altar_tex_cache.has(pos):
		return _broken_altar_tex_cache[pos]
	var idx: int = (pos.x * 31 + pos.y * 17) % _BROKEN_ALTAR_PATHS.size()
	var path: String = _BROKEN_ALTAR_PATHS[idx]
	var tex: Texture2D = load(path) as Texture2D
	_broken_altar_tex_cache[pos] = tex
	return tex
