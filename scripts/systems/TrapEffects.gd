class_name TrapEffects
extends RefCounted
## Trap-effect resolver, extracted from GameBootstrap._trigger_trap.
##
## Each trap type is a small static handler; `trigger(ctx)` is the
## entry point the GameBootstrap dispatcher calls once it has pulled
## the trap's type + depth out of `generator.traps`.
##
## Static-module pattern: no scene-tree access in here. Callers pass
## the player node, generator, dungeon map, trap tile, and two
## callables for the cross-cutting side effects that can't live in a
## pure module (floor descent, hostile spawns). Autoloads
## (`CombatLog`, `GameManager`, `MonsterAI`) are fair game — they're
## globally resolvable in Godot 4.

const TILE_SIZE: int = 64


## Resolve one trap. `ctx` shape:
##   player: Player node
##   generator: DungeonGenerator
##   dmap: DungeonMap (for FOV / redraw after teleport)
##   tree: SceneTree (for noise broadcast)
##   pos: Vector2i trap tile
##   ttype: String — trap type tag ("dart" / "arrow" / ...)
##   depth: int — depth at placement, for damage scaling
##   max_depth: int — ceiling for shaft drop
##   regenerate_dungeon: Callable(going_up: bool, secondary: bool)
##   spawn_hostile: Callable(monster_id: String, center: Vector2i)
static func trigger(ctx: Dictionary) -> void:
	var player = ctx.get("player", null)
	var generator = ctx.get("generator", null)
	if player == null or generator == null:
		return
	var ttype: String = String(ctx.get("ttype", ""))
	var depth: int = int(ctx.get("depth", 1))
	var pos: Vector2i = ctx.get("pos", Vector2i.ZERO)
	match ttype:
		"dart":     _mechanical_dart(player, depth)
		"arrow":    _mechanical_arrow(player, depth)
		"spear":    _mechanical_spear(player, depth)
		"bolt":     _mechanical_bolt(player, depth)
		"teleport": _teleport_trap(player)
		"shaft":    _shaft_trap(player, ctx)
		"alarm":    _alarm_trap(ctx, pos)
		"net":      _net_trap(player)
		"zot":      _zot_trap(player, depth, ctx)
		"golubria": _golubria_trap(player, generator, ctx)
		_:
			CombatLog.add("A trap triggers, but nothing happens.")


# ---- Mechanical traps -----------------------------------------------------

static func _mechanical_dart(player, depth: int) -> void:
	var d: int = 1 + randi() % max(3 + depth / 3, 3)
	player.take_damage(d, "physical")
	if player.has_method("apply_poison"):
		player.apply_poison(1, "a dart")
	CombatLog.add("A poisoned dart hits you for %d!" % d)


static func _mechanical_arrow(player, depth: int) -> void:
	var a: int = 1 + randi() % max(4 + depth / 3, 4)
	player.take_damage(a, "physical")
	CombatLog.add("An arrow thuds into you! (%d dmg)" % a)


static func _mechanical_spear(player, depth: int) -> void:
	var s: int = 1 + randi() % max(6 + depth / 3, 6)
	player.take_damage(s, "physical")
	CombatLog.add("A spear stabs you! (%d dmg)" % s)


static func _mechanical_bolt(player, depth: int) -> void:
	var b: int = 1 + randi() % max(5 + depth / 3, 5)
	player.take_damage(b, "physical")
	CombatLog.add("A crossbow bolt fires into you! (%d dmg)" % b)


# ---- Magical traps --------------------------------------------------------

## Random teleport with a ≥6-tile displacement guarantee. Mirrors
## DCSS trap.cc trap_effect: retry up to 20 times, then fall through
## to a plain random teleport if nothing within the attempt budget
## landed far enough.
static func _teleport_trap(player) -> void:
	CombatLog.add("Space wobbles — you are teleported!")
	if not player.has_method("_teleport_random"):
		return
	var old_pos: Vector2i = player.grid_pos
	for _attempt in 20:
		player._teleport_random()
		var dx_t: int = abs(player.grid_pos.x - old_pos.x)
		var dy_t: int = abs(player.grid_pos.y - old_pos.y)
		if maxi(dx_t, dy_t) >= 6:
			return
	player._teleport_random()


## Shaft drops 1-3 floors. Uses the stairs-down pipeline so floor
## state persistence (kills-stay-dead, items stay gone) still works.
static func _shaft_trap(player, ctx: Dictionary) -> void:
	var max_depth: int = int(ctx.get("max_depth", 25))
	var depth_drop: int = 1 + randi() % 3
	var target_depth: int = mini(max_depth, GameManager.current_depth + depth_drop)
	if target_depth <= GameManager.current_depth:
		CombatLog.add("The floor gives way, but you catch yourself!")
		return
	CombatLog.add("The floor collapses — you plunge %d floors!" % \
			(target_depth - GameManager.current_depth))
	GameManager.current_depth = target_depth
	var regen: Callable = ctx.get("regenerate_dungeon", Callable())
	if regen.is_valid():
		regen.call(false, false)


static func _alarm_trap(ctx: Dictionary, pos: Vector2i) -> void:
	CombatLog.add("An alarm blares!")
	var tree = ctx.get("tree", null)
	if tree != null:
		MonsterAI.broadcast_noise(tree, pos, 30, 0)


static func _net_trap(player) -> void:
	if player.has_method("set_meta"):
		player.set_meta("_rooted_turns", 5)
	CombatLog.add("A net falls on you! (rooted for 5 turns)")


## Zot trap — cascade of nastiness. One of four outcomes per trigger:
## heavy negative damage, random bad status, 1-3 hostile summons, or
## a random teleport. Scales with depth on the damage / status paths.
static func _zot_trap(player, depth: int, ctx: Dictionary) -> void:
	CombatLog.add("A flash of evil energy — the Zot trap triggers!")
	var zot_roll: int = randi() % 4
	match zot_roll:
		0:
			var zd: int = 10 + randi() % max(10 + depth, 10)
			player.take_damage(zd, "negative")
			CombatLog.add("Baleful magic rakes you for %d damage!" % zd)
		1:
			var bad_statuses: Array = ["_confused", "_slowed_turns",
					"_afraid_turns", "_paralysis_turns"]
			var pick: String = String(bad_statuses[randi() % bad_statuses.size()])
			if pick == "_confused":
				player.set_meta("_confused", true)
				player.set_meta("_confusion_turns", 6)
			else:
				player.set_meta(pick, 4 + randi() % 6)
			CombatLog.add("A curse grips you! (%s)" % \
					pick.replace("_turns", "").replace("_", ""))
		2:
			var zot_pool: Array = ["orange_demon", "hell_hound",
					"iron_golem", "ynoxinul", "shadow_demon"]
			var spawn_cb: Callable = ctx.get("spawn_hostile", Callable())
			for _i in 1 + randi() % 3:
				var sid: String = String(zot_pool[randi() % zot_pool.size()])
				if spawn_cb.is_valid():
					spawn_cb.call(sid, player.grid_pos)
			CombatLog.add("Shapes coalesce around you!")
		3:
			CombatLog.add("You are flung across the floor!")
			if player.has_method("_teleport_random"):
				player._teleport_random()


## Golubria portal trap — short-range controlled teleport to a
## visible walkable tile at least 3 away. No damage; the payoff is
## denying nearby monsters their tempo.
static func _golubria_trap(player, generator, ctx: Dictionary) -> void:
	CombatLog.add("A portal of Golubria opens — you step through!")
	var dmap = ctx.get("dmap", null)
	var candidates: Array[Vector2i] = []
	for dx_g in range(-6, 7):
		for dy_g in range(-6, 7):
			var cand: Vector2i = player.grid_pos + Vector2i(dx_g, dy_g)
			if not generator.is_walkable(cand):
				continue
			if dmap != null and not dmap.is_tile_visible(cand):
				continue
			if maxi(abs(dx_g), abs(dy_g)) < 3:
				continue
			candidates.append(cand)
	if candidates.is_empty():
		return
	var dest: Vector2i = candidates[randi() % candidates.size()]
	player.grid_pos = dest
	player.position = Vector2(dest.x * TILE_SIZE + TILE_SIZE / 2.0,
			dest.y * TILE_SIZE + TILE_SIZE / 2.0)
	player.moved.emit(dest)
	if dmap != null:
		dmap.update_fov(dest)
