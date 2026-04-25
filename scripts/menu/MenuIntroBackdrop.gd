extends Control

const CELL: int = 32
const COLS: int = 18
const ROWS: int = 12

const TEX_WALL: Texture2D = preload("res://assets/tiles/individual/dngn/wall/catacombs0.png")
const TEX_FLOOR: Texture2D = preload("res://assets/tiles/individual/dngn/floor/limestone0.png")
const TEX_STAIRS: Texture2D = preload("res://assets/tiles/individual/dngn/gateways/metal_stairs_down.png")

const TEX_PLAYER_BASE: Texture2D = preload("res://assets/tiles/individual/player/base/human_m.png")
const TEX_PLAYER_BODY: Texture2D = preload("res://assets/tiles/individual/player/body/robe_blue.png")
const TEX_PLAYER_WEAPON: Texture2D = preload("res://assets/tiles/individual/player/hand1/short_sword.png")

const TEX_GOBLIN: Texture2D = preload("res://assets/tiles/individual/mon/humanoids/goblin.png")
const TEX_ORC: Texture2D = preload("res://assets/tiles/individual/mon/humanoids/orcs/orc.png")
const TEX_RAT: Texture2D = preload("res://assets/tiles/individual/mon/animals/rat.png")

var _t: float = 0.0

var _layout: PackedStringArray = [
	"##################",
	"#................#",
	"#..###....###....#",
	"#..#..........#..#",
	"#..#..####....#..#",
	"#......#..#......#",
	"#..#...#..#...#..#",
	"#..#..........#..#",
	"#..####....####..#",
	"#................#",
	"#.......>........#",
	"##################",
]

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var vp: Vector2 = size
	var map_size := Vector2(COLS * CELL, ROWS * CELL)
	var origin := Vector2(
		floor((vp.x - map_size.x) * 0.5),
		floor((vp.y - map_size.y) * 0.5)
	)

	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.025, 0.04, 1.0), true)
	_draw_map(origin)
	_draw_torch_glow(origin)
	_draw_entities(origin)
	_draw_vignette(vp)

func _draw_map(origin: Vector2) -> void:
	for y in range(ROWS):
		var row: String = _layout[y]
		for x in range(COLS):
			var c: String = row.substr(x, 1)
			var rect := Rect2(origin + Vector2(x * CELL, y * CELL), Vector2(CELL, CELL))
			match c:
				"#":
					draw_texture_rect(TEX_WALL, rect, false, Color(0.9, 0.9, 0.95, 1.0))
				">":
					draw_texture_rect(TEX_FLOOR, rect, false)
					var pulse: float = 0.82 + sin(_t * 2.1) * 0.08
					draw_texture_rect(TEX_STAIRS, rect, false, Color(pulse, pulse, pulse + 0.08, 1.0))
				_:
					draw_texture_rect(TEX_FLOOR, rect, false)

func _draw_entities(origin: Vector2) -> void:
	var bob: float = sin(_t * 2.8) * 3.0
	var player_pos := origin + Vector2(8 * CELL, 8.8 * CELL + bob)
	_draw_actor(player_pos, TEX_PLAYER_BASE)
	_draw_actor(player_pos, TEX_PLAYER_BODY)
	_draw_actor(player_pos, TEX_PLAYER_WEAPON)

	var rat_offset := sin(_t * 3.2) * 6.0
	_draw_actor(origin + Vector2(4.2 * CELL + rat_offset, 5.4 * CELL), TEX_RAT, Color(0.95, 0.95, 1.0, 0.92))

	var goblin_alpha: float = 0.6 + sin(_t * 1.7) * 0.12
	_draw_actor(origin + Vector2(12.8 * CELL, 4.8 * CELL), TEX_GOBLIN, Color(0.78, 0.9, 0.82, goblin_alpha))

	var orc_alpha: float = 0.46 + sin(_t * 1.3 + 0.6) * 0.08
	_draw_actor(origin + Vector2(13.9 * CELL, 7.0 * CELL), TEX_ORC, Color(0.85, 0.9, 0.78, orc_alpha))

	var stair_hint := origin + Vector2(8.5 * CELL, 10.2 * CELL)
	draw_string(
		ThemeDB.fallback_font,
		stair_hint,
		"descend",
		HORIZONTAL_ALIGNMENT_CENTER,
		120,
		18,
		Color(0.95, 0.88, 0.58, 0.9)
	)

func _draw_actor(pos: Vector2, tex: Texture2D, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(pos, Vector2(CELL, CELL)), false, modulate)

func _draw_torch_glow(origin: Vector2) -> void:
	var glow_a := 0.1 + sin(_t * 2.4) * 0.03
	var glow_b := 0.08 + sin(_t * 1.8 + 1.1) * 0.025
	draw_circle(origin + Vector2(4.0 * CELL, 3.0 * CELL), 120, Color(1.0, 0.62, 0.18, glow_a))
	draw_circle(origin + Vector2(13.5 * CELL, 2.5 * CELL), 100, Color(1.0, 0.55, 0.15, glow_b))

func _draw_vignette(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 160)), Color(0.02, 0.015, 0.03, 0.72), true)
	draw_rect(Rect2(Vector2(0, vp.y - 220), Vector2(vp.x, 220)), Color(0.02, 0.015, 0.03, 0.78), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(120, vp.y)), Color(0.02, 0.015, 0.03, 0.55), true)
	draw_rect(Rect2(Vector2(vp.x - 120, 0), Vector2(120, vp.y)), Color(0.02, 0.015, 0.03, 0.55), true)
