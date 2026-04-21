class_name DungeonMap extends Node2D

const TILE_SIZE: int = 32
## DCSS LOS_DEFAULT_RANGE (defines.h). The mobile port used to run at 6 to
## keep the visible disk small on phone screens; we now match the desktop
## default so line-of-sight semantics line up with every other DCSS system.
const EXPLORE_RADIUS: int = FieldOfView.LOS_DEFAULT_RANGE

var generator: DungeonGenerator = null
var _path_tiles: Array[Vector2i] = []
# Flat-indexed byte array: 1 = explored, 0 = unseen. Resized on render().
var explored: PackedByteArray = PackedByteArray()
# Current-frame visible set (tiles the player can see from their position
# with line-of-sight through walls blocked). Recomputed on update_fov().
var _visible_tiles: Dictionary = {}
var danger_tiles: Array[Vector2i] = []
# AoE preview overlay — tiles an area spell would damage if cast.
# Painted in transparent orange so the player can see the explosion
# radius before committing a tap. Populated by GameBootstrap's
# targeting-hint flow when an area spell enters targeting mode.
var aoe_preview_tiles: Array[Vector2i] = []
# Beam preview — cell list of the ray from player toward each visible
# hostile for a targeted zap. Painted as a cyan trail so wall-hit
# cases are obvious before casting.
var beam_preview_tiles: Array[Vector2i] = []


func render(gen: DungeonGenerator) -> void:
	generator = gen
	_path_tiles.clear()
	explored.resize(DungeonGenerator.MAP_WIDTH * DungeonGenerator.MAP_HEIGHT)
	explored.fill(0)
	_visible_tiles.clear()
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	# Group membership lets sibling systems (MonsterAI wake check) fetch the
	# FOV data without threading a reference through every call site.
	if not is_in_group("dmap"):
		add_to_group("dmap")
	queue_redraw()


## Compute line-of-sight visibility from `center` with Chebyshev `radius`.
## Delegates to FieldOfView (DCSS 0.34 los.cc port). Walls and closed
## doors block sight per DCSS `opacity_default`.
func update_fov(center: Vector2i, radius: int = EXPLORE_RADIUS) -> void:
	if generator == null:
		return
	# Explicit Callable construction — Godot 4's implicit self-binding on a
	# bare method name isn't reliable when passed into a static function
	# parameter typed as Callable. Using `Callable(self, ...)` forces the
	# bind, which keeps `_opaque_at` reachable from `FieldOfView.compute`.
	var opaque_cb: Callable = Callable(self, "_opaque_at")
	var computed: Dictionary = FieldOfView.compute(center, radius, opaque_cb)
	# Defensive fallback: if the new engine somehow returns empty, fall back
	# to the raw Chebyshev disc so at minimum the player isn't standing in
	# a black void. Should never trigger, but guards against surprise
	# regressions that would make monsters/items vanish from the map.
	if computed.is_empty():
		computed = _fallback_cheb_disc(center, radius)
	_visible_tiles = computed
	for tile in _visible_tiles.keys():
		_mark_tile_explored(tile)
	queue_redraw()


func _fallback_cheb_disc(center: Vector2i, radius: int) -> Dictionary:
	var out: Dictionary = {}
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if maxi(absi(dx), absi(dy)) > radius:
				continue
			out[Vector2i(center.x + dx, center.y + dy)] = true
	return out


## Opacity callback passed to FieldOfView. Mirrors DCSS losparam.cc
## `opacity_default`: walls → OPAQUE, closed doors → OPAQUE, everything
## else → CLEAR. (Clouds/smoke are not implemented yet — the HALF
## return value path is reserved.)
func _opaque_at(cell: Vector2i) -> int:
	if cell.x < 0 or cell.x >= DungeonGenerator.MAP_WIDTH:
		return FieldOfView.OPC_OPAQUE
	if cell.y < 0 or cell.y >= DungeonGenerator.MAP_HEIGHT:
		return FieldOfView.OPC_OPAQUE
	var t: int = generator.map[cell.x][cell.y]
	if t == DungeonGenerator.TileType.WALL \
			or t == DungeonGenerator.TileType.DOOR_CLOSED:
		return FieldOfView.OPC_OPAQUE
	return FieldOfView.OPC_CLEAR


## Renamed from is_visible() to avoid shadowing CanvasItem's zero-arg
## is_visible() getter — that conflict made every call resolve to the
## node's own .visible property (always true), leaking actors into
## unexplored tiles.
func is_tile_visible(tile: Vector2i) -> bool:
	return _visible_tiles.has(tile)


## Kept for backward compatibility — just forwards to update_fov.
func mark_explored(center: Vector2i, radius: int = EXPLORE_RADIUS) -> void:
	update_fov(center, radius)


## Mark every tile explored — used by the Magic Mapping scroll.
func reveal_all() -> void:
	if generator == null:
		return
	explored.fill(1)
	queue_redraw()


func is_explored(tile: Vector2i) -> bool:
	var mw: int = DungeonGenerator.MAP_WIDTH
	if tile.x < 0 or tile.x >= mw or tile.y < 0 or tile.y >= DungeonGenerator.MAP_HEIGHT:
		return false
	return explored[tile.y * mw + tile.x] == 1


func _mark_tile_explored(tile: Vector2i) -> void:
	var mw: int = DungeonGenerator.MAP_WIDTH
	if tile.x < 0 or tile.x >= mw or tile.y < 0 or tile.y >= DungeonGenerator.MAP_HEIGHT:
		return
	explored[tile.y * mw + tile.x] = 1


## Bresenham line-of-sight: true if no WALL lies between from and to (endpoints
## excluded so a wall on `to` is still visible — you can see the wall's face).
## Forward to FieldOfView so every LOS query in the project agrees
## with update_fov (DCSS los.cc port). Kept for legacy callers.
func _has_los(from: Vector2i, to: Vector2i) -> bool:
	return FieldOfView.cell_see_cell(from, to, Callable(self, "_opaque_at"))

## Show the planned auto-move path as blue-green dots.
func show_path(path: Array[Vector2i]) -> void:
	_path_tiles.assign(path)
	queue_redraw()

func clear_path() -> void:
	if _path_tiles.is_empty():
		return
	_path_tiles.clear()
	queue_redraw()

func _draw() -> void:
	if generator == null or generator.map.is_empty():
		return
	if TileRenderer.is_ascii():
		_draw_ascii()
	elif TileRenderer.is_dcss():
		_draw_dcss()
	else:
		_draw_lpc()
	# Beam preview — cyan trail along the ray toward each visible enemy.
	# Drawn first so AoE / danger overlays layer on top.
	var beam_color: Color = Color(0.25, 0.75, 0.95, 0.30)
	for tile in beam_preview_tiles:
		if not is_explored(tile):
			continue
		var rect_b := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect_b, beam_color, true)
	# AoE preview — translucent orange for blast radius. Drawn under
	# the enemy (danger) markers so both are visible when they overlap.
	var aoe_color: Color = Color(1.0, 0.60, 0.20, 0.26)
	for tile in aoe_preview_tiles:
		if not is_explored(tile):
			continue
		var rect_a := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect_a, aoe_color, true)
	# Danger tile overlay — red pulsing squares for boss telegraphed attacks
	# + enemy markers during targeting.
	var danger_color: Color = Color(1.0, 0.15, 0.1, 0.45)
	for tile in danger_tiles:
		if not is_explored(tile):
			continue
		var rect := Rect2(tile.x * TILE_SIZE, tile.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
		draw_rect(rect, danger_color, true)
	# Path overlay dots — drawn on top in both modes.
	var path_color: Color = Color(0.2, 0.85, 0.85, 0.55)
	var dot_size: float = TILE_SIZE * 0.35
	for tile in _path_tiles:
		if not is_explored(tile):
			continue
		var cx: float = tile.x * TILE_SIZE + TILE_SIZE * 0.5
		var cy: float = tile.y * TILE_SIZE + TILE_SIZE * 0.5
		draw_circle(Vector2(cx, cy), dot_size, path_color)


func _draw_dcss() -> void:
	var floor_tex: Texture2D = TileRenderer.feature("floor")
	var wall_tex: Texture2D = TileRenderer.feature("wall")
	var stairs_dn_tex: Texture2D = TileRenderer.feature("stairs_down")
	var stairs_up_tex: Texture2D = TileRenderer.feature("stairs_up")
	var water_tex: Texture2D = TileRenderer.feature("water")
	var lava_tex: Texture2D = TileRenderer.feature("lava")
	var tree_tex: Texture2D = TileRenderer.feature("tree")
	var door_open_tex: Texture2D = TileRenderer.feature("door_open")
	var door_closed_tex: Texture2D = TileRenderer.feature("door_closed")
	var unseen_color := Color(0.02, 0.02, 0.04)
	var dim := Color(0.45, 0.45, 0.45)  # mod for explored-but-not-visible
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			var t: int = generator.map[x][y]
			var modulate: Color = Color.WHITE if is_tile_visible(tile) else dim
			var tex: Texture2D = floor_tex
			match t:
				DungeonGenerator.TileType.WALL:
					# Rock filling between rooms stays black — only walls
					# that border a walkable tile (i.e. an actual room /
					# corridor edge) get a wall sprite drawn. DCSS-style
					# clean look instead of a carpet of rock_wall texture.
					if not _wall_borders_floor(tile):
						draw_rect(rect, unseen_color, true)
						continue
					tex = wall_tex
				DungeonGenerator.TileType.TREE:
					# Trees sit on a floor backdrop so edges read.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = tree_tex
				DungeonGenerator.TileType.STAIRS_DOWN:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = stairs_dn_tex
				DungeonGenerator.TileType.STAIRS_UP:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = stairs_up_tex
				DungeonGenerator.TileType.BRANCH_ENTRANCE:
					# Draw a stairs-down under a colour-tinted overlay so the
					# player can tell branch portals apart from normal stairs.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = stairs_dn_tex
					# Tint the modulate downstream — we hack a draw_rect
					# overlay after the tile draw for now.
				DungeonGenerator.TileType.ALTAR:
					# Floor backdrop + DCSS per-god altar texture pulled from
					# rltiles/dngn/altars (ported verbatim). `altar_tex`
					# falls back to ecumenical.png when the god isn't in
					# the ALTAR_TILES mapping yet.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					var god_id: String = String(generator.altars.get(tile, "")) \
							if "altars" in generator else ""
					var altar_tex: Texture2D = TileRenderer.altar_tex(god_id)
					if altar_tex != null:
						draw_texture_rect(altar_tex, rect, false, modulate)
					else:
						# Tile missing → paint the god's signature colour
						# as a diamond so the tile at least identifies.
						var god_col: Color = Color(0.85, 0.85, 0.9)
						if god_id != "":
							var info: Dictionary = GodRegistry.get_info(god_id)
							god_col = info.get("color", god_col)
						var mid: Vector2 = rect.position + rect.size * 0.5
						var half: float = rect.size.x * 0.35
						var poly := PackedVector2Array([
							mid + Vector2(0, -half), mid + Vector2(half, 0),
							mid + Vector2(0, half),  mid + Vector2(-half, 0),
						])
						draw_colored_polygon(poly, god_col * modulate)
						draw_polyline(poly + PackedVector2Array([poly[0]]),
								Color(0, 0, 0, 0.8) * modulate, 1.2)
					continue
				DungeonGenerator.TileType.TRAP:
					# Trap = floor backdrop + a small X glyph in muted grey.
					# Hidden traps are a DCSS stretch goal; ours stay visible.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					var tm: Vector2 = rect.position + rect.size * 0.5
					var tc := Color(0.80, 0.35, 0.35) * modulate
					draw_line(tm + Vector2(-5, -5), tm + Vector2(5, 5), tc, 1.6)
					draw_line(tm + Vector2(-5, 5), tm + Vector2(5, -5), tc, 1.6)
					continue
				DungeonGenerator.TileType.SHOP:
					# Shop tile: floor + a "$" sigil in amber. Simple and
					# readable without leaning on DCSS's shop tilesets.
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					var sh_mid: Vector2 = rect.position + rect.size * 0.5
					var sh_col := Color(1.0, 0.80, 0.25) * modulate
					draw_rect(Rect2(sh_mid - Vector2(8, 8), Vector2(16, 16)),
							sh_col * Color(1, 1, 1, 0.25), true)
					draw_circle(sh_mid, 7.0, sh_col)
					draw_circle(sh_mid, 7.0, Color(0, 0, 0, 0.6) * modulate, false, 1.2)
					# "$" tick marks inside — two short lines forming an S-like glyph
					draw_line(sh_mid + Vector2(-3, -4), sh_mid + Vector2(3, -4),
							Color(0, 0, 0, 0.9) * modulate, 1.2)
					draw_line(sh_mid + Vector2(-3, 4), sh_mid + Vector2(3, 4),
							Color(0, 0, 0, 0.9) * modulate, 1.2)
					continue
				DungeonGenerator.TileType.WATER:
					tex = water_tex
				DungeonGenerator.TileType.LAVA:
					tex = lava_tex
				DungeonGenerator.TileType.ACID:
					# Slime Pits acidic floor — no dedicated tile sprite yet,
					# paint a vivid yellow-green square so it's visually
					# distinct from LAVA (orange) and WATER (blue).
					draw_rect(rect, Color(0.55, 0.95, 0.25) * modulate, true)
					continue
				DungeonGenerator.TileType.DOOR_OPEN:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = door_open_tex
				DungeonGenerator.TileType.DOOR_CLOSED:
					if floor_tex != null:
						draw_texture_rect(floor_tex, rect, false, modulate)
					tex = door_closed_tex
			if tex != null:
				draw_texture_rect(tex, rect, false, modulate)
			else:
				# Last-resort solid fill if the tile asset is missing.
				draw_rect(rect, Color(0.4, 0.4, 0.4) * modulate, true)


## Classic roguelike console view — every tile gets a character glyph.
## True iff any 8-neighbour of `tile` is a walkable feature — corridor
## or room interior. Used so rock walls deep in the dungeon bulk can
## render as empty black space instead of a wall sprite.
func _wall_borders_floor(tile: Vector2i) -> bool:
	if generator == null:
		return false
	for dy in [-1, 0, 1]:
		for dx in [-1, 0, 1]:
			if dx == 0 and dy == 0:
				continue
			var n: Vector2i = Vector2i(tile.x + dx, tile.y + dy)
			if n.x < 0 or n.y < 0 \
					or n.x >= DungeonGenerator.MAP_WIDTH \
					or n.y >= DungeonGenerator.MAP_HEIGHT:
				continue
			var nt: int = generator.map[n.x][n.y]
			if nt == DungeonGenerator.TileType.FLOOR \
					or nt == DungeonGenerator.TileType.DOOR_OPEN \
					or nt == DungeonGenerator.TileType.DOOR_CLOSED \
					or nt == DungeonGenerator.TileType.STAIRS_UP \
					or nt == DungeonGenerator.TileType.STAIRS_DOWN \
					or nt == DungeonGenerator.TileType.WATER \
					or nt == DungeonGenerator.TileType.LAVA \
					or nt == DungeonGenerator.TileType.ACID:
				return true
	return false


func _draw_ascii() -> void:
	var unseen_color := Color(0.02, 0.02, 0.04)
	var bg_color := Color(0.04, 0.04, 0.06)
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile := Vector2i(x, y)
			var rect := Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			# Solid background so glyphs pop.
			draw_rect(rect, bg_color, true)
			var t: int = generator.map[x][y]
			var entry: Array = TileRenderer.ascii_feature(t)
			var glyph: String = String(entry[0])
			var color: Color = entry[1]
			TileRenderer.draw_ascii_glyph(self,
					Vector2(x * TILE_SIZE + TILE_SIZE * 0.5,
							y * TILE_SIZE + TILE_SIZE * 0.5),
					TILE_SIZE, glyph, color, is_tile_visible(tile))


func _draw_lpc() -> void:
	var wall_color: Color = Color(0.18, 0.18, 0.2)
	var floor_color: Color = Color(0.55, 0.55, 0.58)
	var stairs_color: Color = Color(0.95, 0.82, 0.15)
	var stairs_up_color: Color = Color(0.55, 0.78, 0.95)
	var unseen_color: Color = Color(0.02, 0.02, 0.04)
	for x in DungeonGenerator.MAP_WIDTH:
		for y in DungeonGenerator.MAP_HEIGHT:
			var tile: Vector2i = Vector2i(x, y)
			var rect: Rect2 = Rect2(x * TILE_SIZE, y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
			if not is_explored(tile):
				draw_rect(rect, unseen_color, true)
				continue
			var t: int = generator.map[x][y]
			var base: Color = floor_color
			match t:
				DungeonGenerator.TileType.STAIRS_DOWN: base = stairs_color
				DungeonGenerator.TileType.STAIRS_UP: base = stairs_up_color
				_: base = floor_color
			var dim_base: bool = not is_tile_visible(tile)
			if dim_base:
				base = base.darkened(0.55)
			if t == DungeonGenerator.TileType.WALL:
				var wc: Color = wall_color if not dim_base else wall_color.darkened(0.55)
				draw_rect(rect, wc, true)
			else:
				draw_rect(rect, base, true)
