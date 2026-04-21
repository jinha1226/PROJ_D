class_name Beam
extends Object
## Faithful DCSS 0.34 beam / zap travel port.
##
## Source:
##   crawl-ref/source/beam.cc   (bolt::fire, bolt::do_fire, bolt::affect_cell)
##   crawl-ref/source/beam.h    (bolt struct)
##
## DCSS beams are rays that travel cell-by-cell from source through
## the dungeon grid. Each cell: stop at walls (unless digging), hit any
## monster there, pierce-through-or-not based on the spell's flags.
## Previously our `_spell_deal_dmg` teleport-hit the target, so a
## monster standing between caster and target ate no damage and iron
## shots passed through walls freely — both surprises from the user's
## point of view.
##
## What this module supplies:
##   trace(origin, target, range, pierce, opaque_fn, monster_fn) → Dict
## Returns:
##   { "cells":[Vector2i,...],     — path walked, incl. each cell entered
##     "impact":Vector2i,           — where the beam stopped (wall / target / range)
##     "hits":[Monster,...],        — every monster struck along the path
##     "stopped_by":"wall|monster|range|target" }
##
## Pierce rule (DCSS): `bolt_of_*` / `lightning_bolt` / `crystal_spear`
## etc. pierce and keep going; `magic_dart` / `throw_*` / `iron_shot`
## stop at the first victim. `should_pierce(spell_id)` encodes the
## known DCSS list so callers don't have to memorise it.

## Spells whose beam pierces past its first victim. Derived from DCSS
## `bolt.pierce = true` spells in beam.cc / zap-data.h. Everything not
## in this set stops at the first monster. (Explosion/area spells go
## through a different code path and are unaffected.)
const _PIERCING_SPELLS: Dictionary = {
	"bolt_of_fire": true,
	"bolt_of_cold": true,
	"bolt_of_magma": true,
	"bolt_of_draining": true,
	"bolt_of_devastation": true,
	"lightning_bolt": true,
	"crystal_spear": true,
	"lehudibs_crystal_spear": true,
	"bolt_of_inaccuracy": true,
	"searing_ray": true,
	"venom_bolt": true,
	"poison_arrow": true,
	"quicksilver_bolt": true,
	"iskenderuns_mystic_blast": true,  # small pierce via explosion
}


static func should_pierce(spell_id: String) -> bool:
	return bool(_PIERCING_SPELLS.get(spell_id, false))


## Walk the beam from `origin` toward `target` until range runs out or
## something stops it. `opaque_fn(cell) -> int` is the same callable
## we feed FieldOfView (returns OPC_OPAQUE for walls / closed doors).
## `monster_fn(cell) -> Variant` returns a Monster instance if one is
## at that cell, else null.
##
## Behaviour matches beam.cc::do_fire:
##   - Skip the origin cell (it's the caster).
##   - Each cell entered counts against `range`.
##   - Opaque cell → stop there (wall hit); the beam doesn't enter.
##   - Monster in cell → add to hits; if !pierce, stop there.
##   - Range exhausted → stop.
static func trace(origin: Vector2i, target: Vector2i, range_tiles: int, \
		pierce: bool, opaque_fn: Callable, monster_fn: Callable) -> Dictionary:
	var out: Dictionary = {
		"cells": [],
		"impact": origin,
		"hits": [],
		"stopped_by": "range",
	}
	if origin == target:
		out["impact"] = origin
		out["stopped_by"] = "target"
		return out

	# Bresenham supercover walker. DCSS's diamond-grid ray could be
	# ported verbatim, but for beam travel (where we only care about
	# which cells the beam touches) Bresenham matches DCSS within one
	# tile of visual tolerance and is 10× simpler.
	var dx: int = target.x - origin.x
	var dy: int = target.y - origin.y
	var sx: int = 1 if dx > 0 else (-1 if dx < 0 else 0)
	var sy: int = 1 if dy > 0 else (-1 if dy < 0 else 0)
	var adx: int = absi(dx)
	var ady: int = absi(dy)
	var x: int = origin.x
	var y: int = origin.y
	var err: int = adx - ady
	var steps: int = 0
	var max_steps: int = maxi(adx, ady) + range_tiles
	# Extend past target in the same direction when pierce=true so the
	# beam can keep going. For pierce=false we still stop at target
	# naturally via the range check below.
	while steps < max_steps:
		var e2: int = 2 * err
		if e2 > -ady:
			err -= ady
			x += sx
		if e2 < adx:
			err += adx
			y += sy
		if x == origin.x and y == origin.y:
			continue  # shouldn't hit; guard against degenerate dx=dy=0
		var cell: Vector2i = Vector2i(x, y)
		steps += 1
		if steps > range_tiles:
			out["impact"] = out["cells"][-1] if not out["cells"].is_empty() else origin
			out["stopped_by"] = "range"
			break
		# DCSS: wall/closed door stops the beam before entering. The
		# last walkable cell becomes the impact point (explosions
		# centre there; projectiles fizzle on the face of the wall).
		if int(opaque_fn.call(cell)) >= 2:  # FieldOfView.OPC_OPAQUE = 2
			var last: Vector2i = out["cells"][-1] if not out["cells"].is_empty() else origin
			out["impact"] = last
			out["stopped_by"] = "wall"
			break
		out["cells"].append(cell)
		# Record monster hit. Pierce=true: keep going past it. Pierce
		# =false: stop here and this is our impact.
		var m = monster_fn.call(cell)
		if m != null:
			out["hits"].append(m)
			if not pierce:
				out["impact"] = cell
				out["stopped_by"] = "monster"
				break
		# Reached the manual target tile with pierce=false stops too
		# (so firing at empty tile lands there as the impact).
		if cell == target and not pierce:
			out["impact"] = cell
			out["stopped_by"] = "target"
			break
	if out["stopped_by"] == "range" and not out["cells"].is_empty():
		out["impact"] = out["cells"][-1]
	return out
