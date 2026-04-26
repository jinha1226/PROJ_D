class_name FieldOfView extends RefCounted

## Recursive shadowcasting FOV. Algorithm from
## https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting
##
## compute(origin, radius, is_opaque) -> Dictionary[Vector2i, bool]
## is_opaque: Callable(Vector2i) -> bool — returns true if the tile blocks sight.

const _OCTANTS: Array = [
	[1, 0, 0, 1],
	[0, 1, 1, 0],
	[0, -1, 1, 0],
	[-1, 0, 0, 1],
	[-1, 0, 0, -1],
	[0, -1, -1, 0],
	[0, 1, -1, 0],
	[1, 0, 0, -1],
]

static func compute(origin: Vector2i, radius: int, is_opaque: Callable) -> Dictionary:
	var visible: Dictionary = {}
	visible[origin] = true
	for dy in range(-1, 2):
		for dx in range(-1, 2):
			if dx != 0 or dy != 0:
				visible[origin + Vector2i(dx, dy)] = true
	for oct in _OCTANTS:
		_cast(origin, 1, 1.0, 0.0, radius, oct, is_opaque, visible)
	return visible

static func _cast(origin: Vector2i, row: int, start_slope: float, end_slope: float,
		radius: int, oct: Array, is_opaque: Callable, visible: Dictionary) -> void:
	if start_slope < end_slope:
		return
	var next_start: float = start_slope
	var r2: int = radius * radius
	for i in range(row, radius + 1):
		var blocked: bool = false
		var dy: int = -i
		var dx: int = -i
		while dx <= 0:
			var l_slope: float = (float(dx) - 0.5) / (float(dy) + 0.5)
			var r_slope: float = (float(dx) + 0.5) / (float(dy) - 0.5)
			if start_slope < r_slope:
				dx += 1
				continue
			if end_slope > l_slope:
				break
			var sax: int = dx * oct[0] + dy * oct[1]
			var say: int = dx * oct[2] + dy * oct[3]
			var pos: Vector2i = Vector2i(origin.x + sax, origin.y + say)
			if dx * dx + dy * dy <= r2:
				visible[pos] = true
			if blocked:
				if is_opaque.call(pos):
					next_start = r_slope
					dx += 1
					continue
				else:
					blocked = false
					start_slope = next_start
			else:
				if is_opaque.call(pos) and i < radius:
					blocked = true
					_cast(origin, i + 1, start_slope, l_slope, radius, oct,
						is_opaque, visible)
					next_start = r_slope
			dx += 1
		if blocked:
			break
