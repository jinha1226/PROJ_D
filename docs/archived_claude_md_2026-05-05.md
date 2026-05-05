# PocketCrawl

## Project Overview
PocketCrawl is a mobile-leaning dungeon crawler inspired primarily by Dungeon Crawl Stone Soup, but intentionally simplified into a smaller set of skills, classes, and high-impact progression choices. The current goal is to preserve DCSS-style build identity, consumable tension, and dangerous combat decisions while keeping the game readable and manageable on a compact UI.

## Game Identity
- Closest reference: DCSS first, with some Pixel Dungeon pacing/UX considerations
- Current priority: preserve DCSS-flavored build identity while simplifying for mobile readability
- Non-goals:
  - not a full DCSS clone
  - not a pure Pixel Dungeon-like gear escalator
  - not a content-complete traditional roguelike yet

## Tech Stack
- Engine: Godot
- Language: GDScript
- Data: `.tres`, `.json`, scene/script-driven runtime data
- Target platform: mobile-first with desktop development/testing

## Active Runtime
- Primary runtime: run the main Godot game scene/editor project
- Secondary runtime: headless/scripted checks where available
- Important note: if runtime validation is not possible in-session, record that explicitly

## Directory Map
```text
D:\PROJ_D\scenes        -> scene entrypoints, HUD, menus, dialogs
D:\PROJ_D\scripts       -> gameplay logic, entities, systems, UI scripts, dungeon generation
D:\PROJ_D\resources     -> classes, monsters, items, spells, races, balance-facing assets
D:\PROJ_D\docs          -> balance notes, handoff docs, refactor notes, design discussions
D:\PROJ_D\assets        -> tiles, icons, generated art, imported visuals
```

## Core Systems
- Progression: XL 20, skill max 9, split weapon/magic/defense skills, stats, class/race starting state, fighting-based HP growth
- Combat: melee, ranged, magic, tool support, status effects, encounter tension
- Build path: current direction is faith-based major choice, with an Essence-aligned alternate path under discussion
- Economy: consumables are intended to matter; drops and reward timing are a major design concern
- UI understanding: skill, item, faith, bestiary, and system help text are essential for player comprehension

## Cross-Cutting Rules
1. Always identify whether the current task is refactor, balance, or feature work before editing.
2. Do not let outdated docs silently override active runtime behavior; update durable docs after major changes.
3. Keep player-facing explanation in sync with mechanics when changing skills, faith, drops, or status systems.
4. Prefer central system authority over UI-owned state changes.
5. Save/load compatibility and migration concerns must be considered whenever progression or systemic state changes.
6. Follow `D:\PROJ_D\docs\doc_update_protocol.md` whenever design or system rules change.

## Verification Expectations
- Preferred: actual Godot runtime/scene verification
- Acceptable fallback: explicit runtime checklist + note of what could not be verified
- High-priority flows to verify after systemic changes:
  - start flow (race -> class -> run start)
  - first boss -> shrine/faith choice flow
  - essence acquisition/replacement flow
  - combat + kill rewards
  - save/load on changed state systems

## Forbidden / Caution Areas
- Do not mix pure refactor work with balance changes unless the task explicitly calls for both.
- Do not silently change save-facing player state shape without documenting it.
- Do not keep adding giant logic branches to `CombatSystem.gd`, `MagicSystem.gd`, or `Game.gd` when helper extraction is possible.
- Do not assume generated docs still reflect active design direction without checking recent runtime changes.

## Module Index
- `D:\PROJ_D\scripts\CLAUDE.md` -> script/module responsibilities, risk areas, modification rules
- `D:\PROJ_D\docs\balance\...` -> active balance/design docs and Claude handoff files
- `D:\PROJ_D\docs\refactoring_todo.md` -> current refactor progress and remaining structural work

## Reference Docs
- `D:\PROJ_D\docs\refactoring_todo.md`
- `D:\PROJ_D\docs\doc_update_protocol.md`
- `D:\PROJ_D\docs\balance\claude_code_balance_handoff.md`
- `D:\PROJ_D\docs\balance\claude_code_drop_table_handoff.md`
- `D:\PROJ_D\docs\balance\claude_code_essence_and_resistance_handoff.md`
- `D:\PROJ_D\docs\balance\claude_code_faith_and_essence_handoff.md`
- `D:\PROJ_D\docs\balance\claude_code_first_boss_shrine_faith_flow.md`
- `D:\PROJ_D\docs\balance\claude_code_ui_help_and_bestiary_handoff.md`

## Current Working Truths
- Active player-facing progression now uses XL 20 with skill max 9, while long-term balance targeting still references DCSS 27-scale internally.
- Active split skill model: fighting, unarmed, blade, hafted, polearm, ranged, spellcasting, elemental, arcane, hex, necromancy, summoning, armor, shield, agility, tool.
- The project has accumulated many new systems, so context must be established before implementation.
- Documentation is part of the implementation workflow, not an afterthought.
- Faith, essence, drops, and progression are active design areas and should be treated as high-volatility systems.
- When repeated confusion happens, the fix should be promoted into docs or CLAUDE rules rather than rediscovered in chat.
