class_name Pathfinding
## 8-directional A* pathfinding helper using Chebyshev distance heuristic.

const DIRS_8: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)
]


static func find_path(gen: DungeonGenerator, start: Vector2i, goal: Vector2i) -> Array[Vector2i]:
	var result: Array[Vector2i] = []
	if gen == null:
		return result
	if start == goal:
		return result
	if not gen.is_walkable(goal):
		return result

	var open: Array = [start]
	var came_from: Dictionary = {}
	var g_score: Dictionary = {start: 0}
	var f_score: Dictionary = {start: _cheb(start, goal)}
	var closed: Dictionary = {}

	while not open.is_empty():
		# pick lowest f
		var best_i: int = 0
		var best_f: int = f_score.get(open[0], 0x3fffffff)
		for i in range(1, open.size()):
			var fv: int = f_score.get(open[i], 0x3fffffff)
			if fv < best_f:
				best_f = fv
				best_i = i
		var current: Vector2i = open[best_i]
		if current == goal:
			return _reconstruct(came_from, current)
		open.remove_at(best_i)
		closed[current] = true

		for d in DIRS_8:
			var nb: Vector2i = current + d
			if closed.has(nb):
				continue
			if nb != goal and not gen.is_walkable(nb):
				continue
			if nb == goal and not gen.is_walkable(nb):
				continue
			var tentative: int = g_score.get(current, 0x3fffffff) + 1
			if tentative < g_score.get(nb, 0x3fffffff):
				came_from[nb] = current
				g_score[nb] = tentative
				f_score[nb] = tentative + _cheb(nb, goal)
				if nb not in open:
					open.append(nb)
	return result


static func _cheb(a: Vector2i, b: Vector2i) -> int:
	return max(abs(a.x - b.x), abs(a.y - b.y))


static func _reconstruct(came_from: Dictionary, current: Vector2i) -> Array[Vector2i]:
	var path: Array[Vector2i] = []
	var cur: Vector2i = current
	while came_from.has(cur):
		path.append(cur)
		cur = came_from[cur]
	path.reverse()
	return path
