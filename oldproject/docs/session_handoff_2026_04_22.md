# Session Handoff — 2026-04-22 late (updated 2026-04-23)

Next session pick-up. HEAD is clean and runnable.

## Refactor pipeline — status

| Module | Lines out | Status | Commit |
|---|---|---|---|
| R1 TrapEffects | ~107 | ✅ done | `1eeae81f` |
| R7 CloudHooks | ~62 | ✅ done | `3942cbe2` |
| R6 GodConducts | ~80 | ✅ done | `3942cbe2` |
| R3 IdentifyDialog | ~108 | ✅ done | `3942cbe2` |
| R2 GodInvocations | ~497 | ✅ done | `c59f6829` |
| R4 BagTooltips | ~281 | ✅ done (partial) | `d0edfb57` |
| R5 MagicDialog | ~150 | ✅ done + bug #6 fix | (this session) |

**GameBootstrap size**: ~7700 → 6414 lines (≈17% smaller, 7 modules
extracted, ~1285 lines moved out).

## Remaining refactor work

R4 was a partial extraction — it pulled the read-only bag helpers
(tooltip builder, thumbnail, info popup) but left the live dialog
state behind. Similarly R5 kept equip/use/drop callbacks in
GameBootstrap because they touch dialog re-open state.

- **R4.2** — Move `_on_bag_pressed`, `_open_bag_filtered`,
  `_build_equipped_section`, `_bag_category` state into
  `scripts/ui/BagDialog.gd`. Equip / use / drop stay as host
  callbacks. **Medium risk** — requires moving `_bag_dlg` +
  `_suppress_bag_reopen` state.
- **R5.2** — Already in good shape; could still move `_on_cast_pressed`
  + `_on_cast_with_targeting` + `_assign_spell_quickslot` into the
  module but they touch `_targeting_spell` state.

## Active bug queue — user-reported

Items `#1`, `#2`, `#3`, `#4`, `#5`, `#6`, `#7`, `#8` all resolved.

1. ✅ Second-tap area spell movement bug (fixed in `799411ad`).
2. ✅ Status dialog expanded: **Active Effects** section lists every
   `_<name>_turns` meta with tint + countdown (Haste, Invisible, Berserk,
   Poisoned w/ dmg/turn, Corroded w/ AC penalty, pending-teleport, …);
   **Mutations** section iterates `player.mutations` with level/max +
   good/bad flag tint via `MutationRegistry.desc_for`; piety card now
   also draws a 6-star rank line.
3. ✅ Potion of Invisibility dims the player sprite — `Player._refresh_invisibility_visual`
   drops `modulate.a` to 0.45 while `_invisible_turns > 0` and restores on
   expire / cancellation. (Meta key was `_invisible_turns`, not the
   `_invis_turns` the earlier handoff used.)
4. ✅ Scroll of Teleportation defers the teleport 3-5 turns via
   `_pending_teleport_turns`. Stasis (formicid / amulet) still fails the
   scroll immediately; `_teleport_random()` re-checks stasis when the
   counter fires, so mid-countdown stasis fizzles safely.
5. ✅ `TileRenderer.ITEMS` — all 9 book ids were already mapped; added
   the 12 `wand_*` entries to `scripts/core/TileRenderer.gd` (gem-material
   tiles picked to evoke each wand's effect).
6. ✅ Magic dialog — split by school header (MagicDialog now groups
   Conjurations / Fire / Cold / … under accent headers).
   ✅ Spellbook at full memory — Player._apply_consumable_effect
   "learn_spells" now returns false when nothing was learned, so
   the book stays in the bag.
7. ✅ Paper-doll nude fix — `TileRenderer.doll_layer` now falls back
   to the unrand's base item tile (via `UnrandartRegistry.get_info`),
   so equipping `unrand_storm_bow` paints the shortbow overlay.
8. ✅ Scroll of Silence gets a visible aura — `Player._SilenceAura`
   inner class draws a pulsing grey ring beneath the sprite while
   `_silenced_turns > 0`. Self-cast check was already in place at
   `SpellCast.gd:60`.

## Deferred port items — all landed

- ✅ **L2 — Penetration brand (ranged).** `_weapon_brand_<id> == "penetration"`
  on a bow triggers `Beam.trace(pierce=true)` in `Player.try_ranged_attack`
  so one shot hits every monster in the line. Scroll of Brand Weapon rolls
  it only when the equipped weapon is bow-skill.
- ✅ **L3 — Stair-up escape confirm.** `_show_escape_confirm()` gates
  `_end_run(true, "")` on D:1 Dungeon ascent with the Orb — recap shows
  XL / turn / kills / runes and a Stay/Escape pair.
- ✅ **L4 — Translucent stone tile.** `DungeonGenerator.TileType.TRANSLUCENT_STONE`
  added (stone-palette render, FOV passes via `_opaque_at` default, not
  in `is_walkable` whitelist). Vaults can now reference it.
- ✅ **L5 — Autofight smart target priority.** `_on_auto_attack_pressed`
  scores by `hd*3 + (1 - hp_ratio)*10 − dist*4` with FOV gating, so the
  bot finishes weakened threats and closes on high-HD foes instead of
  blindly chasing the nearest rat.

## Ground rules

- Static modules live in `scripts/systems/` or `scripts/ui/`.
- No `@onready` / `$path` inside extracted code. Callers pass
  nodes / arrays / Callables as parameters.
- Autoloads (`GameManager`, `CombatLog`, `TurnManager`,
  `BranchRegistry`, `GodRegistry`, …) are fair game from anywhere.
- Each extraction is its own commit with a before/after line
  delta in the message body.
- Behaviour parity first. Don't refactor logic while moving it.
