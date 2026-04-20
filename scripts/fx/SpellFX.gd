class_name SpellFX
## School-aware visual effects factory for spell casting.
## All methods create short-lived Node2D children on `layer` (EntityLayer).
## Damage / state changes are applied by the caller; effects are cosmetic.
##
## DCSS-style visual language per school:
##   fire   — flickering orange ball + ember explosion
##   cold   — cyan crystal shard + shatter fragments
##   air    — instant zigzag lightning bolt + flash
##   earth  — tumbling rock + dust kick
##   poison — green cloud lingers
##   necro  — purple-black smoke + skull glyph
##   hexes  — no projectile, rotating rune rings on target
##   tloc   — no projectile, dual swirl at origin + destination
##   conj   — white-blue dart + starburst (fallback)
##
## Public API preserves the old `cast_single` / `cast_area` / `cast_slow` /
## `cast_blink` entry points. Each now takes an optional `school` argument
## and dispatches to the right visual; passing "" falls back to generic.

# ---- Constants -----------------------------------------------------------

const SCHOOL_COLOR: Dictionary = {
	"fire":           Color(1.0, 0.35, 0.1),
	"cold":           Color(0.5, 0.85, 1.0),
	"air":            Color(1.0, 0.95, 0.4),
	"earth":          Color(0.75, 0.55, 0.35),
	"poison":         Color(0.45, 0.85, 0.35),
	"necromancy":     Color(0.55, 0.15, 0.7),
	"hexes":          Color(0.9, 0.4, 0.85),
	"translocations": Color(0.75, 0.5, 1.0),
	"conjurations":   Color(0.85, 0.9, 1.0),
	"summonings":     Color(0.9, 0.75, 0.3),
}


# ---- Inner drawable nodes -----------------------------------------------

class _FireBall extends Node2D:
	var ball_color: Color = Color.WHITE
	var ball_radius: float = 10.0
	var phase: float = 0.0
	func _process(d: float) -> void:
		phase += d * 14.0
		queue_redraw()
	func _draw() -> void:
		var flicker: float = 1.0 + 0.18 * sin(phase)
		draw_circle(Vector2.ZERO, ball_radius * flicker, ball_color)
		draw_circle(Vector2.ZERO, ball_radius * 0.60, ball_color.lightened(0.35))
		draw_circle(Vector2.ZERO, ball_radius * 0.28, Color(1, 1, 0.85, 0.9))


class _IceShard extends Node2D:
	var shard_color: Color = Color.WHITE
	var shard_size: float = 10.0
	func _draw() -> void:
		var s: float = shard_size
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(s, 0), Vector2(0, s * 0.45),
			Vector2(-s * 0.7, 0), Vector2(0, -s * 0.45),
		])
		draw_colored_polygon(pts, shard_color)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, shard_color.lightened(0.45), 1.8, true)
		draw_circle(Vector2.ZERO, s * 0.18, Color(1, 1, 1, 0.9))


class _Rock extends Node2D:
	var rock_color: Color = Color(0.72, 0.52, 0.32)
	var rock_size: float = 9.0
	var spin: float = 0.0
	func _process(d: float) -> void:
		spin += d * 10.0
		rotation = spin
		queue_redraw()
	func _draw() -> void:
		var s: float = rock_size
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(s, -s * 0.3), Vector2(s * 0.5, s),
			Vector2(-s * 0.6, s * 0.7), Vector2(-s, -s * 0.4),
			Vector2(-s * 0.2, -s),
		])
		draw_colored_polygon(pts, rock_color)
		var outline: PackedVector2Array = pts.duplicate()
		outline.append(pts[0])
		draw_polyline(outline, rock_color.darkened(0.45), 1.4, true)


class _Wisp extends Node2D:
	var wisp_color: Color = Color.WHITE
	var phase: float = 0.0
	func _process(d: float) -> void:
		phase += d * 7.0
		queue_redraw()
	func _draw() -> void:
		for i in 5:
			var off: Vector2 = Vector2(
				cos(phase + float(i)) * 6.0,
				sin(phase + float(i) * 1.3) * 6.0)
			var r: float = 6.0 - float(i) * 0.7
			var a: float = 0.55 - float(i) * 0.09
			draw_circle(off, max(r, 1.0),
					Color(wisp_color.r, wisp_color.g, wisp_color.b, a))


class _PoisonCloud extends Node2D:
	var cloud_color: Color = Color(0.45, 0.85, 0.35)
	var phase: float = 0.0
	func _process(d: float) -> void:
		phase += d * 3.0
		queue_redraw()
	func _draw() -> void:
		for i in 6:
			var a: float = phase + float(i) * 1.1
			var off: Vector2 = Vector2(cos(a) * 9.0, sin(a * 1.3) * 7.0)
			draw_circle(off, 6.0 + 0.8 * sin(phase + float(i)),
					Color(cloud_color.r, cloud_color.g, cloud_color.b, 0.45))


class _Bolt extends Node2D:
	var bolt_color: Color = Color(1.0, 0.95, 0.4)
	var points: PackedVector2Array = PackedVector2Array()
	var life: float = 0.28
	var age: float = 0.0
	func _process(d: float) -> void:
		age += d
		modulate.a = max(0.0, 1.0 - age / life)
		if age >= life:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		if points.size() < 2:
			return
		draw_polyline(points, bolt_color.lightened(0.5), 6.5, true)
		draw_polyline(points, bolt_color, 3.0, true)
		for p in points:
			draw_circle(p, 3.0, Color(1, 1, 1, 0.85))


class _Swirl extends Node2D:
	var swirl_color: Color = Color(0.8, 0.5, 1.0)
	var phase: float = 0.0
	var life: float = 0.50
	var age: float = 0.0
	func _process(d: float) -> void:
		age += d
		phase += d * 10.0
		modulate.a = max(0.0, 1.0 - age / life)
		if age >= life:
			queue_free()
			return
		queue_redraw()
	func _draw() -> void:
		var progress: float = age / life
		var r_outer: float = 28.0 * (1.0 - progress)
		for i in 14:
			var a: float = phase + float(i) * (TAU / 14.0)
			var r: float = r_outer * (0.6 + 0.4 * sin(phase + float(i)))
			var p: Vector2 = Vector2(cos(a), sin(a)) * r
			draw_circle(p, 3.2, swirl_color)


class _SkullGlyph extends Node2D:
	var glyph_color: Color = Color(0.55, 0.15, 0.7)
	var glyph_size: float = 11.0
	func _draw() -> void:
		var s: float = glyph_size
		draw_circle(Vector2.ZERO, s, glyph_color)
		draw_circle(Vector2(-s * 0.36, -s * 0.08), s * 0.22, Color(0, 0, 0, 0.9))
		draw_circle(Vector2(s * 0.36, -s * 0.08), s * 0.22, Color(0, 0, 0, 0.9))
		var jaw: Rect2 = Rect2(Vector2(-s * 0.5, s * 0.18), Vector2(s, s * 0.36))
		draw_rect(jaw, glyph_color.darkened(0.35))


class _Ring extends Node2D:
	var ring_color: Color = Color.WHITE
	var max_radius: float = 64.0
	var progress: float = 0.0
	var thickness: float = 3.5
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if progress <= 0.0:
			return
		draw_arc(Vector2.ZERO, max_radius * progress, 0.0, TAU, 40,
				ring_color, thickness, true)


class _FloatLabel extends Node2D:
	var label_text: String = ""
	var label_color: Color = Color.WHITE
	var label_size: int = 36
	func _draw() -> void:
		var f: Font = ThemeDB.fallback_font
		if f == null:
			return
		# Outline for legibility against any tile.
		draw_string_outline(f, Vector2.ZERO, label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, 4,
				Color(0, 0, 0, 0.9))
		draw_string(f, Vector2.ZERO, label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, label_size, label_color)


# ---- Primitives ---------------------------------------------------------

## Briefly tints a Node2D with a colour, then restores its original modulate.
static func flash(target: Node2D, color: Color, duration: float = 0.20) -> void:
	if not is_instance_valid(target):
		return
	var orig: Color = target.modulate
	target.modulate = color
	var tw: Tween = target.create_tween()
	tw.tween_interval(duration)
	tw.tween_callback(func():
		if is_instance_valid(target):
			target.modulate = orig)


## Floating damage / status text. Drifts upward and fades out. Size scales
## with the numeric value in `text` when it's numeric, so big hits pop.
static func float_text(layer: Node2D, world_px: Vector2,
		text: String, color: Color) -> void:
	var dmg_val: int = 0
	if text.is_valid_int():
		dmg_val = int(text)
	var lbl: _FloatLabel = _FloatLabel.new()
	lbl.label_text = text
	var tinted: Color = color
	if dmg_val >= 40:
		lbl.label_size = 64
		tinted = Color(1.0, 0.3, 0.25)
	elif dmg_val >= 20:
		lbl.label_size = 54
		tinted = Color(1.0, 0.55, 0.25)
	elif dmg_val >= 8:
		lbl.label_size = 46
	else:
		lbl.label_size = 38
	lbl.label_color = tinted
	lbl.position = world_px + Vector2(-12, -16)
	lbl.z_index = 100
	layer.add_child(lbl)
	var rise_px: float = 66.0 + clamp(float(dmg_val) * 1.2, 0.0, 40.0)
	var duration: float = 0.85
	var tw: Tween = lbl.create_tween()
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - rise_px,
			duration).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, duration) \
			.set_delay(duration * 0.35)
	tw.tween_callback(lbl.queue_free)


## Expanding ring centred at `world_px`. Multiple calls with `delay` create
## a ripple/shockwave sequence.
static func burst_ring(layer: Node2D, world_px: Vector2, radius_px: float,
		color: Color, delay: float = 0.0, thickness: float = 3.5) -> void:
	var ring: _Ring = _Ring.new()
	ring.ring_color = color
	ring.max_radius = radius_px
	ring.thickness = thickness
	ring.progress = 0.0
	ring.modulate.a = 0.9
	ring.position = world_px
	ring.z_index = 45
	layer.add_child(ring)
	var tw: Tween = ring.create_tween()
	if delay > 0.0:
		tw.tween_interval(delay)
	tw.tween_property(ring, "progress", 1.0, 0.38).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "modulate:a", 0.0, 0.38)
	tw.tween_callback(ring.queue_free)


## Scatter `count` small glowing dots outward from `center_px`.
static func _scatter_particles(layer: Node2D, center_px: Vector2, count: int,
		color: Color, spread_px: float, duration: float = 0.38) -> void:
	for i in count:
		var angle: float = TAU * float(i) / float(count) + randf_range(-0.25, 0.25)
		var dist: float = spread_px * randf_range(0.55, 1.0)
		var p: Node2D = Node2D.new()
		p.position = center_px
		p.z_index = 46
		layer.add_child(p)
		p.draw.connect(func():
			p.draw_circle(Vector2.ZERO, randf_range(2.0, 3.5), color))
		p.queue_redraw()
		var end_px: Vector2 = center_px + Vector2(cos(angle), sin(angle)) * dist
		var tw: Tween = p.create_tween()
		tw.parallel().tween_property(p, "position", end_px, duration).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, duration)
		tw.tween_callback(p.queue_free)


## Cold shatter — 6 radial shards fanning out.
static func _shatter(layer: Node2D, center_px: Vector2, color: Color) -> void:
	for i in 6:
		var angle: float = TAU * float(i) / 6.0 + randf_range(-0.2, 0.2)
		var shard: _IceShard = _IceShard.new()
		shard.shard_color = color
		shard.shard_size = 7.0
		shard.position = center_px
		shard.rotation = angle
		shard.z_index = 46
		layer.add_child(shard)
		var end_px: Vector2 = center_px + Vector2(cos(angle), sin(angle)) * 28.0
		var tw: Tween = shard.create_tween()
		tw.parallel().tween_property(shard, "position", end_px, 0.35).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(shard, "modulate:a", 0.0, 0.35)
		tw.tween_callback(shard.queue_free)


## Dust kick — earth impact.
static func _dust_kick(layer: Node2D, center_px: Vector2, color: Color) -> void:
	_scatter_particles(layer, center_px, 9, color.darkened(0.2), 26.0, 0.42)
	burst_ring(layer, center_px, 22.0, color.darkened(0.3), 0.0, 2.5)


## Smoke puff — necro impact.
static func _smoke_puff(layer: Node2D, center_px: Vector2, color: Color) -> void:
	for i in 4:
		var angle: float = randf_range(0.0, TAU)
		var p: Node2D = Node2D.new()
		p.position = center_px
		p.z_index = 47
		layer.add_child(p)
		var r: float = 9.0 + float(i) * 1.5
		p.draw.connect(func():
			p.draw_circle(Vector2.ZERO, r,
					Color(color.r, color.g, color.b, 0.35)))
		p.queue_redraw()
		var end_px: Vector2 = center_px + Vector2(cos(angle), sin(angle)) * 18.0
		var tw: Tween = p.create_tween()
		tw.parallel().tween_property(p, "position", end_px, 0.55).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(p, "modulate:a", 0.0, 0.55)
		tw.parallel().tween_property(p, "scale", Vector2(1.8, 1.8), 0.55)
		tw.tween_callback(p.queue_free)


# ---- School-specific projectile + impact --------------------------------

static func _shoot_projectile(layer: Node2D, from_px: Vector2, to_px: Vector2,
		proj: Node2D, color: Color, duration: float,
		ease_type: int, on_hit: Callable) -> void:
	proj.position = from_px
	proj.z_index = 50
	# Orient non-round projectiles (shards/rocks) toward travel direction.
	var heading: Vector2 = (to_px - from_px)
	if heading.length() > 0.01 and proj is _IceShard:
		proj.rotation = heading.angle()
	layer.add_child(proj)
	var tw: Tween = proj.create_tween()
	tw.tween_property(proj, "position", to_px, duration).set_ease(ease_type)
	tw.tween_callback(func():
		if on_hit.is_valid():
			on_hit.call()
		proj.queue_free())


static func _cast_fire_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var fb: _FireBall = _FireBall.new()
	fb.ball_color = color
	fb.ball_radius = 9.0
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 440.0, 0.10, 0.28)
	_shoot_projectile(layer, from_px, t_pos, fb, color, dur, Tween.EASE_OUT, func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.4))
		burst_ring(layer, t_pos, 22.0, color, 0.0, 3.0)
		_scatter_particles(layer, t_pos, 10, color.lightened(0.25), 30.0, 0.40)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


static func _cast_cold_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var shard: _IceShard = _IceShard.new()
	shard.shard_color = color
	shard.shard_size = 11.0
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 500.0, 0.09, 0.24)
	_shoot_projectile(layer, from_px, t_pos, shard, color, dur, Tween.EASE_IN_OUT, func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.35))
		_shatter(layer, t_pos, color)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


static func _cast_air_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	# Instant zigzag bolt — no travel time.
	var bolt: _Bolt = _Bolt.new()
	bolt.bolt_color = color
	var dir: Vector2 = (t_pos - from_px).normalized() if from_px != t_pos else Vector2.RIGHT
	var perp: Vector2 = Vector2(-dir.y, dir.x)
	var steps: int = 5
	var pts: PackedVector2Array = PackedVector2Array()
	pts.append(from_px)
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var mid: Vector2 = from_px.lerp(t_pos, t) + perp * randf_range(-10.0, 10.0)
		pts.append(mid)
	pts.append(t_pos)
	bolt.points = pts
	layer.add_child(bolt)
	if is_instance_valid(target):
		flash(target, color.lightened(0.5))
	burst_ring(layer, t_pos, 18.0, color, 0.02, 2.5)
	float_text(layer, t_pos + Vector2(0, -16), str(dmg), color)


static func _cast_earth_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var rock: _Rock = _Rock.new()
	rock.rock_color = color
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 380.0, 0.14, 0.34)
	_shoot_projectile(layer, from_px, t_pos, rock, color, dur, Tween.EASE_IN, func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.2))
		_dust_kick(layer, t_pos, color)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


static func _cast_necro_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var wisp: _Wisp = _Wisp.new()
	wisp.wisp_color = color
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 420.0, 0.12, 0.30)
	_shoot_projectile(layer, from_px, t_pos, wisp, color, dur, Tween.EASE_OUT, func():
		if is_instance_valid(target):
			flash(target, color.darkened(0.2))
		var sk: _SkullGlyph = _SkullGlyph.new()
		sk.glyph_color = color
		sk.position = t_pos
		sk.z_index = 48
		layer.add_child(sk)
		var tw: Tween = sk.create_tween()
		tw.tween_property(sk, "scale", Vector2(1.4, 1.4), 0.25).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(sk, "modulate:a", 0.0, 0.35).set_delay(0.10)
		tw.tween_callback(sk.queue_free)
		_smoke_puff(layer, t_pos, color)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


static func _cast_poison_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var cloud: _PoisonCloud = _PoisonCloud.new()
	cloud.cloud_color = color
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 420.0, 0.11, 0.28)
	_shoot_projectile(layer, from_px, t_pos, cloud, color, dur, Tween.EASE_OUT, func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.25))
		var lingering: _PoisonCloud = _PoisonCloud.new()
		lingering.cloud_color = color
		lingering.position = t_pos
		lingering.z_index = 44
		layer.add_child(lingering)
		var tw: Tween = lingering.create_tween()
		tw.tween_interval(0.6)
		tw.tween_property(lingering, "modulate:a", 0.0, 0.4)
		tw.tween_callback(lingering.queue_free)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


static func _cast_conj_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	var dart: Node2D = Node2D.new()
	dart.z_index = 50
	dart.position = from_px
	# Draw a small 4-point star.
	dart.draw.connect(func():
		var s: float = 7.0
		var pts: PackedVector2Array = PackedVector2Array([
			Vector2(s, 0), Vector2(s * 0.3, s * 0.3),
			Vector2(0, s), Vector2(-s * 0.3, s * 0.3),
			Vector2(-s, 0), Vector2(-s * 0.3, -s * 0.3),
			Vector2(0, -s), Vector2(s * 0.3, -s * 0.3),
		])
		dart.draw_colored_polygon(pts, color)
		dart.draw_circle(Vector2.ZERO, s * 0.35, Color(1, 1, 1, 0.9)))
	dart.queue_redraw()
	var heading: Vector2 = (t_pos - from_px)
	if heading.length() > 0.01:
		dart.rotation = heading.angle()
	layer.add_child(dart)
	var dist: float = from_px.distance_to(t_pos)
	var dur: float = clamp(dist / 460.0, 0.09, 0.24)
	var tw: Tween = dart.create_tween()
	tw.tween_property(dart, "position", t_pos, dur)
	tw.tween_callback(func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.4))
		_scatter_particles(layer, t_pos, 6, color.lightened(0.2), 22.0, 0.30)
		burst_ring(layer, t_pos, 14.0, color, 0.0, 2.2)
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color)
		dart.queue_free())


# ---- Public API ---------------------------------------------------------

## Resolve a spell's visual colour — prefers the school palette, falls back
## to `provided` (for legacy call sites passing a spell-specific colour).
static func _resolve_color(school: String, provided: Color) -> Color:
	if SCHOOL_COLOR.has(school):
		return SCHOOL_COLOR[school]
	return provided


## Single-target cast. Dispatches to a school-specific visual; passing
## school="" keeps the old generic ball + flash + damage label.
static func cast_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color, school: String = "") -> void:
	var c: Color = _resolve_color(school, color)
	match school:
		"fire":           _cast_fire_single(layer, from_px, target, dmg, c)
		"cold":           _cast_cold_single(layer, from_px, target, dmg, c)
		"air":            _cast_air_single(layer, from_px, target, dmg, c)
		"earth":          _cast_earth_single(layer, from_px, target, dmg, c)
		"necromancy":     _cast_necro_single(layer, from_px, target, dmg, c)
		"poison":         _cast_poison_single(layer, from_px, target, dmg, c)
		"conjurations":   _cast_conj_single(layer, from_px, target, dmg, c)
		_:                _cast_conj_single(layer, from_px, target, dmg, c)


## Area cast — projectile to epicentre, then school-flavored explosion plus
## per-tile flashes.
static func cast_area(layer: Node2D, from_px: Vector2, center_px: Vector2,
		hit_positions: Array, color: Color, tile_radius_px: float,
		school: String = "") -> void:
	var c: Color = _resolve_color(school, color)
	# Pick a projectile matching the school; fallback = generic conj dart.
	var proj: Node2D
	match school:
		"fire":
			var fb: _FireBall = _FireBall.new()
			fb.ball_color = c
			fb.ball_radius = 11.0
			proj = fb
		"cold":
			var sh: _IceShard = _IceShard.new()
			sh.shard_color = c
			sh.shard_size = 12.0
			proj = sh
		"earth":
			var rk: _Rock = _Rock.new()
			rk.rock_color = c
			rk.rock_size = 10.0
			proj = rk
		"poison":
			var pc: _PoisonCloud = _PoisonCloud.new()
			pc.cloud_color = c
			proj = pc
		"necromancy":
			var wp: _Wisp = _Wisp.new()
			wp.wisp_color = c
			proj = wp
		_:
			var n: Node2D = Node2D.new()
			n.draw.connect(func():
				n.draw_circle(Vector2.ZERO, 9.0, c)
				n.draw_circle(Vector2.ZERO, 4.5, Color(1, 1, 1, 0.9)))
			n.queue_redraw()
			proj = n

	var dist: float = from_px.distance_to(center_px)
	var dur: float = clamp(dist / 440.0, 0.10, 0.30)
	_shoot_projectile(layer, from_px, center_px, proj, c, dur, Tween.EASE_OUT, func():
		# Layered explosion rings.
		burst_ring(layer, center_px, tile_radius_px, c, 0.0, 4.0)
		burst_ring(layer, center_px, tile_radius_px * 1.4,
				c.darkened(0.25), 0.08, 2.5)
		# School-specific secondary effect at epicentre.
		match school:
			"fire":  _scatter_particles(layer, center_px, 16,
					c.lightened(0.2), tile_radius_px * 0.8, 0.48)
			"cold":  _shatter(layer, center_px, c)
			"earth": _dust_kick(layer, center_px, c)
			"poison":
				# Leave a lingering cloud.
				var linger: _PoisonCloud = _PoisonCloud.new()
				linger.cloud_color = c
				linger.position = center_px
				linger.z_index = 44
				layer.add_child(linger)
				var ltw: Tween = linger.create_tween()
				ltw.tween_interval(0.8)
				ltw.tween_property(linger, "modulate:a", 0.0, 0.5)
				ltw.tween_callback(linger.queue_free)
			"necromancy": _smoke_puff(layer, center_px, c)
			_: _scatter_particles(layer, center_px, 12,
					c.lightened(0.2), tile_radius_px * 0.7, 0.38)
		# Per-tile flash on each hit.
		for pos in hit_positions:
			var ring2: _Ring = _Ring.new()
			ring2.ring_color = c
			ring2.max_radius = tile_radius_px * 0.45
			ring2.progress = 0.0
			ring2.modulate.a = 0.7
			ring2.position = pos
			ring2.z_index = 44
			layer.add_child(ring2)
			var tw2: Tween = ring2.create_tween()
			tw2.tween_interval(0.04)
			tw2.tween_property(ring2, "progress", 1.0, 0.28)
			tw2.parallel().tween_property(ring2, "modulate:a", 0.0, 0.28)
			tw2.tween_callback(ring2.queue_free))


## Status effect cast — no projectile, visuals sit on the target. Used for
## slow / confuse / petrify / hex-school spells. `label` goes above target
## (e.g. "SLOW", "HEX").
static func cast_status(layer: Node2D, target_px: Vector2, color: Color,
		school: String = "", label: String = "") -> void:
	var c: Color = _resolve_color(school, color)
	if school == "hexes":
		# Two counter-rotating rune rings.
		for i in 3:
			burst_ring(layer, target_px, 24.0 + float(i) * 14.0, c,
					float(i) * 0.10, 3.0)
		# Sparkle dots orbiting briefly.
		_scatter_particles(layer, target_px, 10, c.lightened(0.3), 16.0, 0.42)
	else:
		# Generic slow ripple (3 rings).
		for i in 3:
			burst_ring(layer, target_px, 28.0 + float(i) * 14.0, c,
					float(i) * 0.12, 3.0)
	if label != "":
		float_text(layer, target_px + Vector2(0, -20), label, c)


## Teleport / blink visual — bright swirl at origin and destination.
static func cast_teleport(layer: Node2D, old_px: Vector2, new_px: Vector2,
		color: Color = Color(0.75, 0.5, 1.0)) -> void:
	var c: Color = color
	# Departure swirl.
	var sw1: _Swirl = _Swirl.new()
	sw1.swirl_color = c
	sw1.position = old_px
	sw1.z_index = 48
	layer.add_child(sw1)
	burst_ring(layer, old_px, 36.0, Color(1, 1, 1, 0.9), 0.0, 3.0)
	float_text(layer, old_px + Vector2(0, -20), "BLINK", c)
	# Arrival swirl — slight delay so visuals don't overlap.
	var dummy: Node2D = Node2D.new()
	layer.add_child(dummy)
	var tw: Tween = dummy.create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(func():
		var sw2: _Swirl = _Swirl.new()
		sw2.swirl_color = c
		sw2.position = new_px
		sw2.z_index = 48
		layer.add_child(sw2)
		burst_ring(layer, new_px, 36.0, c, 0.0, 3.0)
		dummy.queue_free())


# ---- Legacy shims -------------------------------------------------------
# Older call sites that don't pass a school still work; they go through the
# generic conjuration visual.

static func cast_slow(layer: Node2D, target_px: Vector2, color: Color) -> void:
	cast_status(layer, target_px, color, "", "SLOW")


static func cast_blink(layer: Node2D, old_px: Vector2, new_px: Vector2) -> void:
	cast_teleport(layer, old_px, new_px)


## Fires a coloured orb from `from_px` to `to_px`. Retained for call sites
## that just want a generic projectile without damage reporting.
static func shoot(layer: Node2D, from_px: Vector2, to_px: Vector2,
		color: Color, on_hit: Callable = Callable()) -> void:
	var ball: Node2D = Node2D.new()
	ball.position = from_px
	ball.z_index = 50
	layer.add_child(ball)
	ball.draw.connect(func():
		ball.draw_circle(Vector2.ZERO, 9.0, color)
		ball.draw_circle(Vector2.ZERO, 3.8, Color(1, 1, 1, 0.85)))
	ball.queue_redraw()
	var dist: float = from_px.distance_to(to_px)
	var dur: float = clamp(dist / 480.0, 0.10, 0.28)
	var tw: Tween = ball.create_tween()
	tw.tween_property(ball, "position", to_px, dur)
	tw.tween_callback(func():
		if on_hit.is_valid():
			on_hit.call()
		ball.queue_free())
