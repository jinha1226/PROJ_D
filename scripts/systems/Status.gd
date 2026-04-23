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
	"poison":   {"name": "Poisoned",  "color": Color(0.45, 1.0, 0.4),
		"ticks_hp": 1, "element": "poison", "non_lethal": true},
	"burning":  {"name": "Burning",   "color": Color(1.0, 0.55, 0.25),
		"ticks_hp": 2, "element": "fire"},
	# Action-denial
	"frozen":   {"name": "Frozen",    "color": Color(0.55, 0.85, 1.0),
		"skip_turn": true, "element": "cold"},
	"confused": {"name": "Confused",  "color": Color(0.85, 0.4, 0.85),
		"random_move": 0.4},
	"feared":   {"name": "Feared",    "color": Color(0.65, 0.5, 0.9),
		"flee": true},
	# Stat mods (str delta applied on_apply, undone on_remove)
	"berserk":  {"name": "Berserk",   "color": Color(1.0, 0.45, 0.3),
		"str_bonus": 4},
	"might":    {"name": "Mighty",    "color": Color(1.0, 0.7, 0.5),
		"str_bonus": 2},
	"weak":     {"name": "Weakened",  "color": Color(0.55, 0.55, 0.58),
		"str_bonus": -2},
}

# ── Resist scaling ────────────────────────────────────────────────────────
# resists entries:
#   "fire"    → half damage (rounds toward floor)
#   "fire-2"  → quarter damage
#   "fire+"   → vulnerable, 1.5× damage
# Empty element or empty resists array = full damage.
static func resist_scale(base: int, resists, element: String) -> int:
	if element == "" or resists == null:
		return base
	if typeof(resists) != TYPE_ARRAY or resists.is_empty():
		return base
	if resists.has(element + "+"):
		return int(round(float(base) * 1.5))
	if resists.has(element + "-2"):
		return max(0, base / 4)
	if resists.has(element) or resists.has(element + "-1"):
		return max(0, base / 2)
	return base

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
	return has(actor, "frozen")

static func confusion_chance(actor) -> float:
	if has(actor, "confused"):
		return float(INFO["confused"].get("random_move", 0.4))
	return 0.0

static func is_fleeing(actor) -> bool:
	return has(actor, "feared")

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

static func _resists_of(actor) -> Array:
	if "resists" in actor:
		return actor.resists
	if "data" in actor and actor.data != null and "resists" in actor.data:
		return actor.data.resists
	return []

static func _log_tick_damage(actor, id: String, dmg: int) -> void:
	if actor is Player:
		CombatLog.damage_taken("%s ravages you. (-%d HP)"
			% [display_name(id), dmg])
	# Monster ticks don't log — too noisy.
