# PocketCrawl Scripts Module

## What
The `scripts` tree contains the active gameplay runtime for PocketCrawl. Responsibility is split between runtime orchestration, actor state, systems logic, dungeon generation, and player-facing UI scripts. This is the highest-risk modification area in the project.

## Major Areas
- `D:\PROJ_D\scripts\main` -> game loop orchestration, scene-level flow, event sequencing
- `D:\PROJ_D\scripts\entities` -> player, monsters, floor items, persistent runtime state objects
- `D:\PROJ_D\scripts\systems` -> combat, magic, progression, faith, essence, AI, item/spell registries
- `D:\PROJ_D\scripts\ui` -> dialogs, HUD, popups, status/skills/magic/bag presentation, bestiary surfaces
- `D:\PROJ_D\scripts\dungeon` -> map size, generation, tile logic, visibility/traversal support

## Critical Runtime Flow
- Start flow: title/menu -> race/class selection -> game scene start
- First major branch: early boss/shrine flow leading into faith selection
- Save/load: player state + systemic state normalization must stay aligned
- Combat loop: `Game.gd` event chain + `CombatSystem.gd` + `MagicSystem.gd`

## High-Risk Files
- `D:\PROJ_D\scripts\main\Game.gd`
  - very broad orchestration; avoid stuffing more unrelated logic here
- `D:\PROJ_D\scripts\entities\Player.gd`
  - progression, stats, equipment, HP/MP growth, skill state, save-facing data
- `D:\PROJ_D\scripts\systems\CombatSystem.gd`
  - large attack-resolution logic; prefer helper extraction before behavior edits
- `D:\PROJ_D\scripts\systems\MagicSystem.gd`
  - spell dispatch; keep family/group extraction clean
- `D:\PROJ_D\scripts\systems\FaithSystem.gd`
  - should be the authority for faith state, not the UI
- `D:\PROJ_D\scripts\ui\StatusDialog.gd`
  - major aggregation point for player-facing system visibility

## Modification Rules
1. If you change progression formulas, also update the relevant balance docs.
2. If you change faith or essence rules, also check shrine flow, state normalization, and status/bestiary/help text.
3. If you change player-facing systems, consider whether bag/status/skills/magic/bestiary text must change.
4. If you touch a giant file, prefer helper extraction before replacing behavior.
5. If state can be changed in both a system and a dialog, move authority toward the system.
6. If a system rule changes, follow `D:\PROJ_D\docs\doc_update_protocol.md` and update at least one durable doc before closing the task.

## If You Change X, Also Check Y
- If you change `Player.gd` growth rules or skill IDs, also check `Game.gd`, `CombatSystem.gd`, `MagicSystem.gd`, skill UI, race aptitudes, and balance docs.
- If you change `CombatSystem.gd`, also check ranged/tool/magic side interactions and kill-reward behavior.
- If you change `MagicSystem.gd`, also check targeting UI and spell description/help text.
- If you change `FaithSystem.gd`, also check shrine dialogs, early-boss flow, and save/load normalization.
- If you change `StatusDialog.gd`, keep the displayed rules aligned with runtime behavior.

## Known Structural Risks
- historical mixing of refactor and balance changes in one pass
- giant functions in `Game.gd`, `CombatSystem.gd`, `MagicSystem.gd`
- drift between docs and current runtime behavior
- repeated system explanations living only in chat instead of durable docs

## Recommended Workflow In This Module
1. identify the active rule from docs + code
2. classify task as refactor / feature / balance
3. implement narrowly
4. update player-facing text if needed
5. leave a durable handoff/refactor note
