class_name GodRegistry
extends RefCounted
## DCSS god roster (minimal port). Each entry carries:
##   name        — display name
##   title       — what the player worships as ("Trog", "the Shining One")
##   piety_cap   — 200 in DCSS (corresponding roughly to "*******")
##   like_kills  — piety gain per monster kill (any victim)
##   hate_* flags — conducts we enforce (spells for Trog, chaos for Zin, …)
##   invocations — list of ability ids the god grants (see INVOCATIONS below)
##
## This is intentionally a small subset of DCSS's 22+ gods. We ship three
## archetypes that cover the main play styles (melee, caster, generalist),
## leaving room for a broader roster in a later commit.

const GODS: Dictionary = {
	"trog": {
		"name": "Trog",
		"title": "Trog the Wrathful",
		"color": Color(0.90, 0.25, 0.15),
		"piety_cap": 200,
		"kill_piety": 3,
		"hates_spells": true,           # casting spells costs piety
		"desc": "Hate casters, love murder. Berserker fist-god.",
		"invocations": ["berserk", "trog_hand", "brothers_in_arms"],
	},
	"okawaru": {
		"name": "Okawaru",
		"title": "Okawaru",
		"color": Color(0.85, 0.70, 0.25),
		"piety_cap": 200,
		"kill_piety": 2,
		"desc": "Champion of tactical warriors. Gifts weapons and armour.",
		"invocations": ["heroism", "finesse"],
	},
	"zin": {
		"name": "Zin",
		"title": "Zin",
		"color": Color(1.00, 0.95, 0.80),
		"piety_cap": 200,
		"kill_piety": 1,
		"hates_mutation": true,
		"desc": "Law and purity. Heals the faithful, abhors chaos.",
		"invocations": ["vitalisation", "imprison"],
	},
}

## Per-invocation defs. `cost` is the piety spent on use; `min_piety` is the
## piety threshold at which the god grants the ability; `effect` is a free-
## form string that GameBootstrap._invoke dispatches on.
const INVOCATIONS: Dictionary = {
	"berserk": {
		"name": "Berserk", "cost": 25, "min_piety": 30, "effect": "berserk",
		"desc": "Fly into a rage: +damage, +HP, +haste for 15-25 turns.",
	},
	"trog_hand": {
		"name": "Hand of Trog", "cost": 40, "min_piety": 50, "effect": "trog_hand",
		"desc": "Summons a berserker ally to fight at your side.",
	},
	"brothers_in_arms": {
		"name": "Brothers in Arms", "cost": 75, "min_piety": 120, "effect": "brothers",
		"desc": "Summon 3 temporary berserker warriors.",
	},
	"heroism": {
		"name": "Heroism", "cost": 15, "min_piety": 20, "effect": "heroism",
		"desc": "Temporary +5 to all weapon / fighting skills.",
	},
	"finesse": {
		"name": "Finesse", "cost": 35, "min_piety": 60, "effect": "finesse",
		"desc": "Your attacks strike twice per turn (10 turns).",
	},
	"vitalisation": {
		"name": "Vitalisation", "cost": 20, "min_piety": 25, "effect": "vitalisation",
		"desc": "Heals 40 HP and restores 20 MP.",
	},
	"imprison": {
		"name": "Imprison", "cost": 60, "min_piety": 80, "effect": "imprison",
		"desc": "Wall off a single visible foe with stone for 10 turns.",
	},
}


static func has(id: String) -> bool:
	return GODS.has(id)


static func get_info(id: String) -> Dictionary:
	return GODS.get(id, {}).duplicate() if GODS.has(id) else {}


static func all_ids() -> Array:
	return GODS.keys()


static func invocation(id: String) -> Dictionary:
	return INVOCATIONS.get(id, {}).duplicate() if INVOCATIONS.has(id) else {}


## Invocations unlocked at `piety` for `god_id`. Caller can use this to
## render the ability list: dimmed rows below the threshold, bright ones
## above.
static func available_invocations(god_id: String, piety: int) -> Array:
	var out: Array = []
	for inv_id in get_info(god_id).get("invocations", []):
		var inv: Dictionary = invocation(String(inv_id))
		if int(inv.get("min_piety", 0)) <= piety:
			out.append(String(inv_id))
	return out
