# Shop & Gold System — Design Spec
**Date**: 2026-05-08  
**Status**: Approved

---

## Overview

Add a dungeon shop system (DCSS-style shop tile, purchase dialog) and a meaningful gold economy. Players earn gold from floor scatter, humanoid monster kills, and orc-mine treasure rooms, then spend it at randomly placed shops.

---

## 1. Gold Economy

### 1a. Floor Scatter
In `_spawn_items_for_floor(depth)`, spawn 1–3 `gold_pile` items on random walkable tiles.

Amount per pile: `randi_range(5, 10 + depth * 2)`
- Depth 1: 5–12g per pile
- Depth 10: 5–30g per pile
- Depth 18+: 5–46g per pile

### 1b. Humanoid Monster Gold Drop
Add `@export var gold_drop_max: int = 0` to `MonsterData.gd`.

In `CombatSystem._apply_player_kill_rewards()`: if `gold_drop_max > 0`, 30% chance to drop a gold pile at the monster's position.

Drop amount: `randi_range(gold_drop_max / 2, gold_drop_max)`

Values to set in .tres:
| Monster | gold_drop_max |
|---------|--------------|
| orc | 20 |
| orc_warrior | 35 |
| orc_wizard | 30 |
| orc_priest | 40 |
| (other humanoids as added) | 10–20 |

### 1c. Orc Mines Treasure Room (Floors 7–9)
In `_spawn_items_for_floor()`, when depth is in the orc_mines range (7–9):
- Pick one room (not the player spawn room, not the stairs room)
- Scatter 8–12 gold piles of 50–120g each
- Scatter 2–3 bonus items (equipment-weighted)

---

## 2. Shop Placement

### 2a. Frequency
Floors are grouped into 5-floor blocks: [1–5], [6–10], [11–15], [16–20].  
Each block has a **70% chance** of containing exactly one shop floor.  
The shop floor is chosen randomly within the block (excluding floor 1 and the final floor of each block so the player always has time to earn gold before reaching the shop).

**Special shop**: 15% of shops that spawn are "rare shops" (sell randarts + high-tier consumables).

### 2b. Shop Tile
Add `SHOP = 7` to `DungeonMap.Tile` enum.

Rendering:
- Glyph: `$` in gold color
- Tile image: `res://assets/tiles/individual/dngn/...` (use an appropriate existing asset or a colored floor tile)

Placement: one `SHOP` tile placed at the center of a randomly chosen room on the designated floor (not the player spawn room, not the stairs room).

### 2c. State Storage in Game.gd
```
var _shop_items: Array = []         # Array of {item: ItemData, price: int, sold: bool}
var _shop_is_special: bool = false
```
Generated once when the floor is created. Persists through re-visits on the same floor. Cleared on floor transition.

Floor cache: `_shop_items` and `_shop_is_special` are included in the floor cache dict so revisits after branch returns preserve shop state.

---

## 3. Shop Inventory Generation

### 3a. Normal Shop (4–6 items, mixed)
Pick from: weapon, armor, potion, scroll, book (partial), spellpage.

Rough distribution per roll:
- 25% potion
- 20% scroll
- 20% equipment (weapon/armor/ring/amulet/shield)
- 20% book (partial, see §4)
- 15% spellpage (see §4)

### 3b. Special Shop (3–4 randarts + 1–2 consumables)
- Randarts: `ItemRegistry.roll_randart(depth)` for each slot
- Consumables: high-tier potion or scroll

### 3c. Pricing
`_shop_price(item: ItemData, is_randart: bool) -> int`:

| Tier | Consumable | Equipment | Randart |
|------|-----------|-----------|---------|
| 1 | 15g | 40g | — |
| 2 | 25g | 70g | — |
| 3 | 40g | 110g | — |
| 4 | 60g | 160g | 220g |
| 5 | 80g | 220g | 320g |

Books (partial, 2–3 spells): treated as consumable tier × 1.5.  
Full school books: treated as equipment tier × 1.5 (rare/expensive).  
Spellpages: consumable tier.

---

## 4. Spellbook System Overhaul

### 4a. Spellpage (`kind = "spellpage"`)
Single-spell item. Common drop on floors and in shops.

New .tres files for each spell that has a tile asset in `assets/tiles/individual/spell/`:
- fireball, fire_storm, chain_lightning, haste, stoneskin, sleep, polymorph (and others as available)

Fields:
```
kind = "spellpage"
grants_spell_id = "fireball"
tile_path = "res://assets/tiles/individual/spell/fireball.png"
tier = <spell level>
effect = "study"
```

### 4b. Partial Books (dynamic, common)
`ItemRegistry.generate_partial_book(depth) -> ItemData` creates a runtime `ItemData`:
- Pull all spells where `spell.tier <= depth` from a master spell pool
- Pick 2–3 at random (no duplicates, may cross schools)
- Set `grants_spell_ids` to the selected spell ids
- `display_name`: one of a small set of generic names ("worn spellbook", "scribbled notes", "dog-eared tome")
- `tile_path`: random colored book image from `assets/tiles/individual/item/book/`
- `tier` = average of selected spell tiers (rounded up)
- `id = "book_partial"` (runtime-only; item goes into player inventory as a normal item with `effect = "study"`, player reads it to learn the spells — same flow as existing books. The `grants_spell_ids` list is stored in the item entry dict so it survives save/load.)

**Spell pool**: defined in `ItemRegistry` as a list of `{spell_id, tier}` pairs covering all learnable spells. Spells not yet available as standalone (no tile asset) still appear in partial books.

### 4c. Full School Books (static .tres, rare)
Existing `book_fire.tres`, `book_cold.tres`, etc. remain unchanged.

Drop weight in `pick_floor_loot()`: reduce from current ~3% to ~1% (present but rare).  
In shops: full school books only appear in special shops.

### 4d. Floor Drop Integration
`pick_floor_loot()` updated:
- 3% → partial book
- 1% → full school book  
- 2% → spellpage  
(These come out of the misc category, keeping overall item density the same.)

---

## 5. ShopDialog UI

New scene: `scenes/ui/ShopDialog.tscn` + `scripts/ui/ShopDialog.gd`

### Layout
```
┌─────────────────────────────────┐
│ Shop              Gold: 142g    │
├─────────────────────────────────┤
│ [icon] potion of healing    15g │ [Buy]
│ [icon] scroll of ???        25g │ [Buy]  ← blue text (unidentified)
│ [icon] arming sword +0      70g │ [Buy]
│ [icon] fireball page        40g │ [Buy]  ← blue if not yet known
│ [icon] worn spellbook       55g │ [Buy]
│ [icon] chain mail           70g │ [Buy]
└─────────────────────────────────┘
```

### Identification Display Rules
- **White text**: `GameManager.is_identified(item.id)` is true OR item kind is equipment/book
- **Blue text**: potion/scroll/spellpage not yet identified by the player
- In-shop display: always shows **true name** regardless of identification status
- On purchase: `GameManager.identify(item.id)` called immediately → item enters inventory already identified

### Purchase Flow
1. Player taps [Buy]
2. Check `player.gold >= price` — if not, show "Not enough gold" flash, no action
3. `player.gold -= price`
4. `GameManager.identify(item.id)`
5. Add item entry to `player.items` (or `player.known_spells` for spellpage/book)
6. Mark `_shop_items[i].sold = true`
7. Refresh dialog + TopHUD gold

### Turn Cost
Opening/buying in the shop does **not** consume a turn. Stepping onto the shop tile costs one normal move action.

---

## 6. Movement Integration

In `Game.gd`, connect to `player.moved` signal (already exists).  
In `_on_player_moved(new_pos)`: if `map.tile_at(new_pos) == DungeonMap.Tile.SHOP`, call `_open_shop()`.

`_open_shop()`:
- If `_shop_items` is empty, generate shop inventory first
- Instantiate and show `ShopDialog`, pass `_shop_items`, `player`, `_shop_is_special`

---

## 7. Files Changed / Created

| File | Change |
|------|--------|
| `scripts/entities/MonsterData.gd` | Add `gold_drop_max: int = 0` |
| `resources/monsters/orc*.tres` | Set `gold_drop_max` values |
| `scripts/systems/CombatSystem.gd` | Drop gold on humanoid kill |
| `scripts/dungeon/DungeonMap.gd` | Add `Tile.SHOP = 7`, render, walkability |
| `scripts/main/Game.gd` | Shop placement, `_shop_items` state, `_open_shop()`, orc treasure room, floor scatter gold |
| `scripts/systems/ItemRegistry.gd` | `generate_partial_book()`, spell pool, spellpage in loot table, full book weight reduced |
| `scripts/ui/ShopDialog.gd` | New file |
| `scenes/ui/ShopDialog.tscn` | New scene |
| `resources/items/spellpage_*.tres` | New per-spell items (fireball, chain_lightning, haste, stoneskin, sleep, polymorph) |
| `scripts/entities/ItemData.gd` | No change needed (fields already exist) |
| `i18n/translations.csv` | Shop UI strings |
