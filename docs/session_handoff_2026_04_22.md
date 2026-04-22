# Session Handoff — 2026-04-22 late

Picked up by the next session. Everything listed below is **queued, not
in progress** — current HEAD (`799411ad`) is clean and runnable.

## Active bug queue (user-reported, unresolved)

Reported while testing the archmage Spell Test build on mobile web.
Item `#1` is already fixed in `799411ad`; the rest are untouched.

1. ~~Second tap on an area spell moves the player instead of firing.~~
   **Fixed in `799411ad`** (TouchInput.gd no longer auto-disables
   `targeting_mode` between the preview tap and the confirm tap; the
   confirm / cancel branches inside
   `GameBootstrap._on_target_selected` now turn it off themselves).
2. Status dialog should show current move speed (see Haste effect),
   mutation list, and piety progress. Currently shows stats + resists
   + skills + gear but not speed / mut / piety.
3. Potion of Invisibility should dim the player sprite while active —
   set `player.modulate.a` around 0.45 while `_invis_turns > 0`, restore
   on expiry. Status check already exists (`has_meta("_invis_turns")`).
4. Scroll of Teleportation should defer the actual teleport by N turns
   (DCSS: delayed tele counter). Currently fires immediately. Add a
   `_pending_teleport_turns` meta + a per-turn tick that teleports
   when it hits 0.
5. `TileRenderer.ITEMS` dict is missing entries for some books and for
   every wand. Books that do have entries render via
   `item/book/*` paths; wands default to the fallback blob. Scan the
   `assets/dcss_tiles/individual/item/book/` + `/wand/` directories
   and fill the dict.
6. Magic dialog lists every learned spell flat. Split into school
   headers (Fire / Cold / Earth / Air / Necromancy / Alchemy / Hexes /
   Translocations / Summonings / Conjurations) so it reads cleanly.
   Also: when the player reads a spellbook at full memory capacity,
   the book is consumed but no spell is learned — book should stay in
   the bag on that failure path.
7. Equipping the 8 test-character unrands from `_apply_test_character_
   boost` leaves the paper-doll nude. The doll layer lookup
   (`TileRenderer.doll_layer`) probably has no entry for those unrand
   ids, so the composite falls back to the bare race body. Either add
   a generic overlay per slot or wire each test unrand to a
   representative base-item tile.
8. Scroll of Silence: no visible aura drawn, player can still cast.
   Effect is set correctly in `Player._apply_consumable_effect`
   (line ~2875) but the SpellCast silence gate reads the *player's*
   `_silenced_turns` meta — confirm that meta is actually being set,
   that the counter ticks, and that SpellCast.cast reads it. Also add
   a faint halo overlay in DungeonMap for the duration.

## Deferred port items (not yet started)

Originally slated under L2-L5 but deleted from the task list to keep
the refactor session clean. Re-add when the bug queue is empty.

- **L2 — Penetration brand (ranged).** Bow/crossbow/slingshot pieces
  with this brand hit every monster on the beam line instead of the
  first. Reuses `Beam.trace` + `_beam_path_hits`.
- **L3 — Stair-up escape confirm.** Tapping stairs-up on D:1 of the
  main trunk should pop a recap dialog before `_end_run` fires, so
  Orb-less accidental exits don't blow the run.
- **L4 — Translucent stone tile.** Variant of `GLASS_WALL` with a stone
  palette instead of blue — same movement-blocked / sight-through
  semantics, placed as a vault feature.
- **L5 — Autofight smart target priority.** `_on_auto_attack_pressed`
  picks Chebyshev-nearest; switch to a weighted pick that prefers
  low-HP / high-HD targets when distance ties.

## Refactor pipeline

Extraction candidates for GameBootstrap.gd (currently ~5000 lines),
in recommended order. `R1` (TrapEffects) is in flight right now.

| Module | Est. lines out | Risk |
|---|---|---|
| `R1` TrapEffects | ~180 | Low — self-contained |
| `R2` GodInvocations | ~400 | Medium — reads player + monster state |
| `R3` IdentifyDialog | ~100 | Low — standalone dialog builder |
| `R4` BagDialog | ~300 | Medium — touches equip/unequip paths |
| `R5` MagicDialog | ~300 | Medium — mirrors BagDialog scope |
| `R6` GodConducts | ~80 | Low — pure helpers |
| `R7` CloudHooks | ~60 | Low — pure helpers |

Target: pull ~1400 lines, leaving GameBootstrap around 3600 — still
big, but narrowly the scene-tree orchestrator.

## Ground rules for the extraction

- Static modules in `scripts/systems/` or `scripts/ui/`.
- No `@onready` / `$path` inside extracted code — callers pass the
  nodes / arrays they need as parameters.
- Autoloads (`GameManager`, `CombatLog`, `TurnManager`,
  `BranchRegistry`, etc.) are fair game from anywhere; they're
  globally resolvable.
- Each extraction is its own commit with a before/after line delta
  in the message body.
- Behaviour parity first, improvement second. Don't refactor logic
  while moving it.
