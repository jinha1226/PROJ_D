# Mobile HUD Layout

## Current Layout
- **Top HUD**: compact vitals/minimap/status summary
- **Top item strip**: 4 auto-populated item slots directly under the top HUD
- **Bottom main row**: `custom quickslot x4 + AUTO/ATK + WAIT/REST`
- **Bottom menu row**: `Bag / Skill / Spell / Status`
- **Combat log**: 4 visible lines

## Top Item Strip
- Not manually bindable
- Auto-populates from the player's bag order
- Shows the first 4 usable inventory items
- Tap a slot to use that item immediately
- If item count reaches 0, it disappears on refresh

## Bottom Custom Quickslots
- Player-configurable
- Can bind consumables or known spells
- Tap: use/cast
- Long press: rebind
- Drag between slots: swap

## Context Buttons
- **AUTO / ATK**
  - Shows `AUTO` when no hostile is in sight
  - Shows `ATK` when a hostile is visible
- **WAIT / REST**
  - Shows `REST` when safe
  - Shows `WAIT` when hostiles are visible

## Design Goal
Keep the map area large while separating two interaction types:
- top strip = automatic bag consumables
- bottom strip = custom combat/build shortcuts and main menus
