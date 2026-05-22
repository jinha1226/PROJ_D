class_name ExplorerNPC extends NPCActor

## A dungeon explorer NPC rendered with a randomly chosen ULPC sprite.
## Appearance is seeded per-instance so it stays consistent until the NPC dies.

## Melee weapon pool (tier 1-2). Picked at spawn.
const WEAPON_POOL: Array = ["dagger", "short_sword", "mace", "spear", "arming_sword"]
## Armor pool (tier 1-2). Picked at spawn.
const ARMOR_POOL: Array  = ["leather_armor", "robe", "ring_mail"]

const NAMES: Array = [
	"Aldric", "Vera", "Jorim", "Solen", "Mira",
	"Thane", "Cass", "Elun", "Brek", "Fiona",
	"Daren", "Yola", "Keth", "Pern", "Sari",
]

# Races available for random NPC generation.
const _NPC_RACES: Array = ["human", "elf", "dwarf", "hill_orc"]

# Hair colors used for human/elf/dwarf (plain style).
const _HAIR_COLORS: Array = [
	"black", "blonde", "chestnut", "dark_brown", "ginger",
	"gold", "gray", "light_brown", "red", "ash",
]

const WALK_FRAME_COUNT: int = 9
const WALK_FRAME_TIME: float = 0.14
const SPRITE_W: int = 64
const SPRITE_H: int = 64

var _body_tex: Texture2D = null
var _body_color: Color = Color.WHITE
var _head_textures: Array = []  # Array[Texture2D]
var _anim_frame: int = 0
var _anim_timer: float = 0.0
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


func _process(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= WALK_FRAME_TIME:
		_anim_timer -= WALK_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % WALK_FRAME_COUNT
		queue_redraw()


func _randomize_appearance() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(npc_name) ^ get_instance_id()

	var race: String = _NPC_RACES[rng.randi() % _NPC_RACES.size()]
	race_id = race

	var body_path := PlayerRenderer.race_body_path(race)
	_body_tex = PlayerRenderer.load_ulpc_tex(body_path)
	_body_color = PlayerRenderer.race_body_color(race)

	var overlays: Array = PlayerRenderer.race_head_overlays(race)
	_head_textures.clear()
	for path: String in overlays:
		var t := PlayerRenderer.load_ulpc_tex(path)
		if t != null:
			_head_textures.append(t)

	# Human/elf/dwarf get a random hair color overlay on top of head overlays.
	if race in ["human", "elf", "dwarf"]:
		var color: String = _HAIR_COLORS[rng.randi() % _HAIR_COLORS.size()]
		var hair_path := PlayerRenderer.hair_plain_path(color)
		if hair_path != "":
			var ht := PlayerRenderer.load_ulpc_tex(hair_path)
			if ht != null:
				_head_textures.append(ht)

	queue_redraw()


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
	var cs := float(DungeonMap.CELL_SIZE)
	var dir_row: int = _facing_to_row()
	var src_x: int = _anim_frame * SPRITE_W
	var src_y: int = dir_row * SPRITE_H
	var src_rect := Rect2(src_x, src_y, SPRITE_W, SPRITE_H)
	var dst_rect := Rect2(0.0, 0.0, cs, cs)

	if _body_tex != null:
		draw_texture_rect_region(_body_tex, dst_rect, src_rect, _body_color)
	for htex: Texture2D in _head_textures:
		if htex != null:
			draw_texture_rect_region(htex, dst_rect, src_rect, _body_color)

	# Small name label in amber
	if _font != null:
		draw_string(_font, Vector2(1.0, cs - 1.0), npc_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(1.0, 0.78, 0.25, 0.9))


func _facing_to_row() -> int:
	if facing.y > 0: return 0   # down
	if facing.x < 0: return 1   # left
	if facing.x > 0: return 2   # right
	return 3                     # up
