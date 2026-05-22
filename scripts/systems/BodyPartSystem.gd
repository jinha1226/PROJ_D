class_name BodyPartSystem extends RefCounted

## Hit-location, wound tracking, and wound-effect dispatch.
## Duck-types Player and Monster — both need grid_pos, facing, body_wounds, hp_max.

const BODY_TYPES: Dictionary = {
	"humanoid": {
		"parts":   ["head", "torso", "left_arm", "right_arm", "left_leg", "right_leg"],
		"weights": [10,     30,      15,         15,          15,         15]
	},
	"serpentine": {
		"parts":   ["head", "body"],
		"weights": [25,     75]
	},
	"flying": {
		"parts":   ["head", "body", "left_wing", "right_wing"],
		"weights": [20,     40,     20,          20]
	},
	"quadruped": {
		"parts":   ["head", "body", "left_leg", "right_leg"],
		"weights": [15,     45,     20,         20]
	},
}

## part → { level(1 or 2) → [status_id:turns, ...] }
## Arm damage penalty is NOT a status — CombatSystem reads body_wounds directly.
const WOUND_EFFECTS: Dictionary = {
	"head":       {1: ["confused:3"],              2: ["confused:6", "blind:3"]},
	"torso":      {1: ["bleeding:4"],              2: ["bleeding:8", "weakened:6"]},
	"left_arm":   {1: [],                          2: ["bleeding:3", "weakened:4"]},
	"right_arm":  {1: [],                          2: ["bleeding:3", "weakened:4"]},
	"left_leg":   {1: ["slow:4"],                  2: ["slow:8",  "crippled:4"]},
	"right_leg":  {1: ["slow:4"],                  2: ["slow:8",  "crippled:4"]},
	"body":       {1: ["bleeding:4"],              2: ["bleeding:8", "weakened:4"]},
	"left_wing":  {1: ["slow:3"],                  2: ["slow:6"]},
	"right_wing": {1: ["slow:3"],                  2: ["slow:6"]},
}

## Direction → per-part weight multipliers.
## "front"  = attacker is in the direction defender is facing.
## "back"   = attacker is behind.
## "left"   = attacker is on defender's left flank.
## "right"  = attacker is on defender's right flank.
const DIRECTION_BIAS: Dictionary = {
	"front": {"head": 2.0,  "torso": 1.5},
	"back":  {"torso": 1.5, "left_leg": 1.3, "right_leg": 1.3},
	"left":  {"left_arm": 2.5,  "left_leg": 2.0},
	"right": {"right_arm": 2.5, "right_leg": 2.0},
}

const PART_LABELS: Dictionary = {
	"head": "머리", "torso": "몸통",
	"left_arm": "왼팔", "right_arm": "오른팔",
	"left_leg": "왼다리", "right_leg": "오른다리",
	"body": "몸통", "left_wing": "왼날개", "right_wing": "오른날개",
}

## Called from CombatSystem after final damage is resolved.
static func process_hit(defender, final_damage: int, attacker_pos: Vector2i) -> void:
	var body_type: String = "humanoid"
	if "data" in defender and defender.data != null and "body_type" in defender.data:
		body_type = String(defender.data.body_type)
	var bt: Dictionary = BODY_TYPES.get(body_type, BODY_TYPES["humanoid"])
	var side: String = _attack_side(defender, attacker_pos)
	var part: String = _weighted_part(bt, side)
	if part == "":
		return
	var _max_hp: int
	if "hp_max" in defender:
		_max_hp = int(defender.hp_max)
	elif "data" in defender and defender.data != null:
		_max_hp = int(defender.data.hp)
	else:
		_max_hp = max(1, int(defender.hp))
	var wound_chance: float = float(final_damage) / float(max(1, _max_hp))
	if randf() >= wound_chance:
		return
	var wounds: Dictionary = defender.body_wounds if "body_wounds" in defender else {}
	var current: int = int(wounds.get(part, 0))
	if current >= 2:
		return
	var new_level: int = current + 1
	wounds[part] = new_level
	if "body_wounds" in defender:
		defender.body_wounds = wounds
	var effects: Array = WOUND_EFFECTS.get(part, {}).get(new_level, [])
	for entry in effects:
		var parts2: Array = String(entry).split(":")
		if parts2.size() == 2:
			Status.apply(defender, parts2[0], int(parts2[1]))
	if defender is Player:
		var severity: String = "심하게" if new_level == 2 else "약간"
		var label: String = PART_LABELS.get(part, part)
		CombatLog.post("%s 부위가 %s 다쳤습니다!" % [label, severity],
			Color(1.0, 0.55, 0.3) if new_level == 1 else Color(0.9, 0.15, 0.15))

## Decrement every wound by `levels`. Called by healing items/spells.
static func reduce_wounds(actor, levels: int = 1) -> void:
	if not ("body_wounds" in actor):
		return
	var wounds: Dictionary = actor.body_wounds
	for part in wounds.keys().duplicate():
		var val: int = max(0, int(wounds[part]) - levels)
		if val <= 0:
			wounds.erase(part)
		else:
			wounds[part] = val
	actor.body_wounds = wounds

## Returns [[part_id, level], ...] for all parts where level > 0. Used by UI.
static func active_wounds(actor) -> Array:
	if not ("body_wounds" in actor):
		return []
	var result: Array = []
	for part in actor.body_wounds.keys():
		var lvl: int = int(actor.body_wounds[part])
		if lvl > 0:
			result.append([part, lvl])
	return result

## Classifies attacker direction relative to defender's facing.
static func _attack_side(defender, attacker_pos: Vector2i) -> String:
	if not ("grid_pos" in defender) or not ("facing" in defender):
		return "front"
	var av: Vector2i = attacker_pos - defender.grid_pos
	if av == Vector2i.ZERO:
		return "front"
	var f: Vector2i = defender.facing
	var dot: int   = av.x * f.x + av.y * f.y
	var cross: int = av.x * f.y - av.y * f.x
	if absi(dot) >= absi(cross):
		return "front" if dot >= 0 else "back"
	return "left" if cross > 0 else "right"

## Weighted random part selection with direction bias applied.
static func _weighted_part(bt: Dictionary, side: String) -> String:
	var parts: Array  = bt.get("parts", [])
	var weights: Array = bt.get("weights", [])
	if parts.is_empty():
		return ""
	var bias: Dictionary = DIRECTION_BIAS.get(side, {})
	var adjusted: Array = []
	var total: float = 0.0
	for i in parts.size():
		var w: float = float(weights[i] if i < weights.size() else 1)
		w *= float(bias.get(parts[i], 1.0))
		adjusted.append(w)
		total += w
	var roll: float = randf() * total
	var acc: float = 0.0
	for i in parts.size():
		acc += float(adjusted[i])
		if roll < acc:
			return parts[i]
	return parts[-1]
