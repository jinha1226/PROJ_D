# Expedition Rework Design

**Date:** 2026-05-21
**Status:** Spec draft, awaiting user review
**Branch (recommended):** `expedition-rework` (do not commit to `main` during Phase 0~2)
**Source of requirements:** `/mnt/d/PROJ_G/expedition_roguelike_proto/docs/` (treat as authoritative)

---

## 1. What we are changing

PocketCrawl pivots from a DCSS-style continuous 15-floor crawl into a **town-hub expedition roguelike** with permadeath characters, persistent town, and timed expeditions into 5 fixed compressed dungeon floors.

The PROJ_G prototype space already contains the full rule set. We are not redesigning gameplay — we are migrating PROJ_D's working code to satisfy those rules.

### Direction (verbatim from PROJ_G migration plan)
- Persistent town
- Permadeath characters
- Timed/turn-limited expeditions
- Main dungeon compressed from 15 → 5 fixed themed floors
- Fixed theme layouts with variable monster spawns per visit
- Action-based skill growth (9 skills, d100)
- No hunger
- No lifestyle crafting skills
- **No Faith system**
- **No Job/Class selection (race only + 120 starting gold)**

### What dies
- FaithSystem (autoload + 44 reference sites)
- JobSelect scene/script + ClassRegistry + `resources/classes/`
- 15-floor depth assumption (`depth == 15`, B15 boss, B3 temple)
- Shrine/Temple ritual flow
- 16-skill model (fighting, unarmed, blade, hafted, polearm, ranged, spellcasting, elemental, arcane, hex, necromancy, summoning, armor, shield, agility, tool)
- Rune-based victory condition (branch rewards become essences only)

### What is rebuilt
- 9-skill model: Weapon Mastery / Archery / Tactics / Defense / Magery / Stealth / Lockpicking / Tracking / Survival
- Combat formulas (d100, hit/damage/block/cast all per `mobile_skill_balance_rules.md`)
- 5 fixed authored floors @ 42×47 (Buried Catacombs → Green Lair → Orc Mines → Elven Halls → Shattered Abyss)
- 4 branches with essence rewards (Sunken Crypt / Blackfen Swamp / Ice Caves / Infernal Gate)
- Turn budget per expedition (240/260/270/290/300 main, 170-190 branch)
- Town hub scene + persistent `TownState`
- `ExpeditionState` (selected area, turn budget, loot, visit index, seed)
- Character-bound minimap memory (`character.map_memory[layout_id]`)
- Essence system decoupled from faith, 3 slots, unlocks at expedition 1/6/14, carry cap 4

### What survives largely unchanged
- TurnManager, CombatLog, Status, FieldOfView
- ItemRegistry, SpellRegistry, MagicSystem (after faith multiplier removal in Phase 1 — see Risk 2), RingSystem, AoeEffects, MonsterRegistry
- ItemData/FloorItem/MonsterData/SpellData entities
- DungeonMap, MapGen (BSP/cave/large BSP/crypt generators feed the fixed layouts)
- Randart system (`ItemRegistry.make_entry`)
- Item resources, monster resources, spell resources, race resources, tiles

---

## 2. Approach: phased migration on PROJ_D, new branch

**Why PROJ_D in-place, not PROJ_G:** PROJ_G is mostly docs + `.proj_d_reference.gd` stubs and currently has parse/runtime errors per the user. PROJ_D has working F5 smoke, save/load, combat, magic, items, UI. We keep the working game runnable at every step and surgically remove what the new design discards.

**Branch isolation:** All work on `expedition-rework`. `main` stays at 4289d884 (current head) so the existing game is recoverable. Merge to `main` only after Phase 3.

**Survivor-only pre-extraction (not full god-object split):** Refactoring Game.gd's shrine/faith/B15 logic into their own modules would be wasted motion because those modules get deleted in Phase 1 anyway. Phase 0 extracts only what survives the rework. Code being deleted stays in Game.gd until Phase 1 removes it.

---

## 3. Phase plan

Each phase ends with **F5 smoke pass** + commit. No phase merges to main.

### Phase 0 — Survivor extraction (Game.gd → small modules)
Goal: pull out functionality that survives the rework into dedicated files, so Phase 2 has clean call sites to extend.

Extract from `scripts/main/Game.gd`:
- `scripts/main/FloorLifecycle.gd` — Floor Gen & Cache (6 functions). Survives because 5-floor compression still needs gen+cache, just with fixed layouts.
- `scripts/main/MonsterSpawner.gd` — generic monster/item spawning (14 functions minus boss/temple-specific). Will extend to consume `visit_seed` in Phase 2.
- `scripts/ui/EffectsLayer.gd` — damage numbers, projectiles, corpse splat (10 functions). Orthogonal to rework.
- `scripts/systems/SpellTargeting.gd` — essence-related and spell targeting (7 functions). Essence system stays, so this is safe.
- `scripts/core/SaveMigration.gd` — extract migration table from SaveManager (currently inline). Save schema will jump from v4 to a larger version in Phase 2; pre-isolating the migration code makes that jump testable.

Each extraction is its own commit. After each, F5 smoke runs the existing 15-floor game. Behavior unchanged.

**Skip extraction for:** Shrine/Temple/B3/B15 boss flow, `_apply_class_to_player`, JobSelect-bound code, 16-skill XP grant sites, Faith UI handlers. These all get deleted in Phase 1.

**Exit gate:** F5 smoke (start → race → job → walk → bump → autowalk → read scroll → descend → ascend → die) still passes. `git diff main..expedition-rework --stat` shows 5 new files, Game.gd smaller, behavior identical.

### Phase 1 — Strip
Goal: remove all code paths that the new design discards. The game becomes temporarily limited (no shrine, no job select, no faith bonuses) but still launchable.

Deletions:
1. **FaithSystem autoload + file.** Remove all 44 reference sites (Player 10, Game 12, SaveManager 5, FaithSystem 5, others 12). Replace faith-conditional branches with the no-faith path.
2. **JobSelect scene/script.** RaceSelect.gd next-scene constant points to a placeholder Town scene (built in Phase 2; for Phase 1, a stub that says "Town WIP" and offers "Start expedition" → existing dungeon).
3. **ClassRegistry + `resources/classes/`.** Delete folder. Delete `_apply_class_to_player`. Player's starting kit becomes hard-coded race-default for Phase 1; replaced by starter-shop purchases in Phase 2.
4. **`depth == 15` and B15/B3 boss logic.** The 5-floor compression isn't built yet, so for Phase 1 the dungeon is "as many floors as before, but the boss/temple triggers are gone." This is intentional — it isolates the destructive change from the constructive change.
5. **Shrine UI + flow.**
6. **Rune as victory-required item.** Runes stay in `resources/items/` but no scene depends on them.

**Save schema:** Bump `save_version` to 5. Migration from v4 strips `faith_id`, `selected_class_id`, faith-related player fields. Saves from v4 are migrated; players keep gold/items/XL but lose faith state.

**Exit gate:** F5 smoke: race → (skip job, go straight to dungeon stub) → walk → bump → descend → ascend → die → load. No references to FaithSystem, ClassRegistry, JobSelect remain in `scripts/`.

### Phase 2 — Rebuild (core expedition loop)
This is the biggest phase. Break into sub-phases, each F5-runnable.

#### 2a. Town hub scene + TownState autoload
- `scenes/town/Town.tscn` + `scripts/town/Town.gd`
- `TownState` autoload: persistent across deaths. Stores discovered areas, unlocked branches, town progression, account-level flags.
- Town has: character roster slot, "Start Expedition" button → area selection menu, "Starter Shop" button.
- Starter shop: 120 gold to spend on one of the six opening routes (sword+light armor, heavy weapon+healing, bow+light armor, staff+focus, lockpick+dagger, trail kit+bow/spear).
- Character creation flow: MainMenu → RaceSelect → CharacterName → StarterShop → Town.
- Exit gate: can create a character, buy gear, see them in town. No expedition yet.

#### 2b. 9-skill model + skill mapping
- `config/balance/skills.json` rewritten to 9 entries with d100 (0.0~100.0) and rank bands per `mobile_skill_balance_rules.md`.
- `scripts/systems/ExpeditionSkillRules.gd` new file: `xp_needed(skill)`, `gain_xp(action, character, difficulty, risk)` with `anti_grind`, rank-band labels.
- Map old skills → new skills:

| Old (deleted) | New |
|---|---|
| fighting, unarmed, blade, hafted, polearm | Weapon Mastery |
| ranged | Archery |
| spellcasting, elemental, arcane, hex, necromancy, summoning | Magery |
| armor, shield | Defense |
| agility | Stealth (mostly) + Survival (partly) |
| tool | Lockpicking + Tracking |
| (new) | Tactics, Survival |

- Migrate XP banks per character at save load (sum the old buckets into the new bucket, divide by something sane — exact ratio TBD in plan).
- Combat formulas in CombatSystem.gd rewritten per `mobile_skill_balance_rules.md` §Physical Combat / Defense / Magery.
- Exit gate: F5, fight a monster, see hit/miss/damage match new formulas; gain Weapon Mastery XP on hit, Defense XP on hit-taken.

#### 2c. 5 fixed authored floors
- `scripts/systems/ExpeditionFixedLayoutDesigns.gd` — layout data per `fixed_map_layout_designs.md` (42×47, fixed landmarks, branch entrance positions).
- `scripts/systems/ExpeditionZoneRules.gd` — area lookup, layout_seed_for_area, spawn_seed_for_visit, map style, turn budget.
- Floor generation pipeline: `layout_seed` (fixed per floor) → wall/room structure; `spawn_seed` (per visit, `visit_index` from ExpeditionState) → monster placement.
- Atlas svg at `docs/maps/fixed_map_atlas.svg` is the human-readable reference.
- Branch entrances become fixed tile features at the documented positions.
- Exit gate: F5, start expedition → enter Catacombs → see same wall layout every visit → see different monsters per visit.

#### 2d. Turn budget + expedition state + safe return
- `scripts/systems/ExpeditionState.gd` — area_id, main_floor, branch_floor (optional), turn_budget, turns_spent, visit_index, generated_seed, loot, map_memory_updates.
- TurnManager calls into ExpeditionState on `end_player_turn`. When budget hits 0, trigger safe-return.
- Safe-return chance per Survival formula (`mobile_skill_balance_rules.md` §Survival).
- HUD: turn budget visible before expedition launch + during.
- Exit gate: F5, expedition with budget=240, exhaust it, see safe-return roll, return to town, character persists, items kept on success.

#### 2e. Character-bound minimap memory
- `character.map_memory[layout_id]` per `map_and_branch_rules.md`.
- Persistence: on expedition end (success or safe return), explored tiles written into character. On permadeath, character + map_memory deleted.
- Survival affects minimap detail per the four bands (0-29 / 30-54 / 55-79 / 80-100).
- Exit gate: same character revisits same floor, sees prior explored area pre-revealed.

#### 2f. Branches (4 branches × 3 floors) + essence rewards
- Branches: Sunken Crypt (Catacombs), Blackfen Swamp (Green Lair), Ice Caves (Orc Mines), Infernal Gate (Elven Halls). Shattered Abyss has no branch.
- 3 floors per branch (compressed from 4 for mobile). Final branch floor has no down-stairs, spawns boss.
- Branch clear grants essence: `essence_undeath`, `essence_plague`, `essence_glacial`, `essence_infernal`.
- ZoneManager logic recycled but rewritten as `ExpeditionZoneRules.branches_for(main_floor)`.
- Exit gate: enter branch from Catacombs gate, clear 3 floors, fight lich, receive essence_undeath in inventory.

#### 2g. Essence 3-slot system
- `scripts/systems/ExpeditionEssenceRules.gd` per `essence_system_rules.md`.
- 3 slots, unlock at expedition 1/6/14 (tracked in TownState). Carry cap 4.
- First pool: Fire / Ice / Swiftness / Vitality / Venom (normal); War / Stone / Ward (rare); Arcane / Gloam / Serpent / Undeath (unique).
- Every essence has a penalty. `merged_bonuses(character.essence_slots)` returns aggregated data keys consumed by Combat/Magic/Skill systems.
- Pair synergies: Fire+Arcane, Swiftness+Venom, Stone+Vitality, Gloam+Swiftness.
- Exit gate: equip essence in slot, see bonus + penalty applied, swap, replace.

#### 2h. Permadeath flow + town persistence
- On death: character entry removed from roster, map_memory deleted, but TownState (discovered branches, account flags, shop inventory progression) persists.
- New character creation flow accessible from town.
- Save scheme: TownState saved separately from active character. Character save deleted on permadeath; TownState save persists.
- Exit gate: die, return to title or town, create new character, see town progression preserved.

### Phase 3 — Simulator + balance + polish
- `scripts/tools/ExpeditionSimulator.gd` per `mobile_skill_balance_rules.md` §First Simulator Goals.
- Headless balance checks: melee vs 10 baselines, ranged vs 10, Magery vs 5, Defense survival, Lockpicking, Tracking, Survival.
- First balance targets per `mobile_skill_balance_rules.md` §First Balance Targets (10-15 expeditions: main 50-70; 30+: main 80-90).
- Polish: combat log readability, HUD adjustments, final tile selection for fixed maps per `fixed_map_layout_designs.md`.
- Merge to `main`.

---

## 4. Architecture map (post-rework)

```
Autoloads
  TurnManager        (kept)
  CombatLog          (kept)
  ItemRegistry       (kept)
  SpellRegistry      (kept)
  MonsterRegistry    (kept)
  RaceRegistry       (kept)
  TownState          (NEW — persistent town)
  ExpeditionState    (NEW — current expedition)
  ExpeditionSkillRules    (NEW)
  ExpeditionEssenceRules  (NEW)
  ExpeditionZoneRules     (NEW)
  FaithSystem        (DELETED)
  ClassRegistry      (DELETED)

scripts/main/
  Game.gd               (slimmed: dungeon-floor controller only)
  FloorLifecycle.gd     (extracted Phase 0)
  MonsterSpawner.gd     (extracted Phase 0)

scripts/town/
  Town.gd               (NEW)
  StarterShop.gd        (NEW)

scripts/systems/
  ExpeditionFixedLayoutDesigns.gd  (NEW — layout data)
  ExpeditionCharacterCreationRules.gd  (NEW — race-only + 120g)
  CombatSystem.gd       (rewritten per d100 formulas)
  MagicSystem.gd        (faith multipliers gone, Magery-based)
  Status.gd, FieldOfView.gd, RingSystem.gd, AoeEffects.gd  (kept)

scripts/ui/
  EffectsLayer.gd       (extracted Phase 0)
  TownUI.gd             (NEW)
  ExpeditionLaunchDialog.gd  (NEW — shows turn budget, area info)
  BagDialog.gd, ItemDetailDialog.gd, ...  (kept, faith/job refs cleaned)
  ShrineDialog.gd       (DELETED)
  JobSelect.tscn        (DELETED)

scripts/core/
  SaveManager.gd        (rewritten for split TownState/Character saves)
  SaveMigration.gd      (extracted Phase 0, extended Phase 2)
```

---

## 5. Save schema migration

Current `save_version: 4` is monolithic (one blob, missing branch state per C1 audit).

New scheme `save_version: 10` (jump to leave room) splits into two save targets:

**TownState save** (persistent, account-level)
- discovered_areas, unlocked_branches, town_inventory_progression, account_flags, character_roster (names + race + alive/dead)

**Character save** (per-character, deleted on permadeath)
- race_id, name, skills (9-skill d100), inventory, equipment, essence_slots, essence_inventory, map_memory[layout_id], expedition_count (for essence slot unlock gating)
- if in active expedition: ExpeditionState snapshot

**Migration v4 → v10:**
- Strip: faith_id, faith fields, selected_class_id
- Convert: old 16-skill ints → 9-skill d100 (sum buckets, normalize)
- Default: TownState empty (discovered_areas = [Catacombs only], expedition_count = 0, essence slots = 1)
- Inventory/equipment preserved with filter (any class-locked items become race-neutral)
- Branch state from C1 gap: dropped; player resumes in town

---

## 6. Risks and known unknowns

1. **Skill XP conversion ratio**: arbitrary. Plan must define explicit table. Erring low is safer than high (player can re-earn through play; over-grant breaks balance immediately).
2. **MagicSystem already had faith multipliers removed in PROJ_G** but `MagicSystem.gd` in PROJ_D still has them. Phase 1 cleanup is non-trivial; not a copy-paste from PROJ_G reference because PROJ_D MagicSystem may have diverged since the reference snapshot.
3. **Fixed layout authoring**: `fixed_map_atlas.svg` is the source of truth. Need to translate SVG landmark positions to actual tile coordinates. Plan must specify whether layouts are authored as `.tres` data, hand-written GDScript arrays, or generated from constrained MapGen seeds.
4. **Branch boss design**: 4 new bosses required (lich, serpent boss, glacial throne, tyrant). PROJ_D's existing monsters likely cover some; verify in plan.
5. **DCSS-name audit**: CLAUDE.md flags monster/god/unique names as trademark risk. Branch bosses must use names cleared of distinctive DCSS-isms.
6. **F5 smoke test definition will change after Phase 1**: from current "race → job → ..." to "race → name → starter shop → town → expedition." Plan must explicitly redefine the smoke path at each phase exit.
7. **i18n burden**: removing faith strings + adding town/expedition/9-skill strings doubles the i18n diff. Korean + English keep, no third language.
8. **Audit Phase 1 (refactoring_todo.md)** has work-in-progress that may conflict. Need to either complete or shelve it before Phase 0.
9. **`oldproject/` firewall** stays. Nothing from PROJ_G's `*.proj_d_reference.gd` files comes in either — those are PROJ_D snapshots, and we work from current PROJ_D code directly.

---

## 7. Verification at each phase gate

| Phase | F5 smoke flow | Headless check |
|---|---|---|
| 0 | race → job → walk → bump → autowalk → scroll → descend → ascend → die | `--headless --check-only` passes |
| 1 | race → (town stub) → dungeon stub → walk → descend → ascend → die → load | no `FaithSystem`/`JobSelect`/`ClassRegistry` greps in `scripts/` |
| 2a | race → name → starter shop (120g spent) → town | save/load town |
| 2b | town → expedition stub → fight → see new combat + 9-skill XP gain | XP table sanity |
| 2c | town → Catacombs (fixed layout, monsters vary visit-to-visit) | layout determinism (same seed = same walls) |
| 2d | expedition with budget → exhaust → safe-return roll → return | budget HUD always visible |
| 2e | revisit Catacombs → see prior map | map_memory persists across expedition |
| 2f | Catacombs → Crypt branch → 3 floors → lich → essence_undeath | branch boss spawn fixed |
| 2g | equip essence → see bonus+penalty → swap | merged_bonuses correctness |
| 2h | die → roster cleared → town persists → new character | TownState/Character save separation |
| 3 | full loop, 10-15 expedition simulator pass | balance targets met |

---

## 8. Out of scope (deferred to post-merge)

- Camp/rest mechanic mentioned in Survival rules
- Hunger reintroduction (explicitly removed from first pass)
- Lifestyle crafting skills
- Third language i18n
- Account-level meta progression beyond TownState (no roguelike-meta unlock tree)
- Mobile touch UI overhaul (use existing UI; mobile build remains a Phase-3+ concern)
- DCSS-name trademark audit pass (flagged in Risk 5, scheduled before ship not before merge)

---

## 9. Decisions to confirm with user before Phase 0 starts

1. **Branch name** for expedition rework. Recommended: `expedition-rework`.
2. **Phase 0 commits granularity**: one commit per extracted module (5 commits) vs one Phase 0 commit. Recommended: one per module so revert is granular.
3. **Save migration policy for in-progress runs**: migrate v4 saves into v10, or wipe and require new character? Recommended: migrate (keep player goodwill), accept that mid-run state becomes a town landing.
4. **MagicSystem faith multiplier removal**: do it in Phase 1 (with other faith removal) or pull forward to Phase 0 since it's a survivor-touching change? Recommended: Phase 1 (cohesive faith removal commit).
5. **Layout authoring format**: GDScript array literal vs `.tres` resource vs constrained MapGen seed. Recommended: GDScript array literal in `ExpeditionFixedLayoutDesigns.gd` (matches PROJ_G plan, easiest to diff in version control).
6. **Town starter character roster size**: 1 active character at a time, or multi-slot? PROJ_G docs don't specify. Recommended: 1 active, history of deaths kept as flavor.
