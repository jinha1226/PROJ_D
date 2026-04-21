---
name: DCSS port backlog 2026-04-21
description: Remaining DCSS systems to port or finish. Organised by impact; strike through as each lands. Consult before picking the next porting task.
type: project
originSessionId: a6787a73-c32f-4d97-bf7b-67620bf7e827
---
## 🔴 High-impact (big feel / big content)

- [x] **Beam travel (beam.cc)** — d6dfdab7: Beam.gd walks Bresenham supercover ray, stops at walls, records monster hits, pierces for bolt_of_* spells. Still partial: no tile-set-on-fire (burn_wall_effect), no reflection shields, no beam bouncing.
- [~] **God invocation full-parity** — PARTIAL (8d64f889 + 7056ad5f):
  - [x] Makhleb Minor/Major Destruction — rolls from DCSS pool
    (throw_flame/iron_shot/bolt_of_fire/lehudibs/...) via
    _makhleb_random_zap.
  - [x] Okawaru Duel — teleports player adjacent + flees nearby
    monsters (arena approximation).
  - [x] Sif Muna Divine Exegesis — full MP refill + _exegesis_turns
    meta forcing fail_pct=0 for 3 casts.
  - [x] Ashenzari Transfer Knowledge — 1500 XP split across currently-
    trained skills. Passive: cursed slots → +5% XP/slot on kill.
  - [x] Vehumet Gift Spell — piety-tiered pool, respects memorisation
    cap.
  - [x] Fedhas Sunlight/PlantRing/Rain — damage undead, summon plant
    allies, convert FLOOR→WATER nearby.
  - [x] Lugonu Corrupt Level — banish top-5 HD + confuse remainder.
  - [x] Hepliaklqana Idealise/Transference — ally heal+haste, swap
    positions with nearest ally.
  - [ ] Trog gift weapons at piety milestones — TBD
  - [ ] Okawaru weapon/armour gifts — TBD
  - [ ] Sif spellbook gifts — TBD
- [ ] **God passives unrelated to invocations**: Vehumet MP discount on destructive spells, Cheibriados speed-proportional bonus, Gozag gold-only economy, Ru sacrifice system.
- [x] **Weapon brands — full DCSS roster** — 32dd5259: added drain/distortion/antimagic/protection/pain/vorpal/reaping/chaos. Remaining gaps: penetration (needs ranged attack flow), reaching (already covered by polearm reach).
- [x] **Body-armour egos — full roster** — 32dd5259 + 4ec67fdd:
  27 entries in ArmorRegistry.EGOS; all five outstanding flag
  handlers now wired — FLYING plumbs into `_flying`, REFLECTION
  bounces 25% of archer shots back at the shooter, RAMPAGING grants
  +1 speed_mod on moves toward visible hostiles, MAYHEM fears nearby
  enemies (radius 3) on a killing blow, SPIRIT_SHIELD was already
  splitting HP→MP via Player.take_damage.
- [x] **Amulet roster** — 5c2c6d18: AmuletRegistry.gd with 9 entries (Faith/Magic Mastery/Regen/Acrobat/Reflection/Stasis/Guardian Spirit/Gourmand/Nothing). equip_amulet slot on Player; spirit_shield splits HP→MP; stasis blocks tele/blink; acrobat +5 EV on non-combat turns; faith +50% piety; floor drops 2%; bag UI + TileRenderer tiles.
- [~] **Portal vaults** (timed mini-branches) — 5/10 shipped (fa337e7f):
  Sewer / Ossuary / Bailey / Volcano / Icecave. New `is_portal` flag
  in branches.json + `duration` / `monster_pool` / `entry_msg` fields;
  BranchRegistry exposes helpers; GameManager seeds `portal_turns_left`
  on enter; `_on_turn_tick_portal` ticks + collapses at 0 via
  `leave_branch` + `_regenerate_dungeon(going_up=true)`. Arrival
  announce logs "A portal to X shimmers somewhere on this floor".
  Still missing: Wizlab, Trove, Labyrinth, Desolation, Gauntlet.
- [x] **Branch theming** — DONE (89229a3f + 38fbe82b + d7bf79e3):
  - [x] Orcish Mines: Beogh orc conversion wired (CombatSystem.
    _maybe_beogh_convert on melee hit, piety-scaled 10-20% chance,
    swaps Monster → Companion reusing the same MonsterData + hp).
    Mines density bumped (debris 8→14) for grittier feel.
  - [x] Lair: trees 22→28, 2-5 small water ponds via _place_pools.
    Wolf/warg/yak/bear/elephant/hippogriff pack bands added.
    Snake/Spider sub-branch bands (black_mamba, anaconda, spider,
    redback) land simultaneously.
  - [x] Elven Halls: deep_elf faction packs (archer/knight/priest/
    mage/sorcerer/demonologist) + overlapping-boxes gen + extra
    vault stamps (38fbe82b).
  - [x] Slime Pits: dedicated TileType.ACID (9c650c41) — distinct
    from LAVA, blocks movement unless rCorr ≥ 1, teleport-landing
    damages. Slime gen places ACID pools.
  - [x] Vaults / Zot: Vaults gets 6 vault stamps vs 3 elsewhere
    (38fbe82b); Zot gets CRYSTAL_WALL recoloring of 60% stone walls
    (d7bf79e3) for the signature pink crystal halls.
  - [x] Crypt / Tomb: overlapping-boxes gen + undead-heavy spawn
    bands (skeletal_warrior/mummy/wraith leading zombie/wight
    followers, 38fbe82b).
  - [x] Hell / Pan / Abyss specialised gen (d7bf79e3):
    abyss = cave + small lava pools + debris;
    pan = overlapping_boxes + 4 lava pools;
    hell = caves + 5 lava pools + debris (Dis/Gehenna/Cocytus/
    Tartarus/Vestibule all route to this via tileset_branch).

## 🟡 Medium (partial implementations)

- [x] **Monster AI intelligence** — DONE (d7edc8ea + 479a851a + 4ec67fdd).
  Flee tightened, caster kiting, emergency slot priority, silence per-row
  filter, friendly-fire tracer. Final closer: DCSS `cautious` flag now
  read — cautious non-casters with no ranged attack hold position instead
  of walking into a swing. All AI-intel items closed.
- [x] **Monster energy types** — DONE (d7edc8ea). MonsterData exports
  move/attack/spell/missile/swim energy (default 10/6). MonsterRegistry
  applies mon-data.h overrides for naga (move=14), bat (move=5), centaur
  (move=6, missile=7), fire_dragon (attack=15), jelly (move=14,attack=14),
  adder (attack=8), wasp, spriggan, etc. MonsterAI.act returns the
  action cost; Monster.take_turn drains _action_energy by that cost.
- [x] **Monster pack/tactical behaviour** — PARTIAL (479a851a). Pack
  formation: `_maybe_wander` now steers toward the nearest hostile-side
  monster within 6 tiles when the gap is ≥3, so bands stay clustered
  instead of drifting. Caster kiting shipped under AI-intelligence.
  Tactical retreat (explicit fall-back-to-ally-line beyond the
  formation tendency) and cover/flanking still minimal — skipped
  because the game has no ranged-attack flow yet, so there's no
  "covered" state to coordinate around.
- [x] **Transformation forms** — DONE (3977c398 + pre-existing). Form
  JSON already had 30 forms (dragon/statue/tree/hydra-ish/bat/bat_swarm/
  spider/serpent/storm/sphinx/death/...). apply_form previously applied
  only generic stat/AC/HP deltas; now it also reads per-form
  unarmed_base (→ CombatSystem melee bonus when weaponless), move_speed
  (< 10 → _form_move_bonus for fast forms), size (→ _form_size_factor
  read by PlayerDefense), and melds (slot list stashed for UI). Scaling
  with a shapeshifting skill is still flat — our SKILL_IDS has no
  transmutation school, so unarmed_scaling / ac_scaling are no-ops for
  now (revisit when a Shapeshifting skill lands).
- [x] **Poison levels** — DONE (d7edc8ea + earlier). Player had 3-level
  stack from session 5; this session added Monster.apply_poison mirroring
  it. Venom brands / naga tail slap / AF_POISON monster flavour / scroll
  of poison all route through it. rPois+ drops incoming level by 1,
  full immunity (undead/demons/jellies) rejects entirely.
- [x] **Status effects (core)** — f71a217c: Slow/Fear/Charm/Blind/Corona/Daze gameplay wired. Poison 3-level stacking. Remaining: Frozen, Weakness, Silenced expansion, Enthralled, Liquefaction.
- [ ] **Dungeon-feature tile behaviour** — lava/water blocking certain monsters, Teleport trap destination targeting, Zot/Shaft/Golubria traps, glass walls, translucent stone.
- [ ] **Unarmed Combat skill** — skill doesn't exist; monk/brawler unarmed damage is flat.
- [ ] **Invocations skill power scaling** — god abilities don't scale with invocation level.
- [x] **Walking noise** — 2b243722: Player.try_move emits a body-armour-EVP-scaled DCSSNoise pulse (plate=loud, robe=silent). Stealth still trims.
- [x] **Monster shout** — 32dd5259: MonsterAI.wake emits HD-scaled DCSSNoise (hiss 4 → roar 12). Silent-shape jellies and silent-flag mobs muzzled. Wave propagates through walls via the noise grid.
- [~] **Unrandarts** — 50/~200 (29629b76 + 25dc8da7 + 555e1105 +
  3394dbc3). UnrandartRegistry holds entries; WeaponRegistry /
  ArmorRegistry synthesize rows on demand for `unrand_` ids.
  Effects reuse existing brands / egos / ring props — no per-artefact
  special code. Drops at 1.5% per item roll from depth ≥ 5.
  Expansion = just append entries. 22 weapons, 10 armor, 3 aux,
  4 rings, 4 amulets shipped.
- [x] **Randart generation** — 2e17d103: RandartGenerator.gd with 17-prop weighted pool, depth-scaled 1-4 properties, "the Adj Noun" names. Rings only (amulets TBD). Floor drops 15% randart at depth≥4. Equip + tooltip wired.
- [ ] **Identification system** — all items pre-identified; DCSS hides potion/scroll/ring/armour appearances until identified.
- [x] **Player willpower stat** — b842a303: Stats.WL seeded from _race_base_wl (formicid=270 immune, mummy/vine=80, …). _recompute_gear_stats: WL=base+XL*3+willpower_ego*40. willpower_check(hd): random(0..hd*5+30)<WL. Wired in MonsterAI hex branch: confuse/paralyse/slow/fear/charm check WL first. 7-level resist display fixed (rF+ shows "+", not "++"). _apply_elem_resist: rl≥3=immune, -1=×1.5, -2=×2, ≤-3=×3. get_resist() unified source for all racial intrinsics + gear + mutations. Status panel: 5 elemental + WL/rCorr/rMut row.

## 🟢 Small (QoL, nuance)

- [x] **Cleaving** — 2b243722: WeaponRegistry.weapon_cleaves, axes+bardiche. Flank tiles attacked after main swing.
- [x] **Reach** — 2b243722: WeaponRegistry.weapon_reach, polearms=2. Middle-tile clearance enforced; TouchInput auto-routes 2-tile taps.
- [x] **Auxiliary attacks** — 2b243722: minotaur/naga/tengu/centaur/draconian/octopode each fire ~1/3 on connecting hits. Damage scaled by XL. Simpler than DCSS full formula.
- [x] **Ranged-combat range penalty** — DONE (b497954c). CombatSystem.
  ranged_attack applies -3 to-hit per tile past 2 (DCSS ranged_penalty).
  Monster archer path has the same penalty. Player "fire" action (KEY_F)
  enters targeting mode; cap range 7 tiles. MonsterData gains
  ranged_damage/ranged_range + MonsterRegistry._RANGED_OVERRIDES table
  for centaur/yaktaur/deep_elf_archer/kobold_brigand/satyr/faun/
  merfolk_javelineer/orc_warrior/centaur_warrior/yaktaur_captain.
- [x] **Projectile path fidelity** — DONE (b497954c). Ranged attacks
  now walk a bresenham line from attacker to target (Monster side uses
  _path_has_ally guard; player side routes through CombatSystem).
  Walls stop the shot; hostile allies on the path abort the cast.
- [x] **God conducts** — DONE (4ec67fdd). _apply_god_conduct runs
  between kill_piety and cap-clamp: TSO +50% evil kills, Yred +2 holy
  / -1 undead, Zin +1 demonic / -1 chaos/shapeshifters, Elyvilon -1
  non-evil kills, Beogh -3 orc kills, Fedhas -2 plant kills. Negative
  gains trigger a "X frowns at you" log + piety loss. Remaining
  content-gated: Cheibriados haste-ban (enforced at buff sites, not
  kill-time), Okawaru summon/ally-ban (needs summoning flow).
- [x] **Morgue / character dump** — DONE (2ce736ad). user://morgues/
  morgue-<stamp>.txt on run-end with outcome/slayer/character/god/
  depth/turns/kills/stats/AC/EV/SH/WL/equipped gear/resistances/
  learned spells + memory usage.
- [x] **High score board** — DONE (2cfc1429). MetaProgression now
  keeps a 50-entry `runs_history` array with full per-run context
  (race/job/god/level/depth/branch/turns/kills/victory/killer/
  timestamp). `get_top_runs(n)` returns sorted leaderboard for the
  main-menu UI when that lands. Data persists via SaveManager.
- [x] **Help pages / in-game docs** — DONE (2ce736ad). KEY_? opens a
  GameDialog with 6 sections (Controls / Combat basics / Skills /
  Identification / Gods & piety / Status effects). Substitute for
  DCSS's ~15 ref pages.
- [ ] **Macros** — none (low priority on mobile).
- [ ] **Command search** — `?/` lookup missing (would need a
  search-across-JSON dialog; deferred).
- [x] **AoE targeter preview** — 2b243722: orange AoE overlay (area spells) + cyan beam trail (single-target zaps) painted during targeting mode. Cleared on target-select.

## Crossing off

When a backlog item lands, replace its `[ ]` with `[x] (<commit-hash>)` and note which parts are left (if partial). Do NOT delete — the history matters for later retrospectives.

## Active picks (top-of-stack — updated 2026-04-21 session 7)

**UI upgrade COMPLETE** — plan at `docs/superpowers/plans/2026-04-21-ui-upgrade.md`
fully shipped across tasks 1-8.
- Task 1-3 landed session 6 (GameDialog scaffold + UICards + Status).
- Session 7 landed the real root-cause fix for the "Status won't open"
  bug (b6120b70) — `accept_event()` is Control-only, call
  `get_viewport().set_input_as_handled()` from a CanvasLayer instead.
  The session-6 "nested CanvasLayer" diagnosis was wrong; nesting
  CanvasLayers DOES render, the parse error was the real problem.
- Session 7 also shipped Tasks 4-8: Skills ACTIVE Training/Learned
  split (3eb86e99), Bag equipped 2-col card grid (3df8c901), Magic
  school pills + accent Pow/Fail (36a91f08), Map Current-Floor card
  + Legend (1c26527d), and the 10-dialog mass migration to GameDialog
  (cdd1f2b2). Zero AcceptDialog references remain in GameBootstrap.
- Side-fix: rPois displays as `+++` for innate-immune species (f28d091c).

Back on the DCSS-port queue below.

Gods deferred per user direction — don't start god invocation parity
unless explicitly asked. User's queued order:

1. ~~**Amulet roster**~~ — DONE 5c2c6d18
2. ~~**Ring multi-stat coverage + randart generation**~~ — DONE 2e17d103
3. ~~**Player willpower stat + hex resist + 7-level resist**~~ — DONE b842a303
4. ~~**Status effect breadth (core)**~~ — f71a217c: Slow=half-speed(_slow_skip alt), Fear=block-toward-monster, Charm=no-attack, Blind=FOV→2+EV-5, Corona=stealth→0, Daze=33%scatter+EV-2, Poison 3-level(apply_poison helper, rPois check, stacking). MonsterAI: blind/corona/daze/slow/fear/charm spells wired. Remaining: Frozen, Weakness, Silenced expansion, Enthralled.
5. ~~**Status effect breadth (remaining)**~~ — PARTIAL, session 8 (32c64621):
   Frozen (new, cold-dmg rider), Weakness (new, -33% melee), Petrifying
   slowdown (was already transitioning, now also slows), Exhausted
   gameplay (was ticking only, now blocks re-berserk + slows). Paralysis/
   Petrified/Frozen all block SpellCast.cast too. Mesmerised: already
   shipped in session 5 (_mesmerised_turns + try_move block).
   **Still deferred (content-gated)**: Silenced expansion needs
   silence-aura monsters (DCSS silent spectre et al. — not ported);
   Enthralled needs friendly-monster state (tangled with Companion
   system); Liquefaction needs the Liquefy Earth spell + a LIQUEFIED
   tile type. Pick these up when the trigger content lands.
6. ~~**Dungeon tile behaviour**~~ — PARTIAL, session 8:
   Shaft trap (new — drops victim 1-3 floors via `_regenerate_dungeon`),
   Teleport trap DCSS-targeting (retry up to 20× until ≥6 tiles away).
   **Already shipped pre-session**: Water/Lava traversal by race via
   Player._player_can_walk_on (merfolk swim, tengu fly water, djinni
   fly water+lava). **Deferred (no trigger content)**: Golubria pair
   portal (needs the spell), glass/translucent walls (needs a vault/
   branch that places them — DCSS-style `o`/`n` wall variants).
7. ~~**Unarmed Combat skill**~~ — DONE session 8 (e66e3b96):
   "unarmed_combat" in SkillSystem.SKILL_IDS (weapon category); aptitude
   alias → JSON "unarmed"; Player.get_current_weapon_skill returns
   "unarmed_combat" when unarmed so XP tags correctly; CombatSystem
   adds +1 flat damage per 3 skill levels on top of the weapon-skill
   multiplier; attack_delay mindelay reduction uses unarmed_combat
   when fistfighting. SkillRow + _SKILL_DESCS entries for display.
8. ~~**Identification system**~~ — DONE session 8 (d49ac290) + pre-existing:
   Potions/scrolls already had per-run pseudonyms. This session added
   rings ("Silver Ring", "Ruby Ring", …) and amulets ("Brass Amulet",
   "Cameo Amulet"). display_name_for_item routes ring/amulet kinds
   through the pseudonym table; randarts (`randart_*` id prefix) are
   excluded — they keep their rolled artefact name. DCSS put-on
   identification: Player.equip_ring / equip_amulet now auto-identify
   non-randart base items on equip (item-use.cc parity).

After those: monster AI intelligence, per-monster energy types,
portal vaults (Sewers/Ossuary), transformation form expansion,
branch theming (Orc/Elf/Lair), unrandart roster, morgue dump, UI
help pages / macros / `?/` search.

**Don't start** (deferred until user asks): god invocation parity,
god passives, god conducts — user explicitly pushed gods to last.

## Latest commits (since 2c16a61b, 2026-04-20..21 wholesale porting push)

Chronological list so the next session knows where each system lives:
- 2c16a61b — faithful FOV / SpellCast / PlayerDefense
- 66a87311 — AC soak, GDR, MP regen divisor, DCSSNoise
- e0187252 — spell enhancer ×1.5
- 61004d2a — calc_dice div_rand_round + attack_delay skill cap
- befaeb0e — check_awaken + monster_perception + player_stealth
- efed3f77 — intel_factor enum mapping fix
- 5057c295 — stab formula (good/bad stab denominators)
- 144f480e — explicit Callable for FOV + defensive Cheb fallback
- 4a74810c — slaying bonus random2(1+plus) + monster resist divisor
- 4f797418 — monster flavour damage (AF_FIRE/COLD/ELEC/PURE_FIRE/ACID/DROWN/VAMPIRIC)
- bb54c0bb — zoom/auto-move tuning + spawn diagnostics
- cf2a140a — MainMenu call_deferred + faster auto-move
- 01eb8b50 — Monster holiness from flags/shape (not .get 2-arg)
- 34a95cd2 — Noise → DCSSNoise rename (engine class clash)
- 7dc99bc2 — String(x or y) replaced with typed guard
- 26c10352 — zoom +1 step, damage diag
- c87facbd — mobile zoom, item density cut, troll-armour monster-only, regen readout
- 76a36b6b — per-god DCSS altar tiles
- f25189b4 — stair exit guarantee + god guide popups + piety card + bigger status fonts
- d6dfdab7 — Beam.gd travel
- 2b243722 — AoE/beam preview + reach + cleave + aux attacks + walk noise
- 32dd5259 — monster shout + weapon brand roster + armour ego roster (27 SPARM egos)
