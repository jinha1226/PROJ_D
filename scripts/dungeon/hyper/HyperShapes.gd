class_name HyperShapes
extends RefCounted
## Size distribution callbacks + misc shape helpers.
## 1:1 port of DCSS hyper_shapes.lua (size functions) plus the bits of
## rooms_primitive.lua relevant to code-room paint callbacks.
##
## Each size callback returns a Vector2i (DCSS uses {x,y} tables). They
## vary by distribution:
##   size_default       — lower-biased (double-random²)
##   size_square        — uniform N×N
##   size_square_lower  — lower-biased N×N
##   size_narrow        — one axis much smaller than the other
##   size_large         — biased toward the max end

static var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


## Lower-biased size, separately rolled for X and Y. Mirrors DCSS default.
static func size_default(generator: Dictionary, options: Dictionary) -> Vector2i:
	var min_sx: int = int(options.get("min_room_size", 3))
	var max_sx: int = int(options.get("max_room_size", 8))
	var min_sy: int = min_sx
	var max_sy: int = max_sx
	if generator.has("min_size"):
		min_sx = int(generator["min_size"])
		min_sy = int(generator["min_size"])
	if generator.has("max_size"):
		max_sx = int(generator["max_size"])
		max_sy = int(generator["max_size"])
	if generator.has("min_size_x"): min_sx = int(generator["min_size_x"])
	if generator.has("max_size_x"): max_sx = int(generator["max_size_x"])
	if generator.has("min_size_y"): min_sy = int(generator["min_size_y"])
	if generator.has("max_size_y"): max_sy = int(generator["max_size_y"])
	var dx: int = max(1, max_sx - min_sx + 1)
	var dy: int = max(1, max_sy - min_sy + 1)
	return Vector2i(
		min_sx + _random2(_random2(dx)),
		min_sy + _random2(_random2(dy)))


static func size_square(chosen: Dictionary, options: Dictionary) -> Vector2i:
	var min_size: int = int(options.get("min_room_size", 3))
	var max_size: int = int(options.get("max_room_size", 8))
	if chosen.has("min_size"): min_size = int(chosen["min_size"])
	if chosen.has("max_size"): max_size = int(chosen["max_size"])
	var s: int = _rng.randi_range(min_size, max_size)
	return Vector2i(s, s)


static func size_square_lower(chosen: Dictionary, options: Dictionary) -> Vector2i:
	var v: Vector2i = size_default(chosen, options)
	return Vector2i(v.x, v.x)


static func size_narrow(chosen: Dictionary, options: Dictionary) -> Vector2i:
	var v: Vector2i = size_default(chosen, options)
	# Flip to landscape half the time, otherwise portrait. Narrow axis is
	# at most half the wide axis.
	if _rng.randf() < 0.5:
		return Vector2i(v.x, max(2, v.y / 2))
	return Vector2i(max(2, v.x / 2), v.y)


static func size_large(chosen: Dictionary, options: Dictionary) -> Vector2i:
	var min_size: int = int(chosen.get("min_size", options.get("min_room_size", 6)))
	var max_size: int = int(chosen.get("max_size", options.get("max_room_size", 12)))
	var diff: int = max(1, max_size - min_size + 1)
	# Upper-biased: max - random² instead of min + random².
	return Vector2i(max_size - _random2(diff), max_size - _random2(diff))


static func set_seed(seed: int) -> void:
	_rng.seed = seed


static func _random2(n: int) -> int:
	# DCSS's crawl.random2(n) = uniform [0, n-1]; for n<=0 → 0.
	if n <= 0:
		return 0
	return _rng.randi_range(0, n - 1)
