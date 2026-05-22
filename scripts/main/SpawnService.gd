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

func _spawn_monsters_for_floor(depth: int) -> void:
	var count: int = _monster_count_for_depth(depth)
	var rng := RandomNumberGenerator.new()
	rng.seed = host._floor_lifecycle._floor_seed(depth) ^ 0x5A5A5A5A
	_spawn_unique_for_floor(depth, rng)
	var placed: int = 0
	var attempts: int = 0
	while placed < count and attempts < 800:
		attempts += 1
		var p: Vector2i = host.map.random_floor_tile(rng)
		if not host.map.is_walkable(p):
			continue
		if p == host.player.grid_pos:
			continue
		if host._chebyshev(p, host.player.grid_pos) < 3:
			continue
		if host._monster_at(p) != null:
			continue
		var data: MonsterData = MonsterRegistry.pick_by_depth(depth)
		if data == null:
			return
		var m: Monster = host.MonsterScene.new()
		host.monsters_layer.add_child(m)
		m.setup(data, host.map, p)
		m.hit_taken.connect(host._on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(host._on_monster_awareness_changed)
		m.died.connect(host._on_monster_died)
		TurnManager.register_actor(m)
		_roll_monster_weapon(m)
		placed += 1

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

	# ── Place all items on random floor tiles ───────────────────────────
	for item in to_place:
		if item == null:
			continue
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = host.map.random_floor_tile(rng)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			if host._item_at(p) != null:
				continue
			var entry_override: Dictionary = ItemRegistry.make_entry(item.id, depth, 0) if ItemRegistry != null else {"id": item.id, "plus": 0}
			_spawn_floor_item(item, p, 0, entry_override)
			break
	for essence_id in essence_to_place:
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = host.map.random_floor_tile(rng)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			if host._item_at(p) != null:
				continue
			_spawn_essence_floor_item(String(essence_id), p)
			break
	for partial_entry in partial_books_to_place:
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = host.map.random_floor_tile(rng)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			if host._item_at(p) != null:
				continue
			_spawn_partial_book_floor_item(partial_entry, p)
			break
	for sp_data in spellpages_to_place:
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = host.map.random_floor_tile(rng)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			if host._item_at(p) != null:
				continue
			var sp_entry: Dictionary = {"id": sp_data.id, "plus": 0}
			_spawn_floor_item(sp_data, p, 0, sp_entry)
			break

	# ── Gold scatter: 1-3 piles per floor ─────────────────────────────
	var gold_count: int = rng.randi_range(1, 3)
	for _gi in range(gold_count):
		var attempts: int = 0
		while attempts < 40:
			attempts += 1
			var p: Vector2i = host.map.random_floor_tile(rng)
			if not host.map.is_walkable(p):
				continue
			if p == host.player.grid_pos:
				continue
			_spawn_gold_pile(p, rng.randi_range(5, 10 + depth * 2))
			break

	# ── Orc treasure room for depths 7-9 ──────────────────────────────
	host._spawn_orc_treasure_room(depth, rng)

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
	if d <= 5:
		return randi_range(7, 10)
	if d <= 15:
		return randi_range(10, 14)
	return randi_range(9, 13)

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
