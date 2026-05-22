class_name Companion extends Actor

## In-dungeon companion entity. Extends Actor for full stat parity with Player.
## Visuals use the same ULPC spritesheet system as Player (_race_body_path etc.).
## AI handled by CompanionAI; death is permanent (reported to PartyManager).

var data: CompanionData
var pending_energy: float = 0.0  # TurnManager energy accumulator

var _body_tex: Texture2D = null
var _head_textures: Array = []  # Array[Texture2D]
var _anim_frame: int = 0
var _anim_timer: float = 0.0
var _font: Font

const WALK_FRAME_COUNT: int = 9
const WALK_FRAME_TIME: float = 0.14
const SPRITE_W: int = 64
const SPRITE_H: int = 64


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
	_load_ulpc_textures()
	queue_redraw()


func _process(delta: float) -> void:
	_anim_timer += delta
	if _anim_timer >= WALK_FRAME_TIME:
		_anim_timer -= WALK_FRAME_TIME
		_anim_frame = (_anim_frame + 1) % WALK_FRAME_COUNT
		queue_redraw()


# ── Actor virtual overrides ────────────────────────────────────────────────────

func _on_take_damage_visual() -> void:
	modulate = Color(1.0, 0.3, 0.3)
	var tween := create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.25)


func _on_equipment_changed() -> void:
	_load_ulpc_textures()
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
	var dir_row: int = _facing_to_row(facing)
	var src_x: int = _anim_frame * SPRITE_W
	var src_y: int = dir_row * SPRITE_H
	var src_rect := Rect2(src_x, src_y, SPRITE_W, SPRITE_H)
	var dst_rect := Rect2(0.0, 0.0, cs, cs)

	if _body_tex != null:
		draw_texture_rect_region(_body_tex, dst_rect, src_rect)
	for htex: Texture2D in _head_textures:
		if htex != null:
			draw_texture_rect_region(htex, dst_rect, src_rect)

	# Subtle green name label below the sprite
	if data != null and _font != null:
		draw_string(_font, Vector2(1.0, cs - 1.0), data.display_name,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 8, Color(0.5, 1.0, 0.5, 0.9))

	# HP bar across the bottom
	var bar_w: float = cs - 4.0
	var hp_frac: float = float(hp) / float(max(1, hp_max))
	draw_rect(Rect2(2.0, cs - 4.0, bar_w, 3.0), Color(0.15, 0.15, 0.15, 0.7))
	draw_rect(Rect2(2.0, cs - 4.0, bar_w * hp_frac, 3.0), Color(0.25, 0.85, 0.3, 0.85))


func _facing_to_row(f: Vector2i) -> int:
	if f.y > 0: return 0   # down
	if f.x < 0: return 1   # left
	if f.x > 0: return 2   # right
	return 3               # up (default)


func _load_ulpc_textures() -> void:
	if data == null:
		return
	var body_path: String = PlayerRenderer.race_body_path(data.race_id)
	_body_tex = PlayerRenderer.load_ulpc_tex(body_path)
	var head_overlays: Array = PlayerRenderer.race_head_overlays(data.race_id)
	_head_textures.clear()
	for hp_path in head_overlays:
		_head_textures.append(PlayerRenderer.load_ulpc_tex(hp_path))
