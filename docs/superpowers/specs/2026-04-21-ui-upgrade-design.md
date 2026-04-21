# UI Upgrade Design — Dialog Unification, Cards, ACTIVE Split

Date: 2026-04-21
Scope: `scripts/core/GameBootstrap.gd` dialogs + new `scripts/ui/` modules.

## Problems

1. **Skills ACTIVE tab is sticky** — ACTIVE currently filters `training=true OR level>0`. Unchecking a skill leaves its row visible because `level>0` still matches. No rebuild triggers on toggle either, so the checkbox state doesn't visually update.
2. **Inconsistent window UX** — Status window uses attribute cards and gold section headers, but Bag / Skills / Magic / Map are flat VBoxes. Important values blend with body text.
3. **Double close buttons** — Dialogs built on `AcceptDialog` inherit its top-right OK button. Some dialogs add a full-width "Close" button at the bottom, yielding two close affordances with different styling.

## Goals

- Every dialog uses one consistent "big bottom Close" close affordance.
- Bag / Skills / Magic / Map get section headers and selective cardification for important highlights.
- Small info popups (item info, skill info, god guide, quickslot assign) get the same unified chrome (border / rounded / gold title) but no internal card restructure.
- Skills ACTIVE tab splits into `Training` (`training=true`) and `Learned` (`level>0 AND training=false`) sub-sections; toggling reshuffles immediately.

## Non-goals

- No animation/tween changes beyond what is necessary for parity.
- No new screens or gameplay features.
- Tab swipe behaviour in Skills/Bag stays as-is.
- Status window internals stay as-is *beyond* removing its duplicate top close button.

## Architecture

### Component 1 — `scripts/ui/GameDialog.gd` + `scenes/ui/GameDialog.tscn`

A reusable popup that replaces every `AcceptDialog` usage. `CanvasLayer` so it floats above the UI without reparenting into the viewport tree.

```
CanvasLayer (GameDialog)
  Dim: ColorRect (fullscreen, 0.6 alpha black, blocks input)
    Window: PanelContainer (centered, custom size, GameTheme panel style)
      Margin: MarginContainer (16px)
        VBox:
          TitleRow: HBoxContainer
            TitleLabel: 52pt gold (from UICards.section_header semantics)
          Body: ScrollContainer
            BodyVBox: VBoxContainer (consumer-populated)
          CloseButton: Button
            custom_minimum_size = (0, 96)
            font_size = 40
            text = "Close"
            size_flags_horizontal = SIZE_EXPAND_FILL
```

**Public API**

```gdscript
class_name GameDialog
extends CanvasLayer

signal closed

static func create(title: String, size: Vector2i) -> GameDialog
func body() -> VBoxContainer        # container to populate
func set_close_text(text: String) -> void  # default "Close"
func set_on_close(cb: Callable) -> void    # pre-close hook
func close() -> void                # idempotent; emits `closed`
```

**Close paths** (all route to `close()`):
- CloseButton pressed
- Click on Dim outside the Window rect
- `ui_cancel` input action (ESC / back button)
- External caller: `dlg.close()`

### Component 2 — `scripts/ui/UICards.gd`

Static helpers for the card / section vocabulary currently inlined in Status.

```gdscript
class_name UICards

static func section_header(text: String) -> Label
# 52pt, Color(1.0, 0.85, 0.40), self-returning Label

static func card(tint: Color) -> PanelContainer
# PanelContainer with StyleBoxFlat:
#   bg_color = Color(tint.r * 0.15, tint.g * 0.15, tint.b * 0.15, 0.8)
#   border_color = tint, border_width = 3
#   corner_radius = 6
#   content_margin_{left,right} = 16, _{top,bottom} = 12

static func accent_value(text: String, size: int = 42) -> Label
# 42pt (configurable), gold Color(0.85, 0.72, 0.30)

static func dim_hint(text: String) -> Label
# 34pt, modulate Color(0.78, 0.78, 0.85)

static func pill(text: String, tint: Color) -> Control
# Small rounded tag for school badges (Magic dialog)
```

Refactor `_status_attr_card` / `_status_section_header` inside `GameBootstrap.gd` to call the `UICards` helpers so there is one source of truth for these styles.

## Task 1 — Skills ACTIVE tab split

### Current code path
`GameBootstrap._open_skills_dialog(category)` rebuilds the whole dialog on tab change (`_on_skills_tab` calls `queue_free` + `_open_skills_dialog(cat)`).

### Changes
- `_build_skill_rows(container, state)` helper that, **when `category == "active"`**, iterates SKILL_IDS **twice**:
  1. Add `section_header("Training")` → rows where `training == true`.
  2. Add `section_header("Learned")` → rows where `level > 0 AND training == false`.
  3. If both empty, add the existing empty-state hint.
- `_on_skill_training_toggled` after `set_training` re-calls `_open_skills_dialog(_skills_swipe_category)` **only if the currently open tab is `active`**. This gives the promised reshuffle without a cheap no-op rebuild elsewhere.

### Acceptance
- Open dialog on ACTIVE with one trained Axe at Lv 3.
  → header "Training" → Axe row. No "Learned" header.
- Uncheck Axe.
  → header "Training" hidden (empty). header "Learned" shown → Axe row (untrained).
- Check Axe again.
  → Axe moves back under "Training".
- Switch to another tab and back to ACTIVE — same layout.

## Task 2 — Cardification of big-4 dialogs

Small info popups get the unified GameDialog chrome and nothing else. The big-4 get:

### Bag (`_on_bag_pressed`)
- Top row: "Equipped" card grid (4 cards: Weapon / Body / Ring 0+1 / Amulet). Each card shows icon + name + accent stat.
- Tab body: section header = category name, item rows below.
- No per-row card wrapper (density matters).

### Skills (`_open_skills_dialog`)
- ACTIVE tab: two sections (Task 1 above).
- Non-active tabs: one section header per category label.
- Skill rows as-is (checkbox + name + level + xp bar).

### Magic (`_open_magic_dialog`)
- Two section headers: "Known Spells" and (if any in memory) "Memorised".
- Each row: school pill badges (left), spell name, power/fail as accent_value.
- School pills use per-school DCSS-canonical colours (fire=orange, cold=cyan, earth=brown, air=sky, necro=purple, hex=violet, conj=white, trans=mint, sum=green, charms=pink, poison=green-yellow).
- Keep MP cost readout.

### Map (`_open_map_dialog`)
- Section "Current Floor" with accent_value for floor depth + branch name.
- Section "Legend" — card with a small grid of glyph → meaning (stairs up/down, altar, shop, trap).

### Acceptance
- Visually distinct gold section headers in all four.
- Equipped card grid in Bag shows current player loadout at a glance.

## Task 3 — Close button / dialog unification

### Replace AcceptDialog at these call sites
Enumerated by audit of `GameBootstrap.gd` (AcceptDialog.new occurrences):
1. Bag — `_on_bag_pressed`
2. Skills — `_open_skills_dialog`
3. Status — `_on_status_pressed` (remove the manually-added bottom Close; GameDialog provides it)
4. Magic — `_open_magic_dialog`
5. Map — dialog built inside `_on_minimap_pressed`
6. Shop — `_open_shop_dialog`
7. Altar pledge — relevant function in `_on_altar_stepped` or similar
8. Essence invoke — relevant function around existing `_invoke()`
9. Identify picker — around `_on_identify_pick`
10. Quickslot assign — around `_assign_quickslot_item`
11. Item info popup
12. Skill info popup
13. God guide popup (may already be a scene — if so skip)

Each replacement:
```gdscript
var dlg := GameDialog.create("Bag", Vector2i(900, 1100))
popup_mgr.add_child(dlg)
_populate_bag_body(dlg.body(), player)
dlg.set_on_close(func(): _bag_dlg = null)
_bag_dlg = dlg
```

### Shared close semantics
- Background click outside panel → close
- ESC / back button → close
- Full-width bottom "Close" → close
- Per-dialog state refs (`_bag_dlg`, `_skills_dlg`, etc.) cleared via `set_on_close`.

### Acceptance
- No dialog shows a second close button at the top.
- All dialogs have a full-width bottom "Close" 96px tall.
- Tapping outside any dialog closes it.
- `_close_all_dialogs` still works (call `close()` on any tracked GameDialog refs).

## Migration order

Each step independently testable. Do not start the next until prior step visually verified.

1. **Infra**: `GameDialog.gd/tscn` + `UICards.gd`. Build an isolated test scene to verify open / resize / close / body scroll.
2. **Status**: migrate `_on_status_pressed` to GameDialog. Refactor existing `_status_attr_card` / `_status_section_header` to use UICards. Remove the duplicate bottom Close (GameDialog supplies it). Reference point for the rest.
3. **Skills + ACTIVE split**: migrate + Task 1 logic. Verify hybrid flow end-to-end.
4. **Bag / Magic / Map**: migrate + Task 2 cardification.
5. **Remaining popups** (Shop, Altar, Essence invoke, Identify, Quickslot, info popups): migrate chrome only, no card internals.

## File changes summary

**New**:
- `scripts/ui/GameDialog.gd`
- `scenes/ui/GameDialog.tscn`
- `scripts/ui/UICards.gd`

**Modified**:
- `scripts/core/GameBootstrap.gd` — 10-12 dialog builders rewritten to return GameDialog; Status card helpers moved to UICards.

**Unchanged**:
- `scripts/ui/GameTheme.gd` — palette already fits; no edits.
- All non-dialog UI (HUD, quickslot widgets, minimap overlay).
- Gameplay systems, combat, monster AI.

## Risks

- **AcceptDialog semantic loss**: AcceptDialog auto-forwards `confirmed` / `canceled` signals. Migration audits each call site for code that listens on these — most use `dlg.queue_free` which becomes `dlg.close()`. Item-pick flows that resolve a value via signal need explicit callback wiring.
- **Modal stacking**: a few flows open one dialog from within another (shop → buy confirm). GameDialog is a CanvasLayer so z-order must be set explicitly on nested opens.
- **Signal disconnects on close**: `set_on_close` must clear outer refs before the node is freed to avoid the rebuild loop (`_bag_dlg` pointing at a freed node).

## Test plan

- Open each migrated dialog, verify single bottom Close, verify outside-tap / ESC close.
- Skills: train a skill, uncheck it, verify it moves to Learned. Re-check, verify it moves back to Training.
- Bag: pick up weapon, verify Equipped card updates.
- Status: open, verify existing content unchanged, no duplicate Close.
- Magic: cast a spell, verify school pills render with correct colours.
- Map: walk stairs, verify depth accent updates.
- Shop: buy one item, verify close path doesn't leak references (open shop twice, confirm clean state).
