extends Control

const TILE: float = 32.0

const TEX_WALL: Texture2D = preload("res://assets/tiles/individual/dngn/wall/bmaus_stone_wall0.png")
const TEX_FLOOR: Texture2D = preload("res://assets/tiles/individual/dngn/floor/black_cobalt01.png")
const TEX_STAIRS: Texture2D = preload("res://assets/tiles/individual/dngn/gateways/stone_stairs_down.png")
const TEX_ARCH: Texture2D = preload("res://assets/tiles/individual/dngn/gateways/stone_arch.png")
const TEX_PORTAL: Texture2D = preload("res://assets/tiles/individual/dngn/gateways/portal.png")

const TEX_FIGHTER_BASE: Texture2D = preload("res://assets/tiles/individual/player/base/human_m.png")
const TEX_FIGHTER_BODY: Texture2D = preload("res://assets/tiles/individual/player/body/chainmail.png")
const TEX_FIGHTER_WEAPON: Texture2D = preload("res://assets/tiles/individual/player/hand1/short_sword.png")
const TEX_FIGHTER_SHIELD: Texture2D = preload("res://assets/tiles/individual/player/hand2/kite_shield_knight_blue.png")

const TEX_MAGE_BASE: Texture2D = preload("res://assets/tiles/individual/player/base/human_f.png")
const TEX_MAGE_BODY: Texture2D = preload("res://assets/tiles/individual/player/body/robe_purple.png")
const TEX_MAGE_WEAPON: Texture2D = preload("res://assets/tiles/individual/player/hand1/staff_mage.png")

const TEX_SKELETON: Texture2D = preload("res://assets/tiles/individual/mon/undead/revenant.png")
const TEX_GOBLIN: Texture2D = preload("res://assets/tiles/individual/mon/humanoids/goblin.png")
const TEX_ORC: Texture2D = preload("res://assets/tiles/individual/mon/humanoids/orcs/orc.png")
const TEX_DRAGON: Texture2D = preload("res://assets/tiles/individual/mon/dragons/fire_dragon.png")

var _t: float = 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true

func _process(delta: float) -> void:
	_t += delta
	queue_redraw()

func _draw() -> void:
	var vp := size
	_draw_background(vp)
	_draw_side_architecture(vp)
	_draw_depth_layers(vp)
	_draw_center_stage(vp)
	_draw_characters(vp)
	_draw_foreground_props(vp)
	_draw_vignette(vp)

func _draw_background(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, vp), Color(0.03, 0.025, 0.04, 1.0), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, vp.y * 0.48)), Color(0.07, 0.07, 0.1, 0.82), true)
	draw_rect(Rect2(Vector2(0.0, vp.y * 0.48), Vector2(vp.x, vp.y * 0.52)), Color(0.02, 0.02, 0.03, 0.9), true)

func _draw_side_architecture(vp: Vector2) -> void:
	var tile_scale := 2.8
	var wall_size := Vector2(TILE, TILE) * tile_scale
	var left_x := 18.0
	var right_x := vp.x - 18.0 - wall_size.x

	for i in range(8):
		var y := 10.0 + i * (wall_size.y - 6.0)
		_draw_tex(TEX_WALL, Rect2(Vector2(left_x, y), wall_size), Color(0.92, 0.92, 1.0, 1.0))
		_draw_tex(TEX_WALL, Rect2(Vector2(right_x, y), wall_size), Color(0.92, 0.92, 1.0, 1.0))

	var arch_size := Vector2(220.0, 220.0)
	_draw_tex(TEX_ARCH, Rect2(Vector2(54.0, 38.0), arch_size), Color(0.95, 0.95, 1.0, 0.95))
	_draw_tex(TEX_ARCH, Rect2(Vector2(vp.x - 54.0 - arch_size.x, 38.0), arch_size), Color(0.95, 0.95, 1.0, 0.95))

	var torch_y := 158.0 + sin(_t * 1.5) * 2.0
	_draw_torch(Vector2(112.0, torch_y))
	_draw_torch(Vector2(vp.x - 112.0, torch_y + 6.0))

func _draw_depth_layers(vp: Vector2) -> void:
	var center_x := vp.x * 0.5
	var portal_size := Vector2(110.0, 150.0)
	var portal_pos := Vector2(center_x + 120.0, vp.y * 0.43)
	var portal_color := Color(0.75, 0.45, 1.0, 0.92 + sin(_t * 2.6) * 0.07)
	draw_circle(portal_pos + portal_size * 0.5, 86.0, Color(0.45, 0.1, 0.7, 0.18))
	_draw_tex(TEX_PORTAL, Rect2(portal_pos, portal_size), portal_color)

	var arch_size := Vector2(86.0, 86.0)
	_draw_tex(TEX_ARCH, Rect2(Vector2(center_x - 188.0, vp.y * 0.46), arch_size), Color(0.72, 0.74, 0.86, 0.45))
	_draw_tex(TEX_ARCH, Rect2(Vector2(center_x - 46.0, vp.y * 0.47), arch_size), Color(0.72, 0.74, 0.86, 0.35))

	_draw_actor(Vector2(center_x - 156.0, vp.y * 0.565), Vector2(42.0, 42.0), TEX_SKELETON, Color(0.8, 0.84, 0.9, 0.48))
	_draw_actor(Vector2(center_x + 52.0, vp.y * 0.59), Vector2(36.0, 36.0), TEX_GOBLIN, Color(0.68, 0.82, 0.72, 0.36))
	_draw_actor(Vector2(vp.x - 128.0, vp.y * 0.63), Vector2(76.0, 76.0), TEX_DRAGON, Color(0.78, 0.46, 0.22, 0.38))

	draw_circle(Vector2(center_x, vp.y * 0.53), 120.0, Color(0.15, 0.22, 0.38, 0.08))
	draw_circle(Vector2(center_x + 156.0, vp.y * 0.51), 80.0, Color(0.55, 0.18, 0.75, 0.1))

func _draw_center_stage(vp: Vector2) -> void:
	var center_x := vp.x * 0.5
	var stage_y := vp.y * 0.60

	var left_wall := PackedVector2Array([
		Vector2(center_x - 170.0, stage_y - 18.0),
		Vector2(center_x - 96.0, stage_y - 62.0),
		Vector2(center_x - 24.0, stage_y - 20.0),
		Vector2(center_x - 74.0, stage_y + 48.0),
		Vector2(center_x - 182.0, stage_y + 80.0)
	])
	draw_colored_polygon(left_wall, Color(0.18, 0.17, 0.2, 0.95))

	var right_wall := PackedVector2Array([
		Vector2(center_x + 170.0, stage_y - 12.0),
		Vector2(center_x + 76.0, stage_y - 64.0),
		Vector2(center_x + 18.0, stage_y - 14.0),
		Vector2(center_x + 58.0, stage_y + 66.0),
		Vector2(center_x + 174.0, stage_y + 108.0)
	])
	draw_colored_polygon(right_wall, Color(0.14, 0.14, 0.17, 0.96))

	var step_w := 56.0
	var step_h := 34.0
	var top_y := stage_y - 18.0
	for row in range(3):
		var tiles_in_row := 2 + row
		var row_y := top_y + row * step_h
		var start_x := center_x - (tiles_in_row * step_w) * 0.5
		for col in range(tiles_in_row):
			var pos := Vector2(start_x + col * step_w, row_y)
			var rect := Rect2(pos, Vector2(step_w + 6.0, step_h + 8.0))
			_draw_tex(TEX_FLOOR, rect, Color(0.96, 0.92, 0.82, 1.0))
			draw_rect(Rect2(rect.position + Vector2(0.0, rect.size.y - 6.0), Vector2(rect.size.x, 10.0)), Color(0.26, 0.19, 0.12, 0.82), true)
			_draw_glyph(rect.position + rect.size * 0.5)

	var stairs_rect := Rect2(Vector2(center_x - 34.0, stage_y + 74.0), Vector2(150.0, 120.0))
	_draw_tex(TEX_STAIRS, stairs_rect, Color(0.96, 0.95, 1.0, 0.98))

	draw_circle(Vector2(center_x, stage_y + 12.0), 96.0, Color(0.15, 0.42, 0.72, 0.08 + sin(_t * 2.0) * 0.02))

func _draw_characters(vp: Vector2) -> void:
	var center_x := vp.x * 0.5
	var stage_y := vp.y * 0.60
	var fighter_pos := Vector2(center_x - 112.0, stage_y - 28.0 + sin(_t * 1.9) * 2.0)
	var mage_pos := Vector2(center_x - 6.0, stage_y - 44.0 + sin(_t * 2.2 + 0.4) * 2.5)

	var fighter_rect := Rect2(fighter_pos, Vector2(108.0, 108.0))
	_draw_actor_layered(
		fighter_rect,
		[TEX_FIGHTER_BASE, TEX_FIGHTER_BODY, TEX_FIGHTER_WEAPON, TEX_FIGHTER_SHIELD],
		[Color.WHITE, Color.WHITE, Color.WHITE, Color(1.0, 1.0, 1.0, 0.98)]
	)

	var mage_rect := Rect2(mage_pos, Vector2(118.0, 118.0))
	_draw_actor_layered(
		mage_rect,
		[TEX_MAGE_BASE, TEX_MAGE_BODY, TEX_MAGE_WEAPON],
		[Color.WHITE, Color.WHITE, Color(0.96, 0.98, 1.0, 1.0)]
	)

	var orb := mage_rect.position + Vector2(90.0, 16.0)
	draw_circle(orb, 22.0, Color(0.18, 0.72, 1.0, 0.24 + sin(_t * 2.8) * 0.05))
	draw_circle(orb, 12.0, Color(0.48, 0.86, 1.0, 0.72 + sin(_t * 3.4) * 0.08))
	for i in range(6):
		var angle := _t * 1.6 + i * 1.04
		var p := orb + Vector2(cos(angle), sin(angle)) * 28.0
		draw_circle(p, 2.8, Color(0.48, 0.82, 1.0, 0.8))

func _draw_foreground_props(vp: Vector2) -> void:
	var center_x := vp.x * 0.5
	var bottom_y := vp.y * 0.86

	_draw_torch(Vector2(72.0, bottom_y - 28.0), 1.25)
	_draw_torch(Vector2(vp.x - 72.0, bottom_y - 38.0), 1.3)

	_draw_actor(Vector2(42.0, vp.y * 0.735), Vector2(50.0, 50.0), TEX_SKELETON, Color(0.86, 0.88, 0.96, 0.38))
	_draw_actor(Vector2(vp.x - 112.0, vp.y * 0.705), Vector2(54.0, 54.0), TEX_ORC, Color(0.78, 0.84, 0.74, 0.28))

	draw_circle(Vector2(center_x - 128.0, vp.y * 0.66), 12.0, Color(1.0, 0.7, 0.22, 0.22))
	draw_circle(Vector2(center_x + 134.0, vp.y * 0.655), 14.0, Color(1.0, 0.62, 0.18, 0.18))

func _draw_torch(pos: Vector2, scale_mul: float = 1.0) -> void:
	draw_rect(Rect2(pos + Vector2(-4.0, -12.0) * scale_mul, Vector2(8.0, 44.0) * scale_mul), Color(0.28, 0.22, 0.14, 0.95), true)
	draw_circle(pos, 18.0 * scale_mul, Color(1.0, 0.62, 0.16, 0.18 + sin(_t * 2.6 + pos.x * 0.01) * 0.03))
	draw_circle(pos, 9.0 * scale_mul, Color(1.0, 0.84, 0.48, 0.74))
	draw_circle(pos + Vector2(0.0, -8.0) * scale_mul, 7.0 * scale_mul, Color(1.0, 0.48, 0.12, 0.62))

func _draw_actor_layered(rect: Rect2, textures: Array[Texture2D], modulates: Array[Color]) -> void:
	for i in range(textures.size()):
		if textures[i] == null:
			continue
		draw_texture_rect(textures[i], rect, false, modulates[i])

func _draw_actor(pos: Vector2, actor_size: Vector2, tex: Texture2D, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, Rect2(pos, actor_size), false, modulate)

func _draw_tex(tex: Texture2D, rect: Rect2, modulate: Color = Color.WHITE) -> void:
	if tex == null:
		return
	draw_texture_rect(tex, rect, false, modulate)

func _draw_glyph(pos: Vector2) -> void:
	var pulse := 0.6 + sin(_t * 2.2 + pos.x * 0.03) * 0.15
	draw_circle(pos, 4.0, Color(0.98, 0.78, 0.36, pulse))
	draw_line(pos + Vector2(-7.0, 0.0), pos + Vector2(7.0, 0.0), Color(0.72, 0.58, 0.28, pulse), 2.0)
	draw_line(pos + Vector2(0.0, -7.0), pos + Vector2(0.0, 7.0), Color(0.72, 0.58, 0.28, pulse), 2.0)

func _draw_vignette(vp: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, Vector2(vp.x, 174.0)), Color(0.01, 0.01, 0.02, 0.62), true)
	draw_rect(Rect2(Vector2.ZERO, Vector2(28.0, vp.y)), Color(0.01, 0.01, 0.02, 0.52), true)
	draw_rect(Rect2(Vector2(vp.x - 28.0, 0.0), Vector2(28.0, vp.y)), Color(0.01, 0.01, 0.02, 0.52), true)
	draw_rect(Rect2(Vector2(0.0, vp.y - 210.0), Vector2(vp.x, 210.0)), Color(0.01, 0.01, 0.02, 0.72), true)
