class_name SpellRegistry
extends Object
## Two-layer spell catalog:
##   1. SPELLS const — hand-tuned entries with damage/color/desc/effect.
##   2. DCSS JSON (409 spells) — level, range, schools, flags. Loaded lazily.
## SPELLS takes priority on overlap; DCSS data fills in the rest.

const _DCSS_JSON := "res://assets/dcss_spells/spells.json"
const _ZAPS_JSON := "res://assets/dcss_spells/zaps.json"

static var _dcss: Dictionary = {}   # id → dcss entry
static var _zaps: Dictionary = {}   # id → zap dice entry
static var _loaded: bool = false


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var f := FileAccess.open(_DCSS_JSON, FileAccess.READ)
	if f != null:
		var parsed = JSON.parse_string(f.get_as_text())
		f.close()
		if parsed is Array:
			for entry in parsed:
				var sid: String = String(entry.get("id", ""))
				if sid != "":
					_dcss[sid] = entry
	var zf := FileAccess.open(_ZAPS_JSON, FileAccess.READ)
	if zf != null:
		var zparsed = JSON.parse_string(zf.get_as_text())
		zf.close()
		if zparsed is Dictionary:
			_zaps = zparsed


## Merge DCSS data onto a custom entry dict (non-destructive).
static func _enrich(id: String, base: Dictionary) -> Dictionary:
	_ensure_loaded()
	var d: Dictionary = base.duplicate()
	var dc: Dictionary = _dcss.get(id, {})
	if dc.is_empty():
		return d
	# Use DCSS level as difficulty if we don't have one set, or if ours is default 1.
	if not d.has("difficulty") or int(d.get("difficulty", 1)) == 1:
		var dc_lv: int = int(dc.get("level", 1))
		if dc_lv > 0:
			d["difficulty"] = dc_lv
	# Use DCSS level as mp cost if missing.
	if not d.has("mp"):
		d["mp"] = int(dc.get("mp", 1))
	# Use DCSS max_range if our range is default 9 or missing.
	var dc_range: int = int(dc.get("max_range", -1))
	if dc_range > 0 and (not d.has("range") or int(d.get("range", 9)) == 9):
		d["range"] = dc_range
	# Add DCSS flags array.
	if not d.has("flags"):
		d["flags"] = dc.get("flags", [])
	return d


const SPELLS: Dictionary = {
	"magic_dart": {
		"name": "Magic Dart", "school": "conjurations",
		"mp": 1, "min_dmg": 1, "max_dmg": 3, "difficulty": 1,
		"targeting": "single", "range": 9, "effect": "damage",
		"color": Color(0.75, 0.75, 1.0),
		"desc": "A conjured dart. Never misses.",
	},
	"flame_tongue": {
		"name": "Flame Tongue", "school": "fire",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 5, "effect": "damage",
		"color": Color(1.0, 0.4, 0.0),
		"desc": "A short-range gout of flame.",
	},
	"fireball": {
		"name": "Fireball", "school": "fire",
		"mp": 6, "min_dmg": 3, "max_dmg": 30, "difficulty": 5,
		"targeting": "area", "range": 5, "radius": 2, "effect": "damage",
		"color": Color(1.0, 0.6, 0.0),
		"desc": "Explosive fire. Lv5, high power + high failure.",
	},
	"freeze": {
		"name": "Freeze", "school": "cold",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.5, 0.85, 1.0),
		"desc": "Crystallises moisture around the target.",
	},
	"stone_arrow": {
		"name": "Stone Arrow", "school": "earth",
		"mp": 3, "min_dmg": 3, "max_dmg": 21, "difficulty": 3,
		"targeting": "single", "range": 4, "effect": "damage",
		"color": Color(0.75, 0.65, 0.45),
		"desc": "A sharp shard of stone. Lv3, physical damage.",
	},
	"lightning_bolt": {
		"name": "Lightning Bolt", "school": "air",
		"mp": 5, "min_dmg": 1, "max_dmg": 33, "difficulty": 5,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(1.0, 1.0, 0.4),
		"desc": "A bolt of lightning. Lv5, ignores half AC.",
	},
	"pain": {
		"name": "Pain", "school": "necromancy",
		"mp": 2, "min_dmg": 2, "max_dmg": 5, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.55, 0.0, 0.75),
		"desc": "Channels death-energy into raw agony.",
	},
	"slow": {
		"name": "Slow", "school": "hexes",
		"mp": 2, "min_dmg": 0, "max_dmg": 0, "difficulty": 1,
		"targeting": "single", "range": 6, "effect": "slow",
		"color": Color(0.4, 0.9, 0.5),
		"desc": "Halves target speed for 4 turns.",
	},
	"blink": {
		"name": "Blink", "school": "translocations",
		"mp": 2, "min_dmg": 0, "max_dmg": 0, "difficulty": 2,
		"targeting": "self", "range": 0, "effect": "teleport",
		"color": Color(0.8, 0.55, 1.0),
		"desc": "Randomly teleports you a short distance.",
	},
	# --- Lv1 multi-school ---
	"shock": {
		"name": "Shock", "school": "air", "school2": "conjurations",
		"mp": 1, "min_dmg": 1, "max_dmg": 4, "difficulty": 1,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(0.9, 0.95, 1.0),
		"desc": "A jolt of electricity. Pierces armor slightly.",
	},
	# --- Lv2 ---
	"scorch": {
		"name": "Scorch", "school": "fire", "school2": "conjurations",
		"mp": 2, "min_dmg": 2, "max_dmg": 8, "difficulty": 2,
		"targeting": "single", "range": 5, "effect": "damage",
		"color": Color(1.0, 0.5, 0.1),
		"desc": "Intense heat that weakens fire resistance.",
	},
	"static_discharge": {
		"name": "Static Discharge", "school": "air", "school2": "conjurations",
		"mp": 2, "min_dmg": 1, "max_dmg": 6, "difficulty": 2,
		"targeting": "area", "range": 0, "radius": 1, "effect": "damage",
		"color": Color(0.8, 0.9, 1.0),
		"desc": "Electric burst hitting all adjacent enemies.",
	},
	# --- Lv3 ---
	"vampiric_drain": {
		"name": "Vampiric Draining", "school": "necromancy",
		"mp": 3, "min_dmg": 2, "max_dmg": 10, "difficulty": 3,
		"targeting": "single", "range": 1, "effect": "vampiric",
		"color": Color(0.7, 0.0, 0.2),
		"desc": "Drain life from adjacent target. Heals you for damage dealt.",
	},
	"hailstorm": {
		"name": "Hailstorm", "school": "cold", "school2": "conjurations",
		"mp": 4, "min_dmg": 3, "max_dmg": 15, "difficulty": 3,
		"targeting": "area", "range": 6, "radius": 2, "effect": "damage",
		"color": Color(0.6, 0.85, 1.0),
		"desc": "A ring of ice shards around the target.",
	},
	"confuse": {
		"name": "Confuse", "school": "hexes",
		"mp": 3, "min_dmg": 0, "max_dmg": 0, "difficulty": 3,
		"targeting": "single", "range": 6, "effect": "confuse",
		"color": Color(0.9, 0.5, 0.9),
		"desc": "Target moves randomly for 4 turns.",
	},
	"dazzling_flash": {
		"name": "Dazzling Flash", "school": "conjurations", "school2": "hexes",
		"mp": 3, "min_dmg": 1, "max_dmg": 5, "difficulty": 3,
		"targeting": "area", "range": 0, "radius": 2, "effect": "damage",
		"color": Color(1.0, 1.0, 0.8),
		"desc": "Blinding flash hitting nearby enemies.",
	},
	# --- Lv4 ---
	"sticky_flame": {
		"name": "Sticky Flame", "school": "fire", "school2": "conjurations",
		"mp": 4, "min_dmg": 2, "max_dmg": 8, "difficulty": 4,
		"targeting": "single", "range": 5, "effect": "dot_fire",
		"color": Color(1.0, 0.7, 0.0),
		"desc": "Burning gel. Deals fire damage over 4 turns.",
	},
	"airstrike": {
		"name": "Airstrike", "school": "air", "school2": "conjurations",
		"mp": 4, "min_dmg": 3, "max_dmg": 20, "difficulty": 4,
		"targeting": "single", "range": 6, "effect": "damage",
		"color": Color(0.7, 0.85, 1.0),
		"desc": "Smash with compressed air. Ignores armor.",
	},
	"petrify": {
		"name": "Petrify", "school": "hexes", "school2": "earth",
		"mp": 4, "min_dmg": 0, "max_dmg": 0, "difficulty": 4,
		"targeting": "single", "range": 5, "effect": "petrify",
		"color": Color(0.6, 0.55, 0.45),
		"desc": "Gradually turns target to stone. Immobilized 5 turns.",
	},
	"passage": {
		"name": "Passage of Golubria", "school": "translocations",
		"mp": 4, "min_dmg": 0, "max_dmg": 0, "difficulty": 4,
		"targeting": "self", "range": 0, "effect": "teleport",
		"color": Color(0.7, 0.4, 1.0),
		"desc": "Controlled blink to a specific explored tile.",
	},
	# --- Lv5 ---
	"agony": {
		"name": "Agony", "school": "necromancy", "school2": "hexes",
		"mp": 5, "min_dmg": 0, "max_dmg": 0, "difficulty": 5,
		"targeting": "single", "range": 1, "effect": "agony",
		"color": Color(0.4, 0.0, 0.5),
		"desc": "Halves the target's current HP. Melee range.",
	},
	"metabolic_englaciation": {
		"name": "Metabolic Englaciation", "school": "cold", "school2": "hexes",
		"mp": 5, "min_dmg": 0, "max_dmg": 0, "difficulty": 5,
		"targeting": "area", "range": 0, "radius": 4, "effect": "slow",
		"color": Color(0.5, 0.7, 1.0),
		"desc": "Slows all visible enemies for 4 turns.",
	},
	# --- Lv6 ---
	"iron_shot": {
		"name": "Iron Shot", "school": "conjurations", "school2": "earth",
		"mp": 6, "min_dmg": 5, "max_dmg": 40, "difficulty": 6,
		"targeting": "single", "range": 3, "effect": "damage",
		"color": Color(0.5, 0.5, 0.55),
		"desc": "Massive iron projectile. Short range, huge damage.",
	},
	"chain_lightning": {
		"name": "Chain Lightning", "school": "air", "school2": "conjurations",
		"mp": 8, "min_dmg": 3, "max_dmg": 35, "difficulty": 7,
		"targeting": "area", "range": 8, "radius": 3, "effect": "damage",
		"color": Color(1.0, 1.0, 0.5),
		"desc": "Lightning arcing between all visible enemies.",
	},
	# --- Lv7 ---
	"orb_of_destruction": {
		"name": "Orb of Destruction", "school": "conjurations",
		"mp": 7, "min_dmg": 8, "max_dmg": 50, "difficulty": 7,
		"targeting": "single", "range": 8, "effect": "damage",
		"color": Color(0.9, 0.3, 1.0),
		"desc": "A devastating orb of pure magical energy.",
	},
	"fire_storm": {
		"name": "Fire Storm", "school": "fire", "school2": "conjurations",
		"mp": 9, "min_dmg": 5, "max_dmg": 55, "difficulty": 8,
		"targeting": "area", "range": 6, "radius": 3, "effect": "damage",
		"color": Color(1.0, 0.3, 0.0),
		"desc": "Apocalyptic firestorm. Massive area, massive damage.",
	},
}

const SCHOOL_SPELLS: Dictionary = {
	"conjurations": [
		{"id": "magic_dart", "min_level": 1},
		{"id": "dazzling_flash", "min_level": 3},
		{"id": "orb_of_destruction", "min_level": 7},
	],
	"fire": [
		{"id": "flame_tongue", "min_level": 1},
		{"id": "scorch", "min_level": 2},
		{"id": "sticky_flame", "min_level": 4},
		{"id": "fireball", "min_level": 5},
		{"id": "fire_storm", "min_level": 8},
	],
	"cold": [
		{"id": "freeze", "min_level": 1},
		{"id": "hailstorm", "min_level": 3},
		{"id": "metabolic_englaciation", "min_level": 5},
	],
	"earth": [
		{"id": "stone_arrow", "min_level": 3},
		{"id": "iron_shot", "min_level": 6},
	],
	"air": [
		{"id": "shock", "min_level": 1},
		{"id": "static_discharge", "min_level": 2},
		{"id": "airstrike", "min_level": 4},
		{"id": "lightning_bolt", "min_level": 5},
		{"id": "chain_lightning", "min_level": 7},
	],
	"necromancy": [
		{"id": "pain", "min_level": 1},
		{"id": "vampiric_drain", "min_level": 3},
		{"id": "agony", "min_level": 5},
	],
	"hexes": [
		{"id": "slow", "min_level": 1},
		{"id": "confuse", "min_level": 3},
		{"id": "petrify", "min_level": 4},
	],
	"translocations": [
		{"id": "blink", "min_level": 2},
		{"id": "passage", "min_level": 4},
	],
}


## Returns spell data, enriched with DCSS level/range/flags where applicable.
## Falls back to raw DCSS entry if not in our custom SPELLS dict.
static func get_spell(id: String) -> Dictionary:
	_ensure_loaded()
	if SPELLS.has(id):
		return _enrich(id, SPELLS[id])
	# Pure DCSS spell — build a minimal entry from JSON data.
	var dc: Dictionary = _dcss.get(id, {})
	if dc.is_empty():
		return {}
	var schools: Array = dc.get("schools", [])
	return {
		"name":       String(dc.get("name", id.replace("_", " ").capitalize())),
		"school":     schools[0] if schools.size() > 0 else "none",
		"schools":    schools,
		"mp":         int(dc.get("mp", 1)),
		"difficulty": int(dc.get("level", 1)),
		"targeting":  String(dc.get("targeting", "single")),
		"range":      int(dc.get("max_range", 9)) if int(dc.get("max_range", -1)) > 0 else 9,
		"effect":     "damage",
		"flags":      dc.get("flags", []),
		"color":      Color(0.75, 0.75, 1.0),
		"desc":       "",
		"min_dmg":    0,
		"max_dmg":    int(dc.get("level", 1)) * 4,
	}


## True if this spell id is known to us (custom or DCSS).
static func is_known_spell(id: String) -> bool:
	_ensure_loaded()
	return SPELLS.has(id) or _dcss.has(id)


static func get_known_for_player(player: Node, skill_sys: Node) -> Array[String]:
	var known: Array[String] = []
	if player == null:
		return known
	if "learned_spells" in player:
		for sid in player.learned_spells:
			var sp: String = String(sid)
			if sp != "" and not known.has(sp):
				known.append(sp)
		return known
	if skill_sys == null:
		return known
	for school in SCHOOL_SPELLS:
		var level: int = skill_sys.get_level(player, school)
		if level <= 0:
			continue
		for entry in SCHOOL_SPELLS[school]:
			var sid2: String = String(entry.get("id", ""))
			var min_lv: int = int(entry.get("min_level", 1))
			if level >= min_lv and not known.has(sid2):
				known.append(sid2)
	return known


# --- DCSS-ported spell math ------------------------------------------------
#
# Functions below port spl-cast.cc:
#   - _skill_power / calc_spell_power  → calc_spell_power()
#   - raw_spell_fail                   → failure_rate()
#   - per-zap dice roll (zap-data.h)   → roll_damage()


## Return all school ids for a spell. Prefers SPELLS["schools"] (array), then
## SPELLS["school"]+["school2"] (legacy singletons), then DCSS JSON's
## `schools` array. Empty array if nothing is known.
static func get_schools(spell_id: String) -> Array:
	_ensure_loaded()
	var info: Dictionary = SPELLS.get(spell_id, {})
	if info.has("schools") and info["schools"] is Array:
		return info["schools"]
	var out: Array = []
	if info.has("school"):
		out.append(info["school"])
	if info.has("school2") and not out.has(info["school2"]):
		out.append(info["school2"])
	if out.is_empty():
		var dc: Dictionary = _dcss.get(spell_id, {})
		if dc.has("schools") and dc["schools"] is Array:
			for s in dc["schools"]:
				out.append(String(s))
	return out


## DCSS stepdown_value(base, stepping, first_step, _, ceiling) porting
## stepdown.cc:stepdown_value. Used for spell-power stepdown.
static func _stepdown(value: float, step: float) -> float:
	return step * log(1.0 + value / step) / log(2.0)


static func _stepdown_value(base_value: int, stepping: int, first_step: int, ceiling_value: int) -> int:
	if ceiling_value < 0:
		ceiling_value = 0
	if ceiling_value > 0 and ceiling_value < first_step:
		return min(base_value, ceiling_value)
	if base_value < first_step:
		return base_value
	var diff: int = first_step - stepping
	var ceil_rem: int = 0
	if ceiling_value > 0:
		ceil_rem = ceiling_value - diff
	var stepped: float = _stepdown(float(base_value - diff), float(stepping))
	if ceil_rem > 0 and stepped > float(ceil_rem):
		stepped = float(ceil_rem)
	return int(diff + stepped)


## Read the player's effective level for a skill. Prefers skill_state on the
## player; falls back to 0. Caller is responsible for passing a valid player.
static func _player_skill(player: Node, skill_id: String) -> int:
	if player == null:
		return 0
	if "skill_state" in player and player.skill_state is Dictionary \
			and player.skill_state.has(skill_id):
		return int(player.skill_state[skill_id].get("level", 0))
	return 0


## DCSS _skill_power (spl-cast.cc:428). Averages school skills across all
## disciplines, then adds spellcasting/4. Returned value is scaled by 100
## (matching DCSS's internal units, where skill(X, 200) = skill * 2 * 100 /
## 100 = skill * 200). Intended as input to calc_spell_power.
static func _skill_power(spell_id: String) -> int:
	var schools: Array = get_schools(spell_id)
	var count: int = 0
	var sum_scaled: int = 0
	# NOTE: called via calc_spell_power which also passes the player; we look
	# the player up via the currently-casting player (group-based fallback).
	var player: Node = _current_casting_player
	for s in schools:
		var lv: int = _player_skill(player, String(s))
		sum_scaled += lv * 200
		count += 1
	var power: int = 0
	if count > 0:
		power = sum_scaled / count
	power += _player_skill(player, "spellcasting") * 50
	return power


# Thread-local-ish context: the player whose spell we're about to evaluate.
# Set inside calc_spell_power / failure_rate, cleared on return.
static var _current_casting_player: Node = null


## DCSS calc_spell_power (spl-cast.cc:550). Runs the spell-power
## pipeline end-to-end: _skill_power → intel → enhancer ×1.5 →
## Wild/Subdued → stepdown → cap. Post-stepdown multipliers (horror,
## diminished, claustrophobia) remain TODO.
static func calc_spell_power(spell_id: String, player: Node) -> int:
	_ensure_loaded()
	if player == null:
		return 0
	_current_casting_player = player
	var sk_power: int = _skill_power(spell_id)
	_current_casting_player = null
	var intel: int = 10
	if "stats" in player and player.stats != null:
		intel = int(player.stats.INT)
	var power: int = sk_power * intel / 10
	# DCSS _apply_enhancement (spl-cast.cc:672). Each positive enhancer
	# level multiplies power by 1.5; each negative level halves it. This
	# replaces the old additive `staff_spell_bonus` caller hack, which
	# over-rewarded high-skill casters and under-rewarded low-skill ones.
	var enh: int = _enhancer_levels(spell_id, player)
	power = _apply_enhancement(power, enh)
	# DCSS Wild Magic / Subdued Magic mutations: ±30% to spell power
	# per level, applied before stepdown.
	var wild: int = int(player.get_meta("_mut_wild_magic", 0)) \
			if player.has_method("has_meta") else 0
	var subdued: int = int(player.get_meta("_mut_subdued_magic", 0)) \
			if player.has_method("has_meta") else 0
	if wild > 0:
		power = power * (10 + 3 * wild) / 10
	if subdued > 0:
		power = power * 10 / (10 + 3 * subdued)
	power = _stepdown_value(power * 10, 50000, 50000, 200000) / 1000
	# Apply DCSS spell_power_cap from our JSON when present.
	var dc: Dictionary = _dcss.get(spell_id, {})
	var cap: int = int(dc.get("power_cap", 0))
	if cap > 0:
		power = min(power, cap)
	return max(0, power)


## DCSS _apply_enhancement (spl-cast.cc:672). Positive levels: ×1.5
## each; negative levels: ÷2 each.
static func _apply_enhancement(power: int, levels: int) -> int:
	if levels > 0:
		for i in levels:
			power = power * 15 / 10
	elif levels < 0:
		for i in -levels:
			power = power / 2
	return power


## Sum enhancer levels for the given spell / player. Mirrors DCSS
## _spell_enhancement but only counts what our data model tracks:
##   +1  per matching magic staff equipped (WeaponRegistry.staff_spell_school)
##   +1  per matching elemental ring (ring_of_fire/cold/… when implemented)
##   -1  per level of MUT_ANTI_WIZARDRY mutation
static func _enhancer_levels(spell_id: String, player: Node) -> int:
	var lvl: int = 0
	# Staff school match.
	if "equipped_weapon_id" in player:
		var staff_sch: String = WeaponRegistry.staff_spell_school(player.equipped_weapon_id)
		if staff_sch != "":
			var schools: Array = get_schools(spell_id)
			for s in schools:
				if String(s) == staff_sch:
					lvl += 1
					break
	# Anti-wizardry mutation is a global negative enhancer.
	if player.has_method("has_meta"):
		lvl -= int(player.get_meta("_mut_anti_wizardry", 0))
	return lvl


## DCSS raw_spell_fail (spl-cast.cc:455). Polynomial interpolation of a
## chance-to-fail curve, clamped to [0, 100]. Multi-school spells use the
## average school skill via _skill_power above (DCSS does the same). The
## body-armour + shield encumbrance penalty uses
## `player.cc:player_armour_shield_spell_penalty` and makes heavy armour
## a real obstacle to casting.
static func failure_rate(spell_id: String, player: Node) -> int:
	_ensure_loaded()
	if player == null:
		return 99
	_current_casting_player = player
	var skpow: int = _skill_power(spell_id)
	_current_casting_player = null
	var intel: int = 10
	if "stats" in player and player.stats != null:
		intel = int(player.stats.INT)
	var chance: int = 60
	chance -= skpow * 6 / 100
	chance -= intel * 2
	chance += _armour_shield_spell_penalty(player)
	# Wild Magic: +4 fail per level. Subdued: -2 fail per level.
	# Anti-Wizardry: +4 per level.
	if player.has_method("has_meta"):
		chance += 4 * int(player.get_meta("_mut_wild_magic", 0))
		chance -= 2 * int(player.get_meta("_mut_subdued_magic", 0))
		chance += 4 * int(player.get_meta("_mut_anti_wizardry", 0))
	# Difficulty-by-level table from DCSS spl-cast.cc:481.
	var diff_by_lv: Array = [0, 3, 15, 35, 70, 100, 150, 200, 260, 340]
	var spell_level: int = _spell_level(spell_id)
	if spell_level < diff_by_lv.size():
		chance += int(diff_by_lv[spell_level])
	chance = min(chance, 400)
	# DCSS polynomial: ((x+426)*x + 82670)*x + 7245398 / 262144
	var c2: int = (((chance + 426) * chance) + 82670) * chance + 7245398
	c2 = c2 / 262144
	c2 = clampi(c2, 0, 100)
	# DCSS spl-cast.cc:failure_rate_to_int — the UI shows a smoothed
	# percentage derived by running the raw fail through a tetrahedral
	# distribution (3 × random2avg(100, 3)). This makes low raw values
	# feel safer in-hand than "25%" would imply, and is what the user
	# sees on their character sheet / targeting prompt.
	return _smooth_fail_to_display(c2)


## Port of DCSS failure_rate_to_int + _get_true_fail_rate. Converts a raw
## polynomial fail value into the displayed percentage the player reads
## on the spell-list screen.
static func _smooth_fail_to_display(raw_fail: int) -> int:
	if raw_fail <= 0:
		return 0
	if raw_fail >= 100:
		return (raw_fail + 100) / 2
	var target: int = raw_fail * 3
	var outcomes: int = 101 * 101 * 100  # 1,020,100
	var numerator: int
	if target <= 100:
		numerator = _tetrahedral_number(target)
	elif target <= 200:
		numerator = _tetrahedral_number(target) \
				- 2 * _tetrahedral_number(target - 101) \
				- _tetrahedral_number(target - 100)
	else:
		# target > 200 — DCSS uses symmetry around 300 for the upper half
		# of the distribution; mirror the low-side calc.
		var mirror: int = 300 - target
		var mirror_t: int
		if mirror >= 0:
			mirror_t = _tetrahedral_number(mirror)
		else:
			mirror_t = 0
		numerator = outcomes - mirror_t
	var pct: float = 100.0 * float(numerator) / float(outcomes)
	return max(1, int(round(pct)))


static func _tetrahedral_number(n: int) -> int:
	if n <= 0:
		return 0
	return n * (n + 1) * (n + 2) / 6


## DCSS player.cc:2198 player_armour_shield_spell_penalty. Returns the
## combined ENCUMBRANCE cost of the player's body armour + shield in
## fail-chance units, to be added directly to raw_spell_fail's `chance`.
## Returns 0 when no body armour / shield is equipped.
static func _armour_shield_spell_penalty(player: Node) -> int:
	if player == null:
		return 0
	var str_val: int = 10
	if "stats" in player and player.stats != null:
		str_val = int(player.stats.STR)
	var armour_skill: int = _player_skill(player, "armour")
	var shields_skill: int = _player_skill(player, "shields")
	var body: Dictionary = {}
	var shield: Dictionary = {}
	if "equipped_armor" in player and player.equipped_armor is Dictionary:
		body = player.equipped_armor.get("chest", {})
		shield = player.equipped_armor.get("shield", {})
	var body_pen: int = _adjusted_body_armour_penalty(body, str_val, armour_skill, 100)
	var shield_pen: int = _adjusted_shield_penalty(shield, str_val, shields_skill, 100)
	var total: int = 19 * max(body_pen, 0) + 19 * shield_pen
	return max(total, 0) / 100


## DCSS player::adjusted_body_armour_penalty (player.cc:6164). Quadratic in
## the armour's raw EV-penalty, softened by STR and armour skill.
##   2 * evp^2 * (450 - armour_skill*10) * scale / (5 * (str+3)) / 450
static func _adjusted_body_armour_penalty(body: Dictionary, str_val: int, armour_skill: int, scale: int) -> int:
	if body.is_empty():
		return 0
	# Our ArmorRegistry stores ev_penalty as the raw PARM_EVASION (negative).
	# DCSS `unadjusted_body_armour_penalty` divides by 10.
	var evp_raw: int = int(body.get("ev_penalty", 0))
	var base: int = max(0, -evp_raw / 10)
	if base <= 0:
		return 0
	return 2 * base * base * (450 - armour_skill * 10) * scale \
			/ (5 * (str_val + 3)) / 450


## DCSS player::adjusted_shield_penalty (player.cc:6179). Same shape, but
## the falloff uses SK_SHIELDS and a different STR/skill coefficient.
##   2 * evp^2 * (270 - shields_skill*10) * scale / (25 + 5*str) / 270
static func _adjusted_shield_penalty(shield: Dictionary, str_val: int, shields_skill: int, scale: int) -> int:
	if shield.is_empty():
		return 0
	var evp_raw: int = int(shield.get("ev_penalty", 0))
	var base: int = max(0, -evp_raw / 10)
	if base <= 0:
		return 0
	return 2 * base * base * (270 - shields_skill * 10) * scale \
			/ (25 + 5 * str_val) / 270


static func _spell_level(spell_id: String) -> int:
	var info: Dictionary = SPELLS.get(spell_id, {})
	if info.has("difficulty"):
		return int(info["difficulty"])
	var dc: Dictionary = _dcss.get(spell_id, {})
	return int(dc.get("level", 1))


## Evaluate the DCSS zap for this spell at the given power. Returns total
## damage rolled, or -1 if there's no zap data (caller should fall back to
## the spell's legacy min_dmg/max_dmg entry). Port of beam.cc's
## dicedef_calculator / calcdice_calculator → roll.
## DCSS beam flavour → our resistance element tag. Used by combat to
## route a zap's damage through the target's rF/rC/rPois/… scaling.
## Returns "physical" for pure-missile zaps (magic dart, stone arrow);
## "" when the spell has no zap data at all.
static func element_for(spell_id: String) -> String:
	_ensure_loaded()
	var zap: Dictionary = _zaps.get(spell_id, {})
	return String(zap.get("element", "")) if not zap.is_empty() else ""


static func roll_damage(spell_id: String, power: int) -> int:
	_ensure_loaded()
	var zap: Dictionary = _zaps.get(spell_id, {})
	if zap.is_empty():
		return -1
	var kind: String = String(zap.get("kind", "dicedef"))
	var n: int = int(zap.get("n", 1))
	var a: int = int(zap.get("a", 0))
	var mn: int = int(zap.get("mn", 0))
	var md: int = int(zap.get("md", 1))
	var size: int
	if kind == "calcdice":
		var max_dmg: int = a + power * mn / md
		# calc_dice: split max_dmg across n dice.
		if n <= 1:
			n = 1
			size = max_dmg
		elif max_dmg <= n:
			n = max_dmg
			size = 1
		else:
			size = max_dmg / n  # DCSS uses div_rand_round; approximate as floor
	else:  # dicedef
		size = a + power * mn / md
	if size <= 0:
		return 0
	var total: int = 0
	for i in n:
		total += randi_range(1, size)
	return total
