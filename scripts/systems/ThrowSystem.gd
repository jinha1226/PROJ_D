class_name ThrowSystem extends RefCounted

const THROW_RANGE: int = 6

## Trace a line from `from` toward `to` using Bresenham, stopping at the first
## wall or the range limit. Returns the landing tile (may equal `from` + 1 if
## immediately blocked). Does NOT stop on monsters — monsters are hit at the
## landing tile after this call.
static func trace_line(from: Vector2i, to: Vector2i, map: DungeonMap) -> Vector2i:
	var dx: int = to.x - from.x
	var dy: int = to.y - from.y
	var steps: int = maxi(abs(dx), abs(dy))
	if steps == 0:
		return from
	steps = mini(steps, THROW_RANGE)
	var last_open: Vector2i = from
	for i in range(1, steps + 1):
		var px: int = from.x + int(round(float(dx) * i / float(maxi(abs(dx), abs(dy)))))
		var py: int = from.y + int(round(float(dy) * i / float(maxi(abs(dx), abs(dy)))))
		var p := Vector2i(px, py)
		if not map.in_bounds(p) or map.tile_at(p) == DungeonMap.Tile.WALL:
			break
		last_open = p
	return last_open

## Find the first monster at or between `from` (exclusive) and `landing` (inclusive).
static func first_monster_on_path(from: Vector2i, landing: Vector2i, game: Node) -> Monster:
	var dx: int = landing.x - from.x
	var dy: int = landing.y - from.y
	var steps: int = maxi(abs(dx), abs(dy))
	if steps == 0:
		return null
	for i in range(1, steps + 1):
		var px: int = from.x + int(round(float(dx) * i / float(steps)))
		var py: int = from.y + int(round(float(dy) * i / float(steps)))
		var p := Vector2i(px, py)
		for n in game.get_tree().get_nodes_in_group("monsters"):
			if n is Monster and n.grid_pos == p:
				return n
	return null

## Main entry point. Resolves a throw: removes item, traces line, hits monster or
## applies splash effect at landing tile.
static func resolve(entry: Dictionary, target: Vector2i, player: Player, game: Node) -> void:
	var item_id: String = String(entry.get("id", ""))
	var data: ItemData = ItemRegistry.get_by_id(item_id) if ItemRegistry != null else null
	if data == null:
		return

	# Consume one from stack (or remove if count == 1).
	player.remove_thrown_item(entry)

	# Identify on throw (same as use).
	if GameManager != null:
		GameManager.identify_item(item_id)

	var map: DungeonMap = game.map if "map" in game else null
	if map == null:
		return

	var landing: Vector2i = trace_line(player.grid_pos, target, map)
	var hit_monster: Monster = first_monster_on_path(player.grid_pos, landing, game)
	var impact: Vector2i = hit_monster.grid_pos if hit_monster != null else landing

	CombatLog.post("You throw the %s." % data.display_name, Color(0.85, 0.85, 0.6))

	match data.kind:
		"throwing":
			_resolve_weapon(data, player, hit_monster, impact, game)
		"potion":
			_resolve_potion(data, hit_monster, impact, game)

## ── Weapon throws ─────────────────────────────────────────────────────────────

static func _resolve_weapon(data: ItemData, player: Player,
		hit: Monster, impact: Vector2i, game: Node) -> void:
	match data.effect:
		"throw_pierce", "throw_heavy":
			if hit != null:
				var base: int = maxi(1, data.damage)
				var bonus: int = player.get_skill_level("archery") / 2
				var dmg: int = randi_range(base, base + bonus)
				hit.take_damage(dmg)
				hit.become_aware(player.grid_pos)
				CombatLog.post("The %s hits the %s for %d." % [data.display_name, hit.data.display_name, dmg],
					Color(1.0, 0.7, 0.5))
			else:
				CombatLog.post("The %s clatters to the ground." % data.display_name, Color(0.7, 0.7, 0.7))
		"throw_fire_aoe":
			game.map.add_cloud(impact, "fire", 4)
			_splash_aoe(impact, 1, game, func(m: Monster):
				m.take_damage(randi_range(6, 12))
				m.become_aware(player.grid_pos))
			CombatLog.post("The bomb explodes in flames!", Color(1.0, 0.5, 0.2))
		"throw_poison":
			_splash_cloud(impact, 1, "poison", 6, game)
			CombatLog.post("The flask shatters, releasing a toxic cloud.", Color(0.5, 1.0, 0.4))
		"throw_smoke":
			_splash_cloud(impact, 2, "fog", 8, game)
			CombatLog.post("A cloud of smoke billows out.", Color(0.7, 0.7, 0.85))

## ── Potion throws ─────────────────────────────────────────────────────────────

static func _resolve_potion(data: ItemData, hit: Monster,
		impact: Vector2i, game: Node) -> void:
	match data.effect:
		"heal":
			# Healing potion heals the monster — throw carefully.
			if hit != null:
				var heal: int = data.effect_value
				hit.hp = mini(hit.hp_max, hit.hp + heal)
				CombatLog.post("The potion splashes on the %s, healing it!" % hit.data.display_name,
					Color(0.4, 1.0, 0.5))
			else:
				CombatLog.post("The potion shatters harmlessly.", Color(0.7, 0.7, 0.7))
		"restore_mp":
			CombatLog.post("The potion shatters harmlessly.", Color(0.7, 0.7, 0.7))
		"haste":
			if hit != null:
				Status.apply(hit, "haste", data.effect_value)
				CombatLog.post("The potion splashes on the %s — it speeds up!" % hit.data.display_name,
					Color(1.0, 0.8, 0.3))
		"might":
			if hit != null:
				Status.apply(hit, "might", data.effect_value)
				CombatLog.post("The potion splashes on the %s — it grows stronger!" % hit.data.display_name,
					Color(1.0, 0.5, 0.3))
		"berserk":
			if hit != null:
				Status.apply(hit, "berserk", data.effect_value)
				CombatLog.post("The %s flies into a rage!" % hit.data.display_name, Color(1.0, 0.3, 0.3))
		"invisible":
			if hit != null:
				Status.apply(hit, "invisible", data.effect_value)
				CombatLog.post("The %s fades from sight!" % hit.data.display_name, Color(0.7, 0.7, 1.0))
		"drink_poison":
			_splash_cloud(impact, 1, "poison", 5, game)
			if hit != null:
				Status.apply(hit, "poison", 5)
			CombatLog.post("Poison sprays across the ground!", Color(0.4, 1.0, 0.3))
		"drink_confusion":
			if hit != null:
				Status.apply(hit, "confusion", data.effect_value)
				CombatLog.post("The %s looks dazed!" % hit.data.display_name, Color(0.8, 0.6, 1.0))
			else:
				CombatLog.post("The potion shatters, confusion wafting through the air.", Color(0.7, 0.7, 0.7))
		"drink_degeneration":
			if hit != null:
				Status.apply(hit, "weak", data.effect_value)
				CombatLog.post("The %s looks weakened." % hit.data.display_name, Color(0.7, 0.8, 0.5))
		"drink_paralysis":
			if hit != null:
				Status.apply(hit, "paralyzed", data.effect_value)
				CombatLog.post("The %s is paralyzed!" % hit.data.display_name, Color(0.9, 0.9, 0.5))
		"drink_toxic_gas":
			_splash_cloud(impact, 2, "poison", 8, game)
			CombatLog.post("Toxic gas floods the area!", Color(0.3, 1.0, 0.3))
		"drink_liquid_flame":
			_splash_cloud(impact, 1, "fire", 6, game)
			_splash_aoe(impact, 1, game, func(m: Monster):
				m.take_damage(randi_range(4, 8))
				Status.apply(m, "burning", 4))
			CombatLog.post("Liquid flame splashes everywhere!", Color(1.0, 0.45, 0.1))
		"resistance", "cure":
			CombatLog.post("The potion shatters without effect.", Color(0.7, 0.7, 0.7))

## ── Helpers ───────────────────────────────────────────────────────────────────

static func _splash_cloud(center: Vector2i, radius: int,
		cloud_type: String, turns: int, game: Node) -> void:
	var map: DungeonMap = game.map if "map" in game else null
	if map == null:
		return
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var p := center + Vector2i(dx, dy)
			if map.in_bounds(p) and map.tile_at(p) != DungeonMap.Tile.WALL:
				map.add_cloud(p, cloud_type, turns)

static func _splash_aoe(center: Vector2i, radius: int, game: Node,
		cb: Callable) -> void:
	for n in game.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		var d: int = max(abs(n.grid_pos.x - center.x), abs(n.grid_pos.y - center.y))
		if d <= radius:
			cb.call(n)
