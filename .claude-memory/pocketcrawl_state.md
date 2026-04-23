---
name: PocketCrawl current state
description: Snapshot of PocketCrawl — built systems, pending roadmap, architecture decisions. Read first in new sessions.
type: project
originSessionId: 1cc7ec78-12c9-429a-9ad0-009a1a55bfef
---
PocketCrawl (MIT) is the active project at `/mnt/d/PROJ_D/` root.
`oldproject/` is the archived DCSS GPL port — do NOT mix code back
across the firewall. Legal guide lives in
`docs/clean_room_reboot_guide.md`; SRD / tile attribution lives in
`CREDITS.md`.

## Built systems

Use `git log --oneline` for per-commit history. High-level state:

### Core
- TurnManager (reentrancy guard, `end_player_turn(immediate)` for
  auto-rest loop).
- FOV shadowcasting.
- BSP dungeon gen + L-corridor connect + farthest-BFS stairs.
- Depth-banded terrain art (dirt / limestone / bloody cobble / crystal).
- **Per-floor state cache** in `GameManager.floor_cache` — ascend /
  descend restore tiles, explored fog, surviving items, surviving
  monsters (id/pos/hp/status). In-memory only; cleared on death or
  new run.
- Save / Continue to `user://save.json`. Death deletes save. Menu
  exit preserves save if alive. Load rehydrates Player + race sprite
  + paper-doll + identified/pseudonyms.
- **Settings** (persisted to `user://settings.json`):
  use_tiles / rune_shards / unlocks dict.

### Character system
- **6 races** — Human (default), Kobold / Orc / Troll / Minotaur /
  Elf. Non-human races unlock by killing the matching monster id
  (kobold, orc, troll, minotaur, deep_elf_archer). RaceData carries
  stat mods and `resist_mods: Array` (e.g. troll → `["cold+"]`).
- **5 classes** — Warrior / Mage / Rogue default unlocked.
  Berserker (unlock: use `potion_berserk`) and Ice Mage (unlock: use
  `book_ice_magic`). ClassData mirrors unlock fields + starting
  hp/mp/stats/skills/weapon/armor/spells.
- Flow: MainMenu → RaceSelect → **JobSelect** (paper-doll + gear +
  skills 3-line per-card) → Game.
- Player sprite: race base + body armor + hand1 weapon via
  `DOLL_BODY_MAP` / `DOLL_HAND1_MAP` on Player.
- Stats: STR / DEX / INT / AC / EV / WL / resists. Level-up at
  §4.4 XP curve; HP+(5+STR/5), MP+(2+INT/4); auto stat bump at
  XL 12/15/18.

### Combat
- Bump melee with weapon +N plus skill (+dmg, +hit). DEX-scaled for
  dagger category.
- **Weapon brands** (ItemData.brand):
  - flaming → fire element, burning 2 turns on hit
  - freezing → cold, frozen 1 turn
  - venom → poison, poison 3 turns
  - electric → electric, synergises with wet targets
  - draining → necromancy, no status
  Each adds an independent 1d6 elemental hit on top of physical,
  scaled through the resist pipeline.
- Ranged monster attacks via `MonsterData.ranged_attack` dict.
- Kill grants XP + rune shards + triggers race-unlock check.

### Status + resistance (Status.gd)
- Unified module duck-types Player (`statuses` dict) and Monster
  (`status` dict). Dispatches `apply / has / remove / tick_actor`.
- INFO table describes each status (tick damage, element, skip_turn /
  random_move / flee / str_bonus). Stat mods auto-apply on apply,
  auto-revert on remove.
- Active statuses: poison, burning, frozen, confused, feared,
  berserk, might, weak.
- `Status.resist_scale(base, resists, element)` scaling:
    "fire" / "fire+"   = half damage (+1)
    "fire++"           = quarter (+2)
    "fire+++"          = 1/10 (+3, near immune)
    "fire-" / "fire--" / "fire---" = 1.5× / 2× / 3× (vulnerable)
  Entries stack, clamped [-3, +3]. `resist_level` exposes the
  computed value for UI.
- MonsterAI reads `will_skip_turn` (frozen), `is_fleeing` (feared),
  `confusion_chance` (confused → 40% random step).

### Magic (7 spells)
- Self: Heal Wounds, Blink.
- Auto-target / targeted:
  - Magic Dart (single, 1 MP)
  - Ice Bolt (single, cold → frozen)
  - Magic Missile (3-dart multi_damage, cascading)
  - Burning Hands (AoE radius 2, fire → burning)
  - (plus lightning/wet synergy bonus in MagicSystem)
- Power = INT + magic_skill × INT / 10. Fizzle = difficulty×5 −
  skill×3 − INT/2.
- `SpellTargetOverlay` gives tap-to-target UI for spells whose
  effect is not self/self-blink.

### Items (~23)
Weapons: short_sword, dagger, mace, long_sword, battle_axe +
flaming_sword, frost_dagger, venom_dagger, shock_mace (branded T3-4).
Armor: leather_armor, chain_mail, robe.
Potions: healing, might, cure_poison, magic, berserk.
Scrolls: blinking, magic_mapping, teleport, enchant_weapon,
enchant_armor, identify.
Books: book_ice_magic (kind="book", grants_spell + unlocks_class).
Gold pile.

**Layered icons**: ItemData has `tile_path` (unidentified base) +
`identified_tile_path` (overlay). Scrolls base = `scroll/scroll.png`,
overlay = `scroll/i-*.png`. Potions base = coloured bottle, overlay
= `potion/i-*.png`. FloorItem._draw composites only when
`GameManager.is_identified(id)`.

### Identification
- `GameManager.pseudonyms` populated on start_new_run from pools
  (potion adjectives, 2-word scroll names, book adjectives).
- `GameManager.display_name_of(id)` returns pseudonym until
  identified, then real name.
- Player.use_item auto-identifies on first use.
- `scroll_identify` effect opens IdentifyPicker dialog; pick any
  unidentified item to reveal.
- Pickup / drop / bag / quickslot labels all route through
  `display_name_of`.

### Monsters (~18)
T1 (D1-4): rat, bat, kobold
T2 (D2-7): goblin, hobgoblin, adder (poison bite 3 turns)
T3 (D4-12): gnoll, orc, orc_wizard (ranged), giant_wolf_spider
  (poison), gnoll_shaman (ranged holy bolt), deep_elf_archer (ranged)
T4 (D7-16): ogre, troll, minotaur, wight (cold+/necromancy+)
T5 (D11-20): mummy (cold+/necromancy+/fire-), stone_giant (ranged)

### Skills (§4.6)
- 8 skills (blade/blunt/dagger/polearm/ranged/armor/magic/stealth).
- Grow from use. CombatSystem grants weapon-category xp on hit;
  MagicSystem grants magic xp on cast.
- Each level: +5% weapon damage, +1 to-hit. Armor skill reduces
  EV penalty 10% per level. Magic skill feeds spell power + lowers
  fizzle.

### UI
- MainMenu: PocketCrawl title, Continue / New Run / Display /
  Rune Shards / How to Play / BuildVersionLabel.
- TopHUD: Minimap thumbnail (left) + HP/MP/XP thin bars + LevelLabel
  / GoldLabel / TurnLabel + Zoom +/- buttons.
- BottomHUD: **5 quickslots** (down from 8 after layout tests) +
  REST / BAG / SKILLS / MAGIC / STATUS / ACT / MENU.
- Top-left 92×120 minimap overlay → full-size MinimapDialog on tap.
- CombatLogStrip (tappable → LogDialog with 60-entry history).
- Dialogs on GameDialog chrome: Bag, Magic, Skills, **Status (full
  character sheet — race/class portrait + vitals + stats + combat
  + equipment + resistances + active effects + meta)**, Shards,
  Help, Minimap, Log, QuickslotPicker, IdentifyPicker, Death
  (ResultScreen).
- UICards helper (section_header / card / accent_value / dim_hint)
  for consistent dialog sections.
- GameTheme for buttons / panels / scrollcontainers.

### Input
- Keyboard: arrow / WASD / HJKL for move, bump-to-attack.
- Touch: tap grid to step; tap self = wait.
- **Auto-walk (DCSS-style)**: tap distant explored walkable tile →
  BFS path → step per turn. Halts only when a _new_ monster (id not
  in start-of-walk FOV snapshot) enters FOV, or HP drops, or tap
  cancels. Enemies already visible when travel starts don't block.
- Pinch zoom via ZoomController.
- TouchScrollHelper.install on RaceSelect / JobSelect / all
  GameDialog body ScrollContainers.

### CI / Web
- `.github/workflows/deploy-web.yml` builds Godot 4.6.2 HTML5 →
  GitHub Pages. `export_presets.cfg` has "Web" preset at repo root.
- `CREDITS.md` covers SRD 5.1 (CC BY 4.0), DCSS CC0 tiles, Godot MIT.

### Unlock system (earned, persistent)
- `GameManager.unlocks` dict in settings.json.
- Race unlock: kill monster whose id matches
  `RaceData.unlock_trigger_id` (unlock_kind="kill").
- Class unlock: use item whose id matches
  `ClassData.unlock_trigger_id` (unlock_kind="use_item"). Item's
  `unlocks_class_id` + `grants_spell_id` handle both sides.
- `GameManager.try_kill_unlock(monster_id)` / `try_use_unlock(item_id)`
  invoked from combat kill paths (CombatSystem, MagicSystem) and
  Player.use_item respectively.
- RaceSelect / JobSelect show `.unlock_hint()` on locked cards.

## Pending roadmap — ordered by value

### A. Combat / content
1. **Brand drop frequency / randomisation** — branded weapons are
   their own .tres files right now (flaming_sword etc.). Cleaner:
   per-instance brand rolled on spawn, stored in inventory entry.
2. **More SRD monsters** (T3-T5): zombie, skeleton, ghoul, naga,
   dragon (cone-breath needs area targeting).
3. **More spells** — lightning bolt (line), cure wounds (heal
   variant), confuse (status), invisibility.
4. **Wand items** — reuse SpellTargetOverlay. plus = charges.
5. **Player ranged** — bow + `ranged` skill already in SkillSystem;
   add `bow` weapon category and directional fire UI.

### B. Dungeon / environment
6. **Cellular automata caves** (§4.2b) — alternate generator per
   depth band for variety.
7. **Clouds** (§4.10) — fire/cold/poison/smoke tile overlays with
   duration + tick damage / LOS block.
8. **Doors / traps** — tile enum has doors; no interaction yet.

### C. Meta / shops
9. **Rune shard spend screen** — currently just shows balance.
   Permanent upgrades (start HP+5, extra starter potion, manual
   race/class unlock).
10. **Shopkeeper floors** — special tile, gold-for-item.
11. **Achievement / progression tree**.

### D. Polish / bugs
- **True potion identification game** — right now each potion id
  has a fixed base colour. Proper DCSS does per-run randomised
  colour pool so "brown = healing this run, cloudy next run".
- **Quickslot icons are single-layer** — don't composite
  identified_tile_path overlay. Works but less informative.
- **Monster status visuals** — burning/frozen monsters don't tint.
  Could modulate sprite by `Status.color_of(id)` for the first
  active status.

## Architecture — respect these

- **9 autoloads**: GameManager, TurnManager, CombatLog, SaveManager,
  MonsterRegistry, ItemRegistry, ClassRegistry, SpellRegistry,
  RaceRegistry. Adding a new content type = add one autoload + one
  `resources/<kind>/` directory.
- **Content is preload-baked into registry scripts**, NOT runtime
  directory scans. Adding a .tres = add a `const _X = preload(...)`
  + include in the `_ALL_*` array.
- **class_name globals**: Player, Monster, FloorItem, DungeonMap
  (entities) and CombatSystem, MonsterAI, MagicSystem, MapGen,
  FieldOfView, MinimapRenderer, Status, SpellTargetOverlay, UICards
  (static RefCounted modules).
- **Paper-doll setters**: `set_race_from_id / set_equipped_weapon /
  set_equipped_armor` call `_refresh_paperdoll`. Never assign
  equipped_* fields directly; the setters are the only sync path.
- **Unlock triggers**: any new kill or item-use path must call
  `GameManager.try_kill_unlock(id)` or `try_use_unlock(id)` so new
  unlock conditions added to .tres files just work.
- **Damage pipeline**: `Status.resist_scale(base, resists, element)`
  is the single scaling point. CombatSystem/MagicSystem all route
  through it. Status ticks use it too.
- **Status flow**: `Status.apply(actor, id, turns)` is the only
  entry. Tick happens in `Player.tick_statuses()` (player turn
  start) and `Monster._tick_statuses()` (take_turn start).
- **GameDialog chrome**: every popup reuses `GameDialog.create(title)`
  + `.body()`. New dialogs = `class_name XDialog extends RefCounted`
  with `static func open(player, parent)`.
- **Save schema**: `SaveManager.save_run` is single source. Add
  fields to nested `player` dict; `GameManager.load_run` rehydrates.
  Save version bumping not formalised yet but safe to extend with
  `data.get("new_key", default)` patterns.

## Known gotchas

- **Godot autosave race** — editing a script in Claude while the
  Godot editor is open can race with its autosave; recent edits may
  silently revert after a filesystem sweep. Happened repeatedly with
  RaceData.resist_mods, Status.resist_level, StatusDialog header.
  Mitigation: `Project → Reload Current Project` after a batch of
  Claude edits, or close the editor first.
- `BagTooltips.gd` / `SkillsScreen.gd` from oldproject — NOT copied.
  Use `BagDialog` / `SkillsDialog` written fresh.
- WSL can't run the Windows Godot .exe — manual testing in the
  Windows editor only; CI build is the independent verifier.
- Godot 4.6 treats `:=` on `sign()` / `max()` / `abs()` as unsafe
  variant inference; with warnings-as-errors this fails the build.
  Always use `var x: int = sign(...)` when the RHS is a @GlobalScope
  numeric function.
- `CELL_SIZE = 32`. Camera zoom 0.7-2.2 range with 0.2 step.
- `BottomHUD.tscn` font sizes tuned for 720×1280; re-scaling needs
  both tscn fonts + HUD anchors updated.
- 3-arg `Color(r,g,b)` in .tscn fails Godot 4.6 parser; use 4-arg.

## Where to look first (new session)

1. `git log --oneline -20` to see recent landings.
2. Open `/mnt/d/PROJ_D/` in Godot editor → wait for import
   (Reload Current Project if scripts show stale errors).
3. F5 smoke-test — MainMenu → New Run → RaceSelect → JobSelect →
   walk, bump, auto-walk, read scroll, descend, ascend, die.
4. Pick from roadmap §A / §B / §C.
