# scripts/ui — Player-facing surfaces

## What
Dialogs, HUD, popups, pickers, status/skills/magic/bag/bestiary surfaces. These render system state and capture input — they do **not** own state.

## Cardinal rule (CLAUDE.md root rule 5)
UI must not directly mutate system state and must not call `TurnManager.end_player_turn()`. Currently violated across most action callbacks (`ItemDetailDialog.gd:291-407`, `BagDialog.gd`, `QuickslotPicker.gd`).

The pattern target:
```
UI sends intent → System decides validity + turn cost → System updates state → System tells TurnManager
```

The current pattern:
```
UI calls player.set_equipped_*() → UI calls TurnManager.end_player_turn() → UI knows turn costs
```

When refactoring, prefer adding `Player.equip(slot, item_id)` style API that returns success and consumes the turn internally.

## Known issues from 2026-05-05 audit
- **H3** — `BagDialog._tab_filters` (line 69-71) omits `shield`, `wand`, throwing items, `essence`. Player tapping "Armor" tab loses sight of equipped shield → "I lost my item" reports. Fix: data-driven filter table with explicit kind whitelist per tab; add a "기타" tab.
- **H4** — `ItemDetailDialog` action callbacks capture `item_index` in closure. `player.items` mutates between dialog open and action fire (auto-use, identification, drop). Result: wrong item used or crash. Fix: refactor to entry-keyed API (`Player.use_item_by_entry(entry)`); UI captures the `entry` dict, not the index.
- **M11** — UI dialogs instantiate other UI dialogs (`Player.use_item` → `IdentifyPicker.open`). Reverse this: Player emits `identify_requested(item_id)`, Game.gd connects + opens picker. Removes UI ↔ Player cyclic dependency.

## BagDialog perf (audit M8)
`_populate` queue_frees + rebuilds 50+ Control nodes per refresh. Mobile GC pressure visible after frequent equip/use. Cache thumbnails (`_thumb_cache: Dictionary[String, Texture2D]`); only rebuild rows whose entry changed.

## Modification rules
1. New action callback → use entry-based API, not index.
2. New UI surface → consult system getters, never read internal fields.
3. Any "this turn ends a turn" decision lives in the system, not the UI.
4. Animations/effects are UI's, but spawning them on death/hit is the system's call.

## If you change X, also check Y
- `Player.items` mutation rules → all UI consumers using indices.
- New equipment slot → BagDialog tab filter + ItemDetailDialog action set + Player slot equip/unequip + audit P2 asymmetry.
- Tab filter → keep data-driven, do not embed kind list in two places.
