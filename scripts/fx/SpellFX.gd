class_name SpellFX
## Purely-static visual effects factory for spell casting.
## All methods create short-lived Node2D children on `layer` (EntityLayer).
## Damage is applied by the caller; effects are cosmetic-only.

# ---- Inner drawable nodes ------------------------------------------------

class _Ball extends Node2D:
	var ball_color: Color = Color.WHITE
	var ball_radius: float = 9.0
	func _draw() -> void:
		draw_circle(Vector2.ZERO, ball_radius, ball_color)
		draw_circle(Vector2.ZERO, ball_radius * 0.42, Color(1, 1, 1, 0.8))


class _Ring extends Node2D:
	var ring_color: Color = Color.WHITE
	var max_radius: float = 64.0
	var progress: float = 0.0
	func _process(_d: float) -> void:
		queue_redraw()
	func _draw() -> void:
		if progress <= 0.0:
			return
		draw_arc(Vector2.ZERO, max_radius * progress, 0.0, TAU, 40,
				ring_color, 3.5, true)


class _FloatLabel extends Node2D:
	var label_text: String = ""
	var label_color: Color = Color.WHITE
	func _draw() -> void:
		var f: Font = ThemeDB.fallback_font
		if f == null:
			return
		draw_string(f, Vector2.ZERO, label_text,
				HORIZONTAL_ALIGNMENT_LEFT, -1, 13, label_color)


# ---- Public API ----------------------------------------------------------

## Fires a coloured orb from `from_px` to `to_px` (world/entity-layer coords).
## Calls `on_hit` when the ball reaches the target.
static func shoot(layer: Node2D, from_px: Vector2, to_px: Vector2,
		color: Color, on_hit: Callable = Callable()) -> void:
	var ball := _Ball.new()
	ball.ball_color = color
	ball.position = from_px
	ball.z_index = 50
	layer.add_child(ball)
	var dist: float = from_px.distance_to(to_px)
	var dur: float = clamp(dist / 480.0, 0.10, 0.28)
	var tw: Tween = ball.create_tween()
	tw.tween_property(ball, "position", to_px, dur)
	tw.tween_callback(func():
		if on_hit.is_valid():
			on_hit.call()
		ball.queue_free())


## Expanding ring centred at `world_px`. Multiple calls with `delay` create
## a ripple/shockwave sequence.
static func burst_ring(layer: Node2D, world_px: Vector2, radius_px: float,
		color: Color, delay: float = 0.0) -> void:
	var ring := _Ring.new()
	ring.ring_color = color
	ring.max_radius = radius_px
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


## Floating damage / status text. Drifts upward and fades out.
static func float_text(layer: Node2D, world_px: Vector2,
		text: String, color: Color) -> void:
	var lbl := _FloatLabel.new()
	lbl.label_text = text
	lbl.label_color = color
	lbl.position = world_px + Vector2(-10, -12)
	lbl.z_index = 100
	layer.add_child(lbl)
	var tw: Tween = lbl.create_tween()
	tw.parallel().tween_property(lbl, "position:y", lbl.position.y - 52, 0.70)
	tw.parallel().tween_property(lbl, "modulate:a", 0.0, 0.70).set_delay(0.18)
	tw.tween_callback(lbl.queue_free)


## Convenience: shoot → on arrival flash target + show damage label.
static func cast_single(layer: Node2D, from_px: Vector2, target: Node2D,
		dmg: int, color: Color) -> void:
	var t_pos: Vector2 = target.position if is_instance_valid(target) else from_px
	shoot(layer, from_px, t_pos, color, func():
		if is_instance_valid(target):
			flash(target, color.lightened(0.35))
		float_text(layer, t_pos + Vector2(0, -16), str(dmg), color))


## Convenience: shoot to epicentre, then rings + flashes for all hit positions.
static func cast_area(layer: Node2D, from_px: Vector2, center_px: Vector2,
		hit_positions: Array, color: Color, tile_radius_px: float) -> void:
	shoot(layer, from_px, center_px, color, func():
		# Expanding ring at epicentre.
		burst_ring(layer, center_px, tile_radius_px, color, 0.0)
		burst_ring(layer, center_px, tile_radius_px * 1.4, color.darkened(0.3), 0.08)
		# Flash each hit position briefly.
		for pos in hit_positions:
			var ring2 := _Ring.new()
			ring2.ring_color = color
			ring2.max_radius = tile_radius_px * 0.5
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


## Ripple rings for slow/hex effect (no projectile, effect is on target).
static func cast_slow(layer: Node2D, target_px: Vector2, color: Color) -> void:
	for i in 3:
		burst_ring(layer, target_px, 28.0 + i * 14.0, color, float(i) * 0.12)
	float_text(layer, target_px + Vector2(0, -20), "SLOW", color)


## Blink: white burst at old pos, purple burst at new pos.
static func cast_blink(layer: Node2D, old_px: Vector2, new_px: Vector2) -> void:
	var white := Color(1, 1, 1, 0.9)
	var purple := Color(0.75, 0.4, 1.0, 0.9)
	burst_ring(layer, old_px, 40.0, white, 0.0)
	float_text(layer, old_px + Vector2(0, -20), "BLINK", purple)
	# Slight delay so arrival burst appears after departure.
	var dummy := Node2D.new()
	layer.add_child(dummy)
	var tw: Tween = dummy.create_tween()
	tw.tween_interval(0.15)
	tw.tween_callback(func():
		burst_ring(layer, new_px, 40.0, purple, 0.0)
		dummy.queue_free())
