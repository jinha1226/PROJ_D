extends Node
class_name FloorLifecycle

# Phase 0 extraction from Game.gd. Behavior identical — this module
# borrows the host Game node's state via direct reference. Phase 2 may
# refactor to explicit interfaces.

var host: Node  # the Game node; assigned in setup()

func setup(game_node: Node) -> void:
	host = game_node


func _floor_seed(depth: int) -> int:
	return GameManager.seed * 1009 + depth * 31

func _is_shop_floor(depth: int) -> bool:
	# 5-floor blocks: [1-5], [6-10], [11-15], [16-20]
	# Exclude floor 1 and the last floor of each block (which tends to be boss/transition).
	var block_start: int = ((depth - 1) / 5) * 5 + 1
	var block_end: int = block_start + 4
	if depth == 1 or depth == block_end:
		return false
	# Seeded decision: 70% chance this block has a shop, and if so, which floor.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("shop_block_%d" % block_start)
	if rng.randf() >= 0.70:
		return false  # this block has no shop
	# Pick a floor in [block_start+1, block_end-1] (exclude first and last of block)
	var inner_floors: Array = range(block_start + 1, block_end)  # e.g. [2,3,4] for block [1-5]
	var shop_floor: int = inner_floors[rng.randi() % inner_floors.size()]
	return depth == shop_floor

func _generate_floor(depth: int, map_seed: int,
		arrive_from_above: bool = true) -> void:
	host._abyss_turn_counter = 0
	if GameManager.floor_cache.has(depth):
		_restore_floor_from_cache(depth, arrive_from_above)
	else:
		# Defensive clear protects all entry paths (audit C4). Branch-up exit
		# falls through here when the main-path floor was never cached;
		# without this, the just-vacated branch's monsters/items leak in.
		host._spawn_service._clear_monsters()
		host._spawn_service._clear_floor_items()
		var has_branch: bool = ZoneManager.branch_entrance_for_depth(depth) != ""
		var already_cleared: bool = false
		var bid: String = ZoneManager.branch_entrance_for_depth(depth)
		if has_branch:
			already_cleared = GameManager.branches_cleared.has(bid)
		var zone: Dictionary = ZoneManager.zone_for_depth(depth)
		var zone_style: String = "temple" if depth == 3 else String(zone.get("map_style", "bsp"))
		host.map.generate(map_seed, has_branch and not already_cleared, zone_style)
		if has_branch and not already_cleared:
			var ecfg: Dictionary = ZoneManager.branch_config(bid)
			var etex_path: String = String(ecfg.get("entrance_tile", ""))
			host.map._tex_branch_entrance = load(etex_path) as Texture2D if etex_path != "" else null
		else:
			host.map._tex_branch_entrance = null
		if depth == 3:
			host._place_b3_altars(map_seed)
		host.player.bind_map(host.map, host.map.spawn_pos)
		host._spawn_service._spawn_items_for_floor(depth)
		if depth == 3:
			host._spawn_b3_temple_boss()
		elif depth == 15:
			host._spawn_b15_boss_floor()
		elif String(zone.get("id", "")) == "abyss":
			host._spawn_abyss_floor(depth)
		else:
			host._spawn_service._spawn_monsters_for_floor(depth)
		host._scatter_hazard_tiles(zone.get("env", ""))
		# Shop placement — reset each new floor, then conditionally place.
		host._shop_items = []
		host._shop_tile_pos = Vector2i(-1, -1)
		host._shop_is_special = false
		if _is_shop_floor(depth):
			host._place_shop_tile()
	host._refresh_fov()

func _cache_current_floor() -> void:
	if host.map == null or GameManager == null:
		return
	var state: Dictionary = {
		"tiles": PackedByteArray(host.map.tiles),
		"explored": host.map.explored.duplicate(true),
		"spawn_pos": host.map.spawn_pos,
		"stairs_down_pos": host.map.stairs_down_pos,
		"extra_stairs_down_positions": host.map.extra_stairs_down_positions.duplicate(),
		"stairs_up_pos": host.map.stairs_up_pos,
		"rooms": host.map.rooms.duplicate(),
		"altar_map": host.map.altar_map.duplicate(),
		"broken_altar_positions": host.map.broken_altar_positions.duplicate(),
		"altar_active": host.map.altar_active,
		"items": [],
		"monsters": [],
		"corpses": host.map.corpses.duplicate(true),
		"cloud_tiles": host.map.cloud_tiles.duplicate(true),
		"hazard_tiles": host.map.hazard_tiles.duplicate(true),
		"fog_tiles": host.map.fog_tiles.duplicate(true),
		"shop_items": host._shop_items.duplicate(true),
		"shop_is_special": host._shop_is_special,
		"shop_tile_pos": host._shop_tile_pos,
	}
	for n in host.get_tree().get_nodes_in_group("floor_items"):
		if n is FloorItem and n.data != null:
			state.items.append({
				"id": n.data.id,
				"pos": n.grid_pos,
				"plus": n.plus,
				"entry": n.entry.duplicate(true) if not n.entry.is_empty() else {"id": n.data.id, "plus": n.plus},
			})
	for n in host.get_tree().get_nodes_in_group("monsters"):
		if n is Monster and n.data != null and n.hp > 0:
			var msnap: Dictionary = {
				"id": n.data.id,
				"pos": n.grid_pos,
				"hp": n.hp,
				"status": n.status.duplicate(),
			}
			# Awareness state (audit H9) — preserved across save/load.
			if "is_aware" in n: msnap["is_aware"] = n.is_aware
			if "is_alerted" in n: msnap["is_alerted"] = n.is_alerted
			if "last_known_player_pos" in n: msnap["last_known_player_pos"] = n.last_known_player_pos
			if "pending_energy" in n: msnap["pending_energy"] = n.pending_energy
			if "_ability_charge" in n: msnap["_ability_charge"] = n._ability_charge
			state.monsters.append(msnap)
	GameManager.floor_cache[GameManager.depth] = state

func _restore_floor_from_cache(depth: int, arrive_from_above: bool) -> void:
	# Defensive clear protects all entry paths. Idempotent — empty groups are fine.
	# Fixes audit C4 (branch 1F-up exit was leaking branch monsters/items into main dungeon).
	host._spawn_service._clear_monsters()
	host._spawn_service._clear_floor_items()
	var state: Dictionary = GameManager.floor_cache[depth]
	host.map.tiles = state.tiles
	host.map.explored = state.explored.duplicate(true)
	host.map.spawn_pos = state.spawn_pos
	host.map.stairs_down_pos = state.stairs_down_pos
	host.map.extra_stairs_down_positions = state.get("extra_stairs_down_positions", []).duplicate()
	host.map.stairs_up_pos = state.stairs_up_pos
	host.map.rooms = state.rooms.duplicate()
	host.map.altar_map = state.get("altar_map", {}).duplicate()
	host.map.broken_altar_positions = state.get("broken_altar_positions", []).duplicate()
	host.map.altar_active = bool(state.get("altar_active", false))
	host.map.visible_tiles.clear()
	host.map.corpses = state.get("corpses", []).duplicate(true)
	# Disk-loaded corpses lack the runtime Texture2D (not JSON-safe).
	# Rebuild from monster_id; fallback to glyph if id is missing or unknown.
	for corpse in host.map.corpses:
		if not (corpse is Dictionary):
			continue
		if corpse.get("tile", null) != null:
			continue
		var mid: String = String(corpse.get("monster_id", ""))
		if mid == "":
			continue
		if host._corpse_tex_cache.has(mid):
			corpse["tile"] = host._corpse_tex_cache[mid]
			continue
		var mdata: MonsterData = MonsterRegistry.get_by_id(mid) if MonsterRegistry != null else null
		if mdata != null:
			var tex: Texture2D = host._effects_layer._build_corpse_texture(mdata)
			host._corpse_tex_cache[mid] = tex
			corpse["tile"] = tex
	host.map.cloud_tiles = state.get("cloud_tiles", {}).duplicate(true)
	host.map.hazard_tiles = state.get("hazard_tiles", {}).duplicate(true)
	host.map.fog_tiles = state.get("fog_tiles", {}).duplicate(true)
	# Restore shop state.
	host._shop_items = state.get("shop_items", []).duplicate(true)
	host._shop_is_special = bool(state.get("shop_is_special", false))
	host._shop_tile_pos = state.get("shop_tile_pos", Vector2i(-1, -1))
	if host._shop_tile_pos != Vector2i(-1, -1):
		host.map.set_tile(host._shop_tile_pos, DungeonMap.Tile.SHOP)
	host.map._load_atmosphere(depth)
	host.map.queue_redraw()
	var arrival: Vector2i = host.map.stairs_up_pos if arrive_from_above \
			else host.map.stairs_down_pos
	host.player.bind_map(host.map, arrival)
	for entry in state.items:
		var item_entry: Dictionary = entry.get("entry", {"id": String(entry.get("id", "")), "plus": int(entry.get("plus", 0))})
		var d: ItemData = ItemRegistry.get_by_id(String(item_entry.get("id", ""))) if ItemRegistry != null else null
		if d == null:
			continue
		var p: Vector2i = entry.get("pos", Vector2i.ZERO)
		if p == host.player.grid_pos:
			continue  # Don't spawn item under player on arrival.
		host._spawn_service._spawn_floor_item(d, p, int(item_entry.get("plus", 0)), item_entry)
	for entry in state.monsters:
		var md: MonsterData = MonsterRegistry.get_by_id(
				String(entry.get("id", "")))
		if md == null:
			continue
		var p: Vector2i = entry.get("pos", Vector2i.ZERO)
		if p == host.player.grid_pos:
			continue  # Skip monster that would spawn on top of player.
		var m: Monster = host.MonsterScene.new()
		host.monsters_layer.add_child(m)
		m.setup(md, host.map, p)
		m.hp = int(entry.get("hp", md.hp))
		m.status = entry.get("status", {}).duplicate()
		# Restore awareness state if present (audit H9). Old caches lack these
		# keys; .has() guards keep behavior unchanged for in-memory restores.
		if entry.has("is_aware"): m.is_aware = bool(entry["is_aware"])
		if entry.has("is_alerted"): m.is_alerted = bool(entry["is_alerted"])
		if entry.has("last_known_player_pos"):
			var lkp = entry["last_known_player_pos"]
			if lkp is Vector2i: m.last_known_player_pos = lkp
		if entry.has("pending_energy"): m.pending_energy = float(entry["pending_energy"])
		if entry.has("_ability_charge"): m._ability_charge = (entry["_ability_charge"] as Dictionary).duplicate(true) if entry["_ability_charge"] is Dictionary else {}
		if m.has_signal("hit_taken"):
			m.hit_taken.connect(host._on_monster_hit.bind(m))
		if m.has_signal("awareness_changed"):
			m.awareness_changed.connect(host._on_monster_awareness_changed)
		m.died.connect(host._on_monster_died)
		TurnManager.register_actor(m)
		host._spawn_service._roll_monster_weapon(m)
	# Top up to full population on revisit so a previously-cleared floor isn't
	# empty for ~18 turns waiting on _try_respawn_monster's drip-feed.
	_top_up_monsters_to_target(depth)

func _top_up_monsters_to_target(depth: int) -> void:
	if host.map == null or host.player == null:
		return
	var target: int = host._spawn_service._monster_count_for_depth(depth)
	var current: int = host.get_tree().get_nodes_in_group("monsters").size()
	if current >= target:
		return
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	var attempts: int = 0
	while current < target and attempts < 400:
		attempts += 1
		var p: Vector2i = host.map.random_floor_tile(rng)
		if not host.map.is_walkable(p):
			continue
		if p == host.player.grid_pos:
			continue
		if host._chebyshev(p, host.player.grid_pos) < 6:
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
		host._spawn_service._roll_monster_weapon(m)
		current += 1
