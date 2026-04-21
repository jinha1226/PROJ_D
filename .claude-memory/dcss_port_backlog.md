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
- [ ] **Branch theming**:
  - Orcish Mines: Beogh worship converts orcs to allies
  - Elven Halls: elf faction packs
  - Lair branches (Swamp / Snake / Spider / Shoals): terrain-specific tile effects (water movement, poison clouds)
  - Slime Pits: acidic walls
  - Vaults / Zot: vault-entry lockouts
  - Crypt / Tomb: undead-heavy spawn weights
  - Hell 7-floor, Pan 7-floor, Abyss — data only, no special gen

## 🟡 Medium (partial implementations)

- [ ] **Monster AI intelligence** — spell selection is simple freq-weighted; port DCSS `_should_cast_spell` tracer beam / friendly-fire check / emergency slot / cautious flag / antimagic resist.
- [ ] **Monster energy types** — flat 10 per action; DCSS has per-monster `mon_energy_usage` (move/attack/spell/missile/swim costs).
- [ ] **Monster pack/tactical behaviour** — leader follow, tactical retreat, ranged support. Currently packs scatter.
- [ ] **Transformation forms** — FormRegistry has 5-6; DCSS has Dragon, Statue, Tree, Hydra, Lich, Bat Swarm, Fungus, Pig, Spider, Flux and form-specific stats/abilities.
- [ ] **Poison levels** — single DoT scalar; DCSS has 3 levels + per-level resist scaling.
- [ ] **Status effects** — Berserk (no post-rage fatigue), Frozen, Petrifying→Petrified transition, Blind, Corona, Enthralled, Silenced (partial), Exhausted, Mesmerised, Weakness, Daze, Liquefaction.
- [ ] **Dungeon-feature tile behaviour** — lava/water blocking certain monsters, Teleport trap destination targeting, Zot/Shaft/Golubria traps, glass walls, translucent stone.
- [ ] **Unarmed Combat skill** — skill doesn't exist; monk/brawler unarmed damage is flat.
- [ ] **Invocations skill power scaling** — god abilities don't scale with invocation level.
- [x] **Walking noise** — 2b243722: Player.try_move emits a body-armour-EVP-scaled DCSSNoise pulse (plate=loud, robe=silent). Stealth still trims.
- [x] **Monster shout** — 32dd5259: MonsterAI.wake emits HD-scaled DCSSNoise (hiss 4 → roar 12). Silent-shape jellies and silent-flag mobs muzzled. Wave propagates through walls via the noise grid.
- [ ] **Unrandarts** — 0 of ~200 implemented (unique named items with hardcoded effects, e.g. Singing Sword, Bow of Krishna).
- [x] **Randart generation** — 2e17d103: RandartGenerator.gd with 17-prop weighted pool, depth-scaled 1-4 properties, "the Adj Noun" names. Rings only (amulets TBD). Floor drops 15% randart at depth≥4. Equip + tooltip wired.
- [ ] **Identification system** — all items pre-identified; DCSS hides potion/scroll/ring/armour appearances until identified.
- [x] **Player willpower stat** — b842a303: Stats.WL seeded from _race_base_wl (formicid=270 immune, mummy/vine=80, …). _recompute_gear_stats: WL=base+XL*3+willpower_ego*40. willpower_check(hd): random(0..hd*5+30)<WL. Wired in MonsterAI hex branch: confuse/paralyse/slow/fear/charm check WL first. 7-level resist display fixed (rF+ shows "+", not "++"). _apply_elem_resist: rl≥3=immune, -1=×1.5, -2=×2, ≤-3=×3. get_resist() unified source for all racial intrinsics + gear + mutations. Status panel: 5 elemental + WL/rCorr/rMut row.

## 🟢 Small (QoL, nuance)

- [x] **Cleaving** — 2b243722: WeaponRegistry.weapon_cleaves, axes+bardiche. Flank tiles attacked after main swing.
- [x] **Reach** — 2b243722: WeaponRegistry.weapon_reach, polearms=2. Middle-tile clearance enforced; TouchInput auto-routes 2-tile taps.
- [x] **Auxiliary attacks** — 2b243722: minotaur/naga/tengu/centaur/draconian/octopode each fire ~1/3 on connecting hits. Damage scaled by XL. Simpler than DCSS full formula.
- [ ] **Ranged-combat range penalty** — bow/xbow accuracy doesn't fall off with distance. (Our game currently lacks an explicit ranged-attack flow, so skipped until that lands.)
- [ ] **Projectile path fidelity** — missiles don't divert or skim walls.
- [ ] **God conducts** — only Trog's cast-anger wired. Zin mutation/chaos, TSO evil-kill-bonus, Elyvilon neutral-kill-penalty, Cheibriados haste-ban, Yredelemnul holy-kill-bonus, Beogh orc-kill-penalty, Fedhas burn-plant-penalty, Okawaru summon/ally-ban.
- [ ] **Morgue / character dump** — no death-log file written.
- [ ] **High score board** — minimal.
- [ ] **Help pages / in-game docs** — minimal; DCSS ships ~15 reference sections.
- [ ] **Macros** — none.
- [ ] **Command search** — `?/` lookup missing.
- [x] **AoE targeter preview** — 2b243722: orange AoE overlay (area spells) + cyan beam trail (single-target zaps) painted during targeting mode. Cleared on target-select.

## Crossing off

When a backlog item lands, replace its `[ ]` with `[x] (<commit-hash>)` and note which parts are left (if partial). Do NOT delete — the history matters for later retrospectives.

## Active picks (top-of-stack — updated 2026-04-21 session 2)

Gods deferred per user direction — don't start god invocation parity
unless explicitly asked. User's queued order:

1. ~~**Amulet roster**~~ — DONE 5c2c6d18
2. ~~**Ring multi-stat coverage + randart generation**~~ — DONE 2e17d103
3. ~~**Player willpower stat + hex resist + 7-level resist**~~ — DONE b842a303
4. **Status effect breadth** (🟡) — poison 3-level stacking, Frozen,
   Petrifying→Petrified transition (partial — tick exists), Blind,
   Corona, Enthralled, Silenced expansion, Exhausted (exists),
   Mesmerised (exists), Weakness, Daze. Paralysis/Slow/Fear/Charm
   durations now tick but no gameplay effects beyond movement block.
5. **Status effect breadth** (🟡) — poison 3-level stacking, Frozen,
   Petrifying→Petrified transition, Blind, Corona, Enthralled,
   Silenced expansion, Exhausted, Mesmerised, Weakness, Daze. Each
   is a small duration meta + tick in Player._tick_duration_metas
   + interaction site (hit / move / cast).
6. **Dungeon tile behaviour** — Lava / Water blocking, Teleport trap
   targeting, Shaft (drop to layer below), Golubria pair-portal,
   glass/translucent walls for FieldOfView opacity nuance.
7. **Unarmed Combat skill** (🟡) — new skill id "unarmed_combat",
   add to SkillSystem.SKILL_IDS, wire XP grant from unarmed swings
   (weapon_skill_id == ""), and CombatSystem.melee_attack reads the
   level for base damage + mindelay.
8. **Identification system** (🟡) — randomize potion/scroll/ring/amulet
   appearances per run; items carry `appearance_id` + `identified` flag;
   status popup / bag shows "blue potion" until identified; scrolls
   of identify flip the flag.

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
