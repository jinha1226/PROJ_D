class_name WandRegistry
extends RefCounted
## DCSS-faithful wand catalog. Each entry maps a wand id → the spell id
## its evocation fires (per spl-book.cc:_wand_spells) plus the charge
## count formula from item-prop.cc:wand_charge_value. The 12 current DCSS
## wands are all present.
##
## Runtime flow (see Player.evoke_wand / GameBootstrap._on_wand_evoked):
##   1. Target picker for direct/hex wands (utility wands self-target).
##   2. Evocations skill scales the effective spell power (DCSS uses a
##      similar "wand power = evo_skill * 7.5 + 15" — we reuse
##      SpellRegistry.calc_spell_power with evocations substituting for
##      school skill).
##   3. roll_damage / effect handler applies the zap.
##   4. charges -= 1; wand destroyed at 0.

const DATA: Dictionary = {
	"wand_flame": {
		"name": "Wand of Flame",
		"spell": "throw_flame", "kind": "direct",
		"charges_base": 16, "charges_rand": 16,
		"color": Color(1.00, 0.35, 0.15),
		"desc": "A thrown bolt of flame. Hurts fire-resistants little.",
	},
	"wand_iceblast": {
		"name": "Wand of Iceblast",
		"spell": "iceblast", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.60, 0.85, 1.00),
		"desc": "An explosion of ice. Splashes an area.",
	},
	"wand_acid": {
		"name": "Wand of Acid",
		"spell": "corrosive_bolt", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.60, 0.80, 0.30),
		"desc": "A jet of corrosive acid. Strips AC on hit.",
	},
	"wand_light": {
		"name": "Wand of Light",
		"spell": "bolt_of_light", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(1.00, 1.00, 0.85),
		"desc": "A piercing beam of holy light.",
	},
	"wand_quicksilver": {
		"name": "Wand of Quicksilver",
		"spell": "quicksilver_bolt", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.85, 0.85, 0.90),
		"desc": "Strips magical buffs from the target and damages it.",
	},
	"wand_mindburst": {
		"name": "Wand of Mindburst",
		"spell": "mindburst", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.75, 0.40, 0.85),
		"desc": "A burst of psychic energy. Ignores armour.",
	},
	"wand_warping": {
		"name": "Wand of Warping",
		"spell": "warp_space", "kind": "direct",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.85, 0.55, 1.00),
		"desc": "Warps space, pulling the target toward you.",
	},
	"wand_roots": {
		"name": "Wand of Roots",
		"spell": "fastroot", "kind": "hex_root",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.45, 0.65, 0.25),
		"desc": "Roots burst from the ground, holding the target in place.",
	},
	"wand_paralysis": {
		"name": "Wand of Paralysis",
		"spell": "paralyse", "kind": "hex_paralyse",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.55, 0.55, 0.80),
		"desc": "Locks the target in place — no actions for several turns.",
	},
	"wand_charming": {
		"name": "Wand of Charming",
		"spell": "charming", "kind": "hex_charm",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.95, 0.55, 0.70),
		"desc": "Turns the target into a willing ally.",
	},
	"wand_polymorph": {
		"name": "Wand of Polymorph",
		"spell": "polymorph", "kind": "hex_poly",
		"charges_base": 8, "charges_rand": 7,
		"color": Color(0.75, 0.85, 0.45),
		"desc": "Transforms the target into a different creature.",
	},
	"wand_digging": {
		"name": "Wand of Digging",
		"spell": "dig", "kind": "utility_dig",
		"charges_base": 9, "charges_rand": 0,
		"color": Color(0.70, 0.55, 0.30),
		"desc": "Bores through rock walls. Does not hurt monsters.",
	},
}


static func has(id: String) -> bool:
	return DATA.has(id)


static func get_info(id: String) -> Dictionary:
	if not DATA.has(id):
		return {}
	var d: Dictionary = DATA[id].duplicate()
	d["id"] = id
	return d


## DCSS item-prop.cc:wand_charge_value — initial charges on a wand. Depth
## affects only WAND_FLAME and the "late-game" wands; we keep the simpler
## `base + randi(rand)` form since our item generator doesn't hand us
## item_level the way DCSS does.
static func roll_charges(id: String) -> int:
	var info: Dictionary = DATA.get(id, {})
	if info.is_empty():
		return 1
	var base: int = int(info.get("charges_base", 4))
	var r: int = int(info.get("charges_rand", 0))
	return max(1, base + (randi() % max(r, 1) if r > 0 else 0))


## List of all wand ids — used by the floor-gen depth-weighted picker.
static func all_ids() -> Array:
	return DATA.keys()


## Targeting mode for a wand kind: "self" (digging), "single" (direct
## damage or single-target hex), "area" (iceblast splash). Used by the
## GameBootstrap evoke flow to pick the right UI.
static func targeting_for(id: String) -> String:
	var info: Dictionary = DATA.get(id, {})
	match String(info.get("kind", "")):
		"utility_dig": return "direction"
		_:             return "single"
