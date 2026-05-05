# scripts/main — Game orchestration

## What
Top-level scene-loop orchestration. Currently a single 3112-line `Game.gd` god-object: input handling, auto-travel, class/race apply, save migration, floor cache + restore, branch lifecycle, monster spawning, HUD/UI calls, spell visual effects, debug panel. **Highest-risk file in the repo**.

## Critical state
- Corpses are composed at runtime via a GDScript port of DCSS's `tile::corpsify` (`crawl/.../rltiles/tool/tile.cc:160-273`): vertical 2x squash + curved horizontal cut + top/bottom halves offset apart by `cut_separate` → "torn in half" look, then dark red wound along the cut edge. The corpsified body is blitted onto `assets/tiles/corpses/blood_puddle_red.png` (or `blood_green.png` for green-blood ids per `_CORPSE_GREEN_BLOOD`). `_corpse_tile_for_monster` caches the result per monster id in `_corpse_tex_cache` and stores the `Texture2D` on the corpse dict (`tile`). No per-frame `load()`.
- `_apply_loaded_player_state` (lines 522-661) holds 6 inline skill migrations — needs extraction to `SaveMigration.gd`.
- `_on_branch_stairs_up` (1741-1761) missing `_clear_monsters()` on branch 1F-up — Critical C4.

## Decomposition targets (Phase 4)
- `FloorLifecycle.gd` — `_generate_floor` / `_cache_current_floor` / `_restore_floor_from_cache`
- `BranchManager.gd` — branch entry/exit, boss detection, `_handle_first_shrine_boss_clear`
- `SaveMigration.gd` — replace inline if-chains with a versioned migration table
- `EffectsLayer.gd` — damage_number / spell_bolt / hit_effect spawns
- `MonsterFactory.gd` — spawn helpers + signal wiring
- `CorpseService.gd` — composer + cache (move `_build_corpse_texture` and `_corpse_tex_cache`)

## Modification rules
1. Do not extend `Game.gd` with new logic branches — extract first.
2. New systems do not get a Game.gd entry point; they get their own module.
3. UI calls into Game.gd are tolerated; the reverse (Game.gd reaching into UI) requires explicit reason.
4. When touching cache restore (`_restore_floor_from_cache`, branch variants), verify both `_clear_monsters()` and `_clear_floor_items()` are called consistently across all paths.

## If you change X, also check Y
- Floor cache schema → `SaveManager.save_run` (currently incomplete — Critical C1).
- Monster spawn → `MonsterFactory` plan + `Monster.gd` signal connections.
- Branch lifecycle → C4 fix scope; verify all 4 branch up/down paths.

## Known issues from 2026-05-05 audit
Critical C1, C4 root here. Medium M1 (god-object), M2 (save migration), M3 (class starters duplicated), M4 (shrine boss detection), M11 (UI/turn coupling) all touch this file. See `docs/audits/2026-05-05-codebase-audit.md`.
