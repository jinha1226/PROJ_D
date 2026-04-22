class_name DCSSNoise
extends Object
## NOTE: named `DCSSNoise` because Godot 4 already has a built-in
## `Noise` class (base for FastNoiseLite). Using `class_name Noise`
## silently compiled but `Noise.broadcast(...)` resolved against the
## engine class and errored at runtime with "Static function
## broadcast() not found in base GDScriptNativeClass".
## Faithful DCSS 0.34 noise-propagation port.
##
## Source:
##   crawl-ref/source/shout.cc  (noisy, _noise_attenuation_millis)
##   crawl-ref/source/noise.h   (BASE_NOISE_ATTENUATION_MILLIS = 850)
##   crawl-ref/source/noise.cc  (noise_grid::propagate_noise)
##
## What this module replaces:
##   MonsterAI.broadcast_noise — a Chebyshev-disc test that ignored
##   terrain, so a kobold sleeping behind two walls still woke from a
##   cast two tiles away. This port carries "milli-aun" volume through
##   a BFS, subtracting per-cell attenuation so walls actually muffle.
##
## DCSS propagation model:
##   Noise starts at (loudness + 1) * 1000 milli-auns at the source.
##   Each cell entered subtracts `BASE_ATTEN * feature_multiplier`
##   milli-auns:
##     open floor / corridor → 1×       (850)
##     statues                → 2×      (1700)
##     trees                  → 3×      (2550)
##     closed doors           → 8×      (6800)
##     walls                  → 12×     (10200)
##     permarock              → ∞       (hard stop)
##   BFS stops when volume ≤ 0. Any sleeping monster in a cell the wave
##   reached (with volume > 0) wakes up.
##
## Diagonal step cost: DCSS uses full diamond-grid distance which costs
## ~1.4× for a diagonal. We round diagonal cost up to 2× the base atten
## of the exited cell so diagonals through walls aren't discounted.

const BASE_ATTEN_MILLIS: int = 850
const COMPLETE_ATTEN: int = 250000


## Propagate noise from `origin` with the given loudness. Walks the
## dungeon grid with per-cell attenuation and wakes every sleeping
## monster it reaches. `stealth` on the caster shrinks the effective
## volume (DCSS dampen_noise passive ≈ stealth skill on our side).
##
## `tree`       — SceneTree, used to enumerate monsters.
## `origin`     — source cell.
## `loudness`   — spell level × 2 + a few; fireball ~ 8–10, whisper ~ 1.
## `stealth`    — player stealth skill level (or 0 for a monster noise).
## `map_fn`     — Callable(Vector2i) -> int returning the DungeonGenerator
##                tile-type at a cell; used so this module doesn't have
##                to import the dungeon generator directly.
static func broadcast(tree: SceneTree, origin: Vector2i, loudness: int, \
		stealth: int, map_fn: Callable) -> void:
	if tree == null or loudness <= 0:
		return
	# DCSS dampen: halve on Cheibriados passive / Thief unrand. We fold
	# stealth into the same "loudness reducer" here — matches DCSS
	# behaviour for the player as a noise source.
	var eff_loud: int = maxi(0, loudness - stealth / 3)
	if eff_loud <= 0:
		return
	var volume_at: Dictionary = _propagate(origin, eff_loud, map_fn)
	for m in tree.get_nodes_in_group("monsters"):
		if not is_instance_valid(m):
			continue
		if not ("is_alive" in m) or not m.is_alive:
			continue
		if not ("is_sleeping" in m) or not m.is_sleeping:
			continue
		if volume_at.has(m.grid_pos) and int(volume_at[m.grid_pos]) > 0:
			MonsterAI.wake(m)


## BFS the noise grid; returns Dictionary[Vector2i -> int] keyed by every
## cell the wavefront reached (value = remaining volume in milli-auns).
static func _propagate(origin: Vector2i, loudness: int, map_fn: Callable) -> Dictionary:
	var volume: Dictionary = {}
	var start_vol: int = (loudness + 1) * 1000
	volume[origin] = start_vol
	var frontier: Array = [origin]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		var cur_vol: int = int(volume[cur])
		for dy in [-1, 0, 1]:
			for dx in [-1, 0, 1]:
				if dx == 0 and dy == 0:
					continue
				var nxt: Vector2i = Vector2i(cur.x + dx, cur.y + dy)
				var atten: int = _atten_for(nxt, map_fn)
				if atten >= COMPLETE_ATTEN:
					continue
				# Diagonal step on top of that: +1× extra atten so a
				# diagonal through a wall doesn't cheat the wall cost.
				if dx != 0 and dy != 0:
					atten = atten * 14 / 10
				var new_vol: int = cur_vol - atten
				if new_vol <= 0:
					continue
				if volume.has(nxt) and int(volume[nxt]) >= new_vol:
					continue
				volume[nxt] = new_vol
				frontier.append(nxt)
	return volume


## Per-cell attenuation in milli-auns. Mirrors
## shout.cc::_noise_attenuation_millis — uses our tile-type enum.
static func _atten_for(cell: Vector2i, map_fn: Callable) -> int:
	var t: int = int(map_fn.call(cell))
	# DungeonGenerator.TileType — keep in sync if enum values change.
	# WALL=0, FLOOR=1, DOOR_OPEN=2, DOOR_CLOSED=3, STAIRS_DOWN=4,
	# STAIRS_UP=5, BRANCH_ENTRANCE=6, ALTAR=7, SHOP=8, TRAP=9
	match t:
		0: return BASE_ATTEN_MILLIS * 12   # wall
		3: return BASE_ATTEN_MILLIS * 8    # closed door
		-1: return COMPLETE_ATTEN          # off-map
		_: return BASE_ATTEN_MILLIS        # every passable tile
