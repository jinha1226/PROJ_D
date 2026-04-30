class_name MonsterAI extends RefCounted

static var GameManager = Engine.get_main_loop().root.get_node_or_null("/root/GameManager") if Engine.get_main_loop() is SceneTree else null
static var ClassRegistry = Engine.get_main_loop().root.get_node_or_null("/root/ClassRegistry") if Engine.get_main_loop() is SceneTree else null
static var ItemRegistry = Engine.get_main_loop().root.get_node_or_null("/root/ItemRegistry") if Engine.get_main_loop() is SceneTree else null

## Monster AI: adjacent → attack; player in FOV → step toward + update
## last_known_player_pos; alerted but no LOS → chase last known position;
## idle → random step.

static func take_turn(monster: Monster, map: DungeonMap) -> void:
	if monster.is_ally:
		_take_ally_turn(monster, map)
		return
	var player: Player = _find_player()
	if player == null or player.hp <= 0:
		return
	if Status.will_skip_turn(monster):
		return
	if Status.has(player, "time_stopped"):
		return
	if Status.has(player, "hasted") and randf() < 0.5:
		return
	if Status.is_fleeing(monster):
		_flee_step(monster, map, player.grid_pos)
		return
	# Fire telegraphed ability from last turn
	if not monster._ability_charge.is_empty():
		_fire_charge(monster, player, map)
		return
	var confusion: float = Status.confusion_chance(monster)
	if confusion > 0.0 and randf() < confusion:
		_random_step(monster, map)
		return
	var dist: int = _chebyshev(monster.grid_pos, player.grid_pos)
	# Healer: scan for wounded allies before anything else
	if monster.data.ai_flags.has("healer") and _try_heal_ally(monster):
		return
	if dist == 1:
		if _try_special_close(monster, player, map):
			return
		CombatSystem.monster_attack_player(monster, player)
		monster.become_aware(player.grid_pos)
		return
	if _can_see(monster, map, player.grid_pos):
		monster.become_aware(player.grid_pos)
		_pack_alert(monster, player.grid_pos)
		# Summoner: call reinforcements on first sighting
		if monster.data.ai_flags.has("summoner") and not monster._summoned_once:
			_try_summon(monster, map)
		if _try_special_ranged(monster, player, map, dist):
			return
		# Kiter: maintain preferred distance before shooting
		if monster.data.ai_flags.has("kite") and dist < KITE_PREFERRED_RANGE:
			if _kite_step(monster, map, player.grid_pos):
				return
		if _try_ranged(monster, player, dist):
			return
		_step_toward(monster, map, player.grid_pos)
	elif monster.is_alerted and monster.last_known_player_pos != Vector2i(-1, -1):
		# Chase the last known position. Clear alert once we reach it.
		var chase_dist: int = _chebyshev(monster.grid_pos, monster.last_known_player_pos)
		if chase_dist <= 1:
			monster.is_alerted = false
			monster.lose_awareness()
			monster.last_known_player_pos = Vector2i(-1, -1)
		else:
			_step_toward(monster, map, monster.last_known_player_pos)
	else:
		_random_step(monster, map)


# ── Special abilities ───────────────────────────────────────────────────────

# Boss IDs that use telegraphed attacks instead of instant specials.
const KITE_PREFERRED_RANGE: int = 3  # kiter backs off until this chebyshev distance

const BOSS_IDS: Array = [
	"ashen_magpie", "ancient_lich", "blood_duke", "bog_serpent",
	"ember_tyrant", "glacial_sovereign", "gnoll_warlord", "harrow_knight",
	"ogre_chieftain", "orc_warchief", "pale_scholar", "sister_cinder",
	"sovereign_jelly", "stone_warden", "storm_hierophant", "viper_saint",
]

## Close-range specials (dist == 1). Returns true if ability was used.
static func _try_special_close(monster: Monster, player: Player, map: DungeonMap) -> bool:
	var id: String = monster.data.id
	# Boss telegraphed attacks
	if id in BOSS_IDS:
		return _try_boss_telegraph(monster, player, map)
	# Non-boss instant drain/touch abilities
	match id:
		"vampire", "vampire_knight":
			if randf() < 0.30:
				_drain_life(monster, player)
				return true
		"wraith", "shadow_wraith":
			if randf() < 0.35:
				_drain_life(monster, player)
				return true
		"wight":
			if randf() < 0.25:
				_drain_life(monster, player)
				return true
	return false


## Ranged specials (dist > 1). Returns true if ability was used.
static func _try_special_ranged(monster: Monster, player: Player, map: DungeonMap, dist: int) -> bool:
	var id: String = monster.data.id
	# Boss telegraphed attacks at range
	if id in BOSS_IDS and dist <= 5:
		return _try_boss_telegraph(monster, player, map)
	# Non-boss instant ranged specials
	match id:
		"orc_priest":
			if dist <= 7 and randf() < 0.40:
				_smite(monster, player, "The Orc Priest calls down divine wrath!")
				return true
		"deep_elf_death_mage":
			if dist <= 6 and randf() < 0.45:
				_drain_life(monster, player)
				return true
		"mummy":
			if dist <= 5 and randf() < 0.30:
				_smite(monster, player, "The Mummy curses you!")
				return true
		"balrug":
			if dist <= 6 and randf() < 0.40:
				_smite(monster, player, "The Balrug breathes hellfire!")
				return true
		"red_devil":
			if dist <= 5 and randf() < 0.35:
				_smite(monster, player, "The Red Devil spits fire!")
				return true
		"ice_devil":
			if dist <= 5 and randf() < 0.35:
				_smite(monster, player, "The Ice Devil blasts you with cold!")
				return true
		"earth_elemental":
			if dist <= 5 and randf() < 0.30:
				_smite(monster, player, "The Earth Elemental hurls a boulder!")
				return true
	return false


## Boss telegraphed attack selection.
static func _try_boss_telegraph(monster: Monster, player: Player, map: DungeonMap) -> bool:
	if randf() > 0.35:
		return false
	match monster.data.id:
		"ashen_magpie":
			_telegraph_aoe(monster, map, 2,
				"The Ashen Magpie spreads its wings — brace for impact!",
				monster.data.hd * 4)
		"ancient_lich":
			_telegraph_aoe(monster, map, 3,
				"The Ancient Lich channels torment!",
				monster.data.hd * 3)
		"gnoll_warlord", "orc_warchief", "ogre_chieftain":
			_telegraph_aoe(monster, map, 1,
				"The %s raises its weapon for a mighty cleave!" % monster.data.display_name,
				monster.data.hd * 5)
		"storm_hierophant", "ember_tyrant":
			_telegraph_line(monster, player, map,
				"The %s charges a devastating bolt!" % monster.data.display_name,
				monster.data.hd * 6)
		_:
			_telegraph_aoe(monster, map, 2,
				"The %s winds up for a powerful attack!" % monster.data.display_name,
				monster.data.hd * 4)
	monster.become_aware(player.grid_pos)
	return true


## Smite: instant non-LOS damage.
static func _smite(monster: Monster, player: Player, msg: String) -> void:
	var dmg: int = randi_range(monster.data.hd, monster.data.hd * 2 + 2)
	CombatLog.post(msg, Color(1.0, 0.65, 0.2))
	CombatLog.damage_taken("The %s hits you for %d." % [monster.data.display_name, dmg])
	player.take_damage(dmg, monster.data.id)
	monster.become_aware(player.grid_pos)


## Drain life: deals damage and heals the monster.
static func _drain_life(monster: Monster, player: Player) -> void:
	var dmg: int = randi_range(monster.data.hd, monster.data.hd + 4)
	CombatLog.post("The %s drains your life force!" % monster.data.display_name, Color(0.7, 0.3, 1.0))
	CombatLog.damage_taken("You lose %d HP." % dmg)
	player.take_damage(dmg, monster.data.id)
	monster.hp = min(monster.data.hp, monster.hp + dmg / 2)
	monster.emit_signal("stats_changed")
	monster.become_aware(player.grid_pos)


## Telegraph an AoE: show warning tiles for 1 turn around the monster.
static func _telegraph_aoe(monster: Monster, map: DungeonMap,
		radius: int, msg: String, dmg: int) -> void:
	var tiles: Array = []
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var t := monster.grid_pos + Vector2i(dx, dy)
			if map.tile_at(t) != DungeonMap.Tile.WALL:
				tiles.append(t)
				map.set_warning(t, Color(1.0, 0.45, 0.0, 0.45))
	CombatLog.post(msg, Color(1.0, 0.8, 0.2))
	monster._ability_charge = {"name": "aoe", "tiles": tiles, "damage": dmg}


## Telegraph a line bolt: show warning tiles along direction to player.
static func _telegraph_line(monster: Monster, player: Player, map: DungeonMap,
		msg: String, dmg: int) -> void:
	var dir := Vector2i(sign(player.grid_pos.x - monster.grid_pos.x),
						sign(player.grid_pos.y - monster.grid_pos.y))
	var tiles: Array = []
	var cur := monster.grid_pos + dir
	for _i in range(6):
		if map.tile_at(cur) == DungeonMap.Tile.WALL:
			break
		tiles.append(cur)
		map.set_warning(cur, Color(1.0, 0.2, 0.2, 0.5))
		cur += dir
	CombatLog.post(msg, Color(1.0, 0.8, 0.2))
	monster._ability_charge = {"name": "line", "tiles": tiles, "damage": dmg}


## Execute a telegraphed ability (called the turn after telegraph).
static func _fire_charge(monster: Monster, player: Player, map: DungeonMap) -> void:
	var charge: Dictionary = monster._ability_charge
	monster._ability_charge = {}
	for t in charge.get("tiles", []):
		map.warning_tiles.erase(t)
	map.queue_redraw()
	var hit_tiles: Array = charge.get("tiles", [])
	var dmg: int = int(charge.get("damage", monster.data.hd * 2))
	if player.grid_pos in hit_tiles:
		CombatLog.damage_taken("The %s's attack hits you for %d!" % [monster.data.display_name, dmg])
		player.take_damage(dmg, monster.data.id)
	else:
		CombatLog.post("You dodge the %s's attack!" % monster.data.display_name, Color(0.6, 1.0, 0.6))

static func _flee_step(monster: Monster, map: DungeonMap,
		threat: Vector2i) -> void:
	# Step toward the tile that maximises chebyshev distance to threat.
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = _chebyshev(monster.grid_pos, threat)
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var opt := Vector2i(ddx, ddy)
			var next: Vector2i = monster.grid_pos + opt
			if not map.is_walkable(next) or _occupied(next, monster):
				continue
			var d: int = _chebyshev(next, threat)
			if d > best_d:
				best = opt
				best_d = d
	if best != Vector2i.ZERO:
		monster.try_move(best)

static func _try_ranged(monster: Monster, player: Player, dist: int) -> bool:
	var ra: Dictionary = monster.data.ranged_attack
	if ra.is_empty():
		return false
	var max_range: int = int(ra.get("range", 6))
	if dist > max_range:
		return false
	CombatSystem.monster_ranged_attack_player(monster, player, ra)
	return true

static func _find_player() -> Player:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	for n in tree.get_nodes_in_group("player"):
		if n is Player:
			return n
	return null

static func _chebyshev(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))

static func _can_see(monster: Monster, map: DungeonMap, target: Vector2i) -> bool:
	var player: Player = _find_player()
	var radius: int = _effective_sight_range(monster, player)
	if _chebyshev(monster.grid_pos, target) > radius:
		return false
	var is_opaque := func(p: Vector2i) -> bool: return map.is_opaque(p)
	var vis: Dictionary = FieldOfView.compute(monster.grid_pos, radius, is_opaque)
	return vis.has(target)

static func _effective_sight_range(monster: Monster, player: Player) -> int:
	var radius: int = max(3, monster.data.sight_range - 1)
	if player == null:
		return radius
	var stealth_score: int = player.get_skill_level("agility")
	var cls: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
	if cls != null and cls.class_group == "rogue":
		stealth_score += 4
	if player.equipped_weapon_id != "":
		var weapon: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if weapon != null and weapon.category == "dagger":
			stealth_score += 2
	if Status.has(player, "shrouded"):
		stealth_score += 8
	stealth_score += EssenceSystem.stealth_bonus(player)
	return maxi(2, radius - int(floor(float(stealth_score) / 3.0)))

static func _step_toward(monster: Monster, map: DungeonMap, target: Vector2i) -> void:
	var dx: int = sign(target.x - monster.grid_pos.x)
	var dy: int = sign(target.y - monster.grid_pos.y)
	var tried: Array = []
	for opt in [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]:
		if opt == Vector2i.ZERO or tried.has(opt):
			continue
		tried.append(opt)
		var next: Vector2i = monster.grid_pos + opt
		if map.is_walkable(next) and not _occupied(next, monster):
			monster.try_move(opt)
			return
	# Fallback: any 8-dir neighbor that doesn't increase chebyshev
	# distance to the target. Keeps chasers pushing through a blocked
	# cardinal step instead of idling for a turn.
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = _chebyshev(monster.grid_pos, target)
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var opt := Vector2i(ddx, ddy)
			if tried.has(opt):
				continue
			var next: Vector2i = monster.grid_pos + opt
			if not map.is_walkable(next):
				continue
			if _occupied(next, monster):
				continue
			var d: int = _chebyshev(next, target)
			if d < best_d:
				best = opt
				best_d = d
	if best != Vector2i.ZERO:
		monster.try_move(best)

static func _pack_alert(source: Monster, player_pos: Vector2i) -> void:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var player: Player = _find_player()
	if player != null and Status.has(player, "shrouded"):
		return
	var alert_radius: int = 8
	var cls: ClassData = ClassRegistry.get_by_id(GameManager.selected_class_id)
	if cls != null and cls.class_group == "rogue":
		alert_radius = 4
	for node in tree.get_nodes_in_group("monsters"):
		if node == source or not (node is Monster):
			continue
		var m: Monster = node as Monster
		if m.is_alerted or m.hp <= 0:
			continue
		if _chebyshev(source.grid_pos, m.grid_pos) <= alert_radius:
			m.become_aware(player_pos)

static func _random_step(monster: Monster, map: DungeonMap) -> void:
	# Was 50% idle — felt too slack. 20% idle keeps wandering enemies
	# closing on the player more often without turning it into a full
	# chase while they're out of sight.
	if randf() < 0.2:
		return
	var dirs: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1)]
	dirs.shuffle()
	for d in dirs:
		var next: Vector2i = monster.grid_pos + d
		if map.is_walkable(next) and not _occupied(next, monster):
			monster.try_move(d)
			return

static func _take_ally_turn(ally: Monster, map: DungeonMap) -> void:
	if Status.will_skip_turn(ally):
		return
	var target: Monster = _find_nearest_enemy(ally)
	if target == null:
		# No enemies — follow player
		var player: Player = _find_player()
		if player != null and _chebyshev(ally.grid_pos, player.grid_pos) > 2:
			_step_toward(ally, map, player.grid_pos)
		return
	var dist: int = _chebyshev(ally.grid_pos, target.grid_pos)
	if dist == 1:
		CombatSystem.ally_attack_monster(ally, target)
	else:
		_step_toward(ally, map, target.grid_pos)

static func _find_nearest_enemy(ally: Monster) -> Monster:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	var best: Monster = null
	var best_dist: int = 999
	for n in tree.get_nodes_in_group("monsters"):
		if n == ally or not (n is Monster):
			continue
		if n.is_ally:
			continue
		var d: int = _chebyshev(ally.grid_pos, n.grid_pos)
		if d < best_dist:
			best_dist = d
			best = n
	return best

## Kite: try to step away from threat until KITE_PREFERRED_RANGE is reached.
## Returns true if a step was taken.
static func _kite_step(monster: Monster, map: DungeonMap, threat: Vector2i) -> bool:
	var best: Vector2i = Vector2i.ZERO
	var best_d: int = _chebyshev(monster.grid_pos, threat)
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var next: Vector2i = monster.grid_pos + Vector2i(ddx, ddy)
			if not map.is_walkable(next) or _occupied(next, monster):
				continue
			var d: int = _chebyshev(next, threat)
			# Only retreat until preferred range — stop once safe enough
			if d > best_d and d <= KITE_PREFERRED_RANGE + 1:
				best = Vector2i(ddx, ddy)
				best_d = d
	if best != Vector2i.ZERO:
		monster.try_move(best)
		return true
	return false


## Healer: heal the most wounded nearby non-ally monster. Returns true if healed.
static func _try_heal_ally(healer: Monster) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	var best: Monster = null
	var best_ratio: float = 0.5  # only heal below 50% HP
	for n in tree.get_nodes_in_group("monsters"):
		if n == healer or not (n is Monster) or n.is_ally:
			continue
		if n.hp <= 0 or n.data == null:
			continue
		if _chebyshev(healer.grid_pos, n.grid_pos) > 6:
			continue
		var ratio: float = float(n.hp) / float(n.data.hp)
		if ratio < best_ratio:
			best_ratio = ratio
			best = n
	if best == null:
		return false
	var heal: int = healer.data.hd * 3
	best.hp = min(best.data.hp, best.hp + heal)
	best.emit_signal("stats_changed")
	CombatLog.post("The %s calls upon divine power — the %s is healed!" \
			% [healer.data.display_name, best.data.display_name], Color(0.5, 1.0, 0.6))
	return true


## Summoner: spawn 1-2 monsters from summon_pool into adjacent tiles (once per encounter).
static func _try_summon(summoner: Monster, map: DungeonMap) -> void:
	summoner._summoned_once = true
	if summoner.data.summon_pool.is_empty():
		return
	var game := _find_game()
	if game == null or not game.has_method("spawn_monster_at"):
		return
	var count: int = randi_range(1, 2)
	var spawned: int = 0
	# Collect empty adjacent tiles
	var free_tiles: Array = []
	for ddx in [-1, 0, 1]:
		for ddy in [-1, 0, 1]:
			if ddx == 0 and ddy == 0:
				continue
			var t: Vector2i = summoner.grid_pos + Vector2i(ddx, ddy)
			if map.is_walkable(t) and not _occupied(t, summoner):
				free_tiles.append(t)
	free_tiles.shuffle()
	for i in range(mini(count, free_tiles.size())):
		var mid: String = summoner.data.summon_pool[randi() % summoner.data.summon_pool.size()]
		if game.spawn_monster_at(mid, free_tiles[i]):
			spawned += 1
	if spawned > 0:
		CombatLog.post("The %s calls for reinforcements!" % summoner.data.display_name,
				Color(1.0, 0.75, 0.3))


static func _find_game() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	return tree.get_first_node_in_group("game")


static func _occupied(pos: Vector2i, self_monster: Monster) -> bool:
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return false
	# Player blocks
	for n in tree.get_nodes_in_group("player"):
		if n is Player and n.grid_pos == pos:
			return true
	for n in tree.get_nodes_in_group("monsters"):
		if n == self_monster:
			continue
		if n is Monster and n.grid_pos == pos:
			return true
	return false
