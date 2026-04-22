class_name AmuletRegistry
extends RefCounted
## DCSS amulet catalog. One amulet slot; effects mirror the DCSS 0.34
## amulet list. Each entry carries:
##   name        — display name
##   label       — "of X" suffix for random-find messages
##   color       — map-glyph tint
##   stat_bonus  — Dict applied to player stats at equip (same keys as rings)
##   flag        — engine meta set as "_amulet_<flag>" on Player (checked
##                 by combat / movement / cast pipelines)
##   resists     — Dict{element: level} added to get_resist()
## Missing keys mean no effect in that category.

const DATA: Dictionary = {
	"amulet_faith": {
		"name":  "Amulet of Faith",
		"label": "of faith",
		"color": Color(1.00, 0.90, 0.30),
		"flag":  "piety_boost",
		# Increases piety gain from all sources by ~50%. Checked in
		# GodSystem.award_piety: if player has_meta("_amulet_piety_boost")
		# multiply the award by 1.5 before applying.
	},
	"amulet_magic_mastery": {
		"name":       "Amulet of Magic Mastery",
		"label":      "of magic mastery",
		"color":      Color(0.55, 0.40, 1.00),
		"stat_bonus": {"spellpower": 5},
		# DCSS: acts as +50 to all spell-power-contributing skill totals.
		# We approximate with a flat +5 to the computed spell-power bonus.
	},
	"amulet_regeneration": {
		"name":       "Amulet of Regeneration",
		"label":      "of regeneration",
		"color":      Color(0.40, 1.00, 0.55),
		"stat_bonus": {"regen": 1},
		# Grants +1 HP regen per turn. Player._tick_duration_metas already
		# reads stats.regen (or a "regen" meta); _recompute_gear_stats folds
		# the bonus in via the same path as ring_regeneration.
	},
	"amulet_acrobat": {
		"name":  "Amulet of the Acrobat",
		"label": "of the acrobat",
		"color": Color(0.20, 0.80, 1.00),
		"flag":  "acrobat",
		# +5 EV when the player did not melee-attack or cast a spell this
		# turn. Checked in PlayerDefense.player_evasion when the flag is set.
	},
	"amulet_reflection": {
		"name":  "Amulet of Reflection",
		"label": "of reflection",
		"color": Color(0.90, 0.90, 1.00),
		"flag":  "reflect",
		# Reflects projectiles and beams. Handled by the same "_ego_reflect"
		# (shield) and "_amulet_reflect" checks; Beam.gd reads both metas.
	},
	"amulet_stasis": {
		"name":  "Amulet of Stasis",
		"label": "of stasis",
		"color": Color(0.70, 0.70, 0.85),
		"flag":  "stasis",
		# Prevents teleportation (including Zot/Shaft traps), blinking,
		# hasting, and slowing. Checked at the point of application in
		# Player.apply_status / trap handlers / spell targets.
	},
	"amulet_guardian_spirit": {
		"name":  "Amulet of the Guardian Spirit",
		"label": "of the guardian spirit",
		"color": Color(1.00, 0.85, 0.55),
		"flag":  "spirit_shield",
		# When HP damage is taken, half is drained from MP instead.
		# Handled in Player.take_damage alongside the SPARM_SPIRIT_SHIELD
		# check — the "_amulet_spirit_shield" meta is checked there.
	},
	"amulet_gourmand": {
		"name":  "Amulet of Gourmand",
		"label": "of gourmand",
		"color": Color(0.75, 0.55, 0.25),
		"flag":  "gourmand",
		# Allows eating raw meat without a hunger penalty and boosts
		# nutrition from food items. Minor in current mobile build; flag
		# is wired so a future hunger system can read it.
	},
	"amulet_nothing": {
		"name":  "Amulet of Nothing",
		"label": "of nothing",
		"color": Color(0.55, 0.55, 0.55),
		# No mechanical effect. Exists so floor-item drops always produce
		# a valid amulet dict and the equip/unequip path is exercised.
	},
}


static func is_amulet(id: String) -> bool:
	return DATA.has(id)


## Copy with id + slot/kind baked in. Same convention as RingRegistry.
static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate()
	d["id"]   = id
	d["slot"] = "amulet"
	d["kind"] = "amulet"
	return d


static func display_name_for(id: String) -> String:
	return String(DATA.get(id, {}).get("name", id.capitalize().replace("_", " ")))


static func all_ids() -> Array:
	return DATA.keys()


## Pick a random amulet for floor drops. All entries weighted equally.
static func random_id() -> String:
	var keys: Array = DATA.keys()
	return String(keys[randi() % keys.size()])
