class_name MagicSystem extends RefCounted

static func cast(spell_id: String, player: Player, game: Node) -> bool:
	var spell: SpellData = SpellRegistry.get_by_id(spell_id)
	if spell == null:
		return false
	if spell.xl_required > 0 and player.xl < spell.xl_required:
		CombatLog.post("%s requires level %d." % [spell.display_name, spell.xl_required],
			Color(1.0, 0.7, 0.5))
		return false
	if not RacePassiveSystem.on_spell_cast_mp_check(player, spell.mp_cost):
		CombatLog.post("Not enough MP for %s." % spell.display_name,
			Color(1.0, 0.7, 0.5))
		return false
	player.mp = max(0, player.mp - spell.mp_cost)
	var xp_skill: String = spell.school if spell.school != "" else "magic"
	player.grant_skill_xp(xp_skill, float(spell.mp_cost))
	player.emit_signal("stats_changed")
	var power: int = _compute_power(player, spell)
	match spell.effect:
		"heal":
			_cast_heal(spell, player, power, game)
		"blink":
			player._blink(max(2, spell.max_range))
			CombatLog.post("You cast %s." % spell.display_name, Color(0.7, 0.85, 1.0))
		"damage":
			_damage_auto_target(spell, player, power, game)
		"multi_damage":
			_multi_damage(spell, player, power, game, 3)
		"aoe_damage":
			_aoe_damage(spell, player, power, game)
		"chain_damage":
			_chain_damage(spell, player, power, game)
		"drain":
			_cast_drain(spell, player, power, game)
		"hold":
			_apply_status_to_target(spell, player, game, "paralyzed", 5)
		"sleep":
			_cast_sleep(spell, player, game)
		"fear":
			_apply_status_to_target(spell, player, game, "feared", 6)
		"confusion":
			_apply_status_to_target(spell, player, game, "confused", 5)
		"stun":
			_apply_status_to_target(spell, player, game, "stunned", 3)
		"aoe_status":
			_aoe_status(spell, player, game, "confused", 4)
		"earthquake":
			_aoe_status(spell, player, game, "stunned", 3)
		"debuff_str":
			_apply_status_to_target(spell, player, game, "weakened", 8)
		"instant_kill":
			_cast_instant_kill(spell, player, game, 100)
		"power_word_pain":
			_cast_power_word(spell, player, game, 100, "pain")
		"power_word_stun":
			_cast_power_word(spell, player, game, 150, "stun")
		"banish":
			_cast_banish(spell, player, game)
		"fog":
			CombatLog.post("A thick fog fills the area.", Color(0.75, 0.8, 0.9))
		"floor_travel":
			player._teleport_far()
			CombatLog.post("You vanish in a flash of light.", Color(0.8, 0.7, 1.0))
		"disease":
			_apply_status_to_target(spell, player, game, "diseased", 8)
		"polymorph":
			_apply_status_to_target(spell, player, game, "confused", 6)
			CombatLog.post("The target's form shifts!", Color(0.5, 1.0, 0.6))
		"summon":
			CombatLog.post("A spectral ally answers your call!", Color(0.6, 0.9, 0.75))
		"prismatic":
			_cast_prismatic(spell, player, power, game)
		"astral":
			player.apply_status("invulnerable", 4)
			CombatLog.post("You become ethereal!", Color(0.7, 0.85, 1.0))
		"time_stop":
			player.apply_status("time_stopped", 4)
			CombatLog.post("Time freezes around you!", Color(0.9, 0.6, 1.0))
		"buff_ac":
			_cast_buff(player, "mage_armor", 15, spell.display_name,
				"Magical armor surrounds you. (AC %d)" % (13 + player.dexterity / 2),
				Color(0.5, 0.7, 1.0))
			player.refresh_ac_from_equipment()
		"buff_speed":
			_cast_buff(player, "hasted", 12, spell.display_name,
				"You move with unnatural speed!", Color(0.4, 1.0, 0.65))
		"buff_haste":
			_cast_buff(player, "hasted", 8, spell.display_name,
				"Time blurs around you!", Color(0.4, 1.0, 0.65))
		"buff_damage":
			_cast_buff(player, "damage_boost", 8, spell.display_name,
				"Your strikes surge with power! (+1d4 dmg)", Color(1.0, 0.65, 0.3))
		"buff_resist":
			_cast_buff(player, "stoneskin", 10, spell.display_name,
				"Your skin hardens like stone!", Color(0.8, 0.8, 0.65))
		"buff_blur":
			_cast_buff(player, "blur", 10, spell.display_name,
				"Your form becomes indistinct. (+3 EV)", Color(0.7, 0.75, 1.0))
		"buff_stoneskin":
			_cast_buff(player, "stoneskin", 12, spell.display_name,
				"Your skin becomes like stone!", Color(0.8, 0.8, 0.65))
		"buff_magic_ward":
			_cast_buff(player, "magic_ward", 10, spell.display_name,
				"A ward against magic protects you!", Color(0.75, 0.5, 1.0))
		"buff_invulnerable":
			_cast_buff(player, "invulnerable", 3, spell.display_name,
				"You are immune to all harm!", Color(1.0, 0.95, 0.5))
	return true


static func _cast_heal(spell: SpellData, player: Player, power: int, game: Node) -> void:
	var amt: int = 12 + power / 2
	player.heal(amt)
	CombatLog.post("You cast %s. (+%d HP)" % [spell.display_name, amt], Color(0.6, 1.0, 0.6))
	if game != null:
		if game.has_method("spawn_damage_number"):
			game.spawn_damage_number(player.position, amt, Color(0.4, 1.0, 0.5))
		if game.has_method("spawn_hit_effect"):
			game.spawn_hit_effect(player.position + Vector2(16, 16), "heal")


static func _cast_buff(player: Player, status_id: String, turns: int,
		spell_name: String, message: String, col: Color) -> void:
	player.apply_status(status_id, turns)
	CombatLog.post("You cast %s. %s" % [spell_name, message], col)


static func _cast_drain(spell: SpellData, player: Player, power: int, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	var dmg: int = spell.base_damage + randi_range(0, 2) + power / 4
	var scaled: int = Status.resist_scale(dmg, target.data.resists, spell.element)
	CombatLog.hit("You drain the %s for %d." % [target.data.display_name, scaled])
	if game != null and game.has_method("spawn_spell_bolt"):
		var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
		game.spawn_spell_bolt(player.position + half, target.position + half, "drain")
	var was_alive: bool = target.hp > 0
	target.take_damage(scaled)
	var heal_amt: int = max(1, scaled / 2)
	player.heal(heal_amt)
	CombatLog.post("You absorb %d HP." % heal_amt, Color(0.6, 0.9, 0.6))
	if was_alive and target.hp <= 0:
		_on_kill(target, player)


static func _apply_status_to_target(spell: SpellData, player: Player,
		game: Node, status_id: String, turns: int) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	var label: String = Status.display_name(status_id).to_lower()
	CombatLog.post("The %s is %s!" % [target.data.display_name, label],
		Color(0.8, 0.7, 1.0))
	Status.apply(target, status_id, turns)


static func _cast_sleep(spell: SpellData, player: Player, game: Node) -> void:
	var hp_threshold: int = randi_range(25, 40) + randi_range(0, 8) \
		+ randi_range(0, 8) + randi_range(0, 8) + randi_range(0, 8) + randi_range(0, 8)
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	if target.hp > hp_threshold:
		CombatLog.post("The %s resists the sleep!" % target.data.display_name,
			Color(0.75, 0.75, 0.75))
		return
	CombatLog.post("The %s falls asleep!" % target.data.display_name, Color(0.6, 0.65, 0.9))
	Status.apply(target, "sleeping", 6)


static func _aoe_status(spell: SpellData, player: Player, game: Node,
		status_id: String, turns: int) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var hits: int = 0
	var hit_positions: Array = []
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
				abs(n.grid_pos.y - player.grid_pos.y))
		if d > spell.max_range:
			continue
		Status.apply(n, status_id, turns)
		hit_positions.append(n.position + half)
		hits += 1
	var label: String = Status.display_name(status_id).to_lower()
	if hits > 0:
		CombatLog.post("%s affects %d enemies!" % [spell.display_name, hits],
			Color(0.8, 0.7, 1.0))
		if game != null and game.has_method("spawn_aoe_burst"):
			game.spawn_aoe_burst(hit_positions, spell.element)
	else:
		CombatLog.post("No targets in range.", Color(0.75, 0.75, 0.75))


static func _cast_instant_kill(spell: SpellData, player: Player,
		game: Node, hp_max: int) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	if target.hp > hp_max:
		CombatLog.post("The %s is too powerful!" % target.data.display_name,
			Color(0.75, 0.75, 0.75))
		return
	CombatLog.hit("You obliterate the %s!" % target.data.display_name)
	var was_alive: bool = target.hp > 0
	target.take_damage(99999)
	if was_alive and target.hp <= 0:
		_on_kill(target, player)


static func _cast_power_word(spell: SpellData, player: Player, game: Node,
		hp_threshold: int, mode: String) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	if target.hp > hp_threshold:
		CombatLog.post("The %s is too powerful to affect!" % target.data.display_name,
			Color(0.75, 0.75, 0.75))
		return
	if mode == "pain":
		var dmg: int = target.hp / 2
		CombatLog.hit("The %s writhes in agony! (-%d HP)" % [target.data.display_name, dmg])
		target.take_damage(dmg)
	elif mode == "stun":
		Status.apply(target, "stunned", 4)
		CombatLog.hit("The %s is stunned!" % target.data.display_name)


static func _cast_banish(spell: SpellData, player: Player, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	CombatLog.hit("You banish the %s!" % target.data.display_name)
	target.take_damage(99999)


static func _cast_prismatic(spell: SpellData, player: Player, power: int, game: Node) -> void:
	var roll: int = randi_range(0, 5)
	match roll:
		0: _damage_auto_target(spell, player, power, game)
		1: _apply_status_to_target(spell, player, game, "paralyzed", 4)
		2: _apply_status_to_target(spell, player, game, "confused", 5)
		3: _apply_status_to_target(spell, player, game, "feared", 4)
		4: _cast_drain(spell, player, power, game)
		5: _cast_instant_kill(spell, player, game, 80)


static func _compute_power(player: Player, spell: SpellData) -> int:
	var skill_id: String = spell.school if spell.school != "" else "magic"
	var skill: int = player.get_skill_level(skill_id)
	return int(float(player.intelligence) * (1.0 + float(skill) * 0.06))


static func _apply_element_bonus(spell: SpellData, target: Monster, dmg: int) -> int:
	if spell.element == "lightning" and target.is_wet():
		CombatLog.post("Soaked! Lightning surges for extra damage!", Color(0.6, 0.85, 1.0))
		return int(ceil(dmg * 1.5))
	return dmg


static func _element_status(element: String) -> Array:
	match element:
		"fire":      return ["burning", 3]
		"cold":      return ["frozen", 2]
		"poison":    return ["poison", 4]
	return []


static func _apply_elemental_side_effects(spell: SpellData, target: Monster) -> void:
	var pair: Array = _element_status(spell.element)
	if pair.size() == 2 and target.hp > 0:
		Status.apply(target, String(pair[0]), int(pair[1]))


static func _on_kill(target: Monster, player: Player) -> void:
	CombatLog.hit("You kill the %s." % target.data.display_name)
	player.grant_xp(target.data.xp_value)
	player.register_kill()
	GameManager.try_kill_unlock(target.data.id)


static func _damage_auto_target(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, spell.max_range)
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	var dmg: int = spell.base_damage + randi_range(0, 2) + power / 4
	dmg = _apply_element_bonus(spell, target, dmg)
	CombatLog.hit("You hit the %s with %s for %d." \
			% [target.data.display_name, spell.display_name, dmg])
	if game != null and game.has_method("spawn_spell_bolt"):
		var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
		game.spawn_spell_bolt(player.position + half, target.position + half, spell.element)
	var scaled: int = Status.resist_scale(dmg, target.data.resists, spell.element)
	if scaled <= 0 and dmg > 0:
		CombatLog.post("The %s is immune to %s."
				% [target.data.display_name, spell.display_name],
			Color(0.65, 0.75, 0.85))
		return
	var was_alive: bool = target.hp > 0
	target.take_damage(scaled)
	if was_alive and target.hp > 0:
		_apply_elemental_side_effects(spell, target)
	if was_alive and target.hp <= 0:
		_on_kill(target, player)


static func _multi_damage(spell: SpellData, player: Player,
		power: int, game: Node, darts: int) -> void:
	var fired: int = 0
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	for i in range(darts):
		var target: Monster = _find_nearest_visible(player, game, spell.max_range)
		if target == null:
			break
		var dmg: int = spell.base_damage + randi_range(0, 2) + power / 4
		dmg = _apply_element_bonus(spell, target, dmg)
		var scaled: int = Status.resist_scale(dmg, target.data.resists, spell.element)
		CombatLog.hit("A dart strikes the %s for %d." % [target.data.display_name, scaled])
		if game != null and game.has_method("spawn_spell_bolt"):
			game.spawn_spell_bolt(player.position + half, target.position + half,
					spell.element, Callable(), i * 0.09)
		var was_alive: bool = target.hp > 0
		target.take_damage(scaled)
		if was_alive and target.hp > 0:
			_apply_elemental_side_effects(spell, target)
		if was_alive and target.hp <= 0:
			_on_kill(target, player)
		fired += 1
	if fired == 0:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))


static func _chain_damage(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var targets: Array = []
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
				abs(n.grid_pos.y - player.grid_pos.y))
		if d <= spell.max_range:
			targets.append(n)
	if targets.is_empty():
		CombatLog.post("No targets in range.", Color(0.75, 0.75, 0.75))
		return
	var bounces: int = mini(3, targets.size())
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	var prev_pos: Vector2 = player.position + half
	for i in range(bounces):
		var t: Monster = targets[i]
		var dmg: int = spell.base_damage + randi_range(0, 2) + power / 4
		dmg = int(dmg * pow(0.7, i))
		dmg = _apply_element_bonus(spell, t, dmg)
		var scaled: int = Status.resist_scale(dmg, t.data.resists, spell.element)
		CombatLog.hit("Lightning arcs through the %s for %d." % [t.data.display_name, scaled])
		if game != null and game.has_method("spawn_spell_bolt"):
			var tgt_pos: Vector2 = t.position + half
			game.spawn_spell_bolt(prev_pos, tgt_pos, spell.element)
			prev_pos = tgt_pos
		var was_alive: bool = t.hp > 0
		t.take_damage(scaled)
		if was_alive and t.hp > 0:
			_apply_elemental_side_effects(spell, t)
		if was_alive and t.hp <= 0:
			_on_kill(t, player)


static func _aoe_damage(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var hits: int = 0
	var hit_positions: Array = []
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
				abs(n.grid_pos.y - player.grid_pos.y))
		if d > spell.max_range:
			continue
		var dmg: int = spell.base_damage + randi_range(0, 3) + power / 4
		dmg = _apply_element_bonus(spell, n, dmg)
		var scaled: int = Status.resist_scale(dmg, n.data.resists, spell.element)
		if scaled <= 0 and dmg > 0:
			continue
		CombatLog.hit("%s hits the %s for %d." \
				% [spell.display_name, n.data.display_name, scaled])
		hit_positions.append(n.position + half)
		var was_alive: bool = n.hp > 0
		n.take_damage(scaled)
		if was_alive and n.hp > 0:
			_apply_elemental_side_effects(spell, n)
		if was_alive and n.hp <= 0:
			_on_kill(n, player)
		hits += 1
	if hits == 0:
		CombatLog.post("The flames find no target.", Color(0.75, 0.75, 0.75))
	if game != null and game.has_method("spawn_aoe_burst") and not hit_positions.is_empty():
		game.spawn_aoe_burst(hit_positions, spell.element)



static func _find_nearest_visible(player: Player, game: Node,
		max_range: int) -> Monster:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return null
	var best: Monster = null
	var best_d: int = max_range + 1
	var visible: Dictionary = player.compute_fov()
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
