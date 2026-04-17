class_name Companion extends Node2D
## Friendly ally summoned via an essence ability. Mirrors Monster for stats,
## rendering, and turn registration, but uses CompanionAI which targets
## monsters (never player or other companions).
##
## Companions are registered with TurnManager the same way monsters are, so
## each round: player → monsters → companions (turn order defined by
## registration order).

signal died(c: Companion)

const TILE_SIZE: int = 32

@export var generator: DungeonGenerator

var grid_pos: Vector2i = Vector2i.ZERO
var data: MonsterData           # reuse MonsterData stat block
var hp: int = 0
var ac: int = 0
var dex: int = 0
var sight_range: int = 6
var is_alive: bool = true
var tile_size: int = 32
# Optional "expire in N turns" — 0 = permanent.
var lifetime: int = 0
var _move_tween: Tween = null
const _MOVE_TWEEN_DUR: float = 0.10


func _ready() -> void:
	add_to_group("companions")
	texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	z_index = 8
	TurnManager.register_actor(self)


func setup(gen: DungeonGenerator, pos: Vector2i, mdata: MonsterData) -> void:
	generator = gen
	data = mdata
	hp = mdata.hp
	ac = mdata.ac
	dex = mdata.dex
	sight_range = mdata.sight_range if mdata.sight_range > 0 else 6
	grid_pos = pos
	position = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	queue_redraw()


func take_damage(amount: int) -> void:
	if not is_alive:
		return
	hp -= amount
	if hp <= 0:
		_die()


func _die() -> void:
	is_alive = false
	died.emit(self)
	TurnManager.unregister_actor(self)
	var tw := create_tween()
	tw.tween_property(self, "modulate:a", 0.0, 0.4)
	tw.tween_callback(queue_free)


func take_turn() -> void:
	if not is_alive:
		return
	if lifetime > 0:
		lifetime -= 1
		if lifetime == 0:
			_die()
			return
	CompanionAI.act(self)


func move_to_grid(pos: Vector2i) -> void:
	grid_pos = pos
	var target_px: Vector2 = Vector2(pos.x * tile_size + tile_size / 2.0, pos.y * tile_size + tile_size / 2.0)
	if _move_tween != null and _move_tween.is_valid():
		_move_tween.kill()
	_move_tween = create_tween()
	_move_tween.tween_interval(0.04)
	_move_tween.tween_property(self, "position", target_px, _MOVE_TWEEN_DUR)


func _draw() -> void:
	if TileRenderer.is_dcss() and data != null:
		var tex: Texture2D = TileRenderer.monster(String(data.id))
		if tex != null:
			var sz: Vector2 = tex.get_size()
			draw_texture(tex, -sz * 0.5)
			# Small green dot to mark "ally" at a glance.
			draw_circle(Vector2(sz.x * 0.4, -sz.y * 0.4), 3.5, Color(0.3, 1.0, 0.3, 0.9))
			return
	# Fallback: a small green disc so we can still see it.
	draw_circle(Vector2.ZERO, 9.0, Color(0.25, 0.9, 0.35))
	draw_arc(Vector2.ZERO, 9.0, 0.0, TAU, 16, Color.BLACK, 1.0)
