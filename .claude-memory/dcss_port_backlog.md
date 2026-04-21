---
name: DCSS port backlog 2026-04-21
description: Remaining DCSS systems to port or finish. Organised by impact; strike through as each lands. Consult before picking the next porting task.
type: project
originSessionId: a6787a73-c32f-4d97-bf7b-67620bf7e827
---
## 🔴 High-impact (big feel / big content)

- [x] **Beam travel (beam.cc)** — d6dfdab7: Beam.gd walks Bresenham supercover ray, stops at walls, records monster hits, pierces for bolt_of_* spells. Still partial: no tile-set-on-fire (burn_wall_effect), no reflection shields, no beam bouncing.
- [ ] **God invocation full-parity** (5 popular gods first — Trog / Makhleb / Okawaru / Sif Muna / Ashenzari):
  - Trog: gift weapons at piety milestones
  - Makhleb: Major Destruction should roll from the random DCSS pool (Fireball/Iron Shot/…) not fixed dmg
  - Okawaru: Duel teleport-to-arena, weapon/armour gifts
  - Sif Muna: Divine Exegesis (cast any known spell at +power), spellbook gifts
  - Ashenzari: curse-proportional skill boost passive; Scry/Transfer Knowledge
- [ ] **God passives unrelated to invocations**: Vehumet MP discount on destructive spells, Cheibriados speed-proportional bonus, Gozag gold-only economy, Ru sacrifice system.
- [x] **Weapon brands — full DCSS roster** — 32dd5259: added drain/distortion/antimagic/protection/pain/vorpal/reaping/chaos. Remaining gaps: penetration (needs ranged attack flow), reaching (already covered by polearm reach).
- [x] **Body-armour egos — full roster** — 32dd5259: ArmorRegistry.EGOS with 27 entries; roll_ego rolls 6-25% by depth; Player._recompute_gear_stats folds stat/resist/flag effects. Harm ego wired to take_damage & melee_attack. Remaining partial: RAMPAGING/REFLECTION/SPIRIT_SHIELD/FLYING/MAYHEM need per-system handlers beyond just the flag.
- [x] **Amulet roster** — 5c2c6d18: AmuletRegistry.gd with 9 entries (Faith/Magic Mastery/Regen/Acrobat/Reflection/Stasis/Guardian Spirit/Gourmand/Nothing). equip_amulet slot on Player; spirit_shield splits HP→MP; stasis blocks tele/blink; acrobat +5 EV on non-combat turns; faith +50% piety; floor drops 2%; bag UI + TileRenderer tiles.
- [ ] **Portal vaults** (timed mini-branches) — not implemented at all: Sewers, Ossuary, Bailey, Volcano, Icecave, Wizlab, Trove, Labyrinth, Desolation, Gauntlet. Mid-game interest driver in DCSS.
- [~] **Branch theming** — PARTIAL (89229a3f):
  - [x] Orcish Mines: Beogh orc conversion wired (CombatSystem.
    _maybe_beogh_convert on melee hit, piety-scaled 10-20% chance,
    swaps Monster → Companion reusing the same MonsterData + hp).
    Mines density bumped (debris 8→14) for grittier feel.
  - [x] Lair: trees 22→28, 2-5 small water ponds via _place_pools.
    Wolf/warg/yak/bear/elephant/hippogriff pack bands added.
    Snake/Spider sub-branch bands (black_mamba, anaconda, spider,
    redback) land simultaneously.
  - [ ] Elven Halls: elf faction packs (deep_elf_fighter band exists
    but no elf-specific flavor rules)
  - [ ] Slime Pits: acidic walls (needs new tile behaviour + wall-
    touch damage)
  - [ ] Vaults / Zot: vault-entry lockouts (needs timer mechanic)
  - [ ] Crypt / Tomb: undead-heavy spawn weights (population pools
    already route there; tuning TBD)
  - [ ] Hell 7-floor, Pan 7-floor, Abyss — data only, no special gen

## 🟡 Medium (partial implementations)

- [x] **Monster AI intelligence** — DONE (d7edc8ea + 479a851a). Flee
  tightened (25%→10%, human-only, non-caster, one-shot `_has_fled` flag
  reset at 40% HP). Caster kiting: adjacent casters cast→kite→melee.
  Emergency slot priority: spellbook rows flagged `emergency` gated off
  above 33% HP, tripled below; non-emergency rows halved below. Silence
  only filters `vocal` rows (wizard/priest) rather than aborting the
  whole cast so breath weapons still fire at silenced targets. Friendly-
  fire tracer: `_beam_friendly_fire` walks Bresenham caster→target and
  rejects zap spells whose path crosses another hostile. Remaining nice-
  to-have: DCSS `cautious` flag for monsters that won't approach if
  can't retaliate (very minor, not wired yet).
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
- [~] **Unrandarts** — 12/~200 (29629b76). UnrandartRegistry holds
  entries; WeaponRegistry / ArmorRegistry synthesize rows on demand
  for `unrand_` ids. Shipped: Singing Sword, Bow of Krishna, Plutonium
  Sword, Mace of Variability, Wucad Mu's Staff, Skullcrusher, Storm
  Bow, Robe of Augmentation, Cloak of the Thief, Hat of the Alchemist,
  Ring of Shaolin, Amulet of Bloodlust. Effects reuse existing brands/
  egos/ring props — no per-artefact special code. Drops at 1.5% per
  item roll from depth ≥ 5. Expansion = just append entries.
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
- [ ] **God conducts** — only Trog's cast-anger wired. Zin mutation/chaos, TSO evil-kill-bonus, Elyvilon neutral-kill-penalty, Cheibriados haste-ban, Yredelemnul holy-kill-bonus, Beogh orc-kill-penalty, Fedhas burn-plant-penalty, Okawaru summon/ally-ban.
- [ ] **Morgue / character dump** — no death-log file written.
- [ ] **High score board** — minimal.
- [ ] **Help pages / in-game docs** — minimal; DCSS ships ~15 reference sections.
- [ ] **Macros** — none.
- [ ] **Command search** — `?/` lookup missing.
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
