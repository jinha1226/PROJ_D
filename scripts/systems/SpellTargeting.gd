extends Node
class_name SpellTargeting

# Phase 0 extraction from Game.gd. Hosts spell targeting flow
# (begin/cancel/confirm) and AOE application helpers.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node

func apply_fear_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	var n: int = AoeEffects.apply_fear(host, origin, radius, turns)
	if n == 0:
		CombatLog.post(LocaleManager.t("LOG_NOTHING_NEARBY_TO_FRIGHTEN"), Color(0.7, 0.7, 0.75))

func apply_fog_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	AoeEffects.apply_fog(host, origin, radius, turns)

func apply_silence_aoe(origin: Vector2i, radius: int, turns: int) -> void:
	var n: int = AoeEffects.apply_silence(host, origin, radius, turns)
	if n == 0:
		CombatLog.post(LocaleManager.t("LOG_THE_SILENCE_FINDS_NO_VOICES"), Color(0.7, 0.75, 0.85))

func alert_all_monsters() -> void:
	var origin: Vector2i = host.player.grid_pos if host.player != null else Vector2i.ZERO
	AoeEffects.alert_all(host, origin)

func dig_toward(target: Vector2i) -> void:
	var carved: int = AoeEffects.dig_line(host, target, 4)
	if carved == 0:
		CombatLog.post(LocaleManager.t("LOG_THE_WAND_FINDS_NO_WALL"), Color(0.7, 0.7, 0.7))
	else:
		CombatLog.post(LocaleManager.t("LOG_THE_WAND_CARVES_THROUGH_TILE") \
				% [carved, "" if carved == 1 else "s"], Color(0.85, 0.75, 0.5))

func apply_immolation_aoe(origin: Vector2i, radius: int) -> void:
	if host.map == null:
		return
	CombatLog.post(LocaleManager.t("LOG_THE_SCROLL_IGNITES_IN_A"), Color(1.0, 0.55, 0.1))
	var visible: Dictionary = host.player.compute_fov() if host.player != null else {}
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			var pos := origin + Vector2i(dx, dy)
			if not host.map.in_bounds(pos) or host.map.tile_at(pos) == host.map.Tile.WALL:
				continue
			host.map.add_cloud(pos, "fire", 5)
	# Damage all visible monsters in radius
	for n in host.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		var d: int = max(abs(n.grid_pos.x - origin.x), abs(n.grid_pos.y - origin.y))
		if d <= radius and visible.has(n.grid_pos):
			var dmg: int = randi_range(8, 16)
			n.take_damage(dmg)
			n.become_aware(origin)

func begin_spell_targeting(spell: SpellData, p: Player) -> void:
	_cancel_targeting()
	host._targeting_spell = spell
	var visible: Dictionary = p.compute_fov()
	var range_val: int = MagicSystem.effective_spell_range(spell)
	host._targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - p.grid_pos.x), abs(tile.y - p.grid_pos.y))
		if d > 0 and d <= range_val:
			host._targeting_tiles.append(tile)
	host._targeting_node = SpellTargetOverlay.new()
	host._effect_layer.add_child(host._targeting_node)
	host._targeting_node.init(spell, p, host._targeting_tiles)
	CombatLog.post(LocaleManager.t("LOG_TAP_HIGHLIGHTED_TILE_TO_CAST") \
			% spell.display_name, Color(0.8, 0.75, 1.0))

## Two-step targeting for single/auto/nearest spells: auto-selects nearest monster,
## highlights it, requires a second tap on it to confirm the cast.
func begin_spell_targeting_auto(spell: SpellData, p: Player) -> void:
	_cancel_targeting()
	var range_val: int = MagicSystem.effective_spell_range(spell)
	var visible: Dictionary = p.compute_fov()
	host._targeting_tiles = []
	for tile: Vector2i in visible.keys():
		var d: int = max(abs(tile.x - p.grid_pos.x), abs(tile.y - p.grid_pos.y))
		if d > 0 and d <= range_val:
			host._targeting_tiles.append(tile)
	# Find nearest non-ally visible monster in range
	var best: Monster = null
	var best_d: int = range_val + 1
	for n in host.get_tree().get_nodes_in_group("monsters"):
		if not (n is Monster) or n.is_ally:
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - p.grid_pos.x), abs(n.grid_pos.y - p.grid_pos.y))
		if d <= range_val and d < best_d:
			best_d = d
			best = n
	if best == null:
		CombatLog.post(LocaleManager.t("LOG_NO_TARGETS_IN_RANGE"), Color(0.75, 0.75, 0.75))
		return
	host._targeting_spell = spell
	host._targeting_monster = best
	host._targeting_node = SpellTargetOverlay.new()
	host._effect_layer.add_child(host._targeting_node)
	host._targeting_node.init(spell, p, host._targeting_tiles)
	host._targeting_node.set_target(best.grid_pos)
	CombatLog.post(LocaleManager.t("LOG_TAP_THE_TO_CAST_TAP") \
			% [best.data.display_name, spell.display_name], Color(0.8, 0.75, 1.0))

func _cancel_targeting() -> void:
	host._targeting_spell = null
	host._targeting_tiles = []
	host._targeting_monster = null
	if host._targeting_node != null:
		host._targeting_node.queue_free()
		host._targeting_node = null

func _confirm_targeting() -> void:
	var spell := host._targeting_spell
	_cancel_targeting()
	var ok: bool = MagicSystem.cast(spell.id, host.player, host)
	if ok:
		TurnManager.end_player_turn()
