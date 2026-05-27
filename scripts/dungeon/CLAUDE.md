# scripts/dungeon — Map gen and rendering

## What
Map size, BSP+L-corridor generation, FOV shadowcasting, depth-banded terrain art, tile rendering. Two files: `MapGen.gd` (generation), `DungeonMap.gd` (runtime + draw).

## Map identity
- Size 56×62 — enlarged 2026-05-27 (was 46×50; docs had stale 32×36 reference). Constants in `DungeonMap.DEFAULT_GRID_W/H`.
- BSP rooms + L-corridor connect + farthest-BFS stairs.
- Depth-banded floor art: dirt → limestone → bloody cobble → crystal.
- Branch-specific palettes via ZoneManager.

## Rendering perf (audit M7)
`_draw()` runs full-grid loops every redraw — at 56×62 = 3472 cells × 7 broad layers (warning, hazard, cloud, corpse, altar, fog, broken_altar). Per-corpse `load()` was removed in Phase 0 (texture is now resolved at spawn and cached on the corpse dict). Cell count ~3× legacy 32×36 — monitor mobile perf.

Mitigations to consider when revisiting:
- Layers with empty dictionaries already short-circuit; keep that pattern.
- Consider migrating tile main loop to TileMap or MultiMeshInstance2D for mobile 60fps targets.

## Corpse rendering (Phase 0 done 2026-05-05)
Corpse textures are **runtime-composed** via a port of DCSS `tile::corpsify`: monster body squashed 2x vertically, cut along a curved horizontal line, halves offset apart → torn-in-half look with a dark-red wound. Composited onto `assets/tiles/corpses/blood_puddle_red.png` (or `blood_green.png` for green-blood monsters per `_CORPSE_GREEN_BLOOD`). Cached per monster id in `Game.gd._corpse_tex_cache`; resolved `Texture2D` is stored on the corpse dict at spawn; `DungeonMap._draw` reads it directly. If the monster has no body tile, result is null and `_draw` falls back to the `%` glyph. Schema: `{pos:Vector2i, tile:Texture2D, turns_left:int}`.

## FOV / explored
- `visible_tiles`, `explored`, `reveal_all` — three modes that all rendering layers must consider.
- `_restore_floor_from_cache` does NOT call `_clear_monsters()` itself — caller must (see audit C4 for the missed branch path).

## Modification rules
1. New rendering layer → respect visible/explored/reveal_all combo and short-circuit on empty.
2. No `load()` inside `_draw()` — resolve resources at data creation time.
3. Map size constants live in DungeonMap; do not hardcode 56 / 62 elsewhere.

## If you change X, also check Y
- New tile category → AtlasTexture / asset import + render layer order + reveal logic.
- Floor cache shape → match SaveManager schema (audit C1).
