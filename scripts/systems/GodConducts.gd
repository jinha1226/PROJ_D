class_name GodConducts
extends RefCounted
## Per-god kill conducts, extracted from GameBootstrap.
##
## Pure function of (god_id, monster, base_gain) → adjusted_gain.
## Negative result = piety loss + "god frowns" log line (caller
## handles the log since the player's god title lives in the scene).

## Adjust the per-kill piety gain for the player's currently-pledged
## god based on the victim's holiness / genus. Returns `base_gain`
## unchanged when no conduct applies.
static func apply(god_id: String, monster, base_gain: int) -> int:
	if monster == null or monster.data == null:
		return base_gain
	var holiness: String = _derive_holiness(monster)
	var mid: String = String(monster.data.id) if "id" in monster.data else ""
	match god_id:
		"the_shining_one":
			# Bonus piety for slaying the restless dead or demonkind.
			if holiness == "undead" or holiness == "demonic":
				return base_gain + maxi(1, base_gain / 2)
		"yredelemnul":
			# Mirror of TSO — rewards holy kills, penalises killing the
			# undead who serve the same god in spirit.
			if holiness == "holy":
				return base_gain + 2
			if holiness == "undead":
				return -1
		"zin":
			# Zin condemns chaos and mutation. Chaos spawn / shapeshifters
			# anger the god on kill; slaying demons still gains piety.
			if "chaos" in mid or "shapeshifter" in mid:
				return -1
			if holiness == "demonic":
				return base_gain + 1
		"elyvilon":
			# The pacifist god. Natural / neutral kills cost piety;
			# only the unnatural are fair game.
			if holiness == "undead" or holiness == "demonic":
				return base_gain
			return -1
		"cheibriados":
			# No per-kill conduct — speed is the sin, not slaughter.
			return base_gain
		"beogh":
			# Orc-killers insult the god hard.
			if mid.begins_with("orc") or "orc_" in mid or mid == "orc":
				return -3
		"fedhas":
			# Plants are sacred.
			if holiness == "plant":
				return -2
		"okawaru":
			# Lone warrior — no kill conduct (summon/ally ban lives
			# on the invocation side).
			return base_gain
	return base_gain


## Derive holiness tag from monster shape + flags the same way
## CombatSystem / Monster do — "undead" / "demonic" / "holy" / "plant"
## / "natural". Empty string when no conduct class matches.
static func _derive_holiness(monster) -> String:
	if monster.data == null:
		return ""
	if String(monster.data.shape) == "undead":
		return "undead"
	if monster.data.flags == null:
		return ""
	for f in monster.data.flags:
		var lf: String = String(f).to_lower()
		if lf in ["undead", "demonic", "holy", "plant", "natural"]:
			return lf
	return ""
