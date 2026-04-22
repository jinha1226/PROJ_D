# Clean-Room Roguelike Reboot Guide

**Purpose**: Self-contained bootstrap document for starting a new Godot 4
mobile roguelike project that can be released under any license (MIT /
proprietary / commercial). Distills 8 weeks of DCSS port work into actionable
design specs — follow this guide and the game will work.

**Audience**: A fresh Claude session in a new project directory, or a
developer picking up the reboot.

---

## 0. Legal Firewall (read first)

PROJ_D is GPL v2+ (DCSS derivative). The new project must NOT carry over:

- **Game-logic code**: `Beam.gd`, `FieldOfView.gd`, `SpellCast.gd`,
  `PlayerDefense.gd`, `Noise.gd`, `CombatSystem.gd`, `MonsterAI.gd`,
  `SpellRegistry.gd`, `SkillSystem.gd`, `DungeonGenerator.gd`,
  `DesParser.gd`, and the 15+ `*Registry.gd` files.
- **Data**: everything under `assets/dcss_*/`.
- **Tiles**: everything under `assets/dcss_tiles/`.
- **Resources** referencing DCSS: `resources/monsters/*.tres`,
  `resources/essences/*.tres`, `resources/jobs/*.tres`, `resources/races/*.tres`.
- **Names**: "Dungeon Crawl", DCSS god names, DCSS unique monster names,
  DCSS artefact names.

**OK to reuse** (not copyrightable ideas): grid movement, FOV, stairs,
inventory, turn-based, class archetypes, algorithm concepts (BSP,
shadowcasting, Bresenham).

---

## 1. UI Reuse Whitelist — files safe to copy from PROJ_D

Audited via grep. These 21 UI files are pure scaffolding with zero (or
trivial comment-only) DCSS dependencies. **Copy them directly** into the
new project's `scripts/ui/` + corresponding `scenes/ui/`:

### 1a. 13 files — completely clean (direct copy, no edits)

| File | Purpose |
|---|---|
| `GameDialog.gd` + `.tscn` | Popup chrome — CanvasLayer at z=100, dimmer, centered panel, scroll body, bottom Close. ESC / outside-tap closes. Every dialog in the game reuses this. |
| `SkillsScreen.gd` | Skill list viewport scaffolding (the underlying viewport, not DCSS skill names). |
| `BagTooltips.gd` | Inventory tooltip builder — icon stack + stat diff lines. Pure layout, no DCSS items. |
| `ResultScreen.gd` | End-of-run screen (victory / death with stats). |
| `BottomHUD.gd` + `.tscn` | Action bar — quickslot row + menu buttons. |
| `TopHUD.gd` + `.tscn` | HP/MP bars + location label + minimap thumbnail. |
| `QuickSlot.gd` + `.tscn` | Single quickslot button widget. |
| `SkillLevelUpToast.gd` | Pop-up toast when a skill levels up. |
| `ZoomController.gd` | Mobile pinch + wheel camera zoom, persists to `user://settings.json`. |
| `BuildVersionLabel.gd` + `.tscn` | Bottom-corner version stamp. |
| `PopupManager.gd` + `.tscn` | Popup lifecycle (stack, ESC routing). |
| `TouchScrollHelper.gd` | Touch-drag scroll assist for mobile ScrollContainers. |
| `GameTheme.gd` | Godot Theme builder (colors, fonts, button styles). |

### 1b. 5 files — keep code, strip DCSS labels/comments

| File | What to edit |
|---|---|
| `TouchInput.gd` | Strip "DCSS travel.cc" / "DCSS-faithful" comments. Keyboard mapping code itself is generic and fine. |
| `MainMenu.gd` | Rename "DCSS Tiles" / "Classic DCSS" button labels to your game's mode names. |
| `RaceSelect.gd` | Code is generic. Replace the DCSS 22-race list with your species roster. |
| `JobSelect.gd` | Code is generic. Replace `JOB_IDS` array with your class list. |
| `QuickStart.gd` | Code is generic. Replace `COMBOS` array with your recommended starts. |
| `TraitSelect.gd` | Code is generic. Replace `TRAITS_BY_JOB` dict with your trait table. |

### 1c. 3 files — keep code, replace dictionary values

| File | What to replace |
|---|---|
| `SkillRow.gd` | `SKILL_NAMES` dict — replace DCSS skill id → label map with your own. |
| `UICards.gd` | `SCHOOL_COLOURS` dict — replace magic-school color map with your category colors. |
| `MagicDialog.gd` | Rename "school" to "category" throughout; drop school-specific sub-tab logic. The tab/list skeleton stays. |

**Net**: ~95% of the UI layer is reusable. Skip the "rewrite scaffolding"
pain and focus on game logic.

### 1d. Files that must NOT be copied from PROJ_D

Everything under `scripts/systems/`, `scripts/entities/`, `scripts/dungeon/`,
and `scripts/core/` is either DCSS-derived or tightly coupled to DCSS
concepts. Rewrite from the design specs in §4.

### 1e. Data formats vs data content — legal nuance

**Copyright covers creative expression, not functional schemas.** Applied
to our data files:

**Safe to reuse (format = functional, not copyrighted)**:
- JSON structure like `{"by_id": {"<id>": {"hp": N, "speed": N}}}` —
  a functional data layout, not creative expression.
- Field names that are generic roguelike terms: `hp`, `ac`, `ev`, `speed`,
  `damage`, `tier`.
- Godot Resource class `@export var` field declarations are
  **close to safe** — they're method/structure, more functional than
  creative. See "grey-area caveat" below.
- Nested structure (id → stats → attacks array) — functional.

**Must replace (content = creative)**:
- Every specific `.tres` entry (Sigmund's stats, Singing Sword stats, etc.)
- Every JSON entry (the 667 DCSS monsters, 140 unrands, 400 spells).
- Display names, flavor text, descriptions.
- Drop chances, depth ranges, weight values for specific entities.
- Bundled collections (e.g., the roster of 26 gods, the 216 mutations).

**Grey-area caveat**: if your `MonsterData.gd` mirrors DCSS's `mon-data.h`
field-for-field (holiness / shape / habitat / intel / spells_book /
essence_drop_id / …), a strict reading could call it derivative. Safer:

1. Re-author the Resource class yourself, keeping only the fields your
   game uses.
2. Drop DCSS-exotic fields (`holiness`, `shape`, `habitat`, `intel`,
   `spells_book`, `essence_drop_id`) if they don't serve your mechanics.
3. Rename anything that reads like "this was copy-pasted from DCSS's
   header" into something your-game-specific (e.g., `intel` →
   `ai_style` with your own enum values).

### 1f. Workflow for reusing data formats

**Recommended process**:
1. Look at PROJ_D's `MonsterData.gd` / `ItemData.gd` / `ClassData.gd`
   as **spec reference** for what fields a game of this shape needs.
2. Write a fresh class in the new project with your curated field set
   (usually 60-80% of PROJ_D's fields are common-sense roguelike data;
   20-40% are DCSS-specific and can be dropped).
3. Never copy the `.tres` files — author new ones from scratch with your
   own monster/item/class roster.
4. JSON files: keep the schema shape (easier to reason about), fill with
   your content. Don't copy the DCSS JSONs and delete entries; start with
   empty object and add yours.

**Result**: data-layer rewrite costs ~2-3 days instead of 2 weeks
because the structural thinking is already done.

---

## 2. Project Setup

### Godot version
Godot **4.3+** (4.4 / 4.5 fine, avoid 4.6 — flaky on `static var`).

### Folder layout
```
ProjectName/
├── project.godot
├── LICENSE                     # MIT recommended
├── README.md
├── scenes/
│   ├── main/Game.tscn
│   ├── menu/ {MainMenu, JobSelect, RaceSelect, QuickStart}.tscn
│   ├── entities/ {Player, Monster, FloorItem}.tscn
│   ├── ui/ {GameDialog, BottomHUD, TopHUD, QuickSlot, PopupManager}.tscn
│   └── dungeon/DungeonMap.tscn
├── scripts/
│   ├── core/ — GameManager, TurnManager, CombatLog, SaveManager (autoloads)
│   ├── dungeon/ — MapGen, DungeonMap, MonsterSpawner
│   ├── entities/ — Player, Monster, FloorItem
│   ├── systems/ — CombatSystem, MonsterAI, FOV, SkillSystem, MagicSystem
│   ├── ui/ — dialogs + HUD (copy from whitelist)
│   └── fx/ — SpellFX, hit feedback
├── resources/
│   ├── monsters/ — MonsterData .tres (20-30)
│   ├── items/ — ItemData .tres (15-25)
│   ├── spells/ — SpellData .tres (optional — inline works too)
│   └── classes/ — ClassData .tres (3-5)
├── assets/
│   ├── tiles/ — Kenney pack or similar CC0
│   ├── fonts/
│   └── audio/ — freesound CC0
└── docs/
```

### Autoloads (Project Settings → Autoload)
- `GameManager` — run state (depth, seed, gold, identified[])
- `TurnManager` — turn scheduler
- `CombatLog` — rolling message log (signal + ~60 message history)
- `SaveManager` — user:// JSON read/write

---

## 3. Data Model

### MonsterData.gd (resource)
```gdscript
class_name MonsterData extends Resource
@export var id: String
@export var display_name: String
@export var tier: int = 1          # 1-5
@export var hp: int = 10
@export var hd: int = 1            # difficulty + XP scale
@export var ac: int = 0            # damage soak
@export var ev: int = 5            # dodge score
@export var speed: int = 10        # action energy drain
@export var attacks: Array = []    # [{damage:N, flavour:"fire"}]
@export var resists: Array = []    # ["fire", "cold-1" = vulnerable]
@export var min_depth: int = 1
@export var max_depth: int = 25
@export var weight: int = 10       # spawn weight
@export var xp_value: int = 1
@export var is_boss: bool = false
@export var tile_path: String = ""
```

### ItemData.gd
```gdscript
class_name ItemData extends Resource
@export var id: String
@export var display_name: String
@export var kind: String            # "weapon" | "armor" | "potion" | ...
@export var tier: int = 1
@export var tile_path: String = ""
# Weapon
@export var damage: int = 0
@export var delay: float = 1.0
@export var category: String = ""   # "blade", "blunt", "ranged"
# Armor
@export var ac_bonus: int = 0
@export var ev_penalty: int = 0
@export var slot: String = ""       # "body", "helm", "boots", ...
# Potion / scroll
@export var effect: String = ""     # "heal", "identify", "upgrade", ...
@export var effect_value: int = 0
@export var description: String = ""
```

### ClassData.gd
```gdscript
class_name ClassData extends Resource
@export var id: String
@export var display_name: String
@export var description: String
@export var starting_hp: int = 30
@export var starting_mp: int = 5
@export var starting_str: int = 8
@export var starting_dex: int = 8
@export var starting_int: int = 8
@export var starting_weapon: String = ""
@export var starting_armor: String = ""
@export var starting_skills: Dictionary = {}  # {skill_id: level}
@export var starting_spells: Array = []
@export var passive: String = ""    # "warrior_hp_regen", etc.
```

---

## 4. Core Game Systems — Design Specs

Implement each in order. Each spec is self-contained.

### 4.1 Turn System + Energy

**Concept**: DCSS-style energy economy. Each actor has an `_energy` counter.
Every game tick adds `speed` to each actor's energy. When it reaches 100,
the actor spends energy to take actions (move costs 100, attack costs 100,
etc.). Faster monsters (speed > 10 equiv) act more often.

**Simpler variant (recommended for MVP)**: every turn, player acts, then
every live monster acts once. Speed is baked in via action cost (fast
monsters get two actions per player turn).

**TurnManager.gd** (autoload):
```
signal player_turn_started
signal monster_turn_ended
var turn_number: int = 0
var is_player_turn: bool = true
var actors: Array = []

func register_actor(a)              # monster calls on _ready
func unregister_actor(a)            # monster calls on death
func end_player_turn()              # player calls after any action
  - set is_player_turn = false
  - emit monster_turn_started
  - for each actor: actor.take_turn()
  - emit turn_ended
  - call_deferred("start_player_turn")  (defer to avoid stack blowup)
func start_player_turn()
  - turn_number += 1
  - is_player_turn = true
  - emit player_turn_started
```

**Reentrancy guard**: flag `_ending_turn` so recursive end_player_turn calls
(from signal handlers) are ignored. Hit this in PROJ_D.

### 4.2 Dungeon Generation

Two generator styles. Pick per floor (or per "zone") to give variety.

#### 4.2a BSP (rooms + corridors)

**Concept**: recursively split a rectangle into two until leaves are small.
Carve a room in each leaf. Connect rooms with L-shape corridors.

**Algorithm**:
1. Start with full map as one rect (say 35×50).
2. Recursively split each rect:
   - Stop if width×height < 80 OR depth > 4.
   - Pick split axis (horizontal if rect is taller, else vertical; random near square).
   - Pick split point at 40-60% of the axis.
   - Create two children.
3. At each leaf, carve a room:
   - Pick a rectangle inside the leaf, padded by 1-2 tiles from edges.
   - Size: 4-8 wide × 3-7 tall (within leaf bounds).
   - Set tiles to FLOOR.
4. Connect siblings:
   - For each non-leaf node, connect centers of its two children via an
     L-corridor (one horizontal run + one vertical run).
   - Carve corridor tiles to FLOOR.
5. Fill remaining map with WALL.

**Key numbers**: min room 4×3, max 8×7. Leaf stop size 80 area.

**Result**: tight rooms joined by 1-tile corridors. DCSS-like.

#### 4.2b Cellular automata caves

**Concept**: randomly fill, then smooth.

**Algorithm**:
1. Fill map: each tile 45% WALL, 55% FLOOR.
2. Force borders to WALL.
3. Smooth for 4 iterations:
   - For each tile, count WALL neighbors (8-way).
   - If tile is WALL and wall-count ≥ 4 → stay WALL, else FLOOR.
   - If tile is FLOOR and wall-count ≥ 5 → become WALL, else stay FLOOR.
4. Flood-fill from center; keep only the largest connected region.
   Fill all other tiles with WALL.

**Result**: organic cave-like shapes with irregular walls. Good for
"wild" zones.

#### 4.2c Entity placement (after map carved)

1. Pick spawn_pos: center of largest room (or BFS-picked floor tile).
2. Pick stairs_down: floor tile farthest from spawn_pos (BFS distance).
3. **Reachability check**: BFS from spawn; if stairs_down isn't reachable,
   carve a straight-line corridor. Guarantees playability.
4. Place **monsters**: roll 8-25 based on depth (early: 8-15, mid: 15-25).
   - For each: random floor tile ≠ spawn_pos.
   - Use MonsterRegistry to pick id by depth + weight.
5. Place **items**: roll 3-8.
   - 50% weapon, 20% armor, 20% consumable, 10% gold pile.
6. Place **traps**: depth/4 random traps on random floor tiles.
7. Place **stairs_up**: near spawn_pos (unless depth 1).

### 4.3 Field of View — Recursive Shadowcasting

**Algorithm** (independent of DCSS, standard roguelike algorithm):

1. Player at origin, visible radius R (e.g., 8).
2. Mark origin tile visible.
3. For each of 8 octants, recursively scan:
   - Track a "shadow range" [start_slope, end_slope] (initially [1.0, 0.0]).
   - For each row y from 1 to R:
     - For each column x covered by current slopes:
       - tile_pos = convert(octant, x, y)
       - If opaque (wall / closed door):
         - New shadow starts: shrink end_slope to right side of this tile.
         - Continue with trimmed slopes.
       - Else:
         - Mark visible.
         - If was coming out of shadow, resume scan.
     - If whole row was in shadow, stop octant.

**Reference**: https://www.roguebasin.com/index.php/FOV_using_recursive_shadowcasting

**Implementation**: ~80 lines of GDScript. Computed once per player move,
cache `visible_tiles: Dictionary[Vector2i, bool]`.

**Explored set**: separately track `explored: Dictionary` (union of all
visible tiles across moves). Rendering shows:
- Currently visible: full color
- Explored but not visible: dimmed
- Never seen: black

### 4.4 Player Stats & Progression

**Stats**:
- `HP` / `hp_max` — damage / death
- `MP` / `mp_max` — spell mana
- `STR` / `DEX` / `INT` — core attributes (8-20 range typically)
- `AC` — damage soak
- `EV` — dodge
- `WL` — hex/spell resist

**Starting values by class**:
- Warrior: HP 35, MP 2, STR 14 / DEX 10 / INT 6
- Mage: HP 22, MP 8, STR 7 / DEX 10 / INT 14
- Rogue: HP 24, MP 4, STR 10 / DEX 14 / INT 10
- Hunter: HP 26, MP 4, STR 10 / DEX 14 / INT 9

**Experience table** (cumulative XP to reach level N):
```
Level  1  2   3   4   5    6    7    8    9    10
XP     0  10  30  70  140  250  420  700  1150 1800

Level  11   12   13   14   15    16    17    18    19    20
XP     2800 4200 6000 8400 11500 15500 20500 27000 35500 47000
```

**Per-level growth**:
- HP: +5 base + STR/5
- MP: +2 base + INT/4 (mages get +3)
- Stats: +1 to STR/DEX/INT at levels 3, 6, 9, 12, 15, 18 (player picks at
  3/6/9; auto at 12/15/18).

**XP gain**: kill monster XP = `monster.xp_value`. Scale by:
`if monster_depth < player_xl: xp *= (1 - 0.1*(xl - mdepth))` (diminishing
returns on weak kills).

### 4.5 Combat System

#### 4.5a Melee attack

```
func try_attack(attacker, defender):
    weapon_dmg = attacker.weapon_damage + weapon_plus
    stat_bonus = attacker.STR / 3           # for blade/mace
                or attacker.DEX / 3          # for dagger/rapier
    skill = skill_system.get_level(attacker, weapon.category)

    # To-hit
    to_hit_base = 15 + stat_bonus + skill
    to_hit_roll = randi() % to_hit_base
    if to_hit_roll < defender.EV:
        log "miss"
        return

    # Damage
    raw = weapon_dmg + stat_bonus/2 + randi() % (skill*2 + 1)
    soak = randi() % (defender.AC + 1)
    final = max(1, raw - soak)

    # Brand bonus (if weapon is branded)
    if weapon.brand == "flaming": final += randi_range(1,6); element="fire"
    if weapon.brand == "freezing": final += randi_range(1,6); element="cold"
    if weapon.brand == "electric": final += randi_range(1,4)  # rare burst
    ...

    # Element resist
    if defender.resists has element:
        final = final / 2  # each level halves

    defender.HP -= final
    log "hit {target} for {final}"
    if defender.HP <= 0: defender.die()
```

**Key tuning numbers**:
- `to_hit_base` = 15 + stat/3 + skill (5-30 range)
- Defender EV typically 5-15
- AC typically 0-15
- Hit rate at EV=10, to_hit=25 → (25-10)/25 = 60%

#### 4.5b Ranged attack

Same formula, using DEX as stat and `bow` skill. Plus:
- Range penalty: `to_hit -= max(0, (dist - 2) * 3)` — harder at distance.
- Line of sight check (walls block).
- Draw arrow from attacker to defender (SpellFX.cast_single).

#### 4.5c Shield block

Before damage rolls, if defender has shield (SH > 0):
```
sh_roll = randi() % (SH * 2)
if sh_roll > to_hit_roll:
    log "shield blocks"
    return  # attack fully negated
```
Fatigue: each block this turn reduces next block's SH by 25%. Reset at
turn start.

### 4.6 Skill System

**Scope**: keep small. 8 skills, not DCSS's 30.

**Skill list**:
1. `blade` — long blades (swords, scimitars)
2. `blunt` — maces, flails, hammers
3. `dagger` — short blades, stabbing
4. `polearm` — spears, halberds
5. `ranged` — bows, crossbows, throwing
6. `armor` — heavy armor mastery
7. `magic` — one unified spell skill (not per-school like DCSS)
8. `stealth` — sneaking, noise reduction

**Skill level**: 0-20. Starts at level of class's `starting_skills`.

**XP curve**:
```
Level  0  1   2   3   4   5    6    7    8    9    10
XP     0  20  50  100 180 300  470  700  1000 1400 1900

continues doubling-ish to level 20 ~15000 XP.
```

**XP gain on action**:
- Successful melee hit: +1 to weapon's category skill
- Successful ranged hit: +1 to `ranged`
- Successful spell cast: +spell.mp_cost to `magic`
- Taking a hit while wearing heavy armor: +1 to `armor`
- Moving while stealthed: +0.5 to `stealth`

**Effects per level**:
- Weapon skills: +5% damage per level, +1 to-hit per level
- Armor: reduces body armor's EV penalty by 10% per level
- Magic: +2 spell power per level, -3% spell failure per level
- Stealth: -1 monster detection radius per 2 levels

**UI**: player can't manually allocate. It grows from use. Simpler than
DCSS's training checkboxes.

### 4.7 Spell / Magic System

**Spell data**:
```gdscript
class_name SpellData extends Resource
@export var id: String
@export var display_name: String
@export var mp_cost: int = 2
@export var difficulty: int = 1       # 1-9
@export var base_damage: int = 0
@export var range: int = 5
@export var targeting: String = "single"  # "single", "area", "self", "line"
@export var element: String = ""          # "fire", "cold", "electric", "poison", "necromancy", ""
@export var effect: String = ""           # "damage", "heal", "blink", "status_X", ...
```

**Spell roster (MVP — 10 spells)**:
1. Magic Dart — single, 1 MP, 1d4+power/4, difficulty 1
2. Fireball — area r2, 5 MP, 3d6+power/2, fire, difficulty 5
3. Ice Bolt — single, 4 MP, 2d8+power/2, cold, difficulty 4
4. Lightning — line, 6 MP, 4d6, electric, difficulty 6
5. Heal Wounds — self, 6 MP, restore 15+power/2 HP, difficulty 3
6. Blink — self, 2 MP, teleport 4 tiles random, difficulty 2
7. Confuse — single, 4 MP, 5 turns, hex, difficulty 3
8. Shield — self, 3 MP, +5 AC for 20 turns, difficulty 2
9. Haste — self, 5 MP, double speed for 10 turns, difficulty 4
10. Necrotic Bolt — single, 5 MP, 2d8, necromancy, difficulty 5

**Power calc**:
```
power = magic_skill * INT / 10
failure = max(0, 25 + difficulty*5 - magic_skill*3 - INT/2)
```

**Failure roll**: `randi() % 100 < failure` → spell fizzles, MP still spent.

**Targeting mode**:
- Self: instant
- Single/area/line: enter 2-tap targeting
  - First tap: paint preview
  - Second tap on same cell: commit
  - Tap elsewhere: move preview
  - ESC: cancel

### 4.8 Item System

**Kinds**: weapon, armor, potion, scroll, wand, ring, amulet, food, gold

**Identification**:
- Potions/scrolls unidentified start: show random descriptor
  ("Bubbling Potion", "GIB XON" scroll)
- Per-run pseudonym mapping stored in GameManager
- On first use OR scroll-of-identify: reveal
- Same id same appearance across the run

**Enchantment**:
- Weapons/armor can be +N (0 to +9)
- +1 = +1 damage / +1 AC
- Scroll of Enchant Weapon bumps +N
- Found +N chance scales with depth (rarer to find +3 early)

**Brands** (weapons — 20% of floor-gen weapons rolled branded from depth 5):
- Flaming (+1d6 fire damage)
- Freezing (+1d6 cold)
- Electric (1/4 chance +1d10, else +1d3)
- Venom (applies poison status)
- Vorpal (crits on 1/3 swings, +25% damage)
- Draining (drain element, targets weakness)

**Egos** (armor):
- Fire resistance / Cold resistance / Protection (+2 AC) / Evasion (+2 EV)
- Stealth / Magic Resistance / Might (STR+1)

**Pricing (for shops)**: `base = kind_base * tier * (1 + plus*0.3)`
with brand multiplier 1.5-2x.

### 4.9 Monster AI

**State machine per monster**:

```
if sleeping:
    if player in LOS at radius ≤ sight_range:
        wake up, skip this turn
    else:
        idle
    return

if has_status("paralysis"): tick down, skip turn
if has_status("flee"): move away from player
if has_spell_book AND randf() < cast_chance(level) AND player in LOS:
    cast a spell at player
    return

if adjacent to player: attack player
if has_ranged AND player in LOS at 2..range:
    fire ranged (Bresenham LOS check)
    return

if player visible:
    move one tile toward player (greedy, 8-dir, check walkable)
else:
    random walk 50% chance
```

**Pack behavior** (optional): monsters of same id within 5 tiles group-
target the player together. Flee if group HP below 30%.

**Sight**: use same FOV shadowcasting from monster's position; radius from
`sight_range` field.

### 4.10 Cloud / Environmental Effects (optional MVP)

Cloud tile overlays with duration + per-turn damage. Tile → damage + status:
- Fire cloud: 3 dmg/turn, "fire" element
- Cold cloud: 2 dmg/turn, "cold"
- Poison cloud: poison status, 4 turns
- Smoke: blocks LOS, no damage

On player turn start, apply cloud on player's tile, decrement cloud
duration, clean up expired.

### 4.11 Status Effects

Minimal set:
- `poison_turns` — 1 dmg/turn until 0
- `haste_turns` — double speed (act twice per player turn)
- `confusion_turns` — 25% chance per turn to move random direction
- `paralysis_turns` — skip turn
- `fear_turns` — flee from player

Tick them in player's turn-end (own metas) and monster's take_turn top
(monster metas).

---

## 5. Build Order (week-by-week MVP)

### Week 1: Core Loop

**Day 1**: Project scaffold + grid
- Godot project, autoloads, GameManager / TurnManager.
- Copy UI whitelist (§1).
- `DungeonMap.gd` renders a 35×50 grid of '#'/'.' tiles (ASCII).
- `Player.gd` moves with arrow keys.

**Day 2**: FOV + first monster
- `FieldOfView.gd` (shadowcasting from §4.3).
- Only draw visible tiles with fog for explored.
- `Monster.gd` spawn one rat that walks toward player.
- Bump-to-attack: player HP/monster HP, simple damage.

**Day 3**: Dungeon generation
- `MapGen.gd` BSP generator (§4.2a). Places stairs.
- 5-8 monsters per floor.
- Stairs: step on stairs_down → regen at depth+1.

**Day 4**: Items + inventory
- `FloorItem.gd` spawn on gen. Pickup on step.
- `Player.items: Array`.
- Consumable loop: potion of healing heals +15 HP.

**Day 5**: Classes + basic UI
- 3 ClassData resources. JobSelect menu uses them.
- HP/MP bars (BottomHUD / TopHUD from whitelist).
- Combat log strip.

**End week 1**: you can play a 5-floor dungeon with one class.

### Week 2: Content

- 20 monsters across 5 tiers. Each a proper `.tres`.
- 15 items (weapons, armor, potions, scrolls, wands).
- Identification system (unidentified consumables with pseudonyms).
- `CombatSystem.gd` full damage formula (§4.5).
- `SkillSystem.gd` (§4.6).
- Magic system (§4.7) — 5 spells for mage class.
- Saves/loads via SaveManager.

### Week 3: Polish

- Tile art integration (Kenney pack CC0).
- Sound effects on attack / hit / death / pickup.
- Mobile touch UI (tap adjacent tile, quickslot row).
- Character dump / morgue on death.
- Balance pass.

### Week 4: Release

- Android APK export + sign.
- Itch.io upload.
- Ko-fi / donation links.
- README + screenshots + GitHub public.

---

## 6. UI Patterns (from PROJ_D lessons)

- **Dialog pattern**: single `GameDialog.gd` reused for all popups.
  Bottom full-width Close; ESC / outside-tap closes.
- **Quickslot**: 4 slots at bottom. Tap to use, long-press to manage.
- **2-tap targeting**: first tap paints preview, second tap commits.
- **Sub-tabs** for long lists (bag, magic, skills).
- **Status dialog sections**: Header → Vitals → Stats → Combat → Active
  Effects → Equipment → Rings/Amulet → Resistances → Trait → Mutations
  → Runes.

See PROJ_D whitelist files for concrete implementations.

---

## 7. Mobile Optimizations

- Default zoom 4.0 (not 6.5 — camera too close).
- Font min 30pt.
- Tap targets ≥48×48 dp.
- Map 35×50 (portrait-friendly).
- Viewport-relative dialog width (cap 92%).
- Pinch zoom persists.

---

## 8. Balance Cheat Sheet

### Monster HP tiers by depth
- D1-3: 5-20 HP (tier 1-2)
- D4-8: 15-50 HP (tier 2-3)
- D9-15: 40-120 HP (tier 3-4)
- D16-25: 100-300 HP (tier 4-5)

### Player HP by XL (Warrior baseline)
- XL 1: 35
- XL 5: 55
- XL 10: 85
- XL 15: 125
- XL 20: 170

### Damage curves
- Early weapon: 4-8
- Mid: 9-16
- Endgame: 18-28
- Max non-brand hit vs player mid-game: ~player_hp / 3 per swing

### Encounter density
- 8-15 monsters D1-5
- 15-25 D6-15
- 10-20 D16-25 (quality > quantity)

### Item rarity
- Common 60%, Uncommon 30%, Rare 8%, Epic 2%

---

## 9. Algorithm References (public domain)

- **Shadowcasting FOV**: RogueBasin article (see §4.3 link).
- **BSP dungeon gen**: standard, described in §4.2a.
- **Cellular automata caves**: §4.2b.
- **Bresenham line** (beam / LOS check): any textbook.
- **A* pathfinding**: Godot has `AStar2D` built in — no need to roll own.

None require reading DCSS source.

---

## 10. Asset Sources (CC0 / commercial-friendly)

### Tiles
- **Kenney 1-bit** (https://kenney.nl/assets/1-bit-pack) — minimalist
- **Kenney Roguelike** (https://kenney.nl/assets/roguelike-caves-dungeon) — richer
- **OpenGameArt CC0 filter** — thousands of sets
- **Oryx Design Lab** (paid, but commercial license included)

### Sound
- **freesound.org** (CC0 filter)
- **Kenney audio packs** (CC0)

### Music
- **incompetech.com** (Kevin MacLeod) CC BY 3.0 — must credit
- **PlayOnLoop.com** royalty-free

### Fonts
- **Google Fonts**: OFL 1.1
- **Pixel fonts**: "Press Start 2P", "VT323", "Silkscreen"

---

## 11. Monetization Setup (optional)

- **Ko-fi**: instant signup, accepts KRW / USD
- **GitHub Sponsors**: monthly recurring
- **itch.io** "pay what you want": $0 minimum, up to user
- License recommendation: **MIT** (shortest, permissive, commercial-friendly)

---

## 12. PROJ_D Pitfalls — avoid these

1. **Giant JSON at startup**: slow, no editor preview. → Use `.tres`.
2. **Autoload circular deps**: resolve at usage time, not `_ready`.
3. **Signal leaks**: connect once, guard with `is_connected`.
4. **Float/int mixing in damage**: keep all damage `int`.
5. **FOV every frame**: only recompute on move.
6. **Dialog rebuild stutter**: lazy build, toggle `visible` when possible.
7. **Nested CanvasLayer invisible**: attach dialogs to Node2D root.
8. **No unequip button**: add Unequip to equipped cards from day 1.
9. **Miss logs invisible**: show "X misses you" clearly, distinct color.
10. **Dialog overflow**: viewport-relative sizing, 92% max.
11. **Over-engineered skills**: keep to 8, auto-train on use.
12. **Too many classes/items**: 3-5 classes / 20 items for MVP.
13. **Unique monster custom AI**: unless it's a final boss, data-drive it.

---

## 13. What NOT to add in v1

- Multiplayer
- Crafting
- Map editor
- 10+ classes
- Achievements
- DLC / season pass
- In-app purchases

Every one of these killed indie roguelikes. Add post-launch if players ask.

---

## 14. Naming

- Avoid: "Crawl", "Rogue", "Dungeon Crawl", "Stone Soup"
- Short 1-2 syllable: "Delve", "Rune", "Drop"
- Compound: "CryptRunner", "RuneDelve", "StoneFall"
- Check USPTO + Google before finalizing. Buy domain.

---

## 15. First-Session Checklist

When you open a fresh session in the new project:

1. [ ] Create new Godot 4.3+ project in fresh directory (NOT inside PROJ_D).
2. [ ] `git init` + GitHub repo, set to public.
3. [ ] Add `LICENSE` (MIT recommended) + `README.md`.
4. [ ] Project Settings → portrait 720×1280, autoload GameManager /
   TurnManager / CombatLog / SaveManager.
5. [ ] Create folder skeleton (§2).
6. [ ] **Copy UI whitelist** (§1) — 21 files from PROJ_D.
7. [ ] Edit DCSS labels/comments out of 5 files (§1b).
8. [ ] Replace 3 dictionary values (§1c).
9. [ ] Implement Week 1 spec (§5) aiming for playable grid + rat in ~2 hrs.
10. [ ] Commit every hour.

---

## 16. Implementation Order Sanity Check

If you follow §4 specs in this order, the game will run:

1. TurnManager + GameManager (autoload) — game loop foundation.
2. MapGen (§4.2a BSP) — a walkable level exists.
3. DungeonMap render — you can see the level.
4. Player.gd + input — you can move.
5. FOV (§4.3) — you only see near tiles.
6. Monster.gd + spawning — first monster appears.
7. MonsterAI (§4.9 minimal) — monster approaches.
8. CombatSystem (§4.5a) — bumps resolve.
9. FloorItem + inventory — pickup loop.
10. Stairs + depth regeneration — run loop.
11. UI wiring (HUD, dialogs from whitelist) — usable on touch.
12. 20 monsters + 15 items content — variety.
13. SkillSystem (§4.6) — progression.
14. MagicSystem (§4.7) — caster class viable.
15. Classes (§4.4) — 3-5 distinct starts.
16. Save/load — persistence.
17. Tile art swap — visual polish.
18. Sound effects — feedback.
19. Balance tuning — playtest + adjust.

**Week 1 = steps 1-11** — playable MVP.
**Week 2 = steps 12-16** — content + saves.
**Week 3 = steps 17-19** — polish.
**Week 4 = release builds + distribution**.

---

This guide is self-contained. A fresh session reading only this document
(plus the UI whitelist files) can bootstrap a working mobile roguelike in
~4 weeks without touching PROJ_D source code. Implementation direction is
given concretely enough that each system can be built independently.

**Last updated**: 2026-04-25 (after PROJ_D's DCSS port reached ~80% content
parity; reboot decision recorded separately in
`memory/reboot_decision.md`).
