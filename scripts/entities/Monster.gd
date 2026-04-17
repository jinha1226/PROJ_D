class_name Monster extends Node2D

signal died(monster: Monster)

const TILE_SIZE: int = 32
const _CHAR_SPRITE_SCENE := preload("res://scenes/entities/CharacterSprite.tscn")

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var data: MonsterData
var hp: int = 0
var ac: int = 0
var dex: int = 0
var sight_range: int = 6
var is_alive: bool = true
var tile_size: int = 32
# Hex effect: remaining turns where this monster skips its action.
var slowed_turns: int = 0

var _sprite: CharacterSprite = null
var _has_preset: bool = false
var _walk_timer: SceneTreeTimer = null
var _move_tween: Tween = null
var boss_ai: BossAI = null
const _MOVE_TWEEN_DUR: float = 0.12
const _ATTACK_LUNGE_DUR: float = 0.08


func _ready() -> void:
	add_to_group("monsters")
	TurnManager.register_actor(self)
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST


func setup(gen: DungeonGenerator, pos: Vector2i, mdata: MonsterData) -> void:
	generator = gen
	data = mdata
	hp = mdata.hp
	ac = mdata.ac
	dex = mdata.dex
	sight_range = mdata.sight_range if mdata.sight_range > 0 else 6
	grid_pos = pos
	position = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	if mdata.is_boss and BossAI.PATTERNS.has(mdata.id):
		boss_ai = BossAI.new()
		boss_ai.setup(mdata.id)
	_load_sprite()
	if not _has_preset:
		queue_redraw()


func _load_sprite() -> void:
	if data == null:
		return
	# DCSS mode: skip LPC entirely and let _draw() render the DCSS tile.
	if TileRenderer.is_dcss():
		_has_preset = false
		queue_redraw()
		return
	var preset := LPCPresetLoader.load_preset(data.id)
	if preset.is_empty():
		# No preset yet for this monster — keep primitive _draw() fallback.
		_has_preset = false
		return
	_has_preset = true
	_sprite = _CHAR_SPRITE_SCENE.instantiate() as CharacterSprite
	add_child(_sprite)
	_sprite.load_character(preset)
	_sprite.set_direction("down")
	_sprite.play_anim("idle", true)


func take_damage(amount: int) -> void:
	if not is_alive:
		return
	hp -= amount
	if _sprite and hp > 0:
		_sprite.play_anim("hurt", false)
	if hp <= 0:
		die()


func die() -> void:
	if not is_alive:
		return
	is_alive = false
	died.emit(self)
	TurnManager.unregister_actor(self)
	if _sprite:
		_sprite.play_anim("hurt", false)
		var tw := create_tween()
		tw.tween_property(self, "modulate:a", 0.0, 0.4)
		tw.tween_callback(queue_free)
	else:
		queue_free()


func take_turn() -> void:
	if not is_alive:
		return
	var prev_pos: Vector2i = grid_pos
	if boss_ai != null:
		var p: Node = get_tree().get_first_node_in_group("player")
		boss_ai.act(self, p)
	else:
		MonsterAI.act(self)
	if _sprite and grid_pos != prev_pos:
		_sprite.face_toward(grid_pos - prev_pos)
		_sprite.play_anim("walk", true)
		# Reuse a single SceneTreeTimer reference per monster — each turn
		# overwrites the previous one. Connecting only when not already
		# connected avoids piling up lambdas (was a per-turn allocation that
		# kept _sprite captured and could fire after queue_free).
		_walk_timer = get_tree().create_timer(0.2)
		_walk_timer.timeout.connect(_return_to_idle, CONNECT_ONE_SHOT)


func _return_to_idle() -> void:
	if is_alive and _sprite:
		_sprite.play_anim("idle", true)


func get_player() -> Node:
	return get_tree().get_first_node_in_group("player")


func attack_animation_toward(target_grid: Vector2i) -> void:
	if _sprite != null:
		_sprite.face_toward(target_grid - grid_pos)
		_sprite.play_anim("slash", false)


## Used by MonsterAI._move_to — updates grid_pos AND tweens the visual.
## Tween starts after a small interval so the monster's slide doesn't visually
## overlap with the player's still-finishing move tween.
func move_to_grid(pos: Vector2i) -> void:
	grid_pos = pos
	var target_px: Vector2 = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_interval(0.08)  # let player tween finish first
	_move_tween.tween_property(self, "position", target_px, _MOVE_TWEEN_DUR)


func _draw() -> void:
	if _has_preset:
		return
	# DCSS mode: render the monster's tile texture centred on the entity.
	if TileRenderer.is_dcss() and data != null:
		var tex: Texture2D = TileRenderer.monster(String(data.id))
		if tex != null:
			var sz: Vector2 = tex.get_size()
			draw_texture(tex, -sz * 0.5)
			return
	# LPC fallback / generic colored disc.
	var color: Color
	var tier: int = data.tier if data != null else 1
	if tier <= 1:
		color = Color(0.7, 0.7, 0.7)
	elif tier == 2:
		color = Color(0.6, 0.4, 0.2)
	else:
		color = Color(0.85, 0.15, 0.15)
	draw_circle(Vector2.ZERO, 10.0, color)
	draw_arc(Vector2.ZERO, 10.0, 0.0, TAU, 16, Color.BLACK, 1.0)
