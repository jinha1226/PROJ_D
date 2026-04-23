class_name MagicSystem extends RefCounted

## Self-targeted / auto-target spells per guide §4.7. MVP roster: 3
## spells covering the three canonical shapes (damage bolt / self heal
## / self blink). Full targeting UI + area spells arrive with the
## targeting system milestone.

static func cast(spell_id: String, player: Player, game: Node) -> bool:
	var spell: SpellData = SpellRegistry.get_by_id(spell_id)
	if spell == null:
		return false
	if player.mp < spell.mp_cost:
		CombatLog.post("Not enough MP for %s." % spell.display_name,
			Color(1.0, 0.7, 0.5))
		return false
	var power: int = _compute_power(player, spell)
	var fizzle: bool = _roll_fizzle(player, spell)
	player.mp = max(0, player.mp - spell.mp_cost)
	player.grant_skill_xp("magic", float(spell.mp_cost))
	player.emit_signal("stats_changed")
	if fizzle:
		CombatLog.post("Your %s fizzles." % spell.display_name,
			Color(0.7, 0.6, 0.9))
		return true
	match spell.effect:
		"heal":
			var amt: int = 12 + power / 2
			player.heal(amt)
			CombatLog.post("You cast %s. (+%d HP)" % [spell.display_name, amt],
				Color(0.6, 1.0, 0.6))
			if game != null and game.has_method("spawn_damage_number"):
				game.spawn_damage_number(player.position, amt, Color(0.4, 1.0, 0.5))
		"blink":
			player._blink(max(2, spell.max_range))
			CombatLog.post("You cast %s." % spell.display_name,
				Color(0.7, 0.85, 1.0))
		"damage":
			_damage_auto_target(spell, player, power, game)
		"multi_damage":
			_multi_damage(spell, player, power, game, 3)
		"aoe_damage":
			_aoe_damage(spell, player, power, game)
	return true

static func _compute_power(player: Player, spell: SpellData) -> int:
	# §4.7 curve: magic_skill * INT / 10 + INT baseline.
	var skill: int = player.get_skill_level("magic")
	return int(player.intelligence + skill * player.intelligence / 10.0)

static func _roll_fizzle(player: Player, spell: SpellData) -> bool:
	# §4.7: failure = max(0, 25 + difficulty*5 - magic_skill*3 - INT/2).
	var skill: int = player.get_skill_level("magic")
	var fail: int = max(0, 25 + spell.difficulty * 5 - skill * 3
			- player.intelligence / 2)
	return randi() % 100 < fail

static func _apply_element_bonus(spell: SpellData, target: Monster, dmg: int) -> int:
	if spell.element == "lightning" and target.is_wet():
		CombatLog.post("Soaked! Lightning surges for extra damage!", Color(0.6, 0.85, 1.0))
		return int(ceil(dmg * 1.5))
	return dmg

static func _damage_auto_target(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	var dmg: int = spell.base_damage + randi_range(0, 2) + power / 3
	dmg = _apply_element_bonus(spell, target, dmg)
	CombatLog.hit("You hit the %s with %s for %d." \
			% [target.data.display_name, spell.display_name, dmg])
	# Projectile visual
	if game != null and game.has_method("spawn_projectile"):
		var cell: float = DungeonMap.CELL_SIZE
		var half := Vector2(cell * 0.5, cell * 0.5)
		game.spawn_projectile(player.position + half, target.position + half,
				_spell_bolt_color(spell.effect))
	var was_alive: bool = target.hp > 0
	target.take_damage(dmg)
	if was_alive and target.hp <= 0:
		CombatLog.hit("You kill the %s." % target.data.display_name)
		player.grant_xp(target.data.xp_value)
		player.register_kill()
		GameManager.try_kill_unlock(target.data.id)

static func _multi_damage(spell: SpellData, player: Player,
		power: int, game: Node, darts: int) -> void:
	# Magic Missile style: N independent auto-targeted bolts. Each dart
	# re-finds the nearest visible enemy, so kills cascade onto the
	# next survivor rather than overkilling one target.
	var fired: int = 0
	for _i in range(darts):
		var target: Monster = _find_nearest_visible(player, game, spell.max_range)
		if target == null:
			break
		var dmg: int = spell.base_damage + randi_range(0, 2) + power / 4
		dmg = _apply_element_bonus(spell, target, dmg)
		CombatLog.hit("A dart strikes the %s for %d." \
				% [target.data.display_name, dmg])
		var was_alive: bool = target.hp > 0
		target.take_damage(dmg)
		if was_alive and target.hp <= 0:
			CombatLog.hit("You kill the %s." % target.data.display_name)
			player.grant_xp(target.data.xp_value)
			player.register_kill()
			GameManager.try_kill_unlock(target.data.id)
		fired += 1
	if fired == 0:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))

static func _aoe_damage(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	# Burning Hands style: all visible enemies within spell.max_range
	# take damage. No LOS line check beyond the player's own FOV.
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var hits: int = 0
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
				abs(n.grid_pos.y - player.grid_pos.y))
		if d > spell.max_range:
			continue
		var dmg: int = spell.base_damage + randi_range(0, 3) + power / 3
		dmg = _apply_element_bonus(spell, n, dmg)
		CombatLog.hit("%s burns the %s for %d." \
				% [spell.display_name, n.data.display_name, dmg])
		var was_alive: bool = n.hp > 0
		n.take_damage(dmg)
		if was_alive and n.hp <= 0:
			CombatLog.hit("You kill the %s." % n.data.display_name)
			player.grant_xp(n.data.xp_value)
			player.register_kill()
			GameManager.try_kill_unlock(n.data.id)
		hits += 1
	if hits == 0:
		CombatLog.post("The flames find no target.",
			Color(0.75, 0.75, 0.75))

static func _spell_bolt_color(effect: String) -> Color:
	match effect:
		"aoe_damage": return Color(1.0, 0.5, 0.1)
		"multi_damage": return Color(0.8, 0.5, 1.0)
		_: return Color(0.4, 0.7, 1.0)


static func _find_nearest_visible(player: Player, game: Node,
		max_range: int) -> Monster:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return null
	var best: Monster = null
	var best_d: int = max_range + 1
	var visible: Dictionary = {}
	if game != null and game.has_method("_refresh_fov"):
		visible = player.compute_fov()
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
			abs(n.grid_pos.y - player.grid_pos.y))
		if d <= max_range and d < best_d:
			best = n
			best_d = d
	return best
