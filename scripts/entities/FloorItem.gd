class_name FloorItem extends Node2D
## Floor-item visual. Draws kind-specific shapes with a gentle bob.
## Kinds: "potion" | "scroll" | "weapon" | "armor" | "junk"

const TILE_SIZE: int = 32

var grid_pos: Vector2i = Vector2i.ZERO
var item_id: String = ""
var display_name: String = ""
var kind: String = "junk"
var color: Color = Color(0.9, 0.9, 0.4)
var extra: Dictionary = {}  # armor has "slot", etc.

# Bob animation — randomised per item so they don't all pulse together.
var _bob_phase: float = 0.0
const _BOB_SPEED: float = 2.0
const _BOB_AMP: float = 2.2


func _ready() -> void:
	z_index = 5
	add_to_group("floor_items")
	_bob_phase = randf() * TAU
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(p_grid_pos: Vector2i, p_id: String, p_name: String,
		p_kind: String, p_color: Color, p_extra: Dictionary = {}) -> void:
	grid_pos = p_grid_pos
	item_id = p_id
	display_name = p_name
	kind = p_kind
	color = p_color
	extra = p_extra
	position = Vector2(grid_pos.x * TILE_SIZE + TILE_SIZE / 2.0,
			grid_pos.y * TILE_SIZE + TILE_SIZE / 2.0)
	queue_redraw()


func _process(delta: float) -> void:
	_bob_phase += delta * _BOB_SPEED
	queue_redraw()


func _draw() -> void:
	var bob: float = sin(_bob_phase) * _BOB_AMP
	if TileRenderer.is_ascii():
		var entry: Array = TileRenderer.ascii_item(item_id, kind)
		TileRenderer.draw_ascii_glyph(self, Vector2(0.0, bob), 32,
				String(entry[0]), entry[1])
		return
	if TileRenderer.is_dcss():
		# Potions/scrolls: base colour tile always shown, effect overlay
		# only after identification.
		if kind == "potion" or kind == "scroll":
			var base_tex: Texture2D = TileRenderer.consumable_base(item_id, kind)
			if base_tex != null:
				var bsz: Vector2 = base_tex.get_size()
				var ofs: Vector2 = Vector2(-bsz.x * 0.5, -bsz.y * 0.5 + bob)
				draw_texture(base_tex, ofs)
				if GameManager != null and GameManager.is_identified(item_id):
					var overlay: Texture2D = TileRenderer.item(item_id)
					if overlay != null:
						# DCSS overlay PNGs already encode the corner placement
						# with transparency, so we draw at the same offset.
						draw_texture(overlay, ofs)
				return
		# Weapons / armor / junk: single tile blit.
		var tex: Texture2D = TileRenderer.item(item_id)
		if tex != null:
			var sz: Vector2 = tex.get_size()
			draw_texture(tex, Vector2(-sz.x * 0.5, -sz.y * 0.5 + bob))
			return
	# Otherwise fall back to the LPC-style hand-drawn shapes.
	match kind:
		"potion": _draw_potion(bob)
		"scroll": _draw_scroll(bob)
		"weapon": _draw_weapon(bob)
		"armor":  _draw_armor(bob)
		"wand":   _draw_wand(bob)
		"gold":   _draw_gold(bob)
		_:        _draw_generic(bob)


# ── Potion ─────────────────────────────────────────────────────────────────
# Round flask with neck + cork.  Liquid colour = item color.
func _draw_potion(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.0, 0.0, 0.0, 0.85)
	var liquid := color
	var glass  := Color(liquid.r * 0.55 + 0.35, liquid.g * 0.55 + 0.35,
			liquid.b * 0.55 + 0.35, 0.80)
	var cork   := Color(0.55, 0.36, 0.14)

	# Shadow.
	draw_circle(Vector2(1.0, oy + 10.0), 7.5, Color(0, 0, 0, 0.25))

	# Flask body.
	draw_circle(Vector2(0, oy + 5.0), 8.5, outline)
	draw_circle(Vector2(0, oy + 5.0), 7.5, glass)
	# Liquid fill (slightly smaller, shifted down).
	draw_circle(Vector2(0, oy + 6.0), 6.0, liquid)

	# Neck.
	var neck_pts := PackedVector2Array([
		Vector2(-3.0, oy - 4.5), Vector2(3.0, oy - 4.5),
		Vector2(3.5, oy - 1.5), Vector2(-3.5, oy - 1.5),
	])
	draw_colored_polygon(neck_pts, glass)
	draw_polyline(neck_pts + PackedVector2Array([neck_pts[0]]), outline, 1.2)

	# Cork.
	var cork_pts := PackedVector2Array([
		Vector2(-4.0, oy - 8.0), Vector2(4.0, oy - 8.0),
		Vector2(3.0, oy - 4.5), Vector2(-3.0, oy - 4.5),
	])
	draw_colored_polygon(cork_pts, cork)
	draw_polyline(cork_pts + PackedVector2Array([cork_pts[0]]), outline, 1.2)

	# Specular highlight dot.
	draw_circle(Vector2(-3.0, oy + 1.5), 2.0, Color(1, 1, 1, 0.55))


# ── Scroll ─────────────────────────────────────────────────────────────────
# Rolled parchment with coloured wax-seal glow.
func _draw_scroll(bob: float) -> void:
	var oy: float = bob
	var outline  := Color(0.0, 0.0, 0.0, 0.85)
	var parchment := Color(0.96, 0.90, 0.72)
	var roll_col  := Color(0.82, 0.76, 0.58)
	var seal_col  := color

	# Shadow.
	draw_rect(Rect2(-9.0, oy + 4.5, 18.0, 4.0), Color(0, 0, 0, 0.25))

	# Parchment rectangle body.
	draw_rect(Rect2(-8.0, oy - 4.5, 16.0, 9.0), outline)
	draw_rect(Rect2(-7.5, oy - 4.0, 15.0, 8.0), parchment)

	# Rolled left / right ends.
	draw_circle(Vector2(-8.5, oy), 4.5, outline)
	draw_circle(Vector2(-8.5, oy), 3.8, roll_col)
	draw_circle(Vector2(8.5, oy), 4.5, outline)
	draw_circle(Vector2(8.5, oy), 3.8, roll_col)

	# Three text lines on parchment.
	var line_col := Color(0.50, 0.42, 0.28, 0.80)
	for i in 3:
		var ly: float = oy - 2.5 + float(i) * 2.5
		draw_line(Vector2(-5.5, ly), Vector2(5.5, ly), line_col, 0.9)

	# Wax-seal coloured dot in the centre.
	draw_circle(Vector2(0, oy), 3.2, seal_col)
	draw_circle(Vector2(0, oy), 3.2, outline.lightened(0.3), false, 1.0)
	draw_circle(Vector2(-0.8, oy - 0.8), 0.9, Color(1, 1, 1, 0.40))


# ── Weapon ─────────────────────────────────────────────────────────────────
# Diagonal sword silhouette.  Blade tint = item color.
func _draw_weapon(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.0, 0.0, 0.0, 0.85)
	var blade   := color
	var guard   := Color(0.70, 0.60, 0.25)  # gold guard
	var pommel  := guard

	# Shadow.
	draw_line(Vector2(-1.0, oy + 12.5), Vector2(1.0, oy + 12.5), Color(0, 0, 0, 0.25), 6.0)

	# Blade (top-right to lower-left, tilted 45°).
	# Draw as a thin polygon.
	var blen: float = 16.0
	var bhalf: float = 1.5
	var tip := Vector2(0.0, oy - blen * 0.5)
	var base := Vector2(0.0, oy + blen * 0.5)
	var blade_pts := PackedVector2Array([
		tip + Vector2(-bhalf, 0), tip + Vector2(bhalf, 0),
		base + Vector2(bhalf * 0.5, 0), base + Vector2(-bhalf * 0.5, 0),
	])
	# Rotate 40° so it sits diagonally.
	var ang: float = deg_to_rad(40.0)
	var rotated_pts := PackedVector2Array()
	for pt in blade_pts:
		rotated_pts.append(pt.rotated(ang))
	draw_colored_polygon(rotated_pts, blade)
	draw_polyline(rotated_pts + PackedVector2Array([rotated_pts[0]]), outline, 1.0)

	# Specular line on blade.
	draw_line(tip.rotated(ang), (tip + Vector2(0, blen * 0.5)).rotated(ang),
			Color(1, 1, 1, 0.30), 0.8)

	# Cross-guard at midpoint.
	var mid: Vector2 = (tip + Vector2(0, blen * 0.35)).rotated(ang)
	var perp: Vector2 = Vector2(cos(ang + PI * 0.5), sin(ang + PI * 0.5))
	draw_line(mid - perp * 6.0, mid + perp * 6.0, outline, 4.5)
	draw_line(mid - perp * 5.5, mid + perp * 5.5, guard, 2.8)

	# Pommel at hilt.
	var hilt: Vector2 = (tip + Vector2(0, blen * 0.85)).rotated(ang)
	draw_circle(hilt, 3.5, outline)
	draw_circle(hilt, 2.5, pommel)


# ── Armor ──────────────────────────────────────────────────────────────────
# Shield-like icon, varied slightly by slot.
func _draw_armor(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.0, 0.0, 0.0, 0.85)
	var fill    := color
	var shine   := fill.lightened(0.35)
	var slot: String = String(extra.get("slot", "chest"))

	# Shadow.
	draw_circle(Vector2(1.0, oy + 11.5), 6.5, Color(0, 0, 0, 0.25))

	match slot:
		"helm":
			_draw_helm(oy, fill, shine, outline)
		"boots":
			_draw_boots(oy, fill, shine, outline)
		"gloves":
			_draw_gloves(oy, fill, shine, outline)
		_:  # chest / legs / default → shield
			_draw_shield(oy, fill, shine, outline)


func _draw_shield(oy: float, fill: Color, shine: Color, outline: Color) -> void:
	# Pentagon shield: flat top, pointed bottom.
	var pts := PackedVector2Array([
		Vector2(-9.0, oy - 7.0),
		Vector2(9.0,  oy - 7.0),
		Vector2(9.0,  oy + 1.0),
		Vector2(0.0,  oy + 9.0),
		Vector2(-9.0, oy + 1.0),
	])
	draw_colored_polygon(pts, outline)
	var inner_pts := PackedVector2Array([
		Vector2(-7.5, oy - 5.5),
		Vector2(7.5,  oy - 5.5),
		Vector2(7.5,  oy + 0.5),
		Vector2(0.0,  oy + 7.5),
		Vector2(-7.5, oy + 0.5),
	])
	draw_colored_polygon(inner_pts, fill)
	# Boss (central boss rivet).
	draw_circle(Vector2(0, oy - 0.5), 2.5, shine)
	# Cross line.
	draw_line(Vector2(0, oy - 5.0), Vector2(0, oy + 5.0), outline.lightened(0.15), 0.9)
	draw_line(Vector2(-6.0, oy - 1.0), Vector2(6.0, oy - 1.0), outline.lightened(0.15), 0.9)


func _draw_helm(oy: float, fill: Color, shine: Color, outline: Color) -> void:
	# Rounded dome.
	draw_circle(Vector2(0, oy - 1.0), 9.0, outline)
	draw_circle(Vector2(0, oy - 1.0), 7.5, fill)
	# Visor bar.
	draw_rect(Rect2(-7.0, oy + 3.5, 14.0, 3.5), outline)
	draw_rect(Rect2(-6.0, oy + 4.0, 12.0, 2.0), fill.darkened(0.4))
	# Cheek guards.
	draw_rect(Rect2(-9.5, oy + 1.5, 2.5, 6.0), outline)
	draw_rect(Rect2(-8.5, oy + 2.0, 1.5, 5.0), fill.darkened(0.2))
	draw_rect(Rect2(7.0, oy + 1.5, 2.5, 6.0), outline)
	draw_rect(Rect2(7.0, oy + 2.0, 1.5, 5.0), fill.darkened(0.2))
	# Shine.
	draw_circle(Vector2(-3.0, oy - 3.5), 2.0, Color(1, 1, 1, 0.35))


func _draw_boots(oy: float, fill: Color, shine: Color, outline: Color) -> void:
	# Simple boot silhouette (side view): leg + toe.
	var boot_pts := PackedVector2Array([
		Vector2(-4.0, oy - 8.0),
		Vector2(4.0,  oy - 8.0),
		Vector2(4.0,  oy + 4.0),
		Vector2(10.0, oy + 4.0),
		Vector2(10.0, oy + 9.0),
		Vector2(-4.0, oy + 9.0),
	])
	draw_colored_polygon(boot_pts, outline)
	var inner_pts := PackedVector2Array([
		Vector2(-3.0, oy - 7.0),
		Vector2(3.0,  oy - 7.0),
		Vector2(3.0,  oy + 3.0),
		Vector2(9.0,  oy + 3.0),
		Vector2(9.0,  oy + 8.0),
		Vector2(-3.0, oy + 8.0),
	])
	draw_colored_polygon(inner_pts, fill)
	# Highlight on toe.
	draw_circle(Vector2(6.5, oy + 5.5), 1.8, shine)


func _draw_gloves(oy: float, fill: Color, shine: Color, outline: Color) -> void:
	# Palm block + three finger bumps.
	draw_rect(Rect2(-7.0, oy - 0.5, 14.0, 9.5), outline)
	draw_rect(Rect2(-6.0, oy + 0.5, 12.0, 8.0), fill)
	# Fingers (three bumps at top).
	for i in 3:
		var fx: float = -4.5 + float(i) * 4.5
		draw_circle(Vector2(fx, oy - 0.5), 3.0, outline)
		draw_circle(Vector2(fx, oy - 0.5), 2.2, fill)
	# Knuckle shine.
	for i in 3:
		var fx: float = -4.5 + float(i) * 4.5
		draw_circle(Vector2(fx, oy - 1.2), 0.9, shine)


# ── Generic / Junk ─────────────────────────────────────────────────────────
# ── Gold pile ──────────────────────────────────────────────────────────────
# Three stacked coins at slight offsets. Colour is a warm yellow-gold.
func _draw_gold(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.20, 0.15, 0.05, 0.85)
	var coin := Color(1.00, 0.80, 0.20)
	var shine := Color(1.0, 1.0, 0.7, 0.6)
	draw_circle(Vector2(-3.0, oy + 5.0), 6.0, Color(0, 0, 0, 0.2))
	# Three overlapping coins
	for i in 3:
		var cx: float = float(i - 1) * 2.0
		var cy: float = oy + 2.0 - float(i) * 1.8
		draw_circle(Vector2(cx, cy), 5.5, outline)
		draw_circle(Vector2(cx, cy), 4.5, coin)
		draw_circle(Vector2(cx - 1.5, cy - 1.5), 1.2, shine)


# ── Wand ───────────────────────────────────────────────────────────────────
# Short stick with a coloured tip. The tip colour reflects the wand's
# energy; the shaft is a neutral brown so wands read distinct from rings.
func _draw_wand(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.0, 0.0, 0.0, 0.85)
	var shaft := Color(0.50, 0.36, 0.20)
	var tip := color
	draw_line(Vector2(-2.0, oy + 9.0), Vector2(2.0, oy + 9.0), Color(0, 0, 0, 0.25), 4.0)
	# Shaft (diagonal for silhouette).
	draw_line(Vector2(-7.0, oy + 7.0), Vector2(6.0, oy - 6.0), outline, 3.4)
	draw_line(Vector2(-7.0, oy + 7.0), Vector2(6.0, oy - 6.0), shaft, 2.2)
	# Glowing tip.
	draw_circle(Vector2(6.5, oy - 6.5), 3.0, outline)
	draw_circle(Vector2(6.5, oy - 6.5), 2.4, tip)
	draw_circle(Vector2(5.5, oy - 7.0), 0.8, Color(1, 1, 1, 0.6))


func _draw_generic(bob: float) -> void:
	var oy: float = bob
	var outline := Color(0.0, 0.0, 0.0, 0.70)
	draw_circle(Vector2(1.0, oy + 11.0), 7.0, Color(0, 0, 0, 0.20))
	var r: float = 9.0
	var pts: PackedVector2Array = PackedVector2Array([
		Vector2(0, oy - r), Vector2(r, oy), Vector2(0, oy + r), Vector2(-r, oy)
	])
	draw_colored_polygon(pts, color)
	draw_polyline(pts + PackedVector2Array([pts[0]]), outline, 1.5)
	draw_circle(Vector2(-3.0, oy - 2.5), 2.0, Color(1, 1, 1, 0.35))


func as_dict() -> Dictionary:
	var d: Dictionary = {"id": item_id, "name": display_name, "kind": kind, "color": color}
	for k in extra.keys():
		d[k] = extra[k]
	return d
