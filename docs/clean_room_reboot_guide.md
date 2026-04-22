# Clean-Room Roguelike Reboot Guide

**Purpose**: This document captures the know-how gained from porting DCSS to
Godot 4 (PROJ_D) and distills it into guidance for starting a **new, clean-room
roguelike project** that can be released under any license (including
proprietary / commercial) without GPL obligations.

**Audience**: Future-me (Claude) starting a new project in a fresh session, or a
developer reading this directly.

---

## 0. Legal Firewall (read this first)

The entire PROJ_D codebase is a GPL v2+ derivative of DCSS. The new project
must NOT reuse any of:

- **Code** from `scripts/` — specifically `Beam.gd`, `FieldOfView.gd`,
  `SpellCast.gd`, `PlayerDefense.gd`, `Noise.gd`, `CombatSystem.gd`,
  `MonsterAI.gd`, `SpellRegistry.gd`, or any file that comments "port of
  crawl-ref/…" are DCSS-derived.
- **Data** from `assets/dcss_*/` — JSON files generated from DCSS source
  (monster_data.json, spells.json, zaps.json, branches.json, mutations.json,
  spellbooks.json, unrands.json).
- **Tiles** from `assets/dcss_tiles/` — even though most are CC0, they came
  through DCSS's repo and keeping them in the new project invites confusion;
  just pull fresh CC0 tiles directly from the upstream sources.
- **Resource files** under `resources/monsters/`, `resources/essences/`, or
  `resources/jobs/` that reference DCSS names / stats.
- **Names**: "Dungeon Crawl", "Stone Soup", "Crawl", DCSS god names (Zin /
  Makhleb / etc.), DCSS unique monster names (Sigmund / Fannar / Mnoleg /
  etc.), and specific DCSS uniqueartefact names (Wucad Mu / Cerebov /
  Asmodeus / etc.).

**OK to reuse** (not copyrightable):
- Roguelike genre conventions: grid-based movement, FOV, item identification,
  stairs between floors, inventory slots, turn-based combat.
- Common archetypes: Warrior / Mage / Rogue / Hunter, Fighter / Wizard,
  HP / MP / STR / DEX / INT.
- Algorithm ideas: BSP dungeon gen, Bresenham line, shadowcasting FOV,
  random-walk caves — these are algorithm concepts, not code.
- Own implementations of any mechanic inspired by DCSS (as long as code is
  written from scratch, not copied).

**Safer approach**: read roguelikedev wikis, Pixel Dungeon source (MIT-ish /
GPL — so don't copy that either), Brogue source (Apache-ish), RogueBasin
articles. Write your own code.

---

## 1. Project Setup

### Godot version
Use **Godot 4.3+**. 4.6 worked well in PROJ_D but was flaky on some static
vars; 4.3-4.4 is the sweet spot.

### Recommended project layout
```
ProjectName/
├── project.godot
├── scenes/
│   ├── main/
│   │   └── Game.tscn          # main in-game scene
│   ├── menu/
│   │   ├── MainMenu.tscn
│   │   └── JobSelect.tscn
│   ├── entities/
│   │   ├── Monster.tscn
│   │   ├── FloorItem.tscn
│   │   └── Player.tscn
│   ├── ui/
│   │   ├── BottomHUD.tscn
│   │   ├── TopHUD.tscn
│   │   └── GameDialog.tscn
│   └── dungeon/
│       └── DungeonMap.tscn
├── scripts/
│   ├── core/                   # GameManager / TurnManager / CombatLog / SaveManager
│   ├── dungeon/                # DungeonGenerator / DungeonMap / MonsterSpawner
│   ├── entities/               # Player / Monster / FloorItem
│   ├── systems/                # CombatSystem / MonsterAI / FOV / etc.
│   ├── ui/                     # dialogs, cards
│   └── fx/                     # SpellFX
├── resources/
│   ├── monsters/               # MonsterData .tres
│   ├── items/                  # ItemData .tres
│   └── classes/                # JobData .tres
├── assets/
│   ├── tiles/                  # CC0 sprites (see §8)
│   ├── fonts/
│   └── audio/                  # freesound.org CC0
└── docs/
```

### Autoloads (Project Settings → Autoload)
- `GameManager` — run state (depth, seed, gold, identified items)
- `TurnManager` — turn scheduler
- `CombatLog` — rolling message log
- `SaveManager` — user:// JSON read/write
- `TileRenderer` — tile lookup helpers (can be static class instead, see below)

### class_name vs autoload
**Prefer `class_name` static classes** for pure data lookups
(MonsterRegistry, ItemRegistry, etc.). Autoload only what holds run state.
This avoids the "autoload ordering" headaches PROJ_D had.

---

## 2. Data Model

### Monster data — one .tres per monster
```gdscript
# resources/monsters/MonsterData.gd
class_name MonsterData
extends Resource

@export var id: String = ""
@export var display_name: String = ""
@export var hd: int = 1                 # hit dice / difficulty
@export var hp: int = 10
@export var ac: int = 0
@export var ev: int = 5
@export var speed: int = 10             # 10 = normal, 5 = fast, 15 = slow
@export var attacks: Array = []         # [{type:"hit", damage:N, flavour:"fire"}]
@export var resists: Array = []         # ["fire", "cold2"]
@export var xp_value: int = 1
@export var tier: int = 1               # 1-5 difficulty band
@export var glyph_char: String = "?"
@export var glyph_color: String = "white"
@export var min_depth: int = 1
@export var max_depth: int = 25
@export var weight: int = 10            # spawn weight
@export var is_boss: bool = false
@export var essence_drop_id: String = ""
@export var tile_path: String = ""      # "res://assets/tiles/rat.png"
```

**DON'T** parse big JSON at runtime. Use `.tres` per monster. Godot loads
these quickly and you get editor preview / type safety.

**DO** author 20-30 monsters by hand rather than porting hundreds. Fewer,
better-balanced monsters > hundreds of near-duplicates.

### Item data
Similar pattern — one `.tres` per distinct item. Use `kind` field to route
behavior (weapon / armor / potion / scroll / wand / ring).

### Class data
One `.tres` per playable class. Fields: starting weapon, armor, HP/MP
deltas, starting skills (if any).

---

## 3. Core Systems (Build Order)

### Week 1 — playable loop

**Day 1**: Grid movement + FOV
1. `Player.gd` — grid_pos, HP, stats, try_move(delta)
2. `DungeonMap.gd` — grid rendering, wall/floor glyphs
3. `DungeonGenerator.gd` — simple BSP (rectangles connected by corridors)
4. `FieldOfView.gd` — shadowcasting (write from the RogueBasin article, not
   DCSS's los.cc)
5. Player moves, sees walls, bumps into them.

**Day 2**: Turn system + first monster
1. `TurnManager.gd` — `register_actor` / `end_player_turn` / iterates actors
2. `Monster.gd` — grid_pos, HP, take_turn() that moves toward player
3. Player bumps into monster → basic melee (random 1-6 dmg)
4. Monster dies when HP ≤ 0, player dies too.

**Day 3**: Items + pickups
1. `FloorItem.gd` — spawnable Node2D on a grid tile
2. Pickup on step-over (or explicit "pickup" button)
3. `Inventory` on Player — array of item dicts
4. First consumable (Healing Potion — use it from inventory dialog)

**Day 4**: Stairs + multi-floor
1. STAIRS_DOWN / STAIRS_UP tiles in DungeonGenerator
2. Step on stairs + confirm → regen dungeon at depth+1
3. `GameManager.current_depth` tracked

**Day 5**: Basic UI
1. HP/MP bars at top
2. Inventory dialog (tap to open, show items)
3. Combat log strip at bottom
4. End-run screen (died / victory)

### Week 2 — content
- 10-15 more monsters at various tiers
- 5-10 more items
- 3 playable classes with distinct starts
- Floor gen variations (caves vs rooms)
- Save/load via SaveManager

### Week 3 — polish
- Tile art integration (upgrade from ASCII to sprites)
- Sound effects
- Mobile touch UI
- Balance pass

---

## 4. UI Patterns (mobile lessons from PROJ_D)

### Dialog pattern
Single reusable `GameDialog` scene:
- CanvasLayer at layer 100
- Full-rect dimmer
- Centered PanelContainer with gold border
- ScrollContainer body
- Bottom full-width Close button
- ESC / outside-tap closes

Every popup (inventory, status, help, shop) uses this so the UX is
consistent and skinnable from one place.

### Quickslot
Bottom-HUD row of 4 quickslot buttons. Each:
- Tap to use (potion / scroll / wand / spell)
- Long-press to manage (reassign / clear)
- Shows item count badge ("Pot × 3")
- Empty slot shows "+"

Works well on phones — big tap targets, no nested menus for repeated-use
items.

### 2-tap targeting
For ranged spells / wands:
1. First tap on a tile = paint preview (AoE ring or beam path)
2. Second tap on SAME tile = commit
3. Tap elsewhere = move preview
4. Tap outside targeting = cancel

Avoids the "accidentally fired fireball at myself" disaster common with
single-tap.

### Sub-tabs for long lists
Magic / Quickslot / Skills dialogs got too tall. Sub-tabs with abbreviated
labels (CON / FIR / CLD / ERT / AIR for schools) scroll better on phone.

### Status dialog sections
Order that worked:
1. Race/class header + paperdoll
2. HP/MP bars + regen rate
3. Piety (if pledged)
4. Stats (STR/DEX/INT cards)
5. Combat (AC/EV/SH/ATK cards)
6. Active effects (haste / poison / etc.)
7. Equipment (weapon + body)
8. Rings / Amulet
9. Resistances (fire/cold/… with pips)
10. Trait / Mutations
11. Runes

---

## 5. Mobile Optimizations

### Camera
- Default zoom 4.0 (not 6.5 — PROJ_D hit that lesson mid-project)
- Pinch to zoom + persist in user://settings.json
- Camera follows player with a short tween (0.12s) so movement reads

### Touch input
- Big tap targets (≥48×48 dp)
- Movement: tap adjacent tile OR directional buttons OR swipe
- Long-press for auto-explore / inspect

### Map size
- 35×50 tiles feels right for mobile (PROJ_D settled here for Simple mode)
- Smaller = fewer wandering turns, more encounters per floor
- Portrait-friendly aspect ratio

### Font size
- Body text: 36pt (Godot unit, not CSS)
- Section headers: 48pt
- Button labels: 42-48pt
- Don't go below 30pt — unreadable on phone

### Color
- Tint by semantic meaning (damage red, heal green, mana blue)
- High contrast — pure #FFF on pure #000 for text

---

## 6. Balance Cheat Sheet

### Monster HP scaling
Tier 1 (early): 5-15 HP
Tier 2: 15-35
Tier 3: 35-80
Tier 4: 80-180
Tier 5 (boss): 200-500

### Player progression
- Start HP: 25-40 depending on class
- XL max: 20 (simpler than DCSS's 27)
- HP per XL: +5 base + STR/5
- Each XL = significantly more power → players feel growth

### Damage curves
- Early weapon damage: 3-6
- Mid: 8-14
- Endgame: 15-25
- Never let "true damage" (unblockable) exceed player HP / 3

### Monster speed
- Most: 10 (normal)
- Fast (bats, jackals): 5 (acts twice per player turn)
- Slow (naga, slugs): 14 (acts less often)
- Very fast (bat swarms): 2-3

### Item rarity
- Common (60% of drops): healing potions, weak scrolls, basic gear
- Uncommon (30%): enchantment scrolls, +0 magical gear, identify
- Rare (8%): multiple-use wands, strong scrolls, enchanted gear
- Epic (2%): artifacts, unique items

### Encounter density
- 8-15 monsters per floor at D1-5 (early game)
- 15-25 at D6-15 (mid)
- 10-20 at D16-25 (quality > quantity, harder mobs)
- Avoid "all 25 monsters visible at spawn" — feels unfair

---

## 7. Algorithm References (public domain)

### Shadowcasting FOV
Read: https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting
Implement yourself. Ours in PROJ_D came from DCSS = GPL-tainted.

### BSP dungeon gen
1. Start with a big rectangle
2. Recursively split into two sub-rectangles until size < threshold
3. Carve a smaller room inside each leaf
4. Connect rooms via corridors (pick random point in room A, random in B,
   draw an L-shape corridor)

### Random walk caves
1. Fill map with walls
2. Drop "drunks" (random walkers) that turn walls into floor
3. Run 30% fill ratio, then CA smooth 4-5 iterations

### Bresenham line
For beam path / ranged LOS. Standard algorithm, any textbook.

---

## 8. Asset Sources (CC0 / commercial-friendly)

### Tile art
- **Kenney 1-bit pack**: https://kenney.nl/assets/1-bit-pack — compact, works great for minimalist roguelike
- **Kenney Roguelike pack**: https://kenney.nl/assets/roguelike-caves-dungeon — larger, more detailed
- **OpenGameArt**: filter by CC0 — thousands of tilesets
- **Oryx Design Lab**: paid but very high quality, commercial license included
- **RLTiles (original)**: public domain, but DCSS uses heavily — prefer others to avoid confusion

### Sound effects
- **freesound.org**: filter by CC0
- **Kenney audio packs**: CC0, comprehensive
- **zapsplat.com**: free with account

### Music
- **incompetech.com** (Kevin MacLeod): CC BY 3.0 (must credit)
- **PlayOnLoop.com**: has royalty-free options

### Fonts
- **Google Fonts**: most are OFL 1.1 (free commercial use)
- **Pixel fonts for roguelike feel**: "Press Start 2P", "VT323", "Silkscreen"

---

## 9. Monetization Setup (if pursuing donations)

See `docs/monetization_notes.md` (to be written). Short version:
- Ko-fi for one-time support
- GitHub Sponsors for monthly
- itch.io "Pay what you want" build
- Release free + open source to build good-faith
- MIT license is safest (short, permissive, commercial-friendly)

---

## 10. Pitfalls I Hit in PROJ_D (don't repeat)

### Data architecture
- **Mistake**: Storing monster data in giant JSON loaded at startup. Slow,
  hard to edit, no editor preview.
  **Fix**: .tres per entity. Godot caches them cheaply.

### Autoload ordering
- **Mistake**: Autoloads referenced each other circularly → runtime errors
  on first load.
  **Fix**: Keep autoloads independent. Use `get_tree().root.get_node(...)`
  at usage time, not at _ready.

### Signal explosion
- **Mistake**: 50+ signals wired to one player node, some reconnected
  every floor → memory leaks + stale connections.
  **Fix**: Connect once in _ready. If you must reconnect, always disconnect
  first. Use `is_connected` guards.

### Float vs int damage
- **Mistake**: Mixed `float` damage rolls with `int` HP → occasional
  "0 damage" hits after a tiny roll got floored.
  **Fix**: Keep all damage as int. Explicit `int(round(...))` on the one
  place you compute fractional values.

### FOV performance
- **Mistake**: Recomputing FOV every frame during auto-move. Frame dropped.
  **Fix**: Only recompute on player move. Cache visible tiles dict.

### Button rebuild cost
- **Mistake**: Opening Bag dialog rebuilt 50+ child nodes every time,
  causing 1-frame stutter.
  **Fix**: Lazy build (only visible tab). Or keep the dialog alive and
  toggle `visible`.

### CanvasLayer nesting
- **Mistake**: Adding dialogs as children of another CanvasLayer — they
  rendered invisible (no error, no log).
  **Fix**: Attach dialogs to the scene root (Node2D), not nested layers.

### Unequip flow
- **Mistake**: Bag dialog only showed "Info" button on equipped items — no
  way to unequip without dropping + re-picking.
  **Fix**: Bag shows "Unequip" button on equipped slots from day 1.

### Monster count on surrounded
- **Mistake**: Player complained only one of four surrounding monsters
  attacked. Actually all four were attacking — just 3 missed due to high
  EV. Damage + miss log looked identical to "no turn taken".
  **Fix**: Show MISSES in combat log with distinct color. Label multi-hits
  clearly (e.g., "4 monsters attack (3 miss, 1 hits for 5)").

### Mobile viewport overflow
- **Mistake**: Dialog width based on fixed pixel count → overflowed on
  small phone screens.
  **Fix**: Use viewport-relative sizing. Cap at 92% of screen width.

### Over-engineered skills
- **Mistake**: Ported DCSS's 30-skill system. Mobile players never cared.
  **Fix**: 1 class = 1 identity. Growth through items + XL, not per-skill
  leveling. This is the Pixel Dungeon insight.

### Too many gods/items
- **Mistake**: Ported 26 gods + 120 unique artifacts before playtesting.
  **Fix**: 3-5 classes, 10-15 uniques, 1-2 "faction" systems (if any) for
  MVP. Add more only after playtesting proves the core loop.

---

## 11. Suggested Milestones for New Project

### Milestone 0: spike (1 day)
Playable grid movement, FOV, 1 monster, 1 weapon. ASCII rendering.

### Milestone 1: core loop (1 week)
- 10 monsters across 5 floors
- 5 item types (weapon / armor / potion / scroll / wand)
- Basic combat + item use
- Death / victory screen
- Save/load
- ASCII or minimal tiles

### Milestone 2: content (1 week)
- 20-25 monsters across 15 floors
- Class selection (3 classes)
- Identification system
- Tile art integrated (Kenney pack)
- Sound effects

### Milestone 3: polish (1 week)
- Mobile touch UI
- Sub-tabs for inventory
- Help screen
- Morgue / character dump
- Balance pass

### Milestone 4: release (1 week)
- Android export + sign
- itch.io upload
- Ko-fi / donation link
- GitHub repo public
- README + screenshots

**Total: 4 weeks to MVP release. Release early, iterate on feedback.**

---

## 12. What NOT to Add to v1

- Multiplayer
- Complex crafting
- Map editor
- 10+ classes
- Achievements system
- Season passes / DLC
- In-app purchases

Every item in this list killed indie roguelike projects. Add later if the
community asks; don't front-load.

---

## 13. Naming

Avoid: any DCSS term, "Crawl", "Rogue" (trademarked for card game), any
existing popular roguelike's name.

Safer structure:
- 2-syllable short name: "Delve", "Rune", "Drop"
- Compound: "CryptRunner", "RuneDelve", "StoneFall"
- Descriptive phrase: "Descent of the Seven Keys"

Check trademark database (USPTO) + Google before finalizing. Buy domain if
available.

---

## 14. First-Session Checklist (when I start the new project)

1. Create new Godot 4.3+ project in a fresh directory (NOT inside PROJ_D).
2. `git init` + GitHub repo.
3. Add LICENSE (MIT recommended) + README.md stub.
4. Project Settings: portrait 720×1280, autoload GameManager /
   TurnManager / CombatLog / SaveManager.
5. Create folder skeleton (§1).
6. Milestone 0 spike: grid, FOV, move, one monster — aim for playable in
   2 hours.
7. Commit at end of every hour with a meaningful message.
8. Don't touch art until Milestone 2. ASCII is fine for M0-M1.

---

This guide was distilled from ~8 weeks of work on PROJ_D (DCSS port).
The mistakes listed cost hours; avoiding them will let a new project reach
playable MVP in days instead of weeks.
