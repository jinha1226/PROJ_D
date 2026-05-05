# Godot Game Context Template

## Purpose
Use this template for Godot-based games, especially systems-heavy roguelikes, dungeon crawlers, RPGs, and mobile-first titles.

This template is intended for:
- root `CLAUDE.md`
- module-level `CLAUDE.md`
- durable project context for Codex and Claude

---

# 1. Root `CLAUDE.md` Template

```md
# <PROJECT NAME>

## Project Overview
<One short paragraph: what the game is, intended player fantasy, target reference games, platform, and current maturity.>

## Game Identity
- Closest reference: <DCSS / Pixel Dungeon / custom hybrid / etc>
- Current priority: <clarity / speed / depth / accessibility / faithful adaptation>
- Non-goals: <what this game is explicitly not trying to be>

## Tech Stack
- Engine: Godot <version>
- Language: GDScript / C# / other
- Data: <json/tres/res/custom>
- Target platform: <desktop/mobile/web>

## Active Runtime
```bash
<primary editor run path>
<primary headless/test command if any>
```

## Directory Map
```
scenes/              -> scene entrypoints and UI composition
scripts/             -> gameplay logic and systems
resources/           -> classes, monsters, items, spells, races, data assets
docs/                -> architecture, balance, handoff, runtime checklists
assets/              -> tiles, icons, audio, art sources
legacy/              -> inactive or archived content, if present
```

## Core Systems
- Progression: <skills / stats / xl / unlocks>
- Combat: <summary>
- Items: <summary>
- Build path: <faith / essence / classes / races / etc>
- Meta constraints: <save compatibility, mobile constraints, content scope>

## Cross-Cutting Rules
1. <critical repo-wide rule>
2. <current active design direction>
3. <save/load compatibility rule>
4. <how docs should be kept in sync>

## Verification Commands / Checks
- Parse/runtime check: <command or manual path>
- Important gameplay flows to verify: <list>
- If runtime unavailable, state that explicitly in handoff

## Forbidden / Caution Areas
- Do not mix refactor and balance changes unless planned.
- Do not change save schema casually.
- Do not assume old docs still reflect current gameplay.
- Do not patch giant functions repeatedly without considering extraction.

## Module CLAUDE.md Index
- `scripts/CLAUDE.md` -> systems, entities, event flow, risk areas
- `docs/balance/...` -> progression and economy rules
- `docs/refactoring_todo.md` -> current structural cleanup status

## Reference Docs
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/runtime_checklist.md`
- `docs/handoff.md`
- `docs/decision_log.md`
```

---

# 2. `scripts/CLAUDE.md` Template

```md
# Scripts Module

## What
<Short paragraph describing what lives under scripts and how responsibilities are split.>

## Major Areas
- `entities/` -> player, monsters, world actors
- `systems/` -> combat, magic, progression, faith, inventory, drops, AI
- `main/` -> game loop, scene orchestration, event flow
- `ui/` -> dialogs, overlays, panels, help text, status surfaces
- `dungeon/` -> map generation, tiles, traversal, visibility

## Critical Runtime Flow
- Game start: <scene / script path>
- First major player choice: <where it happens>
- Save/load entrypoints: <where>
- Combat loop entrypoints: <where>

## Rules For Modifying This Area
- If you change progression formulas, also update the balance docs.
- If you change a player-facing system, also update UI/help text.
- If you change stateful systems, check save/load paths.
- If you touch giant files, prefer helper extraction first.

## Key Files
- `scripts/main/Game.gd` -> runtime orchestration, event chain, map/monster/item lifecycle
- `scripts/entities/Player.gd` -> stats, skills, progression, equipment, save-facing player state
- `scripts/systems/CombatSystem.gd` -> attack resolution, damage, kill rewards, combat-side effects
- `scripts/systems/MagicSystem.gd` -> spell dispatch and magic-side effects
- `scripts/systems/FaithSystem.gd` -> faith state authority
- `scripts/ui/StatusDialog.gd` -> aggregated player/system presentation

## Known Risk Areas
- giant match/case dispatch in systems files
- duplicated HP/MP progression rules
- state transitions split between UI and systems
- docs drifting behind active runtime behavior

## If You Change X, Also Check Y
- If you change `Player.gd` progression, also check `Game.gd`, skill UI, and docs.
- If you change `FaithSystem.gd`, also check shrine flow, status UI, and save normalization.
- If you change `CombatSystem.gd`, also check ranged/tool/magic edge cases and kill rewards.
- If you change `MagicSystem.gd`, also check targeting UI and spell descriptions.
```

---

# 3. Recommended Durable Docs For Games

```md
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/runtime_checklist.md`
- `docs/handoff.md`
- `docs/decision_log.md`
- `docs/balance/<system>.md`
- `docs/refactoring_todo.md`
- `docs/ui_copy.md`
- `docs/legacy_map.md`
```

---

# 4. Recommended First Pass For Any New Game Project

Create:
1. root `CLAUDE.md`
2. `scripts/CLAUDE.md`
3. `docs/architecture.md`
4. `docs/conventions.md`
5. `docs/runtime_checklist.md`
6. `docs/handoff.md`
7. `docs/decision_log.md`

That gives AI enough structure to work safely on gameplay code, data, and docs.

---

# 5. Game-Specific Update Flow

When working with AI on a game project:
1. discover the active gameplay rule from code/docs
2. confirm whether the task is refactor, balance, or feature work
3. implement narrowly
4. update player-facing text if needed
5. leave a durable handoff or decision note

---

# 6. Quality Bar

A good game context doc should be:
- short enough to scan
- explicit about current game identity
- clear about where the truth lives
- focused on systems and runtime flow
- updated when repeated design confusion happens
```
