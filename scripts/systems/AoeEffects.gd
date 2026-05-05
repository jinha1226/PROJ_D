class_name AoeEffects extends RefCounted

## Static helpers for area-of-effect scroll/wand effects. Keeps Game.gd thin —
## the bridge methods on Game.gd just forward to these. Player.use_item duck-
## type-checks for Game.gd methods, so the bridge methods stay there.

## Apply "feared" status to every visible monster within `radius` of `origin`.
## Returns the number of monsters affected.
static func apply_fear(game, origin: Vector2i, radius: int, turns: int) -> int:
	if game == null or game.player == null or game.map == null:
		return 0
	var visible: Dictionary = game.player.compute_fov()
	var count: int = 0
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		var d: int = max(absi(n.grid_pos.x - origin.x), absi(n.grid_pos.y - origin.y))
		if d > radius or not visible.has(n.grid_pos):
			continue
		Status.apply(n, "feared", turns)
		count += 1
	return count

## Spread fog across walkable tiles within `radius` of `origin`. Wraps
## DungeonMap.add_fog so callers don't reach into the map module directly.
static func apply_fog(game, origin: Vector2i, radius: int, turns: int) -> void:
	if game == null or game.map == null:
		return
	game.map.add_fog(origin, radius, turns)

## Apply "silence" status to visible hostile monsters in radius.
## Visible-state effect for now (status registers in Status.INFO). Hooking it
## into monster ability/spell gating belongs to a follow-up.
static func apply_silence(game, origin: Vector2i, radius: int, turns: int) -> int:
	if game == null or game.player == null:
		return 0
	var visible: Dictionary = game.player.compute_fov()
	var count: int = 0
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		var d: int = max(absi(n.grid_pos.x - origin.x), absi(n.grid_pos.y - origin.y))
		if d > radius or not visible.has(n.grid_pos):
			continue
		Status.apply(n, "silence", turns)
		count += 1
	return count

## Wake every monster on the floor and point them at `origin` (the player).
static func alert_all(game, origin: Vector2i) -> int:
	if game == null:
		return 0
	var count: int = 0
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		if n.has_method("become_aware"):
			n.become_aware(origin)
			count += 1
	return count

## Carve a short tunnel from the player toward `target`. Converts the next
## wall tiles along the cardinal step into floor, up to `length` tiles.
## Stops when it hits an out-of-bounds tile or a non-wall tile after the run.
static func dig_line(game, target: Vector2i, length: int = 4) -> int:
	if game == null or game.map == null or game.player == null:
		return 0
	var from: Vector2i = game.player.grid_pos
	var dx: int = signi(target.x - from.x)
	var dy: int = signi(target.y - from.y)
	if dx == 0 and dy == 0:
		return 0
	var carved: int = 0
	var p: Vector2i = from + Vector2i(dx, dy)
	for _i in length:
		if not game.map.in_bounds(p):
			break
		if game.map.tile_at(p) == game.map.Tile.WALL:
			game.map.set_tile(p, game.map.Tile.FLOOR)
			carved += 1
		p += Vector2i(dx, dy)
	return carved
