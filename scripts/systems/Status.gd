class_name Status extends RefCounted

## Unified status-effect + resistance module. Both Player and Monster
## delegate here for tick / apply / remove so status semantics live in
## one place. Adding a new status = add an INFO entry (+ optional
## branches in _on_apply / _on_remove / _apply_tick below).
##
## Actors are duck-typed. Player uses `statuses: Dictionary`, Monster
## uses `status: Dictionary` — both are "id → turns_remaining". _dict_name
## bridges the two.

const INFO: Dictionary = {
	# Damage-over-time
	"poison":       {"name": "Poisoned",     "color": Color(0.45, 1.0, 0.4),
		"ticks_hp": 1, "element": "poison", "non_lethal": true},
	"burning":      {"name": "Burning",      "color": Color(1.0, 0.55, 0.25),
		"ticks_hp": 2, "element": "fire"},
	"diseased":     {"name": "Diseased",     "color": Color(0.6, 0.8, 0.3),
		"ticks_hp": 1, "element": "poison", "non_lethal": true},
	"bleeding":     {"name": "Bleeding",     "color": Color(0.9, 0.25, 0.25),
		"ticks_hp": 1, "element": ""},
	"wet":          {"name": "Wet",          "color": Color(0.55, 0.8, 1.0)},
	# Movement-impairing wound statuses. speed_mult is a multiplier on the
	# action_cost passed to TurnManager.end_player_turn — values > 1.0 make
	# the actor take longer per action. blind clamps FOV radius to 0 so the
	# victim sees only their own tile.
	"slow":         {"name": "Slow",         "color": Color(0.55, 0.65, 0.85),
		"speed_mult": 1.5},
	"blind":        {"name": "Blind",        "color": Color(0.4, 0.4, 0.5),
		"fov_clamp": 0, "hit_penalty": 8, "ev_penalty": 6},
	"crippled":     {"name": "Crippled",     "color": Color(0.8, 0.45, 0.1),
		"speed_mult": 3.0},
	# Action-denial
	"frozen":       {"name": "Frozen",       "color": Color(0.55, 0.85, 1.0),
		"skip_turn": true, "element": "cold"},
	"paralyzed":    {"name": "Paralyzed",    "color": Color(0.5, 0.75, 1.0),
		"skip_turn": true},
	"sleeping":     {"name": "Sleeping",     "color": Color(0.6, 0.65, 0.9),
		"skip_turn": true},
	"stunned":      {"name": "Stunned",      "color": Color(0.9, 0.85, 0.4),
		"skip_turn": true},
	"confused":     {"name": "Confused",     "color": Color(0.85, 0.4, 0.85),
		"random_move": 0.4},
	"feared":       {"name": "Feared",       "color": Color(0.65, 0.5, 0.9),
		"flee": true},
	"silence":      {"name": "Silenced",     "color": Color(0.7, 0.85, 1.0)},
	# Corrosion / Drain
	"corroded":     {"name": "Corroded",     "color": Color(0.6, 0.85, 0.3),
		"ac_down": 2},
	"drained":      {"name": "Drained",      "color": Color(0.55, 0.35, 0.8),
		"ev_down": 2},
	# Stat debuffs
	"berserk":      {"name": "Berserk",      "color": Color(1.0, 0.45, 0.3),
		"str_bonus": 4},
	"might":        {"name": "Mighty",       "color": Color(1.0, 0.7, 0.5),
		"str_bonus": 2},
	"weak":         {"name": "Weakened",     "color": Color(0.55, 0.55, 0.58),
		"str_bonus": -2},
	"weakened":     {"name": "Weakened",     "color": Color(0.55, 0.55, 0.6),
		"str_bonus": -4},
	# Player buffs (effects checked externally in Combat/Player systems)
	"mage_armor":   {"name": "Mage Armor",   "color": Color(0.5, 0.7, 1.0)},
	"blur":         {"name": "Blur",         "color": Color(0.7, 0.75, 1.0)},
	"stoneskin":    {"name": "Stoneskin",    "color": Color(0.8, 0.8, 0.65)},
	"magic_ward":   {"name": "Magic Ward",   "color": Color(0.75, 0.5, 1.0)},
	"invulnerable": {"name": "Invulnerable", "color": Color(1.0, 0.95, 0.5)},
	"hasted":       {"name": "Hasted",       "color": Color(0.4, 1.0, 0.65)},
	"time_stopped": {"name": "Time Stop",    "color": Color(0.9, 0.6, 1.0)},
	"damage_boost": {"name": "Empowered",    "color": Color(1.0, 0.65, 0.3)},
	"shrouded":     {"name": "Shrouded",     "color": Color(0.7, 0.82, 1.0)},
}

# ── Resist scaling ────────────────────────────────────────────────────────
# Resist entries: element name + optional "+" / "-" suffix chars.
#   "fire"      → +1 resist (half damage)
#   "fire+"     → +1 resist (explicit)
#   "fire++"    → +2 resist (quarter)
#   "fire+++"   → +3 resist (1/10, near-immune)
#   "fire-"     → -1 vulnerable (1.5× damage)
#   "fire--"    → -2 (2×)
#   "fire---"   → -3 (3×)
# Entries stack — e.g. ["fire+", "fire+"] = level +2. Final level is
# clamped to [-3, +3]. Empty element / empty resists = full damage.
const _RESIST_MULT: Dictionary = {
	3: 0.10,  2: 0.25,  1: 0.50,  0: 1.00,
	-1: 1.50, -2: 2.00, -3: 3.00,
}

static func resist_level(resists, element: String) -> int:
	if element == "" or resists == null:
		return 0
	# Player.resists is Dictionary[element → int]; MonsterData.resists is Array of tag strings.
	if typeof(resists) == TYPE_DICTIONARY:
		return clampi(int(resists.get(element, 0)), -3, 3)
	if typeof(resists) != TYPE_ARRAY or resists.is_empty():
		return 0
	var level: int = 0
	for entry in resists:
		var s: String = String(entry)
		if not s.begins_with(element):
			continue
		var suffix: String = s.substr(element.length())
		if suffix == "":
			level += 1
			continue
		for ch in suffix:
			if ch == "+":
				level += 1
			elif ch == "-":
				level -= 1
	return clampi(level, -3, 3)

static func resist_scale(base: int, resists, element: String) -> int:
	if element == "":
		return base
	var level: int = resist_level(resists, element)
	var mult: float = float(_RESIST_MULT.get(level, 1.0))
	return int(round(float(base) * mult))

static func is_lightning_element(element: String) -> bool:
	return element == "lightning" or element == "electric" or element == "electricity"

static func wet_lightning_scale(base: int, actor, element: String) -> int:
	if base <= 0 or actor == null or not is_lightning_element(element):
		return base
	if has(actor, "wet"):
		return int(ceil(float(base) * 1.5))
	return base

static func elemental_damage_scale(base: int, actor, element: String) -> int:
	if base <= 0 or actor == null:
		return base
	if is_lightning_element(element):
		return wet_lightning_scale(base, actor, element)
	if element == "fire" and has(actor, "wet"):
		remove(actor, "wet")
		return max(1, int(ceil(float(base) * 0.75)))
	return base

static func apply_elemental_reaction(actor, element: String) -> void:
	if actor == null:
		return
	if element == "cold" and has(actor, "wet"):
		apply(actor, "frozen", 1)
	elif element == "fire" and has(actor, "wet"):
		remove(actor, "wet")

# ── Status application ────────────────────────────────────────────────────
static func has(actor, id: String) -> bool:
	if actor == null:
		return false
	var key: String = _dict_name(actor)
	if key == "":
		return false
	return int(actor.get(key).get(id, 0)) > 0

static func apply(actor, id: String, turns: int) -> void:
	if actor == null or turns <= 0:
		return
	var key: String = _dict_name(actor)
	if key == "":
		return
	# Survival shortens negative status durations on the player. Beneficial
	# statuses (shroud/might/haste) also shrink as a side effect — acceptable
	# first-pass tradeoff; balance pass can split positive vs negative lists.
	if actor is Player and actor.has_method("get_skill_level"):
		var survival_lv: int = actor.get_skill_level("survival")
		if survival_lv > 0:
			var reduction: float = float(survival_lv) * 0.05
			turns = max(1, int(round(float(turns) * (1.0 - reduction))))
	var d: Dictionary = actor.get(key)
	var first: bool = not d.has(id)
	d[id] = max(int(d.get(id, 0)), turns)
	actor.set(key, d)
	if first:
		_on_apply(actor, id)

static func remove(actor, id: String) -> void:
	var key: String = _dict_name(actor)
	if key == "":
		return
	var d: Dictionary = actor.get(key)
	if not d.has(id):
		return
	d.erase(id)
	actor.set(key, d)
	_on_remove(actor, id)

## Advance every status on `actor` by one turn. Returns expired ids so
## the caller can log "Your X wears off." messages.
static func tick_actor(actor) -> Array:
	var key: String = _dict_name(actor)
	if key == "":
		return []
	var d: Dictionary = actor.get(key)
	if d.is_empty():
		return []
	var expired: Array = []
	for id in d.keys().duplicate():
		_apply_tick(actor, id)
		var left: int = int(d.get(id, 0)) - 1
		if left <= 0:
			expired.append(id)
			d.erase(id)
			_on_remove(actor, id)
		else:
			d[id] = left
	actor.set(key, d)
	return expired

# ── AI hooks ──────────────────────────────────────────────────────────────
static func will_skip_turn(actor) -> bool:
	return has(actor, "frozen") or has(actor, "paralyzed") \
		or has(actor, "sleeping") or has(actor, "stunned")

static func confusion_chance(actor) -> float:
	if has(actor, "confused"):
		return float(INFO["confused"].get("random_move", 0.4))
	return 0.0

static func is_fleeing(actor) -> bool:
	return has(actor, "feared")

## Compute combined speed multiplier from all status effects. Returns
## 1.0 if no slowing statuses are active. Stacking is multiplicative.
static func speed_mult(actor) -> float:
	var key: String = _dict_name(actor)
	if key == "":
		return 1.0
	var d: Dictionary = actor.get(key)
	var mult: float = 1.0
	for id in d.keys():
		var info: Dictionary = INFO.get(id, {})
		if info.has("speed_mult"):
			mult *= float(info["speed_mult"])
	return mult

## Returns -1 if no clamp is active. Otherwise returns the clamp radius
## (e.g., 0 means "only see own tile").
static func fov_clamp(actor) -> int:
	var key: String = _dict_name(actor)
	if key == "":
		return -1
	var d: Dictionary = actor.get(key)
	for id in d.keys():
		var info: Dictionary = INFO.get(id, {})
		if info.has("fov_clamp"):
			return int(info["fov_clamp"])
	return -1

## Summed flat penalty to to_hit_base across all active statuses on actor.
## Used by CombatSystem hit-resolution to apply blind etc.
static func hit_penalty(actor) -> int:
	var key: String = _dict_name(actor)
	if key == "":
		return 0
	var d: Dictionary = actor.get(key)
	var total: int = 0
	for id in d.keys():
		var info: Dictionary = INFO.get(id, {})
		if info.has("hit_penalty"):
			total += int(info["hit_penalty"])
	return total

## Summed flat penalty to effective EV across all active statuses on actor.
## Used by CombatSystem to make blind actors easier to hit.
static func ev_penalty(actor) -> int:
	var key: String = _dict_name(actor)
	if key == "":
		return 0
	var d: Dictionary = actor.get(key)
	var total: int = 0
	for id in d.keys():
		var info: Dictionary = INFO.get(id, {})
		if info.has("ev_penalty"):
			total += int(info["ev_penalty"])
	return total

# ── Helpers ───────────────────────────────────────────────────────────────
static func display_name(id: String) -> String:
	return String(INFO.get(id, {}).get("name", id.capitalize()))

static func color_of(id: String) -> Color:
	return INFO.get(id, {}).get("color", Color.WHITE)

# ── Internals ─────────────────────────────────────────────────────────────
static func _dict_name(actor) -> String:
	if "statuses" in actor:
		return "statuses"
	if "status" in actor:
		return "status"
	return ""

static func _apply_tick(actor, id: String) -> void:
	var info: Dictionary = INFO.get(id, {})
	var dot: int = int(info.get("ticks_hp", 0))
	if dot > 0 and "hp" in actor:
		var elem: String = String(info.get("element", ""))
		var raw: int = resist_scale(dot, _resists_of(actor), elem)
		raw = elemental_damage_scale(raw, actor, elem)
		if raw <= 0:
			return
		var floor_hp: int = 1 if bool(info.get("non_lethal", false)) else 0
		actor.hp = max(floor_hp, int(actor.hp) - raw)
		if actor.has_method("emit_signal"):
			actor.emit_signal("stats_changed")
		_log_tick_damage(actor, id, raw)

static func _on_apply(actor, id: String) -> void:
	var info: Dictionary = INFO.get(id, {})
	var d: int = int(info.get("str_bonus", 0))
	if d != 0 and "strength" in actor:
		actor.strength = max(1, int(actor.strength) + d)

static func _on_remove(actor, id: String) -> void:
	var info: Dictionary = INFO.get(id, {})
	var d: int = int(info.get("str_bonus", 0))
	if d != 0 and "strength" in actor:
		actor.strength = max(1, int(actor.strength) - d)

## Returns Player's Dict[element → int] or Monster's Array[tag] — both shapes are
## accepted by resist_level/resist_scale.
static func _resists_of(actor):
	if "resists" in actor:
		return actor.resists
	if "data" in actor and actor.data != null and "resists" in actor.data:
		return actor.data.resists
	return []

static func _log_tick_damage(actor, id: String, dmg: int) -> void:
	if actor is Player:
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var combat_log = tree.root.get_node_or_null("/root/CombatLog")
			if combat_log != null:
				combat_log.damage_taken("%s ravages you. (-%d HP)"
					% [display_name(id), dmg])
	# Monster ticks don't log — too noisy.
