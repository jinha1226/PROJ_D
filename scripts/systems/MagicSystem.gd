class_name MagicSystem extends RefCounted

static var SpellRegistry = Engine.get_main_loop().root.get_node_or_null("/root/SpellRegistry") if Engine.get_main_loop() is SceneTree else null
static var CombatLog = Engine.get_main_loop().root.get_node_or_null("/root/CombatLog") if Engine.get_main_loop() is SceneTree else null
static var RacePassiveSystem = Engine.get_main_loop().root.get_node_or_null("/root/RacePassiveSystem") if Engine.get_main_loop() is SceneTree else null
const GLOBAL_RANGE_REDUCTION: int = 1

static func effective_spell_range(spell: SpellData) -> int:
	if spell == null:
		return 0
	if spell.max_range <= 0:
		return 0
	return max(1, spell.max_range - GLOBAL_RANGE_REDUCTION)

static func cast(spell_id: String, player: Player, game: Node) -> bool:
	var spell: SpellData = SpellRegistry.get_by_id(spell_id)
	if spell == null:
		return false
	if spell.xl_required > player.xl:
		CombatLog.post("%s requires XL %d." % [spell.display_name, spell.xl_required],
			Color(1.0, 0.7, 0.5))
		return false
	var wizardry_scale: float = max(0.6, 1.0 - float(player.wizardry_bonus) * 0.08)
	var mp_cost: int = max(1, int(ceil(float(spell.mp_cost) * FaithSystem.spell_cost_mult(player) * wizardry_scale)))
	if not RacePassiveSystem.on_spell_cast_mp_check(player, mp_cost):
		CombatLog.post("Not enough MP for %s." % spell.display_name,
			Color(1.0, 0.7, 0.5))
		return false
	player.mp = max(0, player.mp - mp_cost)
	player.emit_signal("stats_changed")
	var power: int = _compute_power(player, spell)
	_cast_effect(spell, player, game, power)
	return true

static func _cast_effect(spell: SpellData, player: Player, game: Node, power: int) -> void:
	if _cast_damage_family(spell, player, game, power):
		return
	if _cast_status_family(spell, player, game):
		return
	if _cast_utility_family(spell, player, game, power):
		return
	_cast_buff_family(spell, player)

static func _cast_damage_family(spell: SpellData, player: Player, game: Node, power: int) -> bool:
	match spell.effect:
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
		"instant_kill":
			_cast_instant_kill(spell, player, game, 100)
		"power_word_pain":
			_cast_power_word(spell, player, game, 100, "pain")
		"power_word_stun":
			_cast_power_word(spell, player, game, 150, "stun")
		"prismatic":
			_cast_prismatic(spell, player, power, game)
		_:
			return false
	return true

static func _cast_status_family(spell: SpellData, player: Player, game: Node) -> bool:
	match spell.effect:
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
		"disease":
			_apply_status_to_target(spell, player, game, "diseased", 8)
		"polymorph":
			_apply_status_to_target(spell, player, game, "confused", 6)
			CombatLog.post("The target's form shifts!", Color(0.5, 1.0, 0.6))
		_:
			return false
	return true

static func _cast_utility_family(spell: SpellData, player: Player, game: Node, power: int) -> bool:
	match spell.effect:
		"heal":
			_cast_heal(spell, player, power, game)
		"blink":
			player._blink(max(2, effective_spell_range(spell)))
			CombatLog.post("You cast %s." % spell.display_name, Color(0.7, 0.85, 1.0))
		"banish":
			_cast_banish(spell, player, game)
		"fog":
			if game != null and game.get("map") != null:
				game.map.add_fog(player.grid_pos, 3, 8)
			CombatLog.post("A thick fog fills the area.", Color(0.75, 0.8, 0.9))
		"floor_travel":
			player._teleport_far()
			CombatLog.post("You vanish in a flash of light.", Color(0.8, 0.7, 1.0))
		"summon":
			_cast_summon(spell, player, power, game)
		"astral":
			player.apply_status("invulnerable", 4)
			CombatLog.post("You become ethereal!", Color(0.7, 0.85, 1.0))
		"time_stop":
			player.apply_status("time_stopped", 4)
			CombatLog.post("Time freezes around you!", Color(0.9, 0.6, 1.0))
		_:
			return false
	return true

static func _cast_buff_family(spell: SpellData, player: Player) -> void:
	match spell.effect:
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
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
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
	target.become_aware(player.grid_pos)
	var heal_amt: int = max(1, scaled / 2)
	player.heal(heal_amt)
	CombatLog.post("You absorb %d HP." % heal_amt, Color(0.6, 0.9, 0.6))
	if was_alive and target.hp <= 0:
		_on_kill(target, player, spell)


static func _apply_status_to_target(spell: SpellData, player: Player,
		game: Node, status_id: String, turns: int) -> void:
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	var label: String = Status.display_name(status_id).to_lower()
	CombatLog.post("The %s is %s!" % [target.data.display_name, label],
		Color(0.8, 0.7, 1.0))
	Status.apply(target, status_id, turns)
	target.become_aware(player.grid_pos)


static func _cast_sleep(spell: SpellData, player: Player, game: Node) -> void:
	var hp_threshold: int = randi_range(25, 40) + randi_range(0, 8) \
		+ randi_range(0, 8) + randi_range(0, 8) + randi_range(0, 8) + randi_range(0, 8)
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	if target.hp > hp_threshold:
		CombatLog.post("The %s resists the sleep!" % target.data.display_name,
			Color(0.75, 0.75, 0.75))
		target.become_aware(player.grid_pos)
		return
	CombatLog.post("The %s falls asleep!" % target.data.display_name, Color(0.6, 0.65, 0.9))
	Status.apply(target, "sleeping", 6)
	target.become_aware(player.grid_pos)


static func _aoe_status(spell: SpellData, player: Player, game: Node,
		status_id: String, turns: int) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var range_val: int = effective_spell_range(spell)
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
		if d > range_val:
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
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
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
		_on_kill(target, player, spell)


static func _cast_power_word(spell: SpellData, player: Player, game: Node,
		hp_threshold: int, mode: String) -> void:
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
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
		target.become_aware(player.grid_pos)
	elif mode == "stun":
		Status.apply(target, "stunned", 4)
		CombatLog.hit("The %s is stunned!" % target.data.display_name)
		target.become_aware(player.grid_pos)


static func _cast_banish(spell: SpellData, player: Player, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
	if target == null:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))
		return
	CombatLog.hit("You banish the %s!" % target.data.display_name)
	target.take_damage(99999)
	target.become_aware(player.grid_pos)


static func _cast_prismatic(spell: SpellData, player: Player, power: int, game: Node) -> void:
	var roll: int = randi_range(0, 5)
	match roll:
		0: _damage_auto_target(spell, player, power, game)
		1: _apply_status_to_target(spell, player, game, "paralyzed", 4)
		2: _apply_status_to_target(spell, player, game, "confused", 5)
		3: _apply_status_to_target(spell, player, game, "feared", 4)
		4: _cast_drain(spell, player, power, game)
		5: _cast_instant_kill(spell, player, game, 80)


static func _armor_spell_mult(player: Player) -> float:
	# Robe amplifies spell power slightly; other armors use encumbrance formula.
	# defense skill reduces effective encumbrance before the penalty is applied.
	if player.equipped_armor_id == "robe":
		return 1.1
	if player.equipped_armor_id == "":
		return 1.0
	var item: ItemData = player.ItemRegistry.get_by_id(player.equipped_armor_id) if player.ItemRegistry != null and player.equipped_armor_id != "" else null
	if item == null:
		return 1.0
	var enc: int = item.encumbrance
	var def_skill: int = player.get_skill_level("armor")
	return maxf(0.5, 1.0 - max(0, enc - def_skill) * 0.03)


static func _compute_power(player: Player, spell: SpellData) -> int:
	var spellcasting: int = player.get_skill_level("spellcasting")
	var school_skill: int = player.get_skill_level(player.spell_skill_for(spell))
	var total_skill: float = float(spellcasting) * 0.5 + float(school_skill)
	var base: int = int(float(player.intelligence) * (1.0 + total_skill * 0.06) * _armor_spell_mult(player))
	var power: int = base + EssenceSystem.spell_power_bonus(player, spell) + player.wizardry_bonus * 4
	return int(float(power) * FaithSystem.spell_damage_mult(player))


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


static func _on_kill(target: Monster, player: Player, spell: SpellData) -> void:
	CombatLog.hit("You kill the %s." % target.data.display_name)
	player.grant_xp(target.data.xp_value)
	player.grant_kill_skill_xp(float(target.data.xp_value), player.spell_skill_for(spell))
	player.register_kill()
	GameManager.try_kill_unlock(target.data.id)


static func _damage_auto_target(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
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
	target.become_aware(player.grid_pos)
	if was_alive and target.hp > 0:
		_apply_elemental_side_effects(spell, target)
	if was_alive and target.hp <= 0:
		_on_kill(target, player, spell)
	_spawn_impact_cloud(spell, target.grid_pos, game)


static func _multi_damage(spell: SpellData, player: Player,
		power: int, game: Node, darts: int) -> void:
	var fired: int = 0
	var half := Vector2(DungeonMap.CELL_SIZE * 0.5, DungeonMap.CELL_SIZE * 0.5)
	for i in range(darts):
		var target: Monster = _find_nearest_visible(player, game, effective_spell_range(spell))
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
		target.become_aware(player.grid_pos)
		if was_alive and target.hp > 0:
			_apply_elemental_side_effects(spell, target)
		if was_alive and target.hp <= 0:
			_on_kill(target, player, spell)
		fired += 1
	if fired == 0:
		CombatLog.post("No target in range.", Color(0.75, 0.75, 0.75))


static func _chain_damage(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var range_val: int = effective_spell_range(spell)
	var targets: Array = []
	for n in tree.get_nodes_in_group("monsters"):
		if not (n is Monster):
			continue
		if not visible.has(n.grid_pos):
			continue
		var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
				abs(n.grid_pos.y - player.grid_pos.y))
		if d <= range_val:
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
		t.become_aware(player.grid_pos)
		if was_alive and t.hp > 0:
			_apply_elemental_side_effects(spell, t)
		if was_alive and t.hp <= 0:
			_on_kill(t, player, spell)


static func _aoe_damage(spell: SpellData, player: Player,
		power: int, game: Node) -> void:
	var tree := game.get_tree() if game != null else null
	if tree == null:
		return
	var visible: Dictionary = player.compute_fov()
	var range_val: int = effective_spell_range(spell)
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
		if d > range_val:
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
		n.become_aware(player.grid_pos)
		if was_alive and n.hp > 0:
			_apply_elemental_side_effects(spell, n)
		if was_alive and n.hp <= 0:
			_on_kill(n, player, spell)
		hits += 1
	if hits == 0:
		CombatLog.post("The flames find no target.", Color(0.75, 0.75, 0.75))
	if game != null and game.has_method("spawn_aoe_burst") and not hit_positions.is_empty():
		game.spawn_aoe_burst(hit_positions, spell.element)
	# AOE fire/poison spells leave lingering clouds
	if hits > 0 and game != null and game.get("map") != null:
		for tile: Vector2i in visible.keys():
			var d: int = max(abs(tile.x - player.grid_pos.x), abs(tile.y - player.grid_pos.y))
			if d <= range_val:
				_spawn_impact_cloud(spell, tile, game)



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

# ── Summon ────────────────────────────────────────────────────────────────────

const _SUMMON_TABLE: Dictionary = {
	"call_imp":        {"monster": "crimson_imp",  "turns": 18, "count": 1},
	"animate_dead":    {"monster": "",             "turns": 20, "count": 1},
	"summon_vermin":   {"monster": "rat",          "turns": 12, "count": 3},
	"animate_skeleton":{"monster": "crypt_zombie", "turns": 20, "count": 1},
	"animate_objects": {"monster": "crimson_imp",  "turns": 15, "count": 2},
	"conjure_fey":     {"monster": "crimson_imp",  "turns": 20, "count": 1},
}

static func _cast_summon(spell: SpellData, player: Player, power: int, game: Node) -> void:
	if game == null or not game.has_method("spawn_ally"):
		CombatLog.post("A spectral ally answers your call!", Color(0.6, 0.9, 0.75))
		return
	var entry: Dictionary = _SUMMON_TABLE.get(spell.id, {})
	var turns: int = int(entry.get("turns", 15)) + power / 8
	var count: int = int(entry.get("count", 1))

	if spell.id == "animate_dead":
		_animate_dead(player, turns, game)
		return

	var monster_id: String = entry.get("monster", "crimson_imp")
	var spawned: int = 0
	for _i in range(count):
		if game.spawn_ally(monster_id, player.grid_pos, turns):
			spawned += 1
	if spawned > 0:
		CombatLog.post("You call forth %s!" % spell.display_name, Color(0.6, 0.9, 0.75))
	else:
		CombatLog.post("No room to summon!", Color(1.0, 0.7, 0.5))

static func _animate_dead(player: Player, turns: int, game: Node) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var gmap = tree.get_nodes_in_group("dungeon_map")
	if gmap.is_empty():
		return
	var dmap = gmap[0]
	if not dmap.has_method("get") or not "corpses" in dmap:
		return
	# Find nearest corpse within range 6
	var best_idx: int = -1
	var best_d: int = 999
	for i in range(dmap.corpses.size()):
		var cpos: Vector2i = dmap.corpses[i].get("pos", Vector2i(-999, -999))
		var d: int = max(abs(cpos.x - player.grid_pos.x), abs(cpos.y - player.grid_pos.y))
		if d <= 6 and d < best_d:
			best_d = d
			best_idx = i
	if best_idx < 0:
		CombatLog.post("No corpses nearby to animate.", Color(1.0, 0.7, 0.5))
		return
	var corpse: Dictionary = dmap.corpses[best_idx]
	dmap.corpses.remove_at(best_idx)
	dmap.queue_redraw()
	# Decide which undead to spawn based on original monster type
	var zombie_id: String = "zombie"
	if game.spawn_ally(zombie_id, player.grid_pos, turns):
		CombatLog.post("A corpse rises to serve you!", Color(0.5, 0.9, 0.6))
	else:
		CombatLog.post("No room to animate!", Color(1.0, 0.7, 0.5))


## Spawn a lingering cloud at pos if the spell's element warrants it.
static func _spawn_impact_cloud(spell: SpellData, pos: Vector2i, game: Node) -> void:
	if game == null or game.get("map") == null:
		return
	var cloud_type: String = ""
	var cloud_turns: int = 0
	match spell.element:
		"fire":    cloud_type = "fire";    cloud_turns = 3
		"poison":  cloud_type = "poison";  cloud_turns = 4
		"cold":    cloud_type = "cold";    cloud_turns = 2
		"lightning", "electric":
			cloud_type = "electricity"; cloud_turns = 2
	if cloud_type != "" and randf() < 0.5:
		game.map.add_cloud(pos, cloud_type, cloud_turns)
