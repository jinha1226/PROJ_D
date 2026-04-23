class_name SpellTargetOverlay extends Node2D

var _spell: SpellData
var _valid_tiles: Array  # Array[Vector2i]
var _hit_tiles: Array    # Array[Vector2i] — tiles that will be visibly affected

func init(spell: SpellData, player: Player, valid_tiles: Array) -> void:
	_spell = spell
	_valid_tiles = valid_tiles
	_hit_tiles = _compute_hit_tiles(spell, player, valid_tiles)
	queue_redraw()

func _compute_hit_tiles(spell: SpellData, player: Player, valid: Array) -> Array:
	match spell.effect:
		"aoe_damage":
			var result := []
			for n in get_tree().get_nodes_in_group("monsters"):
				if not (n is Monster):
					continue
				if valid.has(n.grid_pos):
					result.append(n.grid_pos)
			return result
		"damage", "multi_damage":
			var nearest: Monster = null
			var best: int = 9999
			for n in get_tree().get_nodes_in_group("monsters"):
				if not (n is Monster):
					continue
				if not valid.has(n.grid_pos):
					continue
				var d: int = max(abs(n.grid_pos.x - player.grid_pos.x),
						abs(n.grid_pos.y - player.grid_pos.y))
				if d < best:
					best = d
					nearest = n
			return [nearest.grid_pos] if nearest != null else []
	return []

func _draw() -> void:
	var cs := float(DungeonMap.CELL_SIZE)
	var col := _effect_color()
	var range_fill := Color(col.r, col.g, col.b, 0.12)
	var hit_fill   := Color(col.r, col.g, col.b, 0.45)
	var hit_border := Color(col.r, col.g, col.b, 0.9)

	for tile: Vector2i in _valid_tiles:
		draw_rect(Rect2(Vector2(tile.x * cs, tile.y * cs), Vector2(cs, cs)), range_fill)

	for tile: Vector2i in _hit_tiles:
		draw_rect(Rect2(Vector2(tile.x * cs + 1, tile.y * cs + 1),
				Vector2(cs - 2, cs - 2)), hit_fill)
		draw_rect(Rect2(Vector2(tile.x * cs + 2, tile.y * cs + 2),
				Vector2(cs - 4, cs - 4)), hit_border, false, 2.0)

func _effect_color() -> Color:
	match _spell.effect:
		"damage":       return Color(0.5, 0.7, 1.0)
		"multi_damage": return Color(0.75, 0.55, 1.0)
		"aoe_damage":   return Color(1.0, 0.55, 0.25)
	return Color(0.85, 0.85, 0.85)
