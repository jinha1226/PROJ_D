class_name ExplorerNPC extends NPCActor

## A dungeon explorer NPC: full stats, equipment slots, social relations.
## Wanders toward enemies, collects loot, and may form alliances with other
## explorers if outnumbered.

const NAMES: Array = [
	"Aldric", "Vera", "Jorim", "Solen", "Mira",
	"Thane", "Cass", "Elun", "Brek", "Fiona",
	"Daren", "Yola", "Keth", "Pern", "Sari",
]

var _font: Font = null

func _ready() -> void:
	super._ready()
	_font = ThemeDB.fallback_font
	npc_name = NAMES[randi() % NAMES.size()]
	# Base stats — mid-tier adventurer
	hp = 25
	hp_max = 25
	mp = 4
	mp_max = 4
	strength = 10
	dexterity = 12
	intelligence = 8
	slay_bonus = 2
	ev = 8
	# Skills
	skills["weapon_mastery"] = 3
	skills["tactics"] = 2
	skills["defense"] = 2

func _draw() -> void:
	if _font == null or _map == null:
		return
	var sz: int = DungeonMap.CELL_SIZE
	# "@" glyph in warm amber — distinct from player (white) and monsters
	draw_string(_font, Vector2(6, sz - 6),
		"@", HORIZONTAL_ALIGNMENT_LEFT, -1, sz - 6,
		Color(1.0, 0.78, 0.25))
