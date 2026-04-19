class_name SkillSystem
extends Node
## DCSS-style skill system. Each skill has integer level (0..27) and an XP pool.
## XP is distributed to trained skills whose ids appear in `usage_tags` on each
## grant (typically a monster kill). UI is a separate agent's concern — this
## module only owns the data model + combat-facing getters.

signal skill_leveled_up(player, skill_id: String, new_level: int)
signal xp_gained(player, skill_id: String, amount: float)

const MAX_LEVEL: int = 27
var auto_training: bool = true

const SKILL_IDS: Array = [
	# Weapons
	"axe", "short_blade", "long_blade", "mace", "polearm", "staff",
	"bow", "crossbow", "sling", "throwing",
	# Defense
	"fighting", "armour", "dodging", "shields",
	# Magic (reserved for M2 but defined)
	"spellcasting", "conjurations", "fire", "cold", "earth", "air",
	"necromancy", "hexes", "translocations", "summonings",
	# Misc
	"stealth", "evocations", "essence_channeling",
]

const SKILL_CATEGORY: Dictionary = {
	"axe": "weapon", "short_blade": "weapon", "long_blade": "weapon",
	"mace": "weapon", "polearm": "weapon", "staff": "weapon",
	"bow": "weapon", "crossbow": "weapon", "sling": "weapon", "throwing": "weapon",

	"fighting": "defense", "armour": "defense", "dodging": "defense", "shields": "defense",

	"spellcasting": "magic", "conjurations": "magic", "fire": "magic", "cold": "magic",
	"earth": "magic", "air": "magic", "necromancy": "magic", "hexes": "magic",
	"translocations": "magic", "summonings": "magic",

	"stealth": "misc", "evocations": "misc", "essence_channeling": "misc",
}

## Weapon id → skill id. Used by combat to determine which skill a weapon trains.
## Mirrors WeaponRegistry.weapon_skill_for() but available as a static dict for
## cheap iteration / defaulting.
const WEAPON_SKILL: Dictionary = {
	"axe": "axe", "axe_medium": "axe", "waraxe": "axe",
	"club": "mace", "mace": "mace", "flail": "mace",
	"dagger": "short_blade", "short_sword": "short_blade",
	"rapier": "short_blade", "saber": "short_blade",
	"arming_sword": "long_blade", "longsword": "long_blade",
	"katana": "long_blade", "scimitar": "long_blade", "greatsword": "long_blade",
	"spear": "polearm", "longspear": "polearm", "halberd": "polearm",
	"scythe": "polearm", "trident": "polearm",
	"short_bow": "bow", "long_bow": "bow", "bow": "bow",
	"crossbow": "crossbow",
	"slingshot": "sling",
	"boomerang": "throwing",
	"fire_staff": "staff", "ice_staff": "staff", "lightning_staff": "staff",
	"gnarled_staff": "staff", "crystal_staff": "staff",
	"wand_simple": "evocations",
}


## XP to reach `level` from `level-1`. Curve: 30 * 1.5^(level-1).
## L1=30, L2=45, L3=67, L4=101, L5=152, L10=1153, L15=8757, L27≈1_100_000.
static func xp_for_level(level: int) -> float:
	if level <= 0:
		return 0.0
	return 30.0 * pow(1.5, float(level - 1))


## Initialize skill state on a player. Modifies player.skill_state in place.
func init_for_player(player: Node, starting_skills: Dictionary) -> void:
	if player == null:
		return
	var state: Dictionary = {}
	for id in SKILL_IDS:
		state[id] = {
			"level": 0,
			"xp": 0.0,
			"training": false,
		}
	# Seed starting levels.
	for id in starting_skills.keys():
		if not state.has(id):
			continue
		state[id]["level"] = int(starting_skills[id])
		state[id]["training"] = true
	# Default-training for core defense skills.
	if state.has("fighting"):
		state["fighting"]["training"] = true
	if state.has("armour"):
		state["armour"]["training"] = true
	# Any weapon skill with level > 0 → training.
	for id in state.keys():
		if SKILL_CATEGORY.get(id, "") == "weapon" and state[id]["level"] > 0:
			state[id]["training"] = true
	if "skill_state" in player:
		player.skill_state = state
	else:
		player.set_meta("skills", state)


## Aptitude for this player + skill. Reads Player.race_res.skill_aptitudes
## so racial specialisation (Deep Elf +3 fire, Minotaur -3 spellcasting,
## etc.) translates into XP-per-kill modifiers. Returns 0 if not set.
func _aptitude_for(player: Node, skill_id: String) -> int:
	if player == null:
		return 0
	if not ("race_res" in player) or player.race_res == null:
		return 0
	var apts: Dictionary = player.race_res.skill_aptitudes
	return int(apts.get(skill_id, 0))


func _state_for(player: Node) -> Dictionary:
	if player == null:
		return {}
	if "skill_state" in player and player.skill_state is Dictionary:
		return player.skill_state
	if player.has_meta("skills"):
		return player.get_meta("skills")
	return {}


func get_level(player: Node, skill_id: String) -> int:
	var st: Dictionary = _state_for(player)
	if not st.has(skill_id):
		return 0
	return int(st[skill_id].get("level", 0))


func get_xp(player: Node, skill_id: String) -> float:
	var st: Dictionary = _state_for(player)
	if not st.has(skill_id):
		return 0.0
	return float(st[skill_id].get("xp", 0.0))


func is_training(player: Node, skill_id: String) -> bool:
	var st: Dictionary = _state_for(player)
	if not st.has(skill_id):
		return false
	return bool(st[skill_id].get("training", false))


func set_training(player: Node, skill_id: String, enabled: bool) -> void:
	var st: Dictionary = _state_for(player)
	if not st.has(skill_id):
		return
	st[skill_id]["training"] = enabled


## Grant `amount` XP, split evenly among trained skills matching any tag in
## `usage_tags`. If no trained skill matches, fall back to trained defense
## skills (passive XP). Returns list of `{skill_id, old_level, new_level}`
## for any level-ups that occurred.
func grant_xp(player: Node, amount: float, usage_tags: Array) -> Array:
	var results: Array = []
	if player == null or amount <= 0.0:
		return results
	var st: Dictionary = _state_for(player)
	if st.is_empty():
		return results

	var matched: Array = []
	for tag in usage_tags:
		var tag_s: String = String(tag)
		if tag_s == "":
			continue
		if not st.has(tag_s):
			continue
		if auto_training or bool(st[tag_s].get("training", false)):
			if not matched.has(tag_s):
				matched.append(tag_s)

	if matched.is_empty():
		for id in st.keys():
			if SKILL_CATEGORY.get(id, "") == "defense":
				if auto_training or bool(st[id].get("training", false)):
					matched.append(id)

	if matched.is_empty():
		return results

	var share: float = amount / float(matched.size())
	for skill_id in matched:
		var entry: Dictionary = st[skill_id]
		var old_level: int = int(entry.get("level", 0))
		if old_level >= MAX_LEVEL:
			continue
		# Aptitude modifier: DCSS formula — each +1 apt multiplies the
		# effective XP gained by ~1.41× (faster levelling). -1 halves it.
		var apt: int = _aptitude_for(player, skill_id)
		var effective: float = share * pow(2.0, float(apt) / 2.0)
		entry["xp"] = float(entry.get("xp", 0.0)) + effective
		xp_gained.emit(player, skill_id, effective)
		var new_level: int = old_level
		while new_level < MAX_LEVEL:
			var needed: float = xp_for_level(new_level + 1)
			if float(entry["xp"]) >= needed:
				entry["xp"] = float(entry["xp"]) - needed
				new_level += 1
			else:
				break
		if new_level != old_level:
			entry["level"] = new_level
			results.append({
				"skill_id": skill_id,
				"old_level": old_level,
				"new_level": new_level,
			})
			skill_leveled_up.emit(player, skill_id, new_level)
	return results


## Convenience: derive weapon skill id for a weapon id.
static func weapon_skill_for(weapon_id: String) -> String:
	return String(WEAPON_SKILL.get(weapon_id, ""))
