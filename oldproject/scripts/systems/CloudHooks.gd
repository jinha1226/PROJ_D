class_name CloudHooks
extends RefCounted
## Cloud-related lookup tables + helper, extracted from GameBootstrap.
## All three functions are pure — no scene-tree access — so the module
## is a drop-in static replacement for what used to live inline.

## Map a spell id to the cloud residue it leaves behind after an area
## blast. Returns "" for spells that don't seed a cloud. Expand this
## table when new cloud-placing area spells land.
static func spell_cloud_residue(spell_id: String) -> String:
	match spell_id:
		"fireball", "fire_storm":
			return "fire"
		"hailstorm":
			return "freezing"
		_:
			return ""


## Monster id → death-cloud descriptor ({type, radius}). Empty dict for
## mobs that die cleanly. Plague / rot undead leak noxious gas;
## fire-bodied elementals burn into flame residue; ice-bodied into
## freezing; smoke / shadow demons into smoke.
static func monster_death_cloud(monster_id: String) -> Dictionary:
	match monster_id:
		"bog_body", "plague_shambler", "rotting_hulk", "necrophage", \
		"ghoul", "death_drake":
			return {"type": "noxious", "radius": 1}
		"fire_vortex", "fire_elemental", "creeping_inferno":
			return {"type": "fire", "radius": 2}
		"frost_giant", "ice_statue", "simulacrum":
			return {"type": "freezing", "radius": 1}
		"smoke_demon", "smoke_djinn":
			return {"type": "smoke", "radius": 2}
		_:
			return {}


## Pick a walkable tile to drop an area spell on when no monster is in
## range. Scans Chebyshev rings outward from the player for the first
## visible walkable tile, capped at `max_range`. Falls back to the
## player's own tile when nothing nearby is walkable — harmless since
## the area then hits 0 monsters but still plays FX + cloud residue.
static func fallback_area_center(player, generator, dmap, max_range: int) -> Vector2i:
	if player == null or generator == null:
		return Vector2i.ZERO
	var r: int = max(2, min(max_range, 4))
	for dist in range(2, r + 1):
		# Cardinals first for a clean forward blast; diagonals broaden
		# reach when the facing lanes are blocked.
		var rings: Array = [
			Vector2i(dist, 0), Vector2i(-dist, 0),
			Vector2i(0, dist), Vector2i(0, -dist),
			Vector2i(dist, dist), Vector2i(-dist, -dist),
			Vector2i(dist, -dist), Vector2i(-dist, dist),
		]
		for d in rings:
			var cand: Vector2i = player.grid_pos + d
			if not generator.is_walkable(cand):
				continue
			if dmap != null and not dmap.is_tile_visible(cand):
				continue
			return cand
	return player.grid_pos
