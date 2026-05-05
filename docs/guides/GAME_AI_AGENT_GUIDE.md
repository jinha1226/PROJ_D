# Game AI Agent Guide

## Purpose
This guide adapts the generic AI workflow into a game-development workflow, especially for Godot-based projects, systems-heavy roguelikes, and ongoing balance iteration.

The goal is to make coding agents consistently useful for:
- gameplay system design
- structured refactors
- UI/help text work
- data-driven balance iteration
- safe handoff between sessions and tools

## Core Principle
Treat AI as a gameplay implementation partner, not as a design oracle.

Good results come from:
- explicit active design direction
- separation of runtime code vs design docs
- narrow, verifiable code changes
- durable design notes
- clear distinction between refactor, balance, and feature work

## Recommended Tool Split

### Use Claude for
- class/faction/skill/faith design shaping
- balance framing and tradeoff analysis
- naming, wording, and UX copy
- determining whether a system fits the intended game identity
- deciding what should be documented before implementation

### Use Codex for
- codebase exploration with edits
- targeted refactors
- gameplay logic implementation
- UI/help text integration
- data table edits tied to repo files
- handoff docs, checklists, and implementation summaries

### Best combined workflow
1. Use Claude to decide the design direction.
2. Write the rule as a durable doc.
3. Use Codex to implement in small, verifiable steps.
4. Validate behavior and leave a handoff note.

## Golden Rules For Game Projects
1. Always identify the current game identity before changing systems.
2. Always separate refactor work from balance changes when possible.
3. Always decide whether a system is core, support, or experimental.
4. Always document reward timing, progression timing, and major player choices.
5. Always write UI-facing explanations for non-obvious systems.
6. Always prefer one source of truth for progression formulas and state transitions.
7. Always record first-order design decisions in durable docs.
8. Always keep tooltips, bestiary text, and system docs aligned.
9. Always note what could not be runtime-verified.
10. Always optimize for future sessions, not one-off fixes.

## Game-Specific Session Types

### 1. Orientation Session
Use when entering or resuming a game project.

Ask for or determine:
- active game identity and target reference game
- current core loop
- major systems currently in flux
- active scenes and runtime path
- save/load risk areas

### 2. Refactor Session
Use when code structure is the main problem.

Ask for:
- behavior-preserving extraction
- function/file responsibility cleanup
- clearer ownership boundaries
- explicit note of runtime-unverified changes

### 3. Balance Session
Use when changing numbers, drops, skills, or progression.

Ask for:
- target player experience
- what the current pain point is
- whether the change is global or local
- what docs/tables define the intended rule

### 4. Feature Session
Use when introducing a new mechanic.

Ask for:
- player-facing purpose
- when the player first sees it
- where its explanation lives
- how it interacts with save/load and existing progression

### 5. Handoff Session
Use when another AI or future session will continue.

Always capture:
- what changed
- why it changed
- what remains risky
- what docs must be read next

## Recommended Durable Docs For Game Projects
At minimum, keep these updated:
- `CLAUDE.md`
- `docs/architecture.md`
- `docs/conventions.md`
- `docs/runtime_checklist.md`
- `docs/handoff.md`
- `docs/decision_log.md`

Strongly recommended for systems-heavy games:
- `docs/balance/` notes
- `docs/domain_rules.md`
- `docs/legacy_map.md`
- `docs/ui_copy.md`
- `docs/refactoring_todo.md`

## High-Value Game Rules To Write Down
Promote these into docs early:
- skill responsibilities
- progression formulas
- faith/faction/alignment rules
- item/drop economy tables
- status effect and resistance definitions
- bestiary explanation rules
- first-boss / first-shop / first-major-choice flows
- save migration assumptions

## Refactor Rules For Godot Projects
1. Keep scene flow and system flow separate in docs.
2. Avoid mixing balance changes into pure extraction passes unless explicitly planned.
3. Prefer helper extraction before logic replacement in giant GDScript files.
4. Centralize state transitions for systems like faith, essence, progression, or inventory.
5. When UI strings are broken or duplicated, rebuild small sections instead of patching indefinitely.

## Balance Rules For Roguelikes / Dungeon Crawlers
1. Decide what the game is closer to before tuning: DCSS, Pixel Dungeon, or a custom middle ground.
2. Tie every reward system to a clear timing point.
3. Keep first major build choices explicit and memorable.
4. If a support system competes with a core system, either subordinate it or make the split explicit.
5. Explain every non-obvious system in UI text, not only in docs.

## UI / Help Text Rules
Whenever a system is added or changed, decide whether these need updates:
- skill descriptions
- item descriptions
- bestiary text
- faith/faction descriptions
- first-time help text
- status panel wording

If the player cannot infer the rule from play alone, write a tooltip or short explanation.

## Runtime Verification Standard
Do not end substantial game work without at least one of:
- engine parse check
- scene run check
- targeted manual runtime checklist
- explicit note that runtime verification was not possible

For gameplay systems, also record:
- what trigger was expected
- what screen or scene should expose it
- what save/load case may still be risky

## Knowledge Layers For Game Projects
Treat knowledge as three layers:

1. Raw sources
- code
- scenes
- balance tables
- scratch notes
- external reference games

2. Persistent wiki
- architecture notes
- balance docs
- handoff notes
- runtime checklists
- decision logs

3. Agent rules
- root `CLAUDE.md`
- module `CLAUDE.md`
- reusable templates
- implementation checklists

Promote repeated findings upward. Do not keep core game rules only in chat history.

## Minimal End-Of-Task Checklist
Before ending a game task, ask:
- What system was touched?
- Was this a refactor, a behavior change, or both?
- What screen or flow exposes the change?
- What was verified?
- What still needs runtime confirmation?
- Did we leave a durable note for the next session?

## Best Long-Term Habit
Whenever a game-system correction happens twice, turn it into one of:
- a `CLAUDE.md` rule
- a balance doc entry
- a runtime checklist item
- a UI/help text rule
- a refactoring todo note
