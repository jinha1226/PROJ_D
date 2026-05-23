class_name Companion extends Actor

## In-dungeon companion entity. Extends Actor for full stat parity with Player.
## Visuals use DCSS player/base tiles keyed by race_id.
## AI handled by CompanionAI; death is permanent (reported to PartyManager).

const _RACE_TILE_MAP: Dictionary = {
	"human":    "res://assets/tiles/individual/player/base/human_m.png",
	"elf":      "res://assets/tiles/individual/player/base/elf_m.png",
	"dwarf":    "res://assets/tiles/individual/player/base/dwarf_m.png",
	"hill_orc": "res://assets/tiles/individual/player/base/orc_m.png",
	"troll":    "res://assets/tiles/individual/player/base/troll_m.png",
	"vampire":  "res://assets/tiles/individual/player/base/vampire_m.png",
	"minotaur": "res://assets/tiles/individual/player/base/minotaur_m.png",
	"kobold":   "res://assets/tiles/individual/player/base/kobold_m.png",
	"spriggan": "res://assets/tiles/individual/player/base/spriggan_m.png",
	"gargoyle": "res://assets/tiles/individual/player/base/gargoyle_m.png",
}

var data: CompanionData
var pending_energy: float = 0.0  # TurnManager energy accumulator

var _tile: Texture2D = null
var _font: Font


func _ready() -> void:
	CombatLog = get_node_or_null("/root/CombatLog")
	GameManager = get_node_or_null("/root/GameManager")
	ItemRegistry = get_node_or_null("/root/ItemRegistry")
	_font = ThemeDB.fallback_font
	add_to_group("companions")
	add_to_group("actors")
	died.connect(_on_died)


func setup(cdata: CompanionData, map: DungeonMap, pos: Vector2i) -> void:
	data = cdata
	_map = map
	grid_pos = pos
	position = map.grid_to_world(pos)
	# Mirror stats from persistent data onto Actor vars
	hp_max = cdata.hp_max
	hp = hp_max
	mp_max = cdata.mp_max
	mp = mp_max
	strength = cdata.strength
	dexterity = cdata.dexterity
	intelligence = cdata.intelligence
	xl = cdata.xl
	xp = cdata.xp
	ac = cdata.ac
	ev = cdata.ev
	equipped_weapon_id = cdata.equipped_weapon_id
	equipped_armor_id = cdata.equipped_armor_id
	equipped_shield_id = cdata.equipped_shield_id
	equipped_helmet_id = cdata.equipped_helmet_id
	equipped_gloves_id = cdata.equipped_gloves_id
	equipped_boots_id = cdata.equipped_boots_id
	equipped_ring_id = cdata.equipped_ring_id
	equipped_amulet_id = cdata.equipped_amulet_id
	_load_dcss_tile()
	queue_redraw()


func _process(_delta: float) -> void:
	pass  # No animation in DCSS tile mode.


# ── Actor virtual overrides ────────────────────────────────────────────────────

func _on_take_damage_visual() -> void:
	modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _on_equipment_changed() -> void:
	queue_redraw()


# ── Turn ───────────────────────────────────────────────────────────────────────

func take_turn() -> void:
	if hp <= 0 or data == null or _map == null:
		return
	tick_statuses()
	if hp <= 0:
		return
	CompanionAI.take_turn(self, _map)


# ── Death ──────────────────────────────────────────────────────────────────────

func _on_died() -> void:
	var pm = get_node_or_null("/root/PartyManager")
	if pm != null:
		pm.on_companion_killed(data.id)
	var game = get_tree().current_scene
	if game != null and game.has_method("_on_companion_died"):
		game._on_companion_died(self)
	queue_free()


# ── Data sync ──────────────────────────────────────────────────────────────────

## Write runtime Actor state back to the persistent CompanionData.
## Call before saving and when changing floors.
func sync_to_data() -> void:
	if data == null:
		return
	data.hp_max = hp_max
	data.mp_max = mp_max
	data.strength = strength
	data.dexterity = dexterity
	data.intelligence = intelligence
	data.xl = xl
	data.xp = xp
	data.ac = ac
	data.ev = ev
	data.equipped_weapon_id = equipped_weapon_id
	data.equipped_armor_id = equipped_armor_id
	data.equipped_shield_id = equipped_shield_id
	data.equipped_helmet_id = equipped_helmet_id
	data.equipped_gloves_id = equipped_gloves_id
	data.equipped_boots_id = equipped_boots_id
	data.equipped_ring_id = equipped_ring_id
	data.equipped_amulet_id = equipped_amulet_id


# ── Drawing ────────────────────────────────────────────────────────────────────

func _draw() -> void:
	var cs := float(DungeonMap.CELL_SIZE)
	var dst_rect := Rect2(0.0, 0.0, cs, cs)
	if _tile != null:
		draw_texture_rect(_tile, dst_rect, false)
	# Subtle green name label below the sprite
	if data != null and _font != null:
		draw_string(_font, Vector2(1.0, cs - 1.0), data.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1.0, 0.5, 0.9))
	# HP bar across the bottom
	var bar_w: float = cs - 4.0
	var hp_frac: float = float(hp) / float(max(1, hp_max))
	draw_rect(Rect2(2.0, cs - 4.0, bar_w, 3.0), Color(0.15, 0.15, 0.15, 0.7))
	draw_rect(Rect2(2.0, cs - 4.0, bar_w * hp_frac, 3.0), Color(0.25, 0.85, 0.3, 0.85))


func _load_dcss_tile() -> void:
	if data == null:
		return
	var path: String = String(_RACE_TILE_MAP.get(data.race_id, _RACE_TILE_MAP["human"]))
	if ResourceLoader.exists(path):
		_tile = load(path) as Texture2D
