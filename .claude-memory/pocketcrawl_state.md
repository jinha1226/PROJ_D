---
name: PocketCrawl current state (post 2026-04-23 autonomous session)
description: Snapshot of PocketCrawl new project — what systems exist, what's in the roadmap, and architecture decisions future sessions should respect before extending
type: project
originSessionId: 1cc7ec78-12c9-429a-9ad0-009a1a55bfef
---
PocketCrawl (MIT) is the active project at `/mnt/d/PROJ_D/` root.
`oldproject/` is the archived DCSS GPL port — do NOT mix code back
across the firewall. See `reboot_decision.md` (memory) and
`docs/clean_room_reboot_guide.md` (in repo) for the pivot context and
architecture guide.

## What's already built

Week 1 Days 1-5 (guide §5) + several §4/Week 2 systems are landed
across commits `89ddfa61…bb55c12c` (roughly 29 commits on 2026-04-22→23):

- Core loop: TurnManager with reentrancy guard, FOV shadowcasting
  (§4.3), BSP map gen (§4.2a), stairs → depth regen
- Combat: bump melee (§4.5a), ranged monster attacks (§4.9 extended),
  weapon +N / armor +N read in formulas
- Classes: 3 (warrior / mage / rogue) via JobSelect scene; class data
  sets starting HP/MP/stats/skills/weapon/armor/spells
- Level-up (§4.4): XP curve table, HP+(5+STR/5), MP+(2+INT/4), auto
  stat bumps at XL 12/15/18
- Magic (§4.7 MVP): 3 spells — Magic Dart (auto-target nearest in
  FOV) / Heal Wounds (self) / Blink (self). Mage starts with all 3.
- Skills (§4.6): 8 skills (blade/blunt/dagger/polearm/ranged/armor/
  magic/stealth), grow from use, +5% dmg + +1 to-hit per level for
  weapon skills; armor skill reduces armor EV penalty 10%/level;
  magic skill boosts power + lowers fizzle.
- Status effects (§4.11 minimal): "poison" -1 HP/tick, applied by
  adder bite. Framework extensible — add cases in
  `Player._apply_status_tick`.
- Items: 14 across weapon / armor / potion / scroll / gold. Enchant
  scrolls (weapon/armor +1) use per-instance `plus` field.
- Monsters: 10 types (rat/bat/kobold/goblin/hobgoblin/adder/gnoll/
  orc/ogre/orc_wizard). orc_wizard is first ranged caster.
- UI: TopHUD HP/MP/XP/gold/depth + minimap thumbnail, BottomHUD 8
  quickslots + action buttons, CombatLogStrip overlay above BottomHUD,
  Bag/Magic/Skills/Status/Help/Shards/Death dialogs — all on
  GameDialog chrome.
- MainMenu (포켓크롤) with ContinueButton (shows only if save exists),
  StartButton → JobSelect, Display toggle (Tiles/ASCII), ShardsButton,
  HelpButton.
- Save / Continue via `user://save.json`. Death deletes save. Menu
  exit preserves save if player alive.
- Rune shards meta-currency: earned on death (`depth*2 + xl*3`),
  persisted to `user://settings.json` — spend screen not built yet.
- ASCII / Tile render toggle persisted across sessions; each entity's
  `_draw` branches on `GameManager.use_tiles`.
- Depth-banded terrain art: dirt (D1-3) → limestone (D4-7) → bloody
  cobble (D8-12) → crystal (D13+). Walls swap catacombs→brick past 7.
- Web export: `export_presets.cfg` "Web" preset + existing
  `.github/workflows/deploy-web.yml` (Godot 4.6.2 → Pages). CI needs
  user to enable Pages source = GitHub Actions once.

## Roadmap — what next sessions should pick up

Ordered by approximate value vs cost:

1. **Targeted spell UI** — tap map to aim a bolt/beam. Unlocks
   Fireball, Lightning, Ice Bolt from §4.7 full roster. Also unblocks
   wand items (they reuse targeting).
2. **Identification system (§4.8)** — per-run pseudonym mapping for
   unidentified potions/scrolls. GameManager has `identified` dict
   already; needs display-name override in BagDialog + pseudonym
   pool.
3. **Clouds (§4.10)** — fire/cold/poison/smoke tiles with per-turn
   damage and duration. Simple overlay dict on DungeonMap.
4. **Rune shard spend screen** — MainMenu's ShardsButton shows
   balance but no purchase. Simple permanent upgrades (starting HP
   +5, extra potion, etc.).
5. **More status effects** — confused (25% random dir), fear (flee),
   haste (2× act), might-temp (+STR for N turns). Scaffolding is in
   `Player._apply_status_tick`.
6. **Weapon brands** — flaming / freezing / electric / venom as
   `ItemData.brand`. Add to `CombatSystem.player_attack_monster`
   after base damage.
7. **§4.2b cellular-automata caves** — alternative gen picked per
   depth band for variety.
8. **§4.5c shield block** — SH stat on ItemData, pre-damage roll in
   CombatSystem, per-turn fatigue.
9. **Shopkeepers** — special tile on some floors, popup to buy with
   gold.
10. **Wand items** — needs targeting from #1; then `effect` =
    "wand_bolt" etc., charges stored in `plus`.

## Architecture — respect these

- **Autoloads (8)**: `GameManager` (run state + settings),
  `TurnManager`, `CombatLog`, `SaveManager`, `MonsterRegistry`,
  `ItemRegistry`, `ClassRegistry`, `SpellRegistry`. Each content
  registry scans its `resources/<kind>/*.tres` on `_ready`. Adding a
  new registry type = add one autoload + one directory.
- **class_name globals**: `Player`, `Monster`, `FloorItem`,
  `DungeonMap` (entities) and `CombatSystem`, `MonsterAI`,
  `MagicSystem`, `MapGen`, `FieldOfView`, `MinimapRenderer` (static
  RefCounted modules) are resolvable from anywhere. Prefer this over
  preloading for system code.
- **Content is .tres-driven** — `MonsterData`, `ItemData`,
  `ClassData`, `SpellData`. Each has `@export var` fields and a
  glyph / tile fallback pair. `kind` dispatches effect handlers in
  `Player.use_item`.
- **Rendering toggle** — every entity's `_draw` checks
  `GameManager.use_tiles` and either calls `draw_texture_rect` or
  `draw_string(glyph)`. Don't duplicate this logic elsewhere —
  reuse the pattern.
- **Turn flow** — Player calls `TurnManager.end_player_turn()` after
  any action. Auto-rest loops use `end_player_turn(immediate=true)`
  to skip the deferred `_start_player_turn` (otherwise the while
  loop self-blocks on `is_player_turn=false`).
- **GameDialog chrome** — every popup reuses `GameDialog.create(title)`
  + `.body()`. New dialogs should be `class_name XDialog extends
  RefCounted` with a `static func open(player, parent)`. Don't
  author new popup .tscn files.
- **Save schema** — `SaveManager.save_run(player, gm)` is the single
  source. Bump `version` in the dict when schema changes; add a
  migration branch in `GameManager.load_run` as needed.

## Known gotchas

- `BagTooltips.gd` and `SkillsScreen.gd` from oldproject are NOT
  copied — heavy DCSS Registry coupling. Use `BagDialog` /
  `SkillsDialog` (already written fresh) and extend them.
- `Godot_v*.exe` binaries live in repo root but are gitignored. WSL
  can't run them; any parse verification from Linux side is blocked.
  User must test in the Windows Godot editor or wait on the CI build.
- `CELL_SIZE = 32`. Camera zoom 1.2 → ~19 tiles visible wide. If
  touching either constant, recompute HUD anchors together.
- `BottomHUD.tscn` was re-anchored bottom-wide with font sizes 24/28
  (oldproject was 1080-wide base). Re-scaling the HUD for a
  different viewport means editing that tscn.
- Physics setting `common/enable_pause_aware_picking` in
  `project.godot` is a Godot 3 leftover — Godot 4 ignores it, safe
  to leave but also safe to remove on next sweep.

## Where to look first

- Repo architecture: `docs/clean_room_reboot_guide.md`
- Legal firewall: `docs/clean_room_reboot_guide.md` §0, §1
- Recent changes: `git log --oneline` (don't ask memory to summarize
  activity — git is authoritative)
- UI whitelist correction: `docs/clean_room_reboot_guide.md` §1a
  (BagTooltips / SkillsScreen exception)
