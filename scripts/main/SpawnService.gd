extends Node
class_name SpawnService

# Phase 0 extraction from Game.gd. Hosts spawn/clear of monsters and
# floor items for the active dungeon floor. Branch/boss/temple-specific
# spawners stay in Game.gd because Phase 1/2 will delete or reshape them.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node


func _spawn_items_layer() -> void:
	host.items_layer = Node2D.new()
	host.items_layer.name = "Items"
	host.add_child(host.items_layer)

func _spawn_monsters_layer() -> void:
	host.monsters_layer = Node2D.new()
	host.monsters_layer.name = "Monsters"
	host.add_child(host.monsters_layer)

func _spawn_npcs_layer() -> void:
	host.npcs_layer = Node2D.new()
	host.npcs_layer.name = "NPCs"
	host.add_child(host.npcs_layer)

func _spawn_unique_for_floor(depth: int, rng: RandomNumberGenerator) -> void:
	var unique_data: MonsterData = MonsterRegistry.unique_for_depth(depth)
	if unique_data == null:
		return
	# Only spawn on the last floor of the sector (floor_in_sector == 2) so
	# the player has a chance to prepare across the first two floors.
	var floor_in_sector: int = (depth - 1) % 3
	if floor_in_sector != 2:
		return
	var attempts: int = 0
	while attempts < 200:
		attempts += 1
		var p: Vector2i = host.map.random_floor_tile(rng)
		if not host.map.is_walkable(p):
			continue
		if p == host.player.grid_pos:
			continue
		if host._chebyshev(p, host.player.grid_pos) < 5:
			continue
		if host._monster_at(p) != null:
			continue
		var m: Monster = host.MonsterScene.new()
		host.monsters_layer.add_child(m)
		m.setup(unique_data, host.map, p)
		m.hit_taken.connect(host._on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(host._on_monster_awareness_changed)
		m.died.connect(host._on_monster_died)
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
		CombatLog.post(LocaleManager.t("LOG_A_DANGEROUS_PRESENCE_LURKS_ON"), Color(1.0, 0.75, 0.3))
		return

## Spawns floor monsters using two-axis placement:
##   • Difficulty gradient — rooms farther from the entry get stronger themes.
##   • Room coherence    — 80 % of monsters in a room share the same theme type.
##
## Flow: sort rooms by distance → assign zone (near/mid/far) → pick one
## "theme" MonsterData per room (zone-appropriate strength) → fill each room.
func _spawn_monsters_for_floor(depth: int) -> void:
	var count: int = _monster_count_for_depth(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = host._floor_lifecycle._floor_seed(depth) ^ 0x5A5A5A5A
	_spawn_unique_for_floor(depth, rng)
	if count == 0:
		return
	var zone_id: String = ZoneManager.zone_id_for_depth(depth)
	if not MapDistrictRules.districts(zone_id).is_empty():
		_spawn_monsters_for_districts(depth, zone_id, count, rng, false)
		_spawn_stair_guardian_for_floor(depth, rng)
		return
	if host.map.rooms.is_empty():
		_spawn_stair_guardian_for_floor(depth, rng)
		return

	# ── 1. Sort rooms by Chebyshev distance from spawn (entry) ───────────────
	var entry: Vector2i = host.map.spawn_pos
	var sorted_rooms: Array = host.map.rooms.duplicate()
	sorted_rooms.sort_custom(func(a: Rect2i, b: Rect2i) -> bool:
		return host._chebyshev(a.get_center(), entry) < \
			   host._chebyshev(b.get_center(), entry))
	var n_rooms: int = sorted_rooms.size()

	# ── 2. Assign a zone and a theme monster to each room ─────────────────────
	# zone 0 = near entry (weak), zone 1 = mid, zone 2 = far exit (strong).
	var room_themes: Array = []   # MonsterData or null per room
	for ri in range(n_rooms):
		var zone: int = (ri * 3) / n_rooms           # 0, 1, or 2
		var theme_seed: int = host._floor_lifecycle._floor_seed(depth) \
				^ (ri * 0x7777 + depth * 0x1234)
		room_themes.append(_pick_theme_for_zone(depth, zone, theme_seed))

	# ── 3. Distribute monster budget proportional to room area ───────────────
	var total_area: float = 0.0
	for room in sorted_rooms:
		total_area += float(room.get_area())
	var room_budgets: Array = []
	var distributed: int = 0
	for ri in range(n_rooms):
		var frac: float = float(sorted_rooms[ri].get_area()) / max(1.0, total_area)
		var budget: int = max(0, int(round(float(count) * frac)))
		room_budgets.append(budget)
		distributed += budget
	# Assign leftovers to the farthest rooms first (they get the strongest monsters).
	var leftover: int = count - distributed
	var ri_left: int = n_rooms - 1
	while leftover > 0 and ri_left >= 0:
		room_budgets[ri_left] += 1
		leftover -= 1
		ri_left -= 1

	# ── 4. Place monsters room by room ───────────────────────────────────────
	for ri in range(n_rooms):
		var room: Rect2i = sorted_rooms[ri]
		var theme: MonsterData = room_themes[ri]
		var need: int = room_budgets[ri]
		if need == 0:
			continue
		var placed: int = 0
		var attempts: int = 0
		while placed < need and attempts < 300:
			attempts += 1
			var px: int = rng.randi_range(room.position.x,
					room.position.x + room.size.x - 1)
			var py: int = rng.randi_range(room.position.y,
					room.position.y + room.size.y - 1)
			var p := Vector2i(px, py)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			if host._chebyshev(p, host.player.grid_pos) < 3:
				continue
			if host._monster_at(p) != null:
				continue
			# 80 % theme coherence, 20 % wildcard for variety.
			var use_theme: bool = theme != null and rng.randf() < 0.8
			var data: MonsterData = theme if use_theme \
					else MonsterRegistry.pick_by_depth(depth)
			if data == null:
				continue
			_do_place_monster(data, p)
			placed += 1
	_spawn_stair_guardian_for_floor(depth, rng)

func _spawn_monsters_for_districts(depth: int, zone_id: String, count: int,
		rng: RandomNumberGenerator, branch_pool: bool = false) -> void:
	var districts: Array = MapDistrictRules.districts(zone_id)
	var weighted: Array = []
	var total_weight: int = 0
	for d in districts:
		var role: String = String(d.get("role", ""))
		var weight: int = _district_monster_weight(role)
		if weight <= 0:
			continue
		weighted.append([d, weight])
		total_weight += weight
	if weighted.is_empty():
		return
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < count * 120:
		attempts += 1
		var district: Dictionary = _weighted_district_pick(weighted, total_weight, rng)
		var role: String = String(district.get("role", ""))
		var p: Vector2i = MapDistrictRules.pick_tile(host.map, zone_id, [role], rng)
		if p == Vector2i(-1, -1):
			continue
		if not host.map.is_walkable(p):
			continue
		if p == host.player.grid_pos:
			continue
		if host._chebyshev(p, host.player.grid_pos) < 3:
			continue
		if host._monster_at(p) != null:
			continue
		var data: MonsterData = MonsterRegistry.pick_by_branch(zone_id, depth) if branch_pool \
				else _pick_theme_for_zone(depth, _district_threat_zone(role), rng.randi())
		if data == null:
			continue
		_do_place_monster(data, p)
		placed += 1

func _spawn_stair_guardian_for_floor(depth: int, rng: RandomNumberGenerator) -> void:
	const GUARDIANS: Dictionary = {
		1: "stair_warden",
		2: "mire_channeler",
		3: "mine_breaker",
		4: "mirror_adept",
	}
	var guardian_id: String = String(GUARDIANS.get(depth, ""))
	if guardian_id == "":
		return
	var data: MonsterData = MonsterRegistry.get_by_id(guardian_id)
	if data == null:
		push_warning("Stair guardian not found: %s" % guardian_id)
		return
	var stair_positions: Array[Vector2i] = host._all_down_stairs_positions()
	var anchor: Vector2i = host.map.stairs_down_pos
	if not stair_positions.is_empty():
		anchor = stair_positions[0]
	var pos: Vector2i = _find_guardian_pos_near(anchor, rng)
	if pos == Vector2i(-1, -1):
		return
	var m: Monster = _do_place_monster(data, pos)
	if m != null:
		CombatLog.post("A stair guardian waits near the descent.", Color(1.0, 0.75, 0.35))

func _find_guardian_pos_near(anchor: Vector2i, rng: RandomNumberGenerator) -> Vector2i:
	for radius in range(1, 6):
		var candidates: Array[Vector2i] = []
		for dy in range(-radius, radius + 1):
			for dx in range(-radius, radius + 1):
				if max(abs(dx), abs(dy)) != radius:
					continue
				var p := anchor + Vector2i(dx, dy)
				if not host.map.in_bounds(p):
					continue
				if host.map.is_reserved_feature_tile(p):
					continue
				if not host.map.is_walkable(p):
					continue
				if p == host.player.grid_pos:
					continue
				if host._monster_at(p) != null:
					continue
				candidates.append(p)
		if not candidates.is_empty():
			return candidates[rng.randi_range(0, candidates.size() - 1)]
	return Vector2i(-1, -1)

func _district_monster_weight(role: String) -> int:
	match role:
		"entry":
			return 1
		"skill", "reward":
			return 2
		"pressure", "hazard", "branch", "exit":
			return 4
		_:
			return 2

func _district_threat_zone(role: String) -> int:
	match role:
		"entry":
			return 0
		"skill", "reward":
			return 1
		_:
			return 2

func _weighted_district_pick(weighted: Array, total_weight: int,
		rng: RandomNumberGenerator) -> Dictionary:
	var roll: int = rng.randi_range(0, total_weight - 1)
	var acc: int = 0
	for entry in weighted:
		acc += int(entry[1])
		if roll < acc:
			return entry[0]
	return weighted[-1][0]

## Picks one representative MonsterData for a room zone.
## zone 0 → prefers weak monsters (xp ≤ 2)
## zone 1 → prefers medium monsters (xp 3–4)
## zone 2 → prefers strong monsters (xp ≥ 5)
## Falls back to any depth-appropriate monster if the zone filter yields nothing.
func _pick_theme_for_zone(depth: int, zone: int, seed: int) -> MonsterData:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed
	var best: MonsterData = null
	for _i in range(8):
		var data: MonsterData = MonsterRegistry.pick_by_depth(depth)
		if data == null:
			continue
		var fits: bool
		match zone:
			0: fits = data.xp_value <= 2
			1: fits = data.xp_value >= 3 and data.xp_value <= 4
			_: fits = data.xp_value >= 5
		if fits:
			return data       # first match wins; seeded rng gives deterministic variety
		if best == null:
			best = data       # keep first candidate as fallback
	return best               # fallback if no zone-appropriate monster found

func _do_place_monster(data: MonsterData, p: Vector2i) -> Monster:
	var m: Monster = host.MonsterScene.new()
	host.monsters_layer.add_child(m)
	m.setup(data, host.map, p)
	m.hit_taken.connect(host._on_monster_hit.bind(m))
	if m.has_signal("awareness_changed"):
		m.awareness_changed.connect(host._on_monster_awareness_changed)
	m.died.connect(host._on_monster_died)
	TurnManager.register_actor(m)
	_roll_monster_weapon(m)
	return m

func _spawn_items_for_floor(depth: int) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = host._floor_lifecycle._floor_seed(depth) ^ 0x3C3C3C3C

	# Build the item list to place this floor.
	var to_place: Array[ItemData] = []
	var essence_to_place: Array[String] = []

	# ── Per-floor random drops ──────────────────────────────────────────
	for _i in range(rng.randi_range(1, 3)):
		var d: ItemData = ItemRegistry.pick_kind(depth, "potion")
		if d != null: to_place.append(d)
	for _i in range(rng.randi_range(1, 3)):
		var d: ItemData = ItemRegistry.pick_kind(depth, "scroll")
		if d != null: to_place.append(d)
	for _i in range(rng.randi_range(1, 2)):
		var d: ItemData = ItemRegistry.pick_equipment_weighted(depth)
		if d != null: to_place.append(d)

	# ~1 full school book per 10 floors (10% chance, reduced from 40%)
	if rng.randf() < 0.10:
		var d: ItemData = ItemRegistry.pick_kind(depth, "book")
		if d != null: to_place.append(d)

	# ~3 in 10 floors: partial spellbook with 2–3 depth-appropriate spells
	var partial_books_to_place: Array = []
	if rng.randf() < 0.30:
		if ItemRegistry != null:
			partial_books_to_place.append(ItemRegistry.generate_partial_book(depth))

	# ~2 in 10 floors: random spellpage
	var spellpages_to_place: Array[ItemData] = []
	if rng.randf() < 0.20:
		var sp: ItemData = ItemRegistry.pick_random_spellpage(depth) if ItemRegistry != null else null
		if sp != null: spellpages_to_place.append(sp)

	# ── Sector guaranteed drops (sector = 3-floor block) ───────────────
	# Sector total: enchant_weapon ×1, enchant_armor ×1, wand 1-2, healing 2-3, essence ×2
	var floor_in_sector: int = (depth - 1) % 3  # 0, 1, or 2
	if floor_in_sector == 0:
		# Floor 1: healing + enchant_weapon + wand + essence
		to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		to_place.append(ItemRegistry.get_by_id("scroll_enchant_weapon") if ItemRegistry != null else null)
		var wd: ItemData = ItemRegistry.pick_kind(depth, "wand") if ItemRegistry != null else null
		if wd != null: to_place.append(wd)
		essence_to_place.append(EssenceSystem.random_id())
	elif floor_in_sector == 1:
		# Floor 2: healing + enchant_armor + essence
		to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		to_place.append(ItemRegistry.get_by_id("scroll_enchant_armor") if ItemRegistry != null else null)
		essence_to_place.append(EssenceSystem.random_id())
	else:
		# Floor 3: 50% extra healing + 50% upgrade scroll + 50% wand
		if rng.randf() < 0.5:
			to_place.append(ItemRegistry.get_by_id("potion_healing") if ItemRegistry != null else null)
		if rng.randf() < 0.5:
			to_place.append(ItemRegistry.get_by_id("scroll_upgrade") if ItemRegistry != null else null)
		if rng.randf() < 0.5:
			var wd: ItemData = ItemRegistry.pick_kind(depth, "wand") if ItemRegistry != null else null
			if wd != null: to_place.append(wd)

	# ── Place all items on district-biased floor tiles ──────────────────
	var zone_id: String = ZoneManager.zone_id_for_depth(depth)
	for item in to_place:
		if item == null:
			continue
		var p: Vector2i = _pick_item_tile(rng, zone_id, _preferred_item_roles(item))
		if p != Vector2i(-1, -1):
			var entry_override: Dictionary = ItemRegistry.make_entry(item.id, depth, 0) if ItemRegistry != null else {"id": item.id, "plus": 0}
			_spawn_floor_item(item, p, 0, entry_override)
	for essence_id in essence_to_place:
		var p: Vector2i = _pick_item_tile(rng, zone_id, ["reward", "skill", "branch"])
		if p != Vector2i(-1, -1):
			_spawn_essence_floor_item(String(essence_id), p)
	for partial_entry in partial_books_to_place:
		var p: Vector2i = _pick_item_tile(rng, zone_id, ["reward", "skill", "exit"])
		if p != Vector2i(-1, -1):
			_spawn_partial_book_floor_item(partial_entry, p)
	for sp_data in spellpages_to_place:
		var p: Vector2i = _pick_item_tile(rng, zone_id, ["reward", "skill", "exit"])
		if p != Vector2i(-1, -1):
			var sp_entry: Dictionary = {"id": sp_data.id, "plus": 0}
			_spawn_floor_item(sp_data, p, 0, sp_entry)

	# ── Gold scatter: 1-3 piles per floor ─────────────────────────────
	var gold_count: int = rng.randi_range(1, 3)
	for _gi in range(gold_count):
		var p: Vector2i = _pick_item_tile(rng, zone_id, ["reward", "skill"])
		if p != Vector2i(-1, -1):
			_spawn_gold_pile(p, rng.randi_range(5, 10 + depth * 2))

	# ── Orc treasure room for depths 7-9 ──────────────────────────────
	host._spawn_orc_treasure_room(depth, rng)

func _preferred_item_roles(item: ItemData) -> Array:
	match item.kind:
		"weapon", "armor", "shield", "wand", "book":
			return ["reward", "skill", "exit"]
		"scroll":
			if item.effect in ["enchant_weapon", "enchant_armor", "upgrade"]:
				return ["reward", "skill"]
			return ["skill", "reward", "entry"]
		"potion":
			return ["entry", "skill", "reward"]
		_:
			return ["reward", "skill", "pressure"]

func _pick_item_tile(rng: RandomNumberGenerator, zone_id: String,
		preferred_roles: Array) -> Vector2i:
	var forbidden: Dictionary = {}
	if host.player != null:
		forbidden[host.player.grid_pos] = true
	for p in host.map.prop_tile_paths.keys():
		forbidden[p] = true
	for _i in range(50):
		var p: Vector2i = MapDistrictRules.pick_tile(host.map, zone_id,
				preferred_roles, rng, forbidden)
		if p == Vector2i(-1, -1):
			break
		if host._item_at(p) == null:
			return p
		forbidden[p] = true
	for _i in range(40):
		var p: Vector2i = host.map.random_floor_tile(rng)
		if not host.map.is_walkable(p):
			continue
		if forbidden.has(p):
			continue
		if host._item_at(p) != null:
			continue
		return p
	return Vector2i(-1, -1)

func spawn_ally(monster_id: String, near_pos: Vector2i, turns: int) -> bool:
	if host.map == null or host.monsters_layer == null:
		return false
	var md: MonsterData = MonsterRegistry.get_by_id(monster_id)
	if md == null:
		return false
	# Find an open adjacent tile
	var offsets: Array = [Vector2i(1,0), Vector2i(-1,0), Vector2i(0,1), Vector2i(0,-1),
		Vector2i(1,1), Vector2i(-1,1), Vector2i(1,-1), Vector2i(-1,-1)]
	var spawn_at: Vector2i = Vector2i(-1, -1)
	for off in offsets:
		var p: Vector2i = near_pos + off
		if host.map.is_walkable(p) and host._monster_at(p) == null and p != host.player.grid_pos:
			spawn_at = p
			break
	if spawn_at == Vector2i(-1, -1):
		return false
	var m: Monster = host.MonsterScene.new()
	host.monsters_layer.add_child(m)
	m.setup(md, host.map, spawn_at)
	m.is_ally = true
	m.ally_turns_left = turns
	m.hit_taken.connect(host._on_monster_hit.bind(m))
	m.died.connect(host._on_monster_died)
	TurnManager.register_actor(m)
	host.map.queue_redraw()
	return true

## Spawn a hostile monster at an exact tile (used by summoner AI).
func spawn_monster_at(monster_id: String, pos: Vector2i) -> bool:
	if host.map == null or host.monsters_layer == null:
		return false
	var md: MonsterData = MonsterRegistry.get_by_id(monster_id)
	if md == null:
		return false
	if not host.map.is_walkable(pos) or host._monster_at(pos) != null or pos == host.player.grid_pos:
		return false
	var m: Monster = host.MonsterScene.new()
	host.monsters_layer.add_child(m)
	m.setup(md, host.map, pos)
	m.become_aware(host.player.grid_pos)
	m.hit_taken.connect(host._on_monster_hit.bind(m))
	m.died.connect(host._on_monster_died)
	m.awareness_changed.connect(host._on_monster_awareness_changed)
	_roll_monster_weapon(m)
	TurnManager.register_actor(m)
	host.map.queue_redraw()
	return true


func _roll_monster_weapon(monster: Monster) -> void:
	if monster.data == null:
		return
	var pool_entry = host._MONSTER_WEAPON_POOLS.get(monster.data.id, null)
	if pool_entry == null:
		return
	var normal_pool: Array = pool_entry[0]
	var rare_pool: Array = pool_entry[1]
	# 5% chance for branded/rare weapon
	var weapon_id: String = ""
	if not rare_pool.is_empty() and randf() < 0.05:
		weapon_id = rare_pool[randi() % rare_pool.size()]
	elif not normal_pool.is_empty():
		weapon_id = normal_pool[randi() % normal_pool.size()]
	monster.equipped_weapon_id = weapon_id

func _spawn_floor_item(data: ItemData, pos: Vector2i, plus: int, entry_override: Dictionary = {}) -> void:
	if host.items_layer == null:
		return
	var fi: FloorItem = host.FloorItemScene.new()
	host.items_layer.add_child(fi)
	fi.setup(data, host.map, pos, plus, entry_override)

func _spawn_essence_floor_item(essence_id: String, pos: Vector2i) -> void:
	if ItemRegistry == null or essence_id == "":
		return
	var data: ItemData = ItemRegistry.get_by_id("essence_shard")
	if data == null:
		return
	_spawn_floor_item(data, pos, 0, {"id": "essence_shard", "plus": 0, "essence_id": essence_id})

# Spawns a partial book at pos using a base book ItemData but overriding the
# entry dict so Player.use_item reads grants_spell_ids from the entry.
func _spawn_partial_book_floor_item(partial_entry: Dictionary, pos: Vector2i) -> void:
	if ItemRegistry == null or host.items_layer == null:
		return
	# Use book_partial as the base ItemData carrier (kind, effect, glyph are correct).
	var base_data: ItemData = ItemRegistry.get_by_id("book_partial")
	if base_data == null:
		return
	var fi: FloorItem = host.FloorItemScene.new()
	host.items_layer.add_child(fi)
	fi.setup(base_data, host.map, pos, 0, partial_entry)

## Spawns a gold pile floor item with a custom amount.
## Uses gold_pile as the ItemData carrier; Player.pickup reads entry["amount"].
func _spawn_gold_pile(pos: Vector2i, amount: int) -> void:
	if ItemRegistry == null or host.items_layer == null:
		return
	var base_data: ItemData = ItemRegistry.get_by_id("gold_pile")
	if base_data == null:
		return
	var entry: Dictionary = {
		"id": "gold_pile",
		"kind": "gold",
		"amount": amount,
		"plus": 0,
	}
	var fi: FloorItem = host.FloorItemScene.new()
	host.items_layer.add_child(fi)
	fi.setup(base_data, host.map, pos, 0, entry)

func _find_item_drop_pos(origin: Vector2i) -> Vector2i:
	if host.map == null:
		return origin
	if host.map.is_walkable(origin) and host._monster_at(origin) == null and origin != host.player.grid_pos:
		return origin
	var offsets: Array = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(-1, 1), Vector2i(1, -1), Vector2i(-1, -1),
	]
	for off in offsets:
		var p: Vector2i = origin + off
		if host.map.is_walkable(p) and host._monster_at(p) == null and p != host.player.grid_pos:
			return p
	return origin

func _monster_count_for_depth(d: int) -> int:
	if d <= 1:
		return randi_range(7, 10)
	if d <= 5:
		return randi_range(8, 12)
	if d <= 15:
		return randi_range(11, 15)
	return randi_range(10, 14)

func _spawn_npcs_for_floor(count: int = 10) -> void:
	if not host.get("npcs_layer"):
		return
	# Only spawn on real dungeon floors — skip shop, town, and branch 1F
	if GameManager.depth < 1 or GameManager.branch_zone != "":
		return
	var rng := RandomNumberGenerator.new()
	rng.seed = host._floor_lifecycle._floor_seed(GameManager.depth) ^ 0xABCDABCD
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = host.map.random_floor_tile(rng)
		if not host.map.is_walkable(p):
			continue
		if p == host.player.grid_pos:
			continue
		if host._chebyshev(p, host.player.grid_pos) < 5:
			continue
		if host._monster_at(p) != null:
			continue
		var npc := ExplorerNPC.new()
		host.npcs_layer.add_child(npc)
		npc.setup(host.map, p)
		npc.died.connect(_on_npc_died.bind(npc))
		TurnManager.register_actor(npc)
		placed += 1

func _on_npc_died(npc: NPCActor) -> void:
	TurnManager.unregister_actor(npc)
	npc.remove_from_group("npcs")
	var tw := npc.create_tween()
	tw.tween_property(npc, "modulate:a", 0.0, 0.15)
	tw.tween_callback(npc.queue_free)

func _clear_monsters() -> void:
	for n in host.get_tree().get_nodes_in_group("monsters"):
		TurnManager.unregister_actor(n)
		n.remove_from_group("monsters")
		n.queue_free()

func _clear_npcs() -> void:
	for n in host.get_tree().get_nodes_in_group("npcs"):
		TurnManager.unregister_actor(n)
		n.remove_from_group("npcs")
		n.queue_free()

func _clear_floor_items() -> void:
	for n in host.get_tree().get_nodes_in_group("floor_items"):
		n.remove_from_group("floor_items")
		n.queue_free()
