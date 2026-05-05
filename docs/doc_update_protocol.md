# PocketCrawl Documentation Update Protocol

## Purpose
This document defines how documentation must be updated when game design, balance, progression, faith, essence, drop economy, or player-facing system rules change.

PocketCrawl is still in active development, so documentation must be treated as part of implementation rather than optional cleanup.

## Core Rule
Whenever a design change is made, update the durable document that matches the type of change before considering the task complete.

Do not leave major system changes only in:
- chat history
- commit messages
- temporary notes
- memory of what was discussed

## Update Flow
Use this order whenever a rule changes:

1. Code or design discussion reveals a new rule or a changed rule.
2. Update the most specific durable doc first.
3. If the rule will likely matter again, promote it upward into:
   - `CLAUDE.md`
   - `scripts/CLAUDE.md`
   - `runtime_checklist.md`
   - `decision_log.md`
4. If the change affects player understanding, also update help text / bestiary / item or system descriptions.
5. If runtime verification was not possible, record that explicitly in the task summary or handoff.

## Which Document To Update

### Update `docs/decision_log.md` when
- the game direction changes
- a system is kept/removed/reframed
- a major design tradeoff is resolved
- a reference-game alignment decision changes

Examples:
- introducing `tool`
- changing faith/essence relationship
- reducing resistance types
- changing when the first major build choice happens

### Update `docs/runtime_checklist.md` when
- a new runtime-critical flow is added
- a new regression-prone system appears
- a verification step becomes repeatedly necessary

Examples:
- first boss -> shrine choice flow
- new save/load-sensitive state
- new auto-move or visibility rule

### Update `CLAUDE.md` when
- the project-wide active truth changes
- a repeated confusion should become a top-level rule
- a major design direction becomes stable enough to be treated as baseline context

Examples:
- current target identity shifts
- faith becomes core progression
- essence becomes alternate path only

### Update `scripts/CLAUDE.md` when
- script responsibilities change
- a system authority moves
- a file becomes a known risk area
- repeated implementation mistakes need a module-level warning

Examples:
- `FaithSystem` becomes state authority
- `CombatSystem.gd` gains new helper structure
- `StatusDialog.gd` becomes a key aggregation surface

### Update `docs/balance/*.md` when
- numbers, formulas, drop tables, build roles, or economy structure change
- a Claude/Codex implementation handoff should reflect the new intended rule

Examples:
- drop economy change
- skill responsibility change
- faith passive/penalty redesign
- unique essence reward table change

### Update player-facing help docs/text when
- a system name changes
- a rule becomes less intuitive
- a player-facing choice becomes more important

Examples:
- skill descriptions
- item descriptions
- faith descriptions
- bestiary entries
- system glossary text

## Required Update Trigger Categories
If a task touches one of the following, check whether docs must be updated:

- skills
- progression formulas
- stats / HP / MP growth
- class identity
- race identity
- faith
- essence
- drop economy
- bestiary behavior
- UI explanation text
- save/load-sensitive state

## Minimum Documentation Rule
At least one durable document must be updated when a system rule changes.

If the change is broad, update:
- one specific system doc
- plus one high-level context doc

## Example Mapping

### Example: new faith structure
Update:
- `docs/decision_log.md`
- related `docs/balance/*handoff*.md`
- `CLAUDE.md`
- faith UI/help text if needed

### Example: drop table rebalance
Update:
- `docs/balance/claude_code_drop_table_handoff.md`
- `docs/runtime_checklist.md` if new verification steps are needed

### Example: refactor only, no rule change
Update:
- `docs/refactoring_todo.md`
- `scripts/CLAUDE.md` only if file responsibility or risk notes changed

## End-Of-Task Check
Before closing a substantial task, ask:
- Did the intended rule change?
- If yes, which durable doc now contains that rule?
- If the player needs to understand it, where is that explanation shown?
- If runtime was not verified, was that recorded?

## Practical Rule For Future Sessions
If the same explanation is likely to be needed again, it should not live only in chat.

Promote it into one of:
- `CLAUDE.md`
- `scripts/CLAUDE.md`
- `docs/decision_log.md`
- `docs/runtime_checklist.md`
- `docs/balance/...`
- UI/help/bestiary text guidance
