class_name NpcActionFlee extends NPCAction

func _init() -> void:
	action_name = "flee"
	cost = 1.5   # slightly costlier than attacking so NPC prefers combat unless truly desperate
	preconditions = {hp_critical = true}
	effects       = {hp_critical = false}

func execute(actor: NPCActor) -> bool:
	if actor._known_enemy == null or actor._map == null:
		return false
	# Move away from the known enemy: invert the step-toward direction
	var away: Vector2i = (actor.grid_pos - actor._known_enemy.grid_pos).sign()
	var candidates := _flee_candidates(away)
	for step: Vector2i in candidates:
		var pos := actor.grid_pos + step
		if actor._map.in_bounds(pos) and actor._map.is_walkable(pos):
			actor.grid_pos = pos
			actor.position = actor._map.grid_to_world(pos)
			actor.facing = step
			actor.emit_signal("moved", pos)
			return true
	return false

func _flee_candidates(away: Vector2i) -> Array:
	# Primary direction away, then perpendicular options
	var perp1 := Vector2i(-away.y, away.x)
	var perp2 := Vector2i(away.y, -away.x)
	return [away, away + perp1, away + perp2, perp1, perp2]
