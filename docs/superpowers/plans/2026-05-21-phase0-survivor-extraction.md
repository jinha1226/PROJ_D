# Phase 0 — Survivor Extraction Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Extract 5 survivor modules out of `scripts/main/Game.gd` (currently 3721 lines) so that Phase 1 (faith/job/15F strip) and Phase 2 (rebuild) operate on clean call surfaces, without refactoring code that will be deleted anyway.

**Architecture:** Pure mechanical extraction. Behavior must remain identical at every commit. Each extracted module is a `Node`-subclass utility that Game.gd instantiates as a child (or holds a static-method reference). No new game logic, no autoload additions, no save schema change.

**Tech Stack:** Godot 4.6 / GDScript. Verification = `godot --headless --check-only` (parse) + manual F5 smoke (user-driven). No unit test framework installed; we rely on parse + smoke.

**Branch:** `expedition-rework` (cut from `main` at 563a0ac8).

**Source spec:** `docs/superpowers/specs/2026-05-21-expedition-rework-design.md` §3 Phase 0.

---

## Module Plan (Survivor-Only)

Five new files. **Doomed code (shrine/temple/B3/B15 boss spawn, `_apply_class_to_player`, faith handlers, 16-skill XP grants) stays in Game.gd untouched** — Phase 1 deletes them wholesale.

| # | New file | Game.gd functions extracted | Survives because |
|---|---|---|---|
| 1 | `scripts/main/FloorLifecycle.gd` | `_generate_floor`, `_cache_current_floor`, `_restore_floor_from_cache`, `_top_up_monsters_to_target`, `_floor_seed`, `_is_shop_floor` | 5-floor compression still needs gen + cache + restore |
| 2 | `scripts/main/SpawnService.gd` | `_spawn_monsters_layer`, `_spawn_items_layer`, `_spawn_unique_for_floor`, `_spawn_monsters_for_floor`, `_spawn_items_for_floor`, `spawn_ally`, `spawn_monster_at`, `_roll_monster_weapon`, `_spawn_floor_item`, `_spawn_essence_floor_item`, `_spawn_partial_book_floor_item`, `_spawn_gold_pile`, `_find_item_drop_pos`, `_monster_count_for_depth`, `_clear_monsters`, `_clear_floor_items` | Will extend to consume `visit_seed` in Phase 2 |
| 3 | `scripts/ui/EffectsLayer.gd` | `spawn_damage_number`, `spawn_text_popup`, `spawn_hit_flash`, `spawn_projectile`, `spawn_spell_bolt`, `spawn_hit_effect`, `spawn_aoe_burst`, `_corpse_tile_for_monster`, `_build_corpse_texture`, `_corpsify_cut_y`, `_corpsify_image` | Orthogonal to rework |
| 4 | `scripts/systems/SpellTargeting.gd` | `begin_spell_targeting`, `begin_spell_targeting_auto`, `_cancel_targeting`, `_confirm_targeting`, `apply_fear_aoe`, `apply_fog_aoe`, `apply_silence_aoe`, `apply_immolation_aoe`, `alert_all_monsters`, `dig_toward` | Essence system stays and consumes these |
| 5 | `scripts/core/SaveMigration.gd` | Migration-registry skeleton (no functions exist yet to move; SaveManager has version comments only) | Phase 1/2 needs the migration surface ready |

**Functions explicitly NOT extracted** (will be deleted in Phase 1):
- `_apply_class_to_player`, `_class_starter_items`, `_class_default_active_skills`
- `_spawn_b3_temple_boss`, `_spawn_b15_boss_floor`, `_place_b3_altars`
- `_try_open_shrine_choice`
- `_handle_first_shrine_boss_clear`
- `_grant_passive_skill_xp` (16-skill specific)
- `_handle_monster_essence_drop` — wait, this stays (essence system survives). Reconsidering: keep in Game.gd for Phase 0, decide in Phase 2 whether it moves to EssenceService.

**Functions deferred** (extraction Phase-dependent, not Phase 0):
- Branch functions (`_on_branch_enter`, `_on_branch_stairs_down/up`, `_generate_branch_floor`, `_cache_branch_floor`, `_spawn_branch_*`): branches change shape entirely in Phase 2f, extracting now is wasted motion.
- Abyss functions (`_spawn_abyss_floor`, `_tick_abyss`, `_abyss_find_new_exit`): abyss becomes Main Floor 5 in Phase 2c — may be rewritten.
- Shop functions (`_place_shop_tile`, `_shop_price`, `_generate_shop_inventory`, `_open_shop`): town starter shop replaces dungeon shops in Phase 2a; partial overlap, defer.
- Stair/travel functions (`_on_stairs_down`, `_on_stairs_up`, `_travel_to_floor`): semantics change in Phase 2 (turn budget triggers safe-return, not stairs up at depth 1). Defer.

---

## Verification Pattern (every task)

After every code change, run two checks before commit:

1. **Headless parse**: `godot --headless --quit --check-only --path .`
   Expected output: clean exit, no "Parse Error" or "SCRIPT ERROR" lines. Exit code 0.

2. **F5 smoke (user runs, blocking gate)**: The user opens Godot editor → F5 → walks the smoke path. Per CLAUDE.md §Active Runtime:
   - MainMenu → New Run → RaceSelect → JobSelect → spawn into D:1
   - Walk one step, bump a wall
   - Press Auto-walk (long press tile)
   - Read any scroll from starting inventory
   - Descend stairs to D:2
   - Ascend stairs to D:1
   - `Esc → Menu → Quit` (or die to a monster)
   - Load save (if save exists) and confirm the run resumes.

   If anything misbehaves vs. the pre-extraction baseline, the task is incomplete.

Each task commits **after both checks pass**. If headless parse fails, do not ask user to F5.

---

## Task 0: Branch setup and baseline capture

**Files:**
- None (git-only)

- [ ] **Step 1: Verify clean working tree on `main`**

```bash
git status --porcelain
```

Expected: empty output. If not, ask user before proceeding (uncommitted work present per gitStatus header).

- [ ] **Step 2: Cut the expedition-rework branch from main HEAD**

```bash
git checkout -b expedition-rework
git log -1 --oneline
```

Expected: `563a0ac8 docs(spec): add expedition rework design (2026-05-21)` (or whatever current main HEAD is at execution time).

- [ ] **Step 3: Record baseline Game.gd metrics in commit message of Task 1**

```bash
wc -l scripts/main/Game.gd
grep -c "^func " scripts/main/Game.gd
```

Expected (as of plan write): `3721 scripts/main/Game.gd`, `157 funcs`. Carry these numbers into Task 1's commit message for diff reference.

- [ ] **Step 4: Confirm baseline parse passes**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0, no parse errors. If this already fails on `main`, stop and report — do not start extraction on a broken baseline.

- [ ] **Step 5: Confirm baseline F5 smoke (user)**

Ask user: "Please F5 on `main` HEAD and run the smoke path (race → job → walk → bump → autowalk → scroll → descend → ascend → die). Reply 'baseline OK' or describe any pre-existing issue."

Do not proceed until baseline confirmed.

---

## Task 1: Extract FloorLifecycle.gd

**Files:**
- Create: `scripts/main/FloorLifecycle.gd`
- Modify: `scripts/main/Game.gd` (remove extracted funcs, add delegation)

**Functions extracted** (from `Game.gd`):
- `_floor_seed` (lines 875-877)
- `_is_shop_floor` (lines 878-894)
- `_generate_floor` (lines 1038-1083)
- `_cache_current_floor` (lines 1219-1267)
- `_restore_floor_from_cache` (lines 1268-1359)
- `_top_up_monsters_to_target` (lines 1360-1394)

These functions touch many Game.gd members (`map`, `seed`, `depth`, `GameManager.floor_cache`, etc.). The extraction strategy is **pass-through reference**: FloorLifecycle is a `Node` child of Game; it stores a `host` reference to Game and accesses members through it. This is intentionally minimal — Phase 2 may refactor to proper interfaces, but Phase 0 must not change behavior.

- [ ] **Step 1: Create FloorLifecycle.gd skeleton**

Create file `scripts/main/FloorLifecycle.gd` with content:

```gdscript
extends Node
class_name FloorLifecycle

# Phase 0 extraction from Game.gd. Behavior identical — this module
# borrows the host Game node's state via direct reference. Phase 2 may
# refactor to explicit interfaces.

var host: Node  # the Game node; assigned in setup()

func setup(game_node: Node) -> void:
	host = game_node

# ---- functions extracted from Game.gd ----
# (filled in Step 2)
```

- [ ] **Step 2: Move the 6 functions verbatim from Game.gd into FloorLifecycle.gd**

For each function (`_floor_seed`, `_is_shop_floor`, `_generate_floor`, `_cache_current_floor`, `_restore_floor_from_cache`, `_top_up_monsters_to_target`):

1. Copy the entire function body from Game.gd into FloorLifecycle.gd, in the same order.
2. Inside each function, prefix every bare identifier that referred to a Game member with `host.` (e.g. `map` → `host.map`, `seed` → `host.seed`, `depth` → `host.depth`, `_spawn_*` calls → `host._spawn_*`). Be exhaustive — use `Read` to capture the entire function before editing.
3. Leave private-prefix `_` in the function names (these are not public API, just package-internal).

After step 2 the new file should contain the six functions, each correctly delegating member access to `host`.

- [ ] **Step 3: Delete the 6 functions from Game.gd and add a `_floor_lifecycle` child**

In `Game.gd`:

1. Delete the 6 function definitions (lines noted above; recompute exact lines after each delete because subsequent line numbers shift — use grep `^func _generate_floor` etc. to relocate).
2. In `_ready()`, after the existing setup but before the first floor generation call, add:

```gdscript
_floor_lifecycle = FloorLifecycle.new()
_floor_lifecycle.name = "FloorLifecycle"
add_child(_floor_lifecycle)
_floor_lifecycle.setup(self)
```

3. Add a member declaration near the top of Game.gd alongside other `var` declarations:

```gdscript
var _floor_lifecycle: FloorLifecycle
```

4. Replace every call site inside Game.gd that used the now-deleted functions:
   - `_floor_seed(d)` → `_floor_lifecycle._floor_seed(d)`
   - `_is_shop_floor(d)` → `_floor_lifecycle._is_shop_floor(d)`
   - `_generate_floor(...)` → `_floor_lifecycle._generate_floor(...)`
   - `_cache_current_floor()` → `_floor_lifecycle._cache_current_floor()`
   - `_restore_floor_from_cache(...)` → `_floor_lifecycle._restore_floor_from_cache(...)`
   - `_top_up_monsters_to_target(d)` → `_floor_lifecycle._top_up_monsters_to_target(d)`

Use `grep -n "_generate_floor\|_cache_current_floor\|_restore_floor_from_cache\|_top_up_monsters_to_target\|_floor_seed\|_is_shop_floor" scripts/main/Game.gd` to find every call site. Update them all.

- [ ] **Step 4: Run headless parse**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0. If parse error, the typical cause is a member name change missed in Step 2 (e.g. a function still references bare `map` instead of `host.map`). Fix by grepping `^func ` inside FloorLifecycle.gd for stray bare references.

- [ ] **Step 5: User F5 smoke**

Ask user: "FloorLifecycle extracted. Please F5 and run smoke path. Critical checkpoints: descending generates a new floor, ascending restores cached floor (you should see the same monsters/items where you left them on D:1)."

Wait for "OK" or failure report. If failure, debug before proceeding.

- [ ] **Step 6: Commit**

```bash
git add scripts/main/FloorLifecycle.gd scripts/main/Game.gd
git commit -m "$(cat <<'EOF'
refactor(main): extract FloorLifecycle from Game.gd

Phase 0 survivor extraction. Move floor gen/cache/restore/top-up
functions into FloorLifecycle. Behavior identical. Game.gd shrinks
from baseline 3721 lines.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

- [ ] **Step 7: Verify line count dropped**

```bash
wc -l scripts/main/Game.gd
```

Expected: Game.gd noticeably smaller (roughly 240 fewer lines than baseline 3721, give or take). Record number for next task's commit message.

---

## Task 2: Extract SpawnService.gd

**Files:**
- Create: `scripts/main/SpawnService.gd`
- Modify: `scripts/main/Game.gd`

**Functions extracted** (16 total):
- `_spawn_monsters_layer` (706-710)
- `_spawn_items_layer` (701-705)
- `_spawn_unique_for_floor` (1395-1427)
- `_spawn_monsters_for_floor` (1428-1459)
- `_spawn_items_for_floor` (1460-1595)
- `spawn_ally` (1596-1624)
- `spawn_monster_at` (1625-1645)
- `_roll_monster_weapon` (1646-1661)
- `_spawn_floor_item` (1662-1668)
- `_spawn_essence_floor_item` (1669-1678)
- `_spawn_partial_book_floor_item` (1679-1691)
- `_spawn_gold_pile` (1692-1709)
- `_find_item_drop_pos` (1764-1783)
- `_monster_count_for_depth` (1894-1900)
- `_clear_monsters` (1901-1906)
- `_clear_floor_items` (1907-1911)

**NOT extracted** (stays in Game.gd, deleted in later phases):
- `_spawn_b3_temple_boss`, `_spawn_b15_boss_floor`, `_place_b3_altars` (Phase 1 deletes)
- `_spawn_orc_treasure_room` (Phase 2 may rework — has zone-specific logic)
- `_spawn_branch_monsters`, `_spawn_branch_boss`, `_spawn_branch_resistance_hint` (branches reshape in Phase 2)
- `spawn_damage_number`, `spawn_text_popup`, `spawn_projectile`, etc. (those go to EffectsLayer in Task 3)

- [ ] **Step 1: Create SpawnService.gd skeleton**

```gdscript
extends Node
class_name SpawnService

# Phase 0 extraction from Game.gd. Hosts spawn/clear of monsters and
# floor items for the active dungeon floor. Branch/boss/temple-specific
# spawners stay in Game.gd because Phase 1/2 will delete or reshape them.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node
```

- [ ] **Step 2: Move the 16 functions verbatim into SpawnService.gd**

Same procedure as Task 1 Step 2. For each function:
1. Read the original from Game.gd.
2. Paste into SpawnService.gd.
3. Prefix Game-member references with `host.`. Pay attention to:
   - `MonsterRegistry`, `ItemRegistry`, `SpellRegistry` — these are **autoloads** (global). Do NOT prefix with `host.`.
   - `RaceRegistry`, `ZoneManager`, `ClassRegistry`, `RacePassiveSystem` — autoloads, no prefix.
   - `host.map`, `host.depth`, `host.seed`, `host._world`, `host._items_root`, etc. — these need `host.`.
   - Calls to `_spawn_floor_item`, `_find_item_drop_pos` (i.e., functions *also* being moved): change to bare calls within SpawnService — they're now sibling methods.

- [ ] **Step 3: Delete the 16 functions from Game.gd and add `_spawn_service` child**

1. Delete the 16 functions from Game.gd (recompute line numbers as you go).
2. Add member: `var _spawn_service: SpawnService` near top.
3. In `_ready()` after `_floor_lifecycle` setup, add:

```gdscript
_spawn_service = SpawnService.new()
_spawn_service.name = "SpawnService"
add_child(_spawn_service)
_spawn_service.setup(self)
```

4. Update every call site in Game.gd and FloorLifecycle.gd. Grep:

```bash
grep -n "_spawn_monsters_layer\|_spawn_items_layer\|_spawn_unique_for_floor\|_spawn_monsters_for_floor\|_spawn_items_for_floor\|spawn_ally\|spawn_monster_at\|_roll_monster_weapon\|_spawn_floor_item\|_spawn_essence_floor_item\|_spawn_partial_book_floor_item\|_spawn_gold_pile\|_find_item_drop_pos\|_monster_count_for_depth\|_clear_monsters\|_clear_floor_items" scripts/main/Game.gd scripts/main/FloorLifecycle.gd
```

Replace each call:
- Inside Game.gd: `_spawn_monsters_for_floor(d)` → `_spawn_service._spawn_monsters_for_floor(d)`. Etc.
- Inside FloorLifecycle.gd: `host._spawn_monsters_for_floor(d)` → `host._spawn_service._spawn_monsters_for_floor(d)`.

5. **`spawn_ally` and `spawn_monster_at` are called from outside Game.gd**. Grep entire `scripts/` and `scenes/`:

```bash
grep -rn "\.spawn_ally\|\.spawn_monster_at" scripts/ scenes/ 2>/dev/null
```

For each external caller (likely `MagicSystem.gd`, scroll/wand effects, summoning spells), update `game.spawn_ally(...)` → `game._spawn_service.spawn_ally(...)`. If many callers exist (>5), consider keeping a thin pass-through in Game.gd:

```gdscript
func spawn_ally(monster_id: String, near_pos: Vector2i, turns: int) -> bool:
	return _spawn_service.spawn_ally(monster_id, near_pos, turns)

func spawn_monster_at(monster_id: String, pos: Vector2i) -> bool:
	return _spawn_service.spawn_monster_at(monster_id, pos)
```

This pass-through is acceptable for Phase 0 because changing every external caller is risky and external API stability matters for save-load resume. Document the decision in the commit message.

- [ ] **Step 4: Run headless parse**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0. Common failures here:
- Missed `host.` prefix on a Game member.
- A function calls another extracted sibling using `host._foo` instead of bare `_foo`.

- [ ] **Step 5: User F5 smoke**

Ask user: "SpawnService extracted. F5 and run smoke path. Critical checkpoints: monsters spawn on new floor, items spawn on new floor, kills clear from monster list. Also test: read a Summon Lesser Demon scroll or any summoning spell if available (verifies `spawn_ally` external call path)."

- [ ] **Step 6: Commit**

```bash
git add scripts/main/SpawnService.gd scripts/main/Game.gd scripts/main/FloorLifecycle.gd
git commit -m "$(cat <<'EOF'
refactor(main): extract SpawnService from Game.gd

Phase 0 survivor extraction. Move generic monster/item spawning into
SpawnService. Boss/temple/branch spawners stay in Game.gd (deleted or
reshaped in Phase 1/2). spawn_ally and spawn_monster_at keep thin
pass-throughs in Game.gd for external caller stability.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 3: Extract EffectsLayer.gd

**Files:**
- Create: `scripts/ui/EffectsLayer.gd`
- Modify: `scripts/main/Game.gd`

**Functions extracted** (11 total):
- `_corpse_tile_for_monster` (1784-1793)
- `_build_corpse_texture` (1794-1823)
- `_corpsify_cut_y` (1824-1833)
- `_corpsify_image` (1834-1893)
- `spawn_damage_number` (3472-3486)
- `spawn_text_popup` (3487-3503)
- `spawn_hit_flash` (3508-3550)
- `spawn_projectile` (3551-3554)
- `spawn_spell_bolt` (3555-3589)
- `spawn_hit_effect` (3590-3592)
- `spawn_aoe_burst` (3593-3599)

Note line numbers have shifted from baseline after Task 1+2 deletions. Use `grep -n "^func _corpse_tile_for_monster" scripts/main/Game.gd` to find each before editing.

- [ ] **Step 1: Create EffectsLayer.gd skeleton**

```gdscript
extends Node
class_name EffectsLayer

# Phase 0 extraction from Game.gd. Hosts visual effect spawning:
# damage numbers, text popups, hit flashes, projectiles, spell bolts,
# AOE bursts, and corpse texture building/composition.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node
```

- [ ] **Step 2: Move the 11 functions into EffectsLayer.gd**

Same procedure: copy → prefix `host.` for Game members → keep autoloads bare. Watch for:
- `_world`, `_effects_root`, `_camera` — Game members, prefix with `host.`.
- Sibling calls within EffectsLayer (`_corpsify_image` from `_build_corpse_texture`) — bare.

- [ ] **Step 3: Delete from Game.gd, add `_effects_layer` child, route call sites**

1. Delete the 11 functions.
2. Add `var _effects_layer: EffectsLayer` near top.
3. `_ready()`:

```gdscript
_effects_layer = EffectsLayer.new()
_effects_layer.name = "EffectsLayer"
add_child(_effects_layer)
_effects_layer.setup(self)
```

4. The `spawn_damage_number`, `spawn_text_popup`, `spawn_projectile`, `spawn_hit_flash`, `spawn_spell_bolt`, `spawn_hit_effect`, `spawn_aoe_burst` are public — heavily called externally. Grep:

```bash
grep -rn "\.spawn_damage_number\|\.spawn_text_popup\|\.spawn_projectile\|\.spawn_hit_flash\|\.spawn_spell_bolt\|\.spawn_hit_effect\|\.spawn_aoe_burst" scripts/ scenes/ 2>/dev/null | wc -l
```

If many (>10), keep pass-through wrappers in Game.gd for each public spawn function:

```gdscript
func spawn_damage_number(world_pos: Vector2, amount: int, color: Color) -> void:
	_effects_layer.spawn_damage_number(world_pos, amount, color)

func spawn_text_popup(world_pos: Vector2, text: String, color: Color, ...) -> void:
	_effects_layer.spawn_text_popup(world_pos, text, color, ...)

# etc.
```

Match the original signatures **exactly** including default-argument values (re-read the originals before writing wrappers).

5. The corpse texture functions (`_corpse_tile_for_monster`, `_build_corpse_texture`, `_corpsify_cut_y`, `_corpsify_image`) are likely called only from within Game.gd or SpawnService. Replace internal callers: `_corpse_tile_for_monster(m)` → `_effects_layer._corpse_tile_for_monster(m)` (Game.gd) or `host._effects_layer._corpse_tile_for_monster(m)` (SpawnService.gd).

Check SpawnService.gd for any corpse-related calls and update.

- [ ] **Step 4: Run headless parse**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0.

- [ ] **Step 5: User F5 smoke**

Ask user: "EffectsLayer extracted. F5 and run smoke path. Critical checkpoints: hit a monster → see damage number float up; cast any spell with projectile (Magic Dart, Throw Flame) → see spell bolt; kill a monster → see corpse texture appear. Also: drink any potion or read a scroll → confirm text popup shows."

- [ ] **Step 6: Commit**

```bash
git add scripts/ui/EffectsLayer.gd scripts/main/Game.gd scripts/main/SpawnService.gd
git commit -m "$(cat <<'EOF'
refactor(ui): extract EffectsLayer from Game.gd

Phase 0 survivor extraction. Move damage numbers, text popups, hit
flashes, projectiles, spell bolts, AOE bursts, and corpse texture
composition into EffectsLayer. Public spawn_* functions keep
pass-through wrappers in Game.gd for external caller stability.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 4: Extract SpellTargeting.gd

**Files:**
- Create: `scripts/systems/SpellTargeting.gd`
- Modify: `scripts/main/Game.gd`

**Functions extracted** (10 total):
- `begin_spell_targeting` (~2904)
- `begin_spell_targeting_auto` (~2922)
- `_cancel_targeting` (~2955)
- `_confirm_targeting` (~2963)
- `apply_fear_aoe` (~2136)
- `apply_fog_aoe` (~2141)
- `apply_silence_aoe` (~2144)
- `apply_immolation_aoe` (~2161)
- `alert_all_monsters` (~2149)
- `dig_toward` (~2153)

(Lines approximate — recompute after prior task deletions.)

- [ ] **Step 1: Create SpellTargeting.gd skeleton**

```gdscript
extends Node
class_name SpellTargeting

# Phase 0 extraction from Game.gd. Hosts spell targeting flow
# (begin/cancel/confirm) and AOE application helpers. Will be consumed
# by Phase 2 essence/spell systems.

var host: Node

func setup(game_node: Node) -> void:
	host = game_node
```

- [ ] **Step 2: Move the 10 functions into SpellTargeting.gd**

Same procedure. Members to watch:
- `_active_spell`, `_active_caster`, `_targeting_cursor`, `_targeting_path` — likely Game members holding targeting state. Prefix with `host.`. (Verify exact names by Read.)
- `MagicSystem`, `AoeEffects`, `Status` — autoloads, bare.
- Sibling calls among these 10 functions — bare.

**Important:** the targeting state members (`_active_spell` etc.) might be better moved entirely into SpellTargeting. For Phase 0, leave them in Game.gd and access via `host.` — this preserves behavior. Phase 2 can promote the state if it cleans up nicely.

- [ ] **Step 3: Delete from Game.gd, add `_spell_targeting` child, route call sites**

1. Delete the 10 functions.
2. `var _spell_targeting: SpellTargeting`.
3. `_ready()`:

```gdscript
_spell_targeting = SpellTargeting.new()
_spell_targeting.name = "SpellTargeting"
add_child(_spell_targeting)
_spell_targeting.setup(self)
```

4. Replace call sites in Game.gd:
   - `begin_spell_targeting(...)` → `_spell_targeting.begin_spell_targeting(...)`
   - etc.
5. External callers (likely MagicSystem.gd, item-use code in Player.gd or Game.gd). Grep:

```bash
grep -rn "\.begin_spell_targeting\|\.apply_fear_aoe\|\.apply_fog_aoe\|\.apply_silence_aoe\|\.apply_immolation_aoe\|\.alert_all_monsters\|\.dig_toward" scripts/ scenes/ 2>/dev/null
```

`begin_spell_targeting` and the apply_*_aoe functions are likely public API for spells. Keep pass-through wrappers in Game.gd matching original signatures (re-read them first).

- [ ] **Step 4: Run headless parse**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0.

- [ ] **Step 5: User F5 smoke**

Ask user: "SpellTargeting extracted. F5 and run smoke path. Critical checkpoints: cast a targeted spell (Magic Dart on a visible monster) → see cursor → confirm → hit. Cast an AOE spell (Fireball or any scroll/wand that triggers fear/fog/silence/immolation if reachable). Read a Scroll of Magic Mapping or any scroll with `dig_toward` effect if available (Dig). Cast Alarm or any noise-based effect if available."

If the smoke path doesn't reach AOE spells naturally, ask user to use debug warp (if available) or trust the parse + targeted-spell test.

- [ ] **Step 6: Commit**

```bash
git add scripts/systems/SpellTargeting.gd scripts/main/Game.gd
git commit -m "$(cat <<'EOF'
refactor(systems): extract SpellTargeting from Game.gd

Phase 0 survivor extraction. Move spell targeting flow and AOE
application helpers into SpellTargeting. Targeting state (active
spell/caster/cursor) stays on Game.gd for Phase 0; promotion to
SpellTargeting deferred to Phase 2 essence/spell consumers.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 5: Extract SaveMigration.gd

**Files:**
- Create: `scripts/core/SaveMigration.gd`
- Modify: `scripts/core/SaveManager.gd`

**Background:** SaveManager.gd currently has `const SAVE_VERSION: int = 4` and version comments but **no actual migration code**. Saves older than current version are not actively migrated — older saves either work by coincidence (v3 → v4 added new optional fields) or are wiped externally. Phase 0's job is to establish the migration *surface* so Phase 1 (v4→v5 faith strip) has a clear place to add a function.

- [ ] **Step 1: Read current SaveManager.gd in full to understand load path**

```bash
wc -l scripts/core/SaveManager.gd
```

Read the whole file via Read tool. Identify:
- Where `load_save()` returns the raw dict.
- Whether any consumer (e.g. Game.gd, GameManager.gd) inspects `save_version` after load.

- [ ] **Step 2: Create SaveMigration.gd**

```gdscript
extends Node
class_name SaveMigration

# Save migration registry. Each entry transforms a save dict from
# version N to version N+1. Migrations are applied sequentially when
# a save's version is below the current SAVE_VERSION.
#
# Phase 0: registry skeleton, zero migrations registered (no historical
# migrations exist in code today; v3->v4 was tolerated via default values
# on missing fields). Phase 1 adds the v4->v5 faith-strip migration.
# Phase 2 adds v5->v10 town/character split.

const CURRENT_VERSION: int = 4

# Registry maps from_version -> Callable(dict) -> dict
# When you add a migration, append it here.
static func _migrations() -> Dictionary:
	return {
		# 4: Callable(SaveMigration, "_migrate_v4_to_v5"),  # added in Phase 1
	}

# Apply all migrations needed to bring `data` to CURRENT_VERSION.
# Returns migrated dict. If save is already at CURRENT_VERSION,
# returns data unchanged. If save is newer than CURRENT_VERSION,
# returns data unchanged with a warning (forward-compat best-effort).
static func migrate(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return data
	var ver: int = int(data.get("save_version", data.get("version", 1)))
	if ver > CURRENT_VERSION:
		push_warning("SaveMigration: save version %d is newer than current %d; loading as-is" % [ver, CURRENT_VERSION])
		return data
	var regs := _migrations()
	while ver < CURRENT_VERSION:
		if not regs.has(ver):
			push_warning("SaveMigration: no migration from v%d to v%d; loading as-is with default fields" % [ver, ver + 1])
			return data
		var fn: Callable = regs[ver]
		data = fn.call(data)
		ver += 1
		data["save_version"] = ver
	return data
```

- [ ] **Step 3: Wire SaveManager.gd to route loads through SaveMigration**

Modify `load_save()` in `SaveManager.gd`. Read current implementation (Step 1 already covered this). Change the return path:

Before (paraphrased):
```gdscript
func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return parsed
	return {}
```

After:
```gdscript
func load_save() -> Dictionary:
	if not FileAccess.file_exists(SAVE_PATH):
		return {}
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return {}
	var raw := f.get_as_text()
	f.close()
	var parsed = JSON.parse_string(raw)
	if typeof(parsed) == TYPE_DICTIONARY:
		return SaveMigration.migrate(parsed)
	return {}
```

Also ensure the `const SAVE_VERSION: int = 4` in SaveManager.gd is kept in sync with `SaveMigration.CURRENT_VERSION`. To avoid drift, change SaveManager to import:

```gdscript
const SAVE_VERSION: int = SaveMigration.CURRENT_VERSION
```

Verify by Read that `SAVE_VERSION` is used only when writing saves (e.g. in `save_run` for the `"version"` and `"save_version"` keys). If used elsewhere, audit those sites.

- [ ] **Step 4: Run headless parse**

```bash
godot --headless --quit --check-only --path .
```

Expected: exit code 0. Common parse error: GDScript 4 `Callable.call()` and static `Dictionary` literal containing Callables — if Godot rejects the dict-of-Callable construction at parse time, simplify by returning an empty dict for now:

```gdscript
static func _migrations() -> Dictionary:
	return {}  # populated in Phase 1
```

Either approach is acceptable for Phase 0 — the registry just needs to exist and route through `migrate()`.

- [ ] **Step 5: User F5 smoke**

Ask user: "SaveMigration wired. F5: start a new run, descend to D:2, save & quit. Load. Confirm run resumes at D:2 with state intact. This validates the migration pass-through (your v4 save → SaveMigration.migrate → unchanged → load)."

If an existing save predates v4, expect the warning `"no migration from v3 to v4; loading as-is"` in the Godot console — that's the intended behavior, not a regression.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/SaveMigration.gd scripts/core/SaveManager.gd
git commit -m "$(cat <<'EOF'
refactor(core): add SaveMigration registry, route loads through it

Phase 0 survivor extraction. SaveMigration holds a versioned migration
registry; load_save() runs incoming dicts through migrate() before
returning. Zero migrations registered (historical v<4 saves were
tolerated via default-value fallback, not explicit migration). Phase 1
will add v4->v5 (faith strip); Phase 2 will add v5->v10 (town/character
split).

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Task 6: Phase 0 exit verification

**Files:**
- None (verification only)

- [ ] **Step 1: Confirm Game.gd shrink**

```bash
wc -l scripts/main/Game.gd
grep -c "^func " scripts/main/Game.gd
```

Expected: roughly 2400–2600 lines (down from 3721); roughly 100–115 funcs (down from 157). Exact numbers vary based on pass-through wrappers kept. Record actual numbers.

- [ ] **Step 2: Confirm new files exist with expected structure**

```bash
wc -l scripts/main/FloorLifecycle.gd scripts/main/SpawnService.gd scripts/ui/EffectsLayer.gd scripts/systems/SpellTargeting.gd scripts/core/SaveMigration.gd
```

All five files must exist and be non-trivially sized.

- [ ] **Step 3: Confirm no autoload changes**

```bash
diff <(git show main:project.godot | grep -A 30 '^\[autoload\]') <(grep -A 30 '^\[autoload\]' project.godot)
```

Expected: no diff. Phase 0 must NOT have changed autoloads. (Phase 1+ will remove ClassRegistry; Phase 2 will add Town/Expedition autoloads.)

- [ ] **Step 4: Confirm no save-schema breakage**

```bash
grep -n "SAVE_VERSION\|save_version" scripts/core/SaveManager.gd scripts/core/SaveMigration.gd
```

Expected: `SAVE_VERSION` resolves to 4. `SaveMigration.CURRENT_VERSION` is 4. No schema change in Phase 0.

- [ ] **Step 5: Final user F5 smoke (full smoke path)**

Ask user to do one final F5 covering the entire smoke path end to end:

> MainMenu → New Run → RaceSelect → JobSelect → spawn D:1 → walk → bump → auto-walk → read scroll → descend → ascend → cast a targeted spell if available → die OR quit → restart → load save → confirm resume → quit cleanly.

Wait for "Phase 0 OK".

- [ ] **Step 6: Tag Phase 0 completion**

```bash
git tag phase0-complete
git log --oneline main..HEAD
```

Expected log: 5 refactor commits + the spec commit on main. Total 6 commits including the spec.

- [ ] **Step 7: Update docs/refactoring_todo.md and docs/decision_log.md**

Add to `docs/decision_log.md` (append, do not rewrite):

```markdown
## 2026-05-21 — Phase 0 Survivor Extraction complete

5 modules extracted from Game.gd (3721 → ~2500 lines):
- FloorLifecycle.gd, SpawnService.gd, EffectsLayer.gd, SpellTargeting.gd, SaveMigration.gd

Branch: expedition-rework (not merged to main). Phase 1 (faith/job/15F
strip) starts next. See docs/superpowers/specs/2026-05-21-expedition-rework-design.md.
```

Add to `docs/refactoring_todo.md` a "Phase 0 complete" marker if the file already tracks phases.

Commit:

```bash
git add docs/decision_log.md docs/refactoring_todo.md
git commit -m "$(cat <<'EOF'
docs: mark Phase 0 (survivor extraction) complete

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Phase 0 Exit Criteria (must all be true)

- [ ] Branch `expedition-rework` exists, cut from main HEAD at plan-write time.
- [ ] 5 new files created at the paths specified.
- [ ] Game.gd shrunk by 25–35% (line count).
- [ ] `godot --headless --quit --check-only --path .` exits 0.
- [ ] F5 smoke path passes end-to-end (user-confirmed).
- [ ] Existing saves still load and resume correctly.
- [ ] No autoload changes.
- [ ] No save-schema version change (still v4).
- [ ] All deleted Game.gd content is now in one of the 5 new files (with appropriate `host.` prefixing).
- [ ] Pass-through wrappers preserved for externally-called public methods (`spawn_ally`, `spawn_monster_at`, `spawn_damage_number`, `spawn_text_popup`, `spawn_projectile`, `spawn_hit_flash`, `spawn_spell_bolt`, `spawn_hit_effect`, `spawn_aoe_burst`, `begin_spell_targeting`, `apply_*_aoe`, `alert_all_monsters`, `dig_toward`).
- [ ] Tag `phase0-complete` placed on final commit.
- [ ] Decision log updated.

When all checked, Phase 1 (faith/job/15F strip) plan can be written.

---

## Anti-pattern reminders for the executor

1. **Do not extract code that gets deleted in Phase 1.** Shrine, B3 temple, B15 boss, JobSelect-bound functions, `_apply_class_to_player`, faith-conditional branches — all stay in Game.gd.
2. **Do not change behavior.** Phase 0 is a pure motion of code, not a refactor of logic. If you find a bug, file it for Phase 2 but do not fix it here.
3. **Do not add tests.** PROJ_D has no test framework. Verification is parse + F5.
4. **Do not change save schema.** v4 stays v4.
5. **Do not touch autoloads.** Phase 0 does not register or remove autoloads.
6. **Do not skip user F5 confirmation.** Headless parse catches syntax, but only smoke catches runtime regression in extracted code paths.
7. **If a function references state via mixed paths (e.g. some `host.` some bare), prefer all-`host.` for Game-owned state.** Treat the rule as: every identifier that the original function got from `self` now needs `host.`.
8. **Pass-through wrappers must match original signatures exactly**, including typed parameters and default values. Mismatched signatures cause silent runtime errors that headless parse won't catch.
