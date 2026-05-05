# scripts/core — Core runtime infrastructure

## What
Lifecycle / persistence / turn order. These four files are foundational — bugs here propagate everywhere.

```
GameManager.gd     — autoload, run state, branch_zone, floor_cache, titles
TurnManager.gd     — turn order, reentrancy guard, end_player_turn
SaveManager.gd     — save/load, delete, JSON schema
CombatLog.gd       — message log surface
```

## Critical issue (audit C1)
**`SaveManager.save_run` only serializes Player fields.** Missing from disk:
- `GameManager.branch_zone`, `branch_floor`, `branch_entry_depth`, `branch_floor_cache`, `branches_cleared`
- `GameManager.floor_cache` (all prior-floor snapshots)
- Current map's `altar_active`, `altar_map`, `corpses`, `cloud_tiles`, `hazard_tiles`, `fog_tiles`, `explored`, `visible_tiles`, alive monsters, floor items
- Monster awareness state (`is_aware`, `is_alerted`, `last_known_player_pos`, `pending_energy`, `_ability_charge`) — audit H9

Result on mobile: app background → save → resume = progress corrupted. **Phase 1 first task.**

## Save schema rules (going forward)
1. Schema must match `Game._cache_current_floor()` dict shape — share serialization code.
2. Add `save_version` key. Inline migration if-chains (`Game.gd:522-661`) move to `SaveMigration.gd`.
3. Loading reuses `Game._restore_floor_from_cache` path — do not duplicate restore logic.
4. Any new player-facing state field requires (a) migration plan, (b) test load of pre-change save.

## TurnManager rules
- `end_player_turn(immediate)` is the public API — UI must NOT call this directly. Owning system (Player.equip etc.) decides turn cost.
- Player death must abort the actor turn loop (audit H8): set abort flag from `Game._on_player_died`.
- Reentrancy guard exists; do not bypass.

## SaveManager rules
- `delete_save` runs on death (`GameManager.end_run("death")`) — irrecoverable. Mobile background-as-death scenarios need a backup file path before this becomes acceptable.
- Use `FileAccess` rather than `DirAccess.remove_absolute(globalize_path(...))` — the latter has Android permission edge cases (audit M10).

## If you change X, also check Y
- Add player field → SaveManager schema + migration version bump.
- Change floor cache shape → both `_cache_current_floor` and SaveManager save/load.
- Add autoload → use the bare class identifier (`GameManager.x`) — do not add `static var = get_node_or_null(...)`.
