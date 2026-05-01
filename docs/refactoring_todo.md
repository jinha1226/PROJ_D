# PocketCrawl Refactoring TODO

This document tracks the highest-priority refactoring work after the recent
skill, faith, essence, shrine, and balance-system additions.

The goal is not to redesign everything at once. The goal is to reduce
regression risk, centralize game rules, and make future balance work easier.

## Current Risk Summary

The project is currently functional, but a few systems have grown across too
many files at once:

- HP and progression rules are split across class setup, race growth, stats,
  skill leveling, and auto stat bumps.
- Faith and essence rules are spread across dialog code, player code, save
  logic, and multiple system helpers.
- Combat, magic, and monster AI each contain large monolithic functions that
  are hard to safely extend.
- Several player-facing UI panels still mix system logic, display formatting,
  and stale text handling.

These areas should be refactored before adding many more content-heavy systems.

## Refactoring Phases

## Progress Snapshot

Completed in current refactor pass:
- HP/MP gain helpers were centralized in `Player.gd`
- class/race setup now uses shared HP/MP helpers in `Game.gd`
- faith state authority was moved toward `FaithSystem`
- shrine dialog now applies faith through `FaithSystem.choose_faith()`
- load-time faith normalization was added
- first-boss shrine flow can now open a full faith-choice dialog directly
- first Essence reward now uses the real `Player.add_essence()` path
- first-boss shrine handling and monster essence-drop handling were split into
  dedicated helpers in `Game.gd`
- duplicated kill reward and shield-block logic in `CombatSystem.gd` was reduced
- `CombatSystem` now has player attack profile / hit / base-damage helpers, and
  `player_attack_monster()` has started moving onto those helpers
- `StatusDialog.gd` was rebuilt from scratch to remove corrupted text and
  mixed legacy formatting
- `MagicSystem.cast()` now delegates spell-effect dispatch to
  `_cast_effect(...)`
- `MagicSystem` spell dispatch is now grouped into damage / status / utility /
  buff families

Still pending:
- final HP growth model decision (`endurance`, strength scaling, race growth)
- removing the remaining fallback-style altar step dependency if direct choice
  becomes the only desired UX
- deeper `CombatSystem` decomposition
- deeper data-driven spell family split within `MagicSystem`

### Phase 1: Progression Model Cleanup

Priority: highest

Goal:
- define one consistent source of truth for HP, MP, stat growth, and skill
  effects

Main files:
- [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- [SkillsDialog.gd](D:\PROJ_D\scripts\ui\SkillsDialog.gd)
- [RaceData.gd](D:\PROJ_D\scripts\entities\RaceData.gd)
- class resources in [resources/classes](D:\PROJ_D\resources\classes)

Problems to solve:
- starting HP comes from class setup logic
- per-level HP comes from race growth
- strength can still affect HP
- endurance skill adds HP directly
- auto stat bump may also change HP

Target cleanup:
- define a single progression spec for:
  - starting HP
  - HP gain on XL
  - HP gain from skills
  - HP gain from stats
  - MP gain on XL
  - MP gain from magic systems
- move all derived stat recalculation into named helper functions instead of
  incremental mutation from many call sites

Recommended changes:
- add a single `recalculate_progression_stats()` or equivalent helper on
  `Player`
- reduce direct `hp_max += X` changes outside progression/equipment/status
  helpers
- centralize skill-on-level effects in one place
- document the final HP/MP model in code comments near the implementation

Open design questions:
- is endurance permanent in the final 6-skill model?
- does strength affect HP at all?
- is HP growth fully XL-based, or partly skill-based?

### Phase 2: Faith / Essence / Shrine Flow Cleanup

Priority: highest

Goal:
- make the first-boss shrine choice, faith state, and essence branch behave as
  one coherent system

Main files:
- [FaithSystem.gd](D:\PROJ_D\scripts\systems\FaithSystem.gd)
- [EssenceSystem.gd](D:\PROJ_D\scripts\systems\EssenceSystem.gd)
- [ShrineDialog.gd](D:\PROJ_D\scripts\ui\ShrineDialog.gd)
- [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)

Problems to solve:
- faith selection timing and shrine activation are not fully unified
- faith state is partially represented by strings and partially by side effects
- essence permission rules depend on both explicit faith and legacy empty-state
  handling
- shrine dialog currently owns some system mutations directly

Target cleanup:
- define a single faith state model:
  - no faith chosen yet
  - one of the four normal faiths
  - essence path
- define one authority for:
  - can use essence?
  - can choose shrine?
  - has first shrine choice happened?
  - what happens when switching or loading state?

Recommended changes:
- move faith-application side effects from dialog code into `FaithSystem`
- add explicit helpers such as:
  - `choose_faith(player, faith_id)`
  - `enter_essence_path(player)`
  - `can_use_essence(player)`
- let UI call systems, not mutate player state directly
- treat empty `faith_id` only as migration state, not ongoing gameplay state

Open design questions:
- is essence path a true fifth faith or a separate non-faith route?
- should first essence choice happen immediately on selecting Essence?
- should shrine choice happen on boss clear or on altar interaction?

### Phase 3: Combat Decomposition

Priority: high

Goal:
- break large combat functions into smaller rule-specific helpers

Main files:
- [CombatSystem.gd](D:\PROJ_D\scripts\systems\CombatSystem.gd)
- [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- [Monster.gd](D:\PROJ_D\scripts\entities\Monster.gd)

Problems to solve:
- one attack function currently handles too many responsibilities
- weapon category logic, faith multipliers, brands, backstab, and XP rewards
  are tightly coupled
- future work on tool skill, ranged rebalance, or faith bonuses will be risky

Recommended extraction points:
- weapon category and required skill mapping
- attack accuracy calculation
- raw damage calculation
- post-hit special effects
- on-kill rewards and XP distribution
- unaware/backstab logic

Suggested target structure:
- `compute_attack_profile(...)`
- `roll_hit(...)`
- `compute_damage(...)`
- `apply_hit_effects(...)`
- `apply_kill_rewards(...)`

### Phase 4: Magic System Decomposition

Priority: high

Goal:
- reduce the size of the central spell dispatch function and make spell effects
  easier to add safely

Main files:
- [MagicSystem.gd](D:\PROJ_D\scripts\systems\MagicSystem.gd)
- spell data resources
- [MagicDialog.gd](D:\PROJ_D\scripts\ui\MagicDialog.gd)

Problems to solve:
- spell behavior is mostly controlled through large string matches
- spell rules, target rules, damage rules, and UI assumptions are mixed
- balance changes require editing large switch-style logic

Recommended refactor direction:
- split spells by effect family:
  - bolt/projectile
  - blast/aoe
  - summon
  - status/debuff
  - blink/mobility
  - self-buff
- add helper methods for each family
- keep `cast()` as orchestration, not full behavior implementation

Open design questions:
- should schools remain flavor-only, or affect behavior tables later?
- should spell range/cost modifiers live entirely in `FaithSystem` and player
  stats helpers?

### Phase 5: Monster AI Data-Driven Cleanup

Priority: medium-high

Goal:
- make AI behavior more data-driven and reduce monster-id-specific branching

Main files:
- [MonsterAI.gd](D:\PROJ_D\scripts\systems\MonsterAI.gd)
- [MonsterData.gd](D:\PROJ_D\scripts\entities\MonsterData.gd)
- monster resources in [resources/monsters](D:\PROJ_D\resources\monsters)

Problems to solve:
- AI contains many hardcoded monster id checks
- boss logic, ranged logic, support logic, and status logic are intertwined
- adding a new monster often means adding more special-case code

Recommended refactor direction:
- move more intent flags into `MonsterData`
  - `is_boss`
  - `ai_style`
  - `preferred_range`
  - `special_ability`
  - `charge_attack_type`
- keep shared AI routines in code
- reduce ID comparisons where possible

### Phase 6: UI Text / Tooltip / Encoding Cleanup

Priority: medium-high

Goal:
- make the systems readable to players and remove stale or broken text output

Main files:
- [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)
- [SkillsDialog.gd](D:\PROJ_D\scripts\ui\SkillsDialog.gd)
- [BagDialog.gd](D:\PROJ_D\scripts\ui\BagDialog.gd)
- [BestiaryDialog.gd](D:\PROJ_D\scripts\ui\BestiaryDialog.gd)
- [ShrineDialog.gd](D:\PROJ_D\scripts\ui\ShrineDialog.gd)

Problems to solve:
- some text still contains mojibake or stale formatting artifacts
- important systems are implemented, but their explanations are inconsistent
- system text and logic formatting are mixed in the same methods

Recommended changes:
- remove corrupted strings first
- centralize short descriptions where practical
- make skill, faith, item, and monster explanations consistent with current
  systems

## Immediate File-Level TODOs

### [Player.gd](D:\PROJ_D\scripts\entities\Player.gd)
- unify HP/MP recalculation flow
- isolate endurance effects from generic skill XP code
- reduce direct mutation of derived stats from many places
- consider extracting:
  - progression helpers
  - inventory item effect helpers
  - essence/stat recalculation helpers

### [Game.gd](D:\PROJ_D\scripts\main\Game.gd)
- reduce responsibility in class application and spawn initialization
- move faith/shrine progression logic into dedicated systems
- split save/load migration concerns from core runtime logic

### [FaithSystem.gd](D:\PROJ_D\scripts\systems\FaithSystem.gd)
- become the single authority for faith state and faith-derived modifiers
- stop relying on empty-string gameplay semantics after migrations

### [EssenceSystem.gd](D:\PROJ_D\scripts\systems\EssenceSystem.gd)
- separate:
  - effect application
  - passive queries
  - resonance logic
  - inventory capacity rules
- normalize interactions with faith restrictions

### [CombatSystem.gd](D:\PROJ_D\scripts\systems\CombatSystem.gd)
- split attack resolution into smaller helpers
- isolate balance constants near the relevant logic

### [MagicSystem.gd](D:\PROJ_D\scripts\systems\MagicSystem.gd)
- replace giant effect dispatch with grouped handlers
- make spell family behaviors easier to audit and tune

### [MonsterAI.gd](D:\PROJ_D\scripts\systems\MonsterAI.gd)
- move repeated boss/behavior checks into data tags where possible
- separate ranged, caster, support, and boss routines

### [StatusDialog.gd](D:\PROJ_D\scripts\ui\StatusDialog.gd)
- remove broken strings and encoding damage
- split rendering helpers by section:
  - stats
  - equipment
  - faith
  - essence
  - resonance

## Suggested Execution Order

1. progression cleanup
2. faith / essence state cleanup
3. shrine first-boss event cleanup
4. combat decomposition
5. magic decomposition
6. monster AI cleanup
7. UI text and tooltip pass

## Do Not Refactor Yet

Avoid large rewrites of these areas until the progression and faith models are
stable:

- full item economy rewrite
- full resist-system rewrite
- wide monster roster rebalance
- final tooltip wording pass
- large new content additions

## Success Criteria

This refactor pass is successful if:

- HP and MP sources are explainable in one short paragraph
- first shrine / faith / essence behavior has one clear flow
- combat and magic can be changed without editing giant functions every time
- status and skill screens explain the current rules without corrupted text
- adding one new monster, one new spell, or one new faith perk no longer feels
  risky
