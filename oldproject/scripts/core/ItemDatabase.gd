extends Node
## Minimal ItemDatabase autoload stub for LPCSpriteLoader.
## Only the surfaces touched by LPCSpriteLoader are implemented:
##   - get_item(item_id) -> Dictionary   (uses "slot" field only)
##   - get_material_color(mat_id) -> Color
##
## Slot data is inferred from lpc_defs filename conventions so that
## _any_equipped_in_slot() can decide whether to draw default_shirt etc.

const _SLOT_BY_SUFFIX := {
	"_chest": "chest",
	"_legs":  "legs",
	"_boots": "feet",
	"_gloves":"hands",
	"_helm":  "head",
}

const _MATERIAL_COLORS := {
	"iron":   Color(0.72, 0.72, 0.78),
	"steel":  Color(0.80, 0.82, 0.88),
	"bronze": Color(0.80, 0.55, 0.30),
	"silver": Color(0.90, 0.90, 0.95),
	"gold":   Color(1.00, 0.85, 0.30),
	"leather":Color(0.55, 0.35, 0.20),
	"wood":   Color(0.50, 0.35, 0.20),
	"brown":  Color(0.55, 0.35, 0.20),
	"black":  Color(0.15, 0.15, 0.15),
	"white":  Color(0.95, 0.95, 0.95),
	"red":    Color(0.80, 0.20, 0.20),
	"blue":   Color(0.25, 0.40, 0.85),
	"green":  Color(0.30, 0.65, 0.30),
}

func get_item(item_id: String) -> Dictionary:
	# Infer slot from id suffix. Unknown items return empty dict.
	for suf in _SLOT_BY_SUFFIX.keys():
		if item_id.ends_with(suf):
			return {"id": item_id, "slot": _SLOT_BY_SUFFIX[suf]}
	return {}

func get_material_color(mat_id: String) -> Color:
	return _MATERIAL_COLORS.get(mat_id, Color.WHITE)
