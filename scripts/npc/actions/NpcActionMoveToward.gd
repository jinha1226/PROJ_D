class_name NpcActionMoveToward extends NPCAction

func _init() -> void:
	action_name = "move_toward_enemy"
	cost = 1.0
	preconditions = {has_enemy_in_sight = true, adjacent_to_enemy = false}
	effects       = {adjacent_to_enemy = true}

func execute(actor: NPCActor) -> bool:
	if actor._known_enemy == null:
		return false
	var step := _step_toward(actor, actor._known_enemy.grid_pos)
	if step == Vector2i.ZERO:
		return false
	var new_pos := actor.grid_pos + step
	actor.grid_pos = new_pos
	actor.position = actor._map.grid_to_world(new_pos)
	actor.facing = step
	actor.emit_signal("moved", new_pos)
	return true

func _step_toward(actor: NPCActor, target: Vector2i) -> Vector2i:
	var dx := sign(target.x - actor.grid_pos.x)
	var dy := sign(target.y - actor.grid_pos.y)
	# Try diagonal first, then cardinal axes
	var candidates := [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]
	for step: Vector2i in candidates:
		if step == Vector2i.ZERO:
			continue
		var pos := actor.grid_pos + step
		if actor._map.in_bounds(pos) and actor._map.is_walkable(pos):
			return step
	return Vector2i.ZERO
