class_name CloudSystem
extends RefCounted
## DCSS cloud system — tile-level transient hazards created by spells,
## monster breath, and some god effects. Each cloud tile stores:
##   type          — "fire", "freezing", "mephitic", "smoke", "noxious"
##   turns_left    — decrements each player turn
##   damage        — per-turn tick (0 for non-damaging clouds)
##   element       — damage element tag (routes through rF/rC/rPois)
##
## The system is a pure data container; CombatLog / Player damage
## calls fire through the caller (GameBootstrap) when a player / monster
## steps onto or starts a turn on a cloud tile.

const CLOUD_DEFS: Dictionary = {
	"fire": {
		"name": "fire cloud",
		"color": Color(1.00, 0.45, 0.15, 0.55),
		"damage": 4,
		"element": "fire",
		"duration_min": 5,
		"duration_max": 8,
	},
	"freezing": {
		"name": "freezing cloud",
		"color": Color(0.55, 0.85, 1.00, 0.55),
		"damage": 3,
		"element": "cold",
		"duration_min": 4,
		"duration_max": 6,
	},
	"mephitic": {
		"name": "mephitic cloud",
		"color": Color(0.55, 0.95, 0.25, 0.50),
		"damage": 0,
		"element": "",
		"duration_min": 8,
		"duration_max": 12,
		"status": "confusion",   # applies confusion on tick
	},
	"noxious": {
		"name": "noxious cloud",
		"color": Color(0.25, 0.60, 0.10, 0.55),
		"damage": 2,
		"element": "poison",
		"duration_min": 10,
		"duration_max": 14,
	},
	"smoke": {
		"name": "smoke cloud",
		"color": Color(0.40, 0.40, 0.40, 0.65),
		"damage": 0,
		"element": "",
		"duration_min": 10,
		"duration_max": 14,
		"fov_block": true,  # opaque to FOV
	},
	"ice": {
		"name": "ice cloud",
		"color": Color(0.80, 0.95, 1.00, 0.50),
		"damage": 2,
		"element": "cold",
		"duration_min": 6,
		"duration_max": 10,
	},
}


## Place a cloud at `pos` of the given type. Duration is randomised
## between the type's min/max. Overwrites any existing cloud on that
## tile (DCSS behaviour — clouds don't stack).
static func place(clouds: Dictionary, pos: Vector2i, type_id: String,
		rng: RandomNumberGenerator = null) -> void:
	var d: Dictionary = CLOUD_DEFS.get(type_id, {})
	if d.is_empty():
		return
	var dmin: int = int(d.get("duration_min", 5))
	var dmax: int = int(d.get("duration_max", 8))
	var turns: int
	if rng != null:
		turns = rng.randi_range(dmin, dmax)
	else:
		turns = dmin + randi() % (dmax - dmin + 1)
	clouds[pos] = {
		"type": type_id,
		"turns_left": turns,
		"damage": int(d.get("damage", 0)),
		"element": String(d.get("element", "")),
		"status": String(d.get("status", "")),
		"fov_block": bool(d.get("fov_block", false)),
	}


## Place a cloud patch of radius `radius` around `center` with gaps —
## not every cell in the radius gets a cloud (DCSS rolls a 70% per
## cell chance). Centre tile is always covered.
static func place_patch(clouds: Dictionary, center: Vector2i, type_id: String,
		radius: int, rng: RandomNumberGenerator = null) -> void:
	place(clouds, center, type_id, rng)
	for dx in range(-radius, radius + 1):
		for dy in range(-radius, radius + 1):
			if dx == 0 and dy == 0:
				continue
			var dist: int = maxi(abs(dx), abs(dy))
			if dist > radius:
				continue
			# DCSS cloud scatter: 70% chance each tile in the blast.
			var r: float = rng.randf() if rng != null else randf()
			if r < 0.7:
				place(clouds, center + Vector2i(dx, dy), type_id, rng)


## Decrement every cloud's turns_left by 1; remove expired clouds.
## Called once per player turn.
static func tick(clouds: Dictionary) -> Array:
	var expired: Array = []
	for pos in clouds.keys():
		var c: Dictionary = clouds[pos]
		c["turns_left"] = int(c["turns_left"]) - 1
		if c["turns_left"] <= 0:
			expired.append(pos)
	for p in expired:
		clouds.erase(p)
	return expired


## Apply a cloud's damage / status to the actor standing on it. Called
## by the caller (GameBootstrap) after checking actor grid_pos.
static func apply_to_actor(cloud: Dictionary, actor) -> void:
	if actor == null:
		return
	var dmg: int = int(cloud.get("damage", 0))
	var elem: String = String(cloud.get("element", ""))
	var status: String = String(cloud.get("status", ""))
	if dmg > 0 and actor.has_method("take_damage"):
		if elem == "poison" and actor.has_method("apply_poison"):
			actor.apply_poison(1, "a noxious cloud")
		else:
			actor.take_damage(dmg, elem)
	# Mephitic = confusion roll. DCSS also checks poison immunity —
	# we skip that for now, rPois is a boolean the caller can gate.
	if status == "confusion" and actor.has_method("set_meta"):
		actor.set_meta("_confused", true)
		actor.set_meta("_confusion_turns",
				maxi(3, int(actor.get_meta("_confusion_turns", 0))))


## FOV opacity contribution from a cloud. Used by DungeonMap._opaque_at
## to return OPAQUE for smoke clouds.
static func blocks_fov(cloud: Dictionary) -> bool:
	return bool(cloud.get("fov_block", false))
