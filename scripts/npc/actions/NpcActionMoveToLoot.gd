class_name NpcActionMoveToLoot extends NPCAction

func _init() -> void:
	action_name = "move_to_loot"
	cost = 1.0
	preconditions = {has_loot_nearby = true, at_loot_pos = false}
	effects       = {at_loot_pos = true}

func execute(actor: NPCActor) -> bool:
	if actor._known_loot_tile == Vector2i(-1, -1):
		return false
	var step := _step_toward(actor, actor._known_loot_tile)
	if step == Vector2i.ZERO:
		return false
	var new_pos := actor.grid_pos + step
	actor.grid_pos = new_pos
	actor.position = actor._map.grid_to_world(new_pos)
	actor.facing = step
	actor.emit_signal("moved", new_pos)
	return true

func _step_toward(actor: NPCActor, target: Vector2i) -> Vector2i:
	var dx: int = sign(target.x - actor.grid_pos.x)
	var dy: int = sign(target.y - actor.grid_pos.y)
	var candidates := [Vector2i(dx, dy), Vector2i(dx, 0), Vector2i(0, dy)]
	for step: Vector2i in candidates:
		if step == Vector2i.ZERO:
			continue
		var pos := actor.grid_pos + step
		if actor._map.in_bounds(pos) and actor._map.is_walkable(pos):
			return step
	return Vector2i.ZERO
