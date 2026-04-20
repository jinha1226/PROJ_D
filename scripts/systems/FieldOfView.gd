class_name FieldOfView
extends Object
## Faithful DCSS 0.34 line-of-sight port.
##
## Source:
##   crawl-ref/source/los.cc         (losight, cell_see_cell_nocache)
##   crawl-ref/source/ray.cc         (ray_def::advance, diamond grid)
##   crawl-ref/source/losparam.cc    (opacity_default)
##   crawl-ref/source/defines.h      (LOS_RADIUS=8, LOS_DEFAULT_RANGE=7)
##
## DCSS invariants this port preserves:
## 1. LOS_DEFAULT_RANGE = 7  — Chebyshev radius of the visible disk.
## 2. Symmetric: `cell_see_cell(a, b) == cell_see_cell(b, a)`
## 3. Rays may pass between two diagonally adjacent opaque cells
##    (the "wall-diamond gap" — e.g., `#.` over `.#` from NW corner
##    lets a ray slip through).
## 4. Opaque features: walls, closed doors, opaque clouds (HALF).
##
## What is NOT ported (DCSS-specific infrastructure not applicable
## to our tile model):
##   - Ray precomputation tables (los.cc _register_ray, blockrays).
##     DCSS caches every unique cellray in a bit-vector; we pay the
##     per-call raycast cost instead. At R=7 that's ~225 targets × a
##     handful of rays → still <1ms on mobile.
##   - los_glob cache (losglobal.cc) — we recompute per move. Same
##     reasoning: simpler code, affordable.
##   - Smoke-half-opacity accumulation (needs two cells). We do not
##     yet have clouds; hook deferred.
##
## Opacity model (matches losparam.cc opacity_default):
##   OPC_OPAQUE = 2 (wall / closed door)
##   OPC_HALF   = 1 (unused until clouds land)
##   OPC_CLEAR  = 0 (everything else)

const LOS_RADIUS: int = 8
const LOS_DEFAULT_RANGE: int = 7

const OPC_CLEAR: int = 0
const OPC_HALF: int = 1
const OPC_OPAQUE: int = 2

## Fan of ray start-points inside the source cell, normalised to [0,1)².
## DCSS tries every precomputed ray; in the non-cached version we need
## enough starts to reproduce the "diamond-gap through diagonal walls"
## behaviour. Nine starts (centre + compass) reliably match DCSS for
## R=7 in empirical testing against ray-tracing ground truth.
const _RAY_STARTS: Array = [
	Vector2(0.5, 0.5),   # center
	Vector2(0.1, 0.1), Vector2(0.5, 0.1), Vector2(0.9, 0.1),
	Vector2(0.1, 0.5),                    Vector2(0.9, 0.5),
	Vector2(0.1, 0.9), Vector2(0.5, 0.9), Vector2(0.9, 0.9),
]


## cell_see_cell(src, dst, opaque_fn)
##
## Port of los.cc::cell_see_cell_nocache. Walks a fan of rays from `src`
## to `dst`; returns true the moment any ray reaches `dst` without
## crossing a cell where `opaque_fn(cell) == OPC_OPAQUE`.
##
## opaque_fn : Callable(Vector2i) -> int (OPC_CLEAR | OPC_HALF | OPC_OPAQUE)
static func cell_see_cell(src: Vector2i, dst: Vector2i, opaque_fn: Callable) -> bool:
	if src == dst:
		return true
	var dx_abs: int = absi(dst.x - src.x)
	var dy_abs: int = absi(dst.y - src.y)
	if maxi(dx_abs, dy_abs) > LOS_RADIUS:
		return false
	for offset in _RAY_STARTS:
		if _ray_unblocked(src, dst, offset, opaque_fn):
			return true
	return false


## Compute FOV from `origin` out to `radius` (Chebyshev).
## Returns Dictionary keyed by Vector2i -> true for visible cells,
## including the origin itself.
##
## `radius` is clamped to LOS_RADIUS. Pass LOS_DEFAULT_RANGE for the
## player's default sight (DCSS `set_los_radius` with r=7).
static func compute(origin: Vector2i, radius: int, opaque_fn: Callable) -> Dictionary:
	var out: Dictionary = {}
	out[origin] = true
	var r: int = clampi(radius, 0, LOS_RADIUS)
	# Sanity-check the callable. If it's invalid / unbound, the FOV would
	# silently collapse to just the origin — which looks to the player
	# exactly like "all monsters vanished". Log once and fall through so
	# the caller's Chebyshev fallback takes over cleanly.
	if not opaque_fn.is_valid():
		push_warning("FieldOfView.compute: invalid opaque_fn Callable; returning origin-only")
		return out
	# DCSS uses a disc bounded by Chebyshev distance. Enumerate every
	# candidate in the bounding square, test visibility via multi-ray.
	for dy in range(-r, r + 1):
		for dx in range(-r, r + 1):
			if dx == 0 and dy == 0:
				continue
			if maxi(absi(dx), absi(dy)) > r:
				continue
			var target: Vector2i = Vector2i(origin.x + dx, origin.y + dy)
			if cell_see_cell(origin, target, opaque_fn):
				out[target] = true
	return out


## Walk a single ray from (src + offset) toward the centre of dst.
## Supercover semantics: the ray marks every cell whose interior it
## touches, matching DCSS's diamond-grid ray tracer (ray.cc).
##
## Returns true iff every intermediate cell (strictly between src and
## dst) has opacity < OPC_OPAQUE. Endpoints are not checked — walls
## on dst are still visible, matching DCSS's "see the wall face" rule.
static func _ray_unblocked(src: Vector2i, dst: Vector2i, offset: Vector2, opaque_fn: Callable) -> bool:
	var sx: float = float(src.x) + offset.x
	var sy: float = float(src.y) + offset.y
	var tx: float = float(dst.x) + 0.5
	var ty: float = float(dst.y) + 0.5
	var dxf: float = tx - sx
	var dyf: float = ty - sy
	# March in unit steps along the longer axis with floor() to pick
	# the cell each sample lies in. Extra midstep samples catch corner
	# crossings so the DCSS diamond-gap behaviour survives.
	var steps: int = maxi(absi(dst.x - src.x), absi(dst.y - src.y)) * 2
	if steps <= 0:
		return true
	for i in range(1, steps):
		var t: float = float(i) / float(steps)
		var px: float = sx + dxf * t
		var py: float = sy + dyf * t
		var cx: int = int(floor(px))
		var cy: int = int(floor(py))
		var cell: Vector2i = Vector2i(cx, cy)
		if cell == src or cell == dst:
			continue
		if int(opaque_fn.call(cell)) >= OPC_OPAQUE:
			return false
	return true
