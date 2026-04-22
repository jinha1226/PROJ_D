class_name RuneRegistry
extends Object
## DCSS runes — 15 collectible MacGuffins, one per "runed" branch.
## Needed to unlock Zot (≥ 3 runes in DCSS standard); the Orb of Zot
## on Zot:5 is the final objective once Zot is accessible.
##
## Each entry:
##   id             — "decaying_rune" etc.
##   name           — Display name ("decaying rune of Zot").
##   source_branch  — branch id the rune drops in (floor = max depth).
##   color          — Godot Color for tile / popup tint.
##   glyph          — ASCII fallback char.

const RUNES: Dictionary = {
	"decaying_rune": {
		"name": "decaying rune of Zot",
		"source_branch": "swamp",
		"color": Color(0.45, 0.70, 0.25),
		"glyph": "Ω",
	},
	"serpentine_rune": {
		"name": "serpentine rune of Zot",
		"source_branch": "snake",
		"color": Color(0.35, 0.85, 0.45),
		"glyph": "Ω",
	},
	"gossamer_rune": {
		"name": "gossamer rune of Zot",
		"source_branch": "spider",
		"color": Color(0.85, 0.85, 1.00),
		"glyph": "Ω",
	},
	"barnacled_rune": {
		"name": "barnacled rune of Zot",
		"source_branch": "shoals",
		"color": Color(0.50, 0.75, 0.95),
		"glyph": "Ω",
	},
	"slimy_rune": {
		"name": "slimy rune of Zot",
		"source_branch": "slime",
		"color": Color(0.60, 0.95, 0.25),
		"glyph": "Ω",
	},
	"silver_rune": {
		"name": "silver rune of Zot",
		"source_branch": "vaults",
		"color": Color(0.90, 0.90, 0.95),
		"glyph": "Ω",
	},
	"golden_rune": {
		"name": "golden rune of Zot",
		"source_branch": "tomb",
		"color": Color(1.00, 0.85, 0.25),
		"glyph": "Ω",
	},
	"iron_rune": {
		"name": "iron rune of Zot",
		"source_branch": "dis",
		"color": Color(0.55, 0.55, 0.65),
		"glyph": "Ω",
	},
	"obsidian_rune": {
		"name": "obsidian rune of Zot",
		"source_branch": "gehenna",
		"color": Color(0.95, 0.35, 0.15),
		"glyph": "Ω",
	},
	"icy_rune": {
		"name": "icy rune of Zot",
		"source_branch": "cocytus",
		"color": Color(0.75, 0.95, 1.00),
		"glyph": "Ω",
	},
	"bone_rune": {
		"name": "bone rune of Zot",
		"source_branch": "tartarus",
		"color": Color(0.85, 0.80, 0.70),
		"glyph": "Ω",
	},
	"abyssal_rune": {
		"name": "abyssal rune of Zot",
		"source_branch": "abyss",
		"color": Color(0.45, 0.10, 0.65),
		"glyph": "Ω",
	},
	"demonic_rune": {
		"name": "demonic rune of Zot",
		"source_branch": "pan",
		"color": Color(0.85, 0.25, 0.95),
		"glyph": "Ω",
	},
	"mossy_rune": {
		"name": "mossy rune of Zot",
		"source_branch": "lair",  # DCSS Lair Rune (Forest branch actually)
		"color": Color(0.45, 0.80, 0.35),
		"glyph": "Ω",
	},
	"glowing_rune": {
		"name": "glowing rune of Zot",
		"source_branch": "elf",
		"color": Color(1.00, 1.00, 0.55),
		"glyph": "Ω",
	},
}


## Minimum runes required to pass the Zot entry gate. DCSS standard:
## the Zot entrance on Depths:5 demands 3 runes. Harder challenges
## require more but the base gate matches 3.
const ZOT_GATE_REQUIREMENT: int = 3


static func has(id: String) -> bool:
	return RUNES.has(id)


static func get_info(id: String) -> Dictionary:
	var info: Dictionary = RUNES.get(id, {})
	return info.duplicate() if not info.is_empty() else {}


static func all_ids() -> Array:
	return RUNES.keys()


## The rune id that drops in `branch_id`, or "" if that branch carries
## no rune. Called by DungeonGenerator to decide whether the floor
## should spawn a rune pickup.
static func rune_for_branch(branch_id: String) -> String:
	for rid in RUNES.keys():
		if String(RUNES[rid].get("source_branch", "")) == branch_id:
			return String(rid)
	return ""
