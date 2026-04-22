---
name: PocketCrawl current state (updated 2026-04-23 late session)
description: Snapshot of PocketCrawl — what systems exist, what's in the roadmap, and architecture decisions future sessions should respect before extending
type: project
originSessionId: 1cc7ec78-12c9-429a-9ad0-009a1a55bfef
---
PocketCrawl (MIT) is the active project at `/mnt/d/PROJ_D/` root.
`oldproject/` is the archived DCSS GPL port — do NOT mix code back
across the firewall. Legal/architecture guide lives in
`docs/clean_room_reboot_guide.md`; SRD / tile attribution lives in
`CREDITS.md`.

## Built systems — trust these exist, extend don't rewrite

Use `git log --oneline` for per-commit history. High-level state:

### Core
- TurnManager (reentrancy guard, `end_player_turn(immediate)` for rest loop)
- FOV shadowcasting (RogueBasin algorithm)
- BSP dungeon gen + L-corridor connect + farthest-BFS stairs
- Depth-banded terrain art (dirt/limestone/bloody-cobble/crystal)
- Save/Continue via `user://save.json`. Death deletes save. Menu exit
  preserves save if alive. Load rehydrates Player + race sprite +
  paper-doll.

### Character system
- **5 races** — Human (default), Kobold / Orc / Troll / Minotaur /
  Elf (all locked, unlocked by killing the same-named monster).
  Stat mods applied on top of class starting stats.
- **5 classes** — Warrior / Mage / Rogue (default unlocked), Berserker
  (unlock: use `potion_berserk`), Ice Mage (unlock: use
  `book_ice_magic`).
- Flow: MainMenu → **RaceSelect** → **JobSelect** → Game.
- Player sprite = race base (human_m/kobold_m/...) layered with
  body (leather/chain/robe) + hand1 (weapon) paper-doll overlays.
  Maps hardcoded in Player.gd (`DOLL_BODY_MAP`, `DOLL_HAND1_MAP`).
- Stats: STR / DEX / INT / AC / EV / WL. Level-up at §4.4 XP curve,
  HP + STR/5, MP + INT/4. Auto stat bump at XL 12/15/18.

### Combat
- Bump melee (§4.5a) with weapon +N, skill (+dmg%, +to-hit), DEX-based
  dagger crit. Unarmed fallback 2 dmg.
- Ranged monster attacks (`ranged_attack` dict on MonsterData).
- Kill grants XP + rune shards + triggers race-unlock check.

### Magic (6 spells)
- Self-target: Heal Wounds, Blink.
- Auto-target nearest: Magic Dart (single), Ice Bolt, Magic Missile
  (3 bolts cascading), Burning Hands (AOE radius 2).
- `MagicSystem.cast` effect branches: heal, blink, damage,
  multi_damage, aoe_damage. Power = INT + magic_skill × INT / 10.
  Fizzle chance from difficulty − skill × 3 − INT/2.

### Items (18 total)
Weapons: short_sword, dagger, mace, long_sword, battle_axe.
Armor: leather_armor, chain_mail, robe.
Potions: healing, might, cure_poison, magic (MP), berserk.
Scrolls: blinking, magic_mapping, teleport, enchant_weapon, enchant_armor.
Books: book_ice_magic.
Gold pile.
Each has tile_path + ASCII glyph + optional `unlocks_class_id` /
`grants_spell_id` for unlock-trigger items.

### Monsters (18 total)
T1 (D1-4): rat, bat, kobold
T2 (D2-7): goblin, hobgoblin, adder (poison bite 3 turns)
T3 (D4-12): gnoll, orc, orc_wizard (ranged), giant_wolf_spider (poison),
  gnoll_shaman (ranged), deep_elf_archer (ranged)
T4 (D7-16): ogre, troll, minotaur, wight
T5 (D11-20): mummy, stone_giant (ranged rock throw)

### Skills
- 8 skills: blade / blunt / dagger / polearm / ranged / armor / magic /
  stealth. Grow from use. Level 0-20.
- Class starting skills: Warrior blade+armor, Mage+IceMage magic+dagger,
  Rogue dagger+stealth, Berserker blunt+armor.

### Status effects
- Active: poison (−1 HP/tick), berserk (+4 STR, on-remove reverts).
- Scaffolding (`_apply_status_tick` + `_on_status_removed`) ready for
  confused / fear / haste / slow / might-temp. Monster-side ticks
  NOT wired yet — Monster.status dict exists but `take_turn` doesn't
  call tick.

### UI
- MainMenu: PocketCrawl title, Continue / New Run / Display toggle /
  Rune Shards popup / How to Play / BuildVersionLabel bottom-right.
- TopHUD (slim, 150px tall): HP/MP/XP bars, Zoom +/− buttons.
- BottomHUD: 8 quickslots + BAG / SKILLS / MAGIC / STATUS / WAIT /
  REST / AUTO / ATCK / MENU.
- Top-left 92×120 minimap overlay → tap opens full-size MinimapDialog.
- CombatLogStrip above BottomHUD → tap opens LogDialog (60-msg full
  history).
- Dialogs on GameDialog chrome: Bag, Magic, Skills, Status, Shards,
  Help, Minimap, Log, QuickslotPicker, Death (ResultScreen).
- ASCII / Tile toggle branches in each entity's `_draw`.

### Unlock system (earned, persistent)
- `GameManager.unlocks` dict, persisted to `user://settings.json`.
- Race unlock: kill monster whose id matches RaceData.unlock_trigger_id
  when unlock_kind="kill". Triggered in CombatSystem +
  MagicSystem kill paths.
- Class unlock: use item whose id matches ClassData.unlock_trigger_id
  when unlock_kind="use_item". Triggered in Player.use_item.
- ItemData.unlocks_class_id / grants_spell_id extras run regardless
  of `effect` match — so a flavour-less "study" book still unlocks +
  teaches its spell.
- Default-unlocked entries (Human race, Warrior/Mage/Rogue classes)
  have `unlocked = true` in their .tres.

### Input
- Keyboard: arrow / WASD / HJKL.
- Touch: tap map → single step in dominant axis (bump attack on
  occupied tile). Tap self = wait.
- Pinch zoom via ZoomController (from oldproject UI whitelist).

### CI / Web
- `.github/workflows/deploy-web.yml` builds Godot 4.6.2 HTML5 →
  GitHub Pages. `export_presets.cfg` has "Web" preset at repo root.
- CREDITS.md lists SRD 5.1 (CC BY 4.0), DCSS CC0 tiles, Godot MIT.

## Pending roadmap — ordered by value

### A. Combat / content
1. **Weapon brands** — `ItemData.brand` field exists. Wire flaming /
   freezing / venom / electric / vorpal / draining in
   `CombatSystem.player_attack_monster` after base damage (§4.5a).
2. **Targeted spell UI** — tap a tile to aim Fireball / Lightning /
   targeted Ice Bolt. Currently all damage spells auto-target nearest.
   Unblocks wand items too.
3. **Player ranged attack** — bow weapon + `ranged` skill +
   direction-pick UI (or tap a far tile).
4. **Identification system** (§4.8) — per-run pseudonym pool for
   potions/scrolls/books. GameManager.identified dict already exists;
   needs display-name override in BagDialog.
5. **Wand items** — charges in `plus` field. Reuses targeting UI.

### B. Dungeon / environment
6. **Cellular automata caves** (§4.2b) — pick per depth band for gen
   variety. Add to `MapGen`.
7. **Clouds** (§4.10) — fire/cold/poison/smoke tile overlays with
   duration + per-turn damage.
8. **Doors / traps** — door tile enum exists but unused. Trap
   placement mentioned in §4.2c, unimplemented.

### C. Meta / shops
9. **Rune shard spend screen** — MainMenu "Rune Shards" currently just
   shows balance. Permanent upgrades (start HP+5, +1 starter potion,
   **manual race/class unlock as shard sink** for players who don't
   want to grind the kill-trigger).
10. **Shopkeepers** — special tile on some floors, gold-for-item.

### D. Polish / bugs
- **Monster status ticks not running** — `Monster.status` dict never
  advances. If confused/fear/haste are added for monsters, need to
  call tick_statuses in `Monster.take_turn` or `MonsterAI.take_turn`.
- **Game.gd ~500 lines** — signal routing methods could move to a
  helper. Not urgent.
- **JobSelect locked card UX** — shows hint but user can still tap
  card; should be visually disabled (button disabled alone isn't
  obvious enough).

## Architecture — respect these

- **9 autoloads**: `GameManager` (run state + settings + unlocks +
  unlock trigger helpers), `TurnManager`, `CombatLog`, `SaveManager`,
  `MonsterRegistry`, `ItemRegistry`, `ClassRegistry`, `SpellRegistry`,
  `RaceRegistry`. Adding a new content type = add one autoload + one
  directory under `resources/`.
- **Content is preload-baked into the registry script**, NOT scanned
  at runtime. Adding a new .tres = add a `const _X: Resource = preload(...)`
  line + include it in `_ALL_*` array. Avoids Godot's autoload-phase
  filesystem scan failing on fresh clones.
- **class_name globals**: `Player`, `Monster`, `FloorItem`,
  `DungeonMap` (entities) and `CombatSystem`, `MonsterAI`,
  `MagicSystem`, `MapGen`, `FieldOfView`, `MinimapRenderer` (static
  RefCounted modules). Prefer this over preload-by-path for system code.
- **Paper-doll**: Player holds `_base_tex` + `_body_doll_tex` +
  `_hand1_doll_tex`. `set_race_from_id` / `set_equipped_weapon` /
  `set_equipped_armor` are the setters — they call
  `_refresh_paperdoll` which is the ONLY path to keep sprite in sync.
  Never set `equipped_weapon_id` directly.
- **Unlock trigger flow** — anywhere you implement a new kill or use
  path, call `GameManager.try_kill_unlock(monster_id)` or
  `GameManager.try_use_unlock(item_id)` so new unlock conditions added
  to race/class .tres files just work.
- **Save schema** — single source `SaveManager.save_run`. Add new
  fields to the nested `player` dict and rehydrate in
  `Game._apply_loaded_player_state`. Legacy saves without a key fall
  through to field defaults.
- **GameDialog chrome** — every popup reuses `GameDialog.create(title)`
  + `.body()`. New dialogs = `class_name XDialog extends RefCounted`
  with a `static func open(player, parent)`. No new popup .tscn files.

## Known gotchas

- `BagTooltips.gd` and `SkillsScreen.gd` from oldproject — NOT copied.
  Use `BagDialog` / `SkillsDialog` (written fresh on GameDialog).
- `Godot_v*.exe` binaries live in repo root but are gitignored. WSL
  can't run them. User must test in Windows Godot editor or wait on CI.
- `CELL_SIZE = 32`. Default camera zoom 1.2 (zoom buttons 0.7-2.2).
- BottomHUD font sizes tuned for 720×1280 viewport; re-scaling needs
  both tscn font values + HUD anchors updated.
- Godot often re-saves .tres files and strips `load_steps` — harmless.
  Also sometimes regenerates the `uid://...` — harmless; commit the
  new uid.
- Some in-game Edits hit "File has not been read" race with Godot
  re-saves. If an edit seems to vanish, re-read the file, re-apply.

## Next-session first steps

1. `git log --oneline` to see what landed.
2. Re-open `/mnt/d/PROJ_D/` in Godot editor → wait for import to
   settle (watches for `.tres` / `.import` updates).
3. F5 to smoke-test — MainMenu → New Run → RaceSelect (Human) →
   JobSelect (Warrior) → walk, bump a rat, descend, die, see shards.
4. Pick a task from roadmap §A — weapon brands and targeted spell UI
   are the two highest-value next moves.
