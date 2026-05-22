class_name ExplorerNPC extends NPCActor

## A dungeon explorer NPC rendered with a DCSS tile chosen at spawn.
## Tile is seeded per-instance and stays fixed until the NPC dies.

const NAMES: Array = [
	"Aldric", "Vera", "Jorim", "Solen", "Mira",
	"Thane", "Cass", "Elun", "Brek", "Fiona",
	"Daren", "Yola", "Keth", "Pern", "Sari",
]

## Melee weapon pool (tier 1-2). Picked at spawn.
const WEAPON_POOL: Array = ["dagger", "short_sword", "mace", "spear", "arming_sword"]
## Armor pool (tier 1-2). Picked at spawn.
const ARMOR_POOL: Array  = ["leather_armor", "robe", "ring_mail"]

## DCSS tile pool for random NPC appearance.
const TILE_POOL: Array = [
	"res://assets/tiles/individual/mon/humanoids/humans/human.png",
	"res://assets/tiles/individual/mon/humanoids/humans/human2.png",
	"res://assets/tiles/individual/mon/humanoids/humans/human3.png",
	"res://assets/tiles/individual/mon/humanoids/humans/vault_guard.png",
	"res://assets/tiles/individual/mon/humanoids/humans/vault_sentinel.png",
	"res://assets/tiles/individual/mon/humanoids/humans/occultist.png",
	"res://assets/tiles/individual/mon/humanoids/humans/arcanist.png",
	"res://assets/tiles/individual/mon/humanoids/humans/necromancer.png",
	"res://assets/tiles/individual/mon/humanoids/elves/elf.png",
	"res://assets/tiles/individual/mon/humanoids/elves/deep_elf_knight.png",
	"res://assets/tiles/individual/mon/humanoids/elves/deep_elf_archer.png",
	"res://assets/tiles/individual/mon/humanoids/dwarf.png",
]

var _tile: Texture2D = null
var _font: Font = null

## Race chosen at spawn. Stored so NPCInfoDialog can display it.
var race_id: String = "human"


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
	skills["weapon_mastery"] = 3
	skills["tactics"] = 2
	skills["defense"] = 2
	_randomize_appearance()
	_assign_starter_equipment()


func _randomize_appearance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc_name) ^ get_instance_id()
	var tile_path: String = TILE_POOL[rng.randi() % TILE_POOL.size()]
	if ResourceLoader.exists(tile_path):
		_tile = load(tile_path) as Texture2D

	# Assign race_id from tile path for NPCInfoDialog display.
	if "elf" in tile_path:
		race_id = "elf"
	elif "dwarf" in tile_path:
		race_id = "dwarf"
	else:
		race_id = "human"


func _assign_starter_equipment() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc_name) ^ get_instance_id() ^ 0xE901

	equipped_weapon_id = WEAPON_POOL[rng.randi() % WEAPON_POOL.size()]
	equipped_armor_id  = ARMOR_POOL[rng.randi() % ARMOR_POOL.size()]

	# Apply base AC from armor.
	var armor_ac: Dictionary = {
		"leather_armor": 3,
		"robe":          1,
		"ring_mail":     5,
	}
	ac = armor_ac.get(equipped_armor_id, 2)


func _draw() -> void:
	if _map == null:
		return
	var cs: float = float(DungeonMap.CELL_SIZE)
	if _tile != null:
		draw_texture_rect(_tile, Rect2(0.0, 0.0, cs, cs), false)
	else:
		# Fallback glyph when tile is missing.
		if _font != null:
			draw_string(_font, Vector2(6.0, cs - 6.0),
				"@", HORIZONTAL_ALIGNMENT_LEFT, -1, int(cs) - 6,
				Color(1.0, 0.78, 0.25))

	# Small name label below sprite.
	if _font != null:
		draw_string(_font, Vector2(1.0, cs - 1.0), npc_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.78, 0.25, 0.9))
