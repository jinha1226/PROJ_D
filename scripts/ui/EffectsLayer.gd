extends Node
class_name EffectsLayer

# Phase 0 extraction from Game.gd. Hosts visual effect spawning:
# damage numbers, text popups, hit flashes, projectiles, spell bolts,
# AOE bursts, and corpse texture building/composition.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node


const _BOLT_TILES: Dictionary = {
	"fire":      "res://assets/tiles/effects/bolt/fire_bolt.png",
	"cold":      "res://assets/tiles/effects/bolt/ice_bolt.png",
	"lightning": "res://assets/tiles/effects/bolt/lightning_bolt.png",
	"poison":    "res://assets/tiles/effects/bolt/poison_bolt.png",
	"death":     "res://assets/tiles/effects/bolt/death_bolt.png",
	"drain":     "res://assets/tiles/effects/bolt/drain_bolt.png",
	"":          "res://assets/tiles/effects/bolt/magic_dart.png",
}
const _HIT_TILES: Dictionary = {
	"fire":      ["res://assets/tiles/effects/hit/fire0.png",
				  "res://assets/tiles/effects/hit/fire1.png",
				  "res://assets/tiles/effects/hit/fire2.png"],
	"cold":      ["res://assets/tiles/effects/hit/ice0.png",
				  "res://assets/tiles/effects/hit/ice1.png",
				  "res://assets/tiles/effects/hit/ice2.png"],
	"lightning": ["res://assets/tiles/effects/hit/lightning0.png",
				  "res://assets/tiles/effects/hit/lightning1.png",
				  "res://assets/tiles/effects/hit/lightning2.png"],
	"poison":    ["res://assets/tiles/effects/hit/poison0.png",
				  "res://assets/tiles/effects/hit/poison1.png",
				  "res://assets/tiles/effects/hit/poison2.png"],
	"drain":     ["res://assets/tiles/effects/hit/drain0.png",
				  "res://assets/tiles/effects/hit/drain1.png",
				  "res://assets/tiles/effects/hit/drain2.png"],
	"death":     ["res://assets/tiles/effects/hit/drain0.png",
				  "res://assets/tiles/effects/hit/drain1.png",
				  "res://assets/tiles/effects/hit/drain2.png"],
	"heal":      ["res://assets/tiles/effects/hit/heal0.png",
				  "res://assets/tiles/effects/hit/heal1.png"],
	"":          ["res://assets/tiles/effects/hit/magic0.png",
				  "res://assets/tiles/effects/hit/magic1.png"],
}


func _corpse_tile_for_monster(monster: Monster) -> Texture2D:
	if monster == null or monster.data == null:
		return null
	var mid: String = String(monster.data.id)
	if host._corpse_tex_cache.has(mid):
		return host._corpse_tex_cache[mid]
	var tex: Texture2D = _build_corpse_texture(monster.data)
	host._corpse_tex_cache[mid] = tex
	return tex

func _build_corpse_texture(data: MonsterData) -> Texture2D:
	var body_path: String = String(data.tile_path)
	if body_path == "" or not ResourceLoader.exists(body_path):
		return null
	var body_tex: Texture2D = load(body_path) as Texture2D
	if body_tex == null:
		return null
	var body_img: Image = body_tex.get_image()
	if body_img == null:
		return null
	body_img.convert(Image.FORMAT_RGBA8)
	# Port of DCSS rltiles tile::corpsify (tile.cc:160-273): vertical 2x squash,
	# curved horizontal cut, top/bottom halves offset apart → "torn in half" look.
	var corpsified: Image = _corpsify_image(body_img, 32, 32, 3, 4)
	var blood_path: String = host._CORPSE_BLOOD_GREEN if host._CORPSE_GREEN_BLOOD.get(String(data.id), false) else host._CORPSE_BLOOD_RED
	var out_img: Image = null
	if ResourceLoader.exists(blood_path):
		var blood_tex: Texture2D = load(blood_path) as Texture2D
		if blood_tex != null:
			var blood_img: Image = blood_tex.get_image()
			if blood_img != null:
				out_img = blood_img.duplicate() as Image
				out_img.convert(Image.FORMAT_RGBA8)
				var ox: int = (out_img.get_width() - corpsified.get_width()) / 2
				var oy: int = (out_img.get_height() - corpsified.get_height()) / 2
				out_img.blend_rect(corpsified, Rect2i(0, 0, corpsified.get_width(), corpsified.get_height()), Vector2i(ox, oy))
	if out_img == null:
		out_img = corpsified
	return ImageTexture.create_from_image(out_img)

func _corpsify_cut_y(x: int, w: int, h: int) -> int:
	var cy: int = h / 2 + 2
	var lim1: int = w / 8
	var lim2: int = w / 3
	if x < lim1 or x >= w - lim1:
		cy += 2
	elif x < lim2 or x >= w - lim2:
		cy += 1
	return cy

func _corpsify_image(orig: Image, cw: int, ch: int, cut_separate: int, cut_height: int) -> Image:
	var out: Image = Image.create(cw, ch, false, Image.FORMAT_RGBA8)
	out.fill(Color(0, 0, 0, 0))
	var ow: int = orig.get_width()
	var oh: int = orig.get_height()
	# Bounding box of non-transparent pixels
	var xmin: int = ow
	var ymin: int = oh
	var xmax: int = -1
	var ymax: int = -1
	for y in oh:
		for x in ow:
			if orig.get_pixel(x, y).a > 0.0:
				if x < xmin: xmin = x
				if y < ymin: ymin = y
				if x > xmax: xmax = x
				if y > ymax: ymax = y
	if xmax < 0:
		return out
	var centerx: int = (xmax + xmin) / 2
	var centery: int = (ymax + ymin) / 2
	var image_scale: float = max(float(ow) / float(cw), float(oh) / float(ch))
	var height_proj: float = 2.0
	var written: PackedByteArray = PackedByteArray()
	written.resize(cw * ch)
	for y in ch:
		for x in cw:
			var cy: int = _corpsify_cut_y(x, cw, ch)
			if y > cy - cut_height and y <= cy:
				continue
			var x1: int = int(float(x - cw / 2.0) * image_scale) + centerx
			var y1: int = int(float(y - ch / 2.0) * height_proj * image_scale) + centery
			if y >= cy:
				x1 -= cut_separate
				y1 -= cut_height / 2
			else:
				x1 += cut_separate
				y1 += cut_height / 2 + cut_height % 2
			if x1 < 0 or x1 >= ow or y1 < 0 or y1 >= oh:
				continue
			var p: Color = orig.get_pixel(x1, y1)
			if p.a <= 0.0:
				continue
			# Skip pure black rim/shadow pixels (DCSS convention)
			if p.r == 0.0 and p.g == 0.0 and p.b == 0.0:
				continue
			out.set_pixel(x, y, p)
			written[x + y * cw] = 1
	# Wound color along the cut edge (dark red gash)
	var wound: Color = Color8(140, 16, 16)
	var wound_height: int = min(2, cut_height)
	for x in cw:
		var cy2: int = _corpsify_cut_y(x, cw, ch)
		var top_y: int = cy2 - cut_height
		if top_y >= 0 and top_y < ch and written[x + top_y * cw] == 1:
			var start: int = top_y + 1
			for yy in range(start, min(start + wound_height, ch)):
				out.set_pixel(x, yy, wound)
	return out


func spawn_damage_number(world_pos: Vector2, amount: int, color: Color) -> void:
	if host._effect_layer == null:
		return
	var lbl := Label.new()
	lbl.text = "-%d" % amount
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = world_pos + Vector2(-20, -32)
	lbl.z_index = 10
	host._effect_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 48.0, 0.65)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.65)
	tw.tween_callback(lbl.queue_free)

func spawn_text_popup(world_pos: Vector2, text: String, color: Color,
		font_size: int = 28, duration: float = 0.6) -> void:
	if host._effect_layer == null:
		return
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", font_size)
	lbl.add_theme_color_override("font_color", color)
	lbl.position = world_pos + Vector2(-12, -24)
	lbl.z_index = 10
	host._effect_layer.add_child(lbl)
	var tw := lbl.create_tween()
	tw.tween_property(lbl, "position:y", lbl.position.y - 28.0, duration)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, duration)
	tw.tween_callback(lbl.queue_free)

## Spawn a brief hit flash on a monster sprite node.
func spawn_hit_flash(target_node: Node2D) -> void:
	if target_node == null:
		return
	var tw := target_node.create_tween()
	tw.tween_property(target_node, "modulate", Color(1.0, 0.3, 0.3, 1.0), 0.06)
	tw.tween_property(target_node, "modulate", Color.WHITE, 0.12)

## Spawn a DCSS tile projectile from world_start to world_end.
func spawn_projectile(world_start: Vector2, world_end: Vector2,
		_color: Color, on_arrive: Callable = Callable()) -> void:
	spawn_spell_bolt(world_start, world_end, "", on_arrive)

func spawn_spell_bolt(world_start: Vector2, world_end: Vector2,
		element: String, on_arrive: Callable = Callable(),
		delay: float = 0.0) -> void:
	if host._effect_layer == null:
		if on_arrive.is_valid():
			on_arrive.call()
		return
	var key: String = element if _BOLT_TILES.has(element) else ""
	var tile_path: String = _BOLT_TILES[key]
	const SZ := 32.0
	var half := Vector2(SZ * 0.5, SZ * 0.5)
	if ResourceLoader.exists(tile_path):
		var rect := TextureRect.new()
		rect.texture = load(tile_path)
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.custom_minimum_size = Vector2(SZ, SZ)
		rect.size = Vector2(SZ, SZ)
		rect.pivot_offset = half
		rect.rotation = (world_end - world_start).angle()
		rect.position = world_start - half
		rect.z_index = 8
		rect.visible = false
		host._effect_layer.add_child(rect)
		var tw := rect.create_tween()
		if delay > 0.0:
			tw.tween_interval(delay)
		tw.tween_callback(func(): rect.visible = true)
		tw.tween_property(rect, "position", world_end - half, 0.18)
		tw.tween_callback(rect.queue_free)
		if on_arrive.is_valid():
			tw.tween_callback(on_arrive)
	else:
		if on_arrive.is_valid():
			on_arrive.call()

func spawn_hit_effect(_world_pos: Vector2, _element: String) -> void:
	pass

func spawn_aoe_burst(_target_positions: Array, _element: String) -> void:
	pass
