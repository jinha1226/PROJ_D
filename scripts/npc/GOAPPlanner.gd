class_name GOAPPlanner extends RefCounted

## A* GOAP planner. Given a world state, a goal (desired state keys), and a
## list of NPCActions, returns the lowest-cost ordered action sequence that
## satisfies the goal. Returns [] if no plan is found within MAX_ITERATIONS.

const MAX_ITERATIONS: int = 128

static func plan(world_state: Dictionary, goal: Dictionary, actions: Array) -> Array:
	if goal.is_empty() or _goal_satisfied(world_state, goal):
		return []

	# open list: Array of {state, plan, g}
	# sorted ascending by f = g + h each pop
	var open: Array = []
	var closed: Array = []  # Array of state hashes (int)

	open.append({state = world_state.duplicate(), plan = [], g = 0.0})

	var iters: int = 0
	while not open.is_empty() and iters < MAX_ITERATIONS:
		iters += 1
		open.sort_custom(func(a, b):
			return (a.g + _heuristic(a.state, goal)) < (b.g + _heuristic(b.state, goal))
		)
		var current: Dictionary = open.pop_front()

		if _goal_satisfied(current.state, goal):
			return current.plan

		var h: int = _hash_state(current.state)
		if closed.has(h):
			continue
		closed.append(h)

		for action: NPCAction in actions:
			if not action.is_applicable(current.state):
				continue
			var new_state: Dictionary = current.state.duplicate()
			new_state.merge(action.effects, true)
			var new_h: int = _hash_state(new_state)
			if closed.has(new_h):
				continue
			open.append({
				state = new_state,
				plan = current.plan + [action],
				g = current.g + action.cost,
			})

	return []

static func _goal_satisfied(state: Dictionary, goal: Dictionary) -> bool:
	for key in goal:
		if state.get(key) != goal[key]:
			return false
	return true

static func _heuristic(state: Dictionary, goal: Dictionary) -> int:
	var n: int = 0
	for key in goal:
		if state.get(key) != goal[key]:
			n += 1
	return n

static func _hash_state(state: Dictionary) -> int:
	var keys: Array = state.keys()
	keys.sort()
	var parts: Array = []
	for k in keys:
		parts.append("%s=%s" % [k, str(state[k])])
	return ",".join(parts).hash()
