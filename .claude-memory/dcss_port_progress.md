---
name: DCSS port progress 2026-04-20
description: What's DCSS-ported vs what still diverges. Check before resuming port work. User wants balance 100% DCSS.
type: project
originSessionId: bae6094b-d58f-4ab0-a2ee-8b749d2d51bc
---

## Licensing (unchanged)
GPL-compliant open distribution. Numbers/stats copied freely, expression (text/code/flavor) authored ourselves. DCSS source cloned at `/mnt/d/PROJ_D/crawl/`.

## Completed ports (as of 2026-04-20)

- Map gen, Vaults, Monsters data (667), Monster pop table, Species aptitudes (35)
- Door open on bump (c79f664c)
- Weapon/Armour stats from item-prop.cc (c79f664c)
- Skill XP curves (0c277107)
- Spell data 409 spells — `assets/dcss_spells/spells.json` (0c277107). Multi-school data correct: iron_shot/stone_arrow both have conj+earth in SpellRegistry.gd too.
- Depth-weighted item gen tables `assets/dcss_items/item_gen.json` (10385a7b)
- Monster XP / potion effects / brands / branches / uniques / traps (6b61bb3f)
- Map-reveal on floor load fix (3c03000d)
- **Backgrounds: 26 DCSS jobs ported** (uncommitted, 2026-04-20). `tools/convert_dcss_jobs.py` parses `crawl-ref/source/dat/jobs/*.yaml` → `resources/jobs/*.tres`. Removed 11 non-DCSS jobs (warlock, mage, cleric, rogue, ranger, barbarian, skald, assassin, transmuter, wizard, arcane_marksman). Updated JobSelect/TraitSelect/TileRenderer/MetaProgression/QuickStart to reference new roster. Wanderer kept hand-tuned (DCSS randomises its kit in ng-wanderer.cc and we can't port that yet — converter skips wanderer.tres).
- **Starting HP/MP: DCSS formula** (65d4ef83). Ported `player.cc get_real_hp/get_real_mp` into `Player._dcss_max_hp/_dcss_max_mp`. Added `hp_mod`/`mp_mod` to RaceData, sourced from `aptitudes.json`. GameBootstrap now uses RaceRegistry.fetch so DCSS mods actually apply. Level-up recomputes from scratch preserving HP/MP ratio (DCSS calc_hp style). Validated: Gargoyle EarthEl Lv1 = 10 HP / 3 MP (was 35 / 13). Fighter XL 27 = 166 HP matches DCSS endgame.
- **Spell math: DCSS power / failure / zap damage** (uncommitted, 2026-04-20). `tools/convert_dcss_zaps.py` parses `zap-data.h` + `spl-zap.cc` → `assets/dcss_spells/zaps.json` (141 spells with per-spell dicedef/calcdice coefficients). `SpellRegistry` gains `calc_spell_power` (full DCSS pipeline: skills → INT → stepdown → cap), `failure_rate` (raw_spell_fail polynomial clamped 0..100), `roll_damage` (zap dice), `get_schools` (handles multi-school properly). All 4 callers in GameBootstrap updated; multi-school spells now use avg skill for power and min-of-schools for failure, and XP trains every discipline. Legacy bracket-based `failure_chance` removed.

## BALANCE BUGS TO FIX (priority order, user wants 100% DCSS parity)

### 0. ✅ DONE (2026-04-20): Starting HP/MP DCSS formula

### 1. ✅ DONE (2026-04-20): Spell damage = per-spell zap dice

### 2. ✅ DONE (2026-04-20): Per-monster HP 33% variance via DCSS hit_points() in Monster.gd._dcss_roll_hp

### 3. ✅ DONE (2026-04-20): Multi-school calc via SpellRegistry.get_schools

### 4. ✅ DONE (2026-04-20): Minimap refresh moved after _restore_floor

### 5. ✅ DONE (2026-04-20): Spawn count uses DCSS 3d(_mon_die_size) — D:1 avg ~19.5

### 6. ✅ DONE (2026-04-20): Floor-gen items = 3 + 3d9 (6..30) via GameBootstrap._place_random_floor_item

### 7. ✅ DONE (2026-04-20): raw_spell_fail polynomial + armour/shield encumbrance penalty
- SpellRegistry._armour_shield_spell_penalty ports player.cc adjusted_body_armour_penalty + adjusted_shield_penalty. Chain mail on Lv1 earth-mage: sandblast fail 24% → 83%. Plate: 100%.

### 8. ✅ DONE (2026-04-20): Auto-move now halts on newly-visible stairs (up and down) — _seen_stair_tiles snapshot on start, _newly_visible_stair check each step

### 9. ✅ DONE (subsumed by #0 2026-04-20): Starting HP now uses DCSS formula via race.hp_mod

## Still-pending (bigger jobs)
- **Monster AI complete (2026-04-20)**: sleep / casting / flee-on-low-HP / band spawning / door opening all shipped. Remaining minor: amphibious/flying movement, pack-targeting leader protection.
- **Mutations DONE (6978322d)**: 216 mutations from mutation-data.h → MutationRegistry. Potion of Mutation applies random rolls. Player.apply_mutation/remove_mutation covers stats/HP/MP/AC/resist deltas. Non-modelled (racial-specific tails, form-shifts) land in the dict without mechanical effect.
- **Monster casting DONE (bcbd11b9)**: 338 spellbooks from mon-spell.h → spellbooks.json. MonsterAI._try_cast_at uses freq-weighted picks; damage via SpellRegistry.roll_damage.
- **Stealth/noise DONE (30e71eff)**: detection range scales with stealth skill. broadcast_noise(tree, origin, loudness, stealth) wakes sleepers on melee/cast.
- **Branches activation**: data exists (`assets/dcss_branches/`), TileType.BRANCH_ENTRANCE defined, but entrance placement + inter-branch travel UX not wired. Big scope.
- **Gods / piety system**: zero coverage. Biggest single feature left. Session-scale work each.
- Vault SUBST/KMONS support in DesParser

## Tier 4 items alignment (2026-04-20)
- **Wands: 12 DCSS wands DONE** (bcf449cc). `WandRegistry.gd`. Each maps wand_id → spell_id per spl-book.cc:_wand_spells. Charges from item-prop.cc:wand_charge_value. Evoke flow in Player.use_item/_evoke_wand: nearest-visible-hostile target, Evocations-scaled power (~15 + evo*7), SpellRegistry.roll_damage for direct zaps, hex handlers for paralysis/roots/charm/poly/dig. Floor-gen and kill drops include wands. TODO: proper target picker UI, WAND_DIGGING wall-carve logic, polymorph effect modelling.
- **Potions DCSS-aligned DONE** (396b9a5e). Removed 4 non-DCSS (agility, degeneration, restore, poison-drink), added 9 (attraction, enlightenment, cancellation, ambrosia, invisibility, experience, berserk_rage, mutation-queued, lignify). Turn-based expiration in Player._tick_duration_metas.
- **Scrolls DCSS-aligned DONE** (976c1e39). Added 8: noise, summoning, torment, brand_weapon, silence, amnesia, poison_scroll, butterflies. Weapon brand writes a meta consumed by CombatSystem.melee_attack for per-hit elemental damage. Silence short-circuits GameBootstrap._execute_cast.
- **Spellbooks: 88 DCSS books DONE** (624193fa). `tools/convert_dcss_books.py` parses book-data.h → `assets/dcss_spells/books.json`. ConsumableRegistry lazily merges JSON at runtime; floor-gen "consumable" slice gives 20% chance of a book.

## Sleep-state + MonsterAI hex handling (2026-04-20)
- Monsters spawn BEH_SLEEP (7/8 chance) — DCSS dungeon.cc:4252 parity. Wake on LOS / damage / adjacent ring. Render a `Z` glyph on sleepers. Invisibility potion hides player from wake checks. Paralysis and rooted metas respected by MonsterAI.act(). Poison DoT ticks at turn start.

## Session-end notes (2026-04-20)
- User plays Gargoyle Earth-mage; finds early game too easy. Primary culprits: #2 (monster HP too low), #5 (spawn count 1/4), #3 (multi-school broken means earth aptitude wasted).
- False alarms ruled out this session: iron_shot data IS correct (both schools present), minimap DOES refresh on floor change (but with stale order bug #4).
- Start next session with #2 (monster HP regen) + #3 (multi-school calc). Those two unlock most of the "too easy" feel and are low-LOC fixes.

## Session 2 update (2026-04-20, later)
- **#2 REVISED**: monster `hp_10x / 10` actually matches DCSS average exactly. Rat hp_10x=25 → 2.5 avg matches DCSS. Memory's earlier "rat~5" target was wrong. What's still missing: **per-monster 33% HP variance roll** (DCSS `hit_points()` in mon-util.cc 2251). Minor impact vs other bugs.
- Discovered bigger culprit: **starting HP/MP are 2-3× DCSS** — see new #0 in priority list. Likely #1 cause of "too easy" feel.
- Also discovered Warlock etc. were non-DCSS fabrications — ported DCSS's 26 backgrounds this session (see Completed ports section).
- Next session: start with **#0 starting HP/MP** — biggest balance impact, low-LOC. Then #3 multi-school calc.

## Session 3 update (2026-04-21): Wholesale source ports
Motivated by user asking "전반적인 시스템 전체를 그냥 통째로 깃헙 소스를 통해 가져오고싶어". Strategy: file-by-file faithful translation of DCSS C++ into GDScript modules, with explicit source-line citations in doc comments. Pushed 9 commits: 2c16a61b → 4a74810c.

New faithful-port modules (all in `scripts/systems/`):
- `FieldOfView.gd` — los.cc / losparam.cc / ray.cc. Multi-ray fan with diamond-gap diagonal rule. Closed doors block sight. EXPLORE_RADIUS → DCSS LOS_DEFAULT_RANGE=7. `DungeonMap.update_fov` delegates; `_opaque_at` mirrors opacity_default.
- `SpellCast.gd` — spl-cast.cc::cast_a_spell + player.cc pay_mp/refund_mp. Single canonical MP-pay pipeline. Three divergent cast paths in GameBootstrap now all route through this → fixes mp=1 spell non-consumption.
- `PlayerDefense.gd` — player.cc::_player_evasion. Size factor + armour-STR reduction + shield penalty + aux slots + form + rings + petrify/caught halving. Replaces old ad-hoc EV formula.
- `Noise.gd` — shout.cc::noisy + noise.cc propagation. BFS with per-cell atten (walls 12×, doors 8×, floor 1×). MonsterAI.broadcast_noise delegates.

Formula fixes inside existing systems:
- CombatSystem AC soak: random2(2*ac+1) → random2(1+ac) (halves effective armour damage-prevention; actor.cc:355).
- CombatSystem GDR: adds `16*sqrt(sqrt(ac))%` guaranteed dmg reduction capped ac/2 (player.cc:6620).
- MP regen divisor: /7 → /2 (player.cc:1298). Late-game MP flow now matches DCSS.
- calc_spell_power: enhancer ×1.5 per match (staff school), ÷2 per anti-wizardry level. Replaces additive staff_spell_bonus hack.
- calc_dice: size uses div_rand_round not floor (random.cc:289), preserving expected damage.
- Player attack_delay: port player-act.cc:252. Skill-capped delay reduction + speed/heavy brand mods. Was flat weapon_speed * 10.
- check_awaken: port shout.cc:264. x_chance_in_y(monster_perception, player_stealth). Stealth now meaningful — sleepers can be snuck past at high stealth.
- monster_perception: port shout.cc:252. `(5 + HD*3/2) * intel_factor / 20`, intel_factor = {brainless:15, animal:20, human:30}.
- player_stealth scaled: port player.cc:3329. dex*3 + stealth_skill*15 - body_armour_penalty² * 2/3.
- Stab: port attack.cc:1426. good_stab (sleep/paralysed/petrified) = divisor 1; bad_stab (confused/held/fleeing) = 4. DCSS skill-scaled multiplier + DEX flat bonus on good stabs. Replaces fixed 4x/2x/1.5x mults.
- Player resist_adjust_damage: port fight.cc:853 player branch. res>3 immune, poison/neg bonus_res=1, neg uses res*2 special divisor.
- Monster resist_adjust_damage: DCSS monster divisor `1+bonus_res+res*res` (stronger than player). Boolean elements (poison/neg/holy) immune at res≥3.
- Slaying: port attack.cc:840 player_apply_slaying_bonuses. Weapon plus + gear_damage_bonus applies as +random2(1+plus) AFTER skill multipliers. Old code added flat pre-mult and again post-AC (double count).

Defensive additions (fix + guardrail for "monsters vanished" report):
- DungeonMap.update_fov: explicit `Callable(self, "_opaque_at")` to force self-bind; Godot 4 implicit method-to-Callable can silently fail when passed as a typed static parameter.
- DungeonMap: `_fallback_cheb_disc` kicks in if FieldOfView.compute ever returns empty (shouldn't happen but guards against regressions that would hide all actors).
- GameBootstrap: `[spawn] depth=X spawned=Y` print in `_spawn_monsters_for_current_depth` for diagnosis.

Uncommitted: none (everything pushed up to 4a74810c).
Next candidates: monster flavour → player resist routing; apply_chunked_AC; beam.cc ray travel (biggest remaining gap).

## Session 4 update (2026-04-21, later) — balance tail + beam + combat nuance + egos

Extension of the wholesale-porting push; user approved continuing through the backlog file-by-file. Commits 4f797418 → 32dd5259.

Content ports:
- **beam.cc travel (d6dfdab7)** — `scripts/systems/Beam.gd`. Bresenham supercover walker stops at walls/doors, records every monster struck; `should_pierce(spell_id)` encodes the DCSS piercing set (bolt_of_*, lightning_bolt, crystal_spear, venom_bolt, etc.). `_cast_single_target` + `_execute_targeted_cast` in GameBootstrap both route through `_beam_resolve_target` / `_beam_path_hits`. Non-pierce redirects to the real first hit; pierce rolls separate damage per victim.
- **AoE / beam preview (2b243722)** — DungeonMap.aoe_preview_tiles + beam_preview_tiles. `_show_targeting_hint` paints orange AoE radius around each visible foe for area spells, cyan trail along beam rays for single-target zaps. Cleared on target-select.
- **Reach / Cleave (2b243722)** — WeaponRegistry.weapon_reach (polearm=2) + weapon_cleaves (axe+bardiche). Player.try_attack_at enforces the middle-cell clearance; TouchInput auto-routes 2-tile taps. Cleave runs a full extra CombatSystem.melee_attack per flank.
- **Auxiliary attacks (2b243722)** — CombatSystem dispatches minotaur headbutt, naga tail slap (+poison), tengu/centaur kick, draconian tail, octopode tentacle on 1/3-ish connecting hits.
- **Walking noise (2b243722)** — Player.try_move emits a DCSSNoise pulse scaled by body-armour EVP (plate=loud, robe=silent). Stealth skill trims.
- **Monster shout (32dd5259)** — MonsterAI.wake emits HD-scaled DCSSNoise (hiss 4 → roar 12), propagates through walls. Silent-shape/flag mobs muzzled.
- **Weapon brand roster (32dd5259)** — drain, pain (scales with necromancy skill), distortion (blink/banish roll), antimagic (burns MP), vorpal (25% +25% dmg), reaping (kill→raise meta), chaos (random element per hit). Existing brands (flaming/freezing/electrocution/venom/holy_wrath) now route through element resist. Electrocution 1/4 burst 8-20 dmg matches DCSS.
- **Armour egos (32dd5259)** — `ArmorRegistry.EGOS` with 27 SPARM_* entries. `roll_ego(slot, chance)` picks compatible egos at 6-25% rate scaled by depth. `Player._recompute_gear_stats` folds stat_bonus / resists / flag effects; `get_resist` reads per-equipped-armour ego resists. Harm ego (`_ego_harm` meta) wired to both take_damage (+30%) and CombatSystem.melee_attack (+30%). Stale ego metas are cleared at recompute top so swap-off works. Egos NOT YET wired beyond the flag: RAMPAGING, REFLECTION, SPIRIT_SHIELD, FLYING, MAYHEM.

UX fixes shipped this session:
- Zoom tuning (bb54c0bb→c87facbd→26c10352): DEFAULT_ZOOM ended at 6.5 for mobile. Auto-move at 0.08s/step.
- MainMenu._ensure_meta uses call_deferred to dodge "busy root" root-add error.
- Per-god altar tiles from rltiles/dngn/altars (76a36b6b).
- Altar pledge popup with GodRegistry.GUIDES beginner text (f25189b4).
- Status screen: Piety card under vitals + all font sizes bumped ~25% (f25189b4).
- Stair placement guards: `_ensure_stair_has_exit` pushes stair to a walkable-neighbour tile when DCSS layout drops it in a wall pocket (f25189b4).
- Troll-leather armour pulled from floor pool, restricted to troll kill drop (c87facbd).
- Item count 6..30 → 3..11 (c87facbd). Ring drop rate 8% → 3%.

Bugs squashed this session:
- Monster._mon_resist_level: Resource.get() is 1-arg in Godot 4 — read holiness from data.shape/flags instead (01eb8b50).
- Noise class name collided with engine's Noise abstract — renamed to DCSSNoise (34a95cd2).
- String(x or y) Variant coercion threw "nonexistent String constructor" on current_branch accesses — replaced all 5 sites with typed check (7dc99bc2).
- Monster damage not landing: physical soaked to 0 while flavour damage present was zeroed by dealt_any gate (bb54c0bb fix queue).

Uncommitted: none. Git main at 32dd5259.

Session 5 queue (recorded in dcss_port_backlog.md "Active picks"):
1. Amulet roster (highest priority)
2. Multi-stat rings + randart generation
3. Player willpower stat (plugs into all hex/MR effects)
4. Status effect breadth (poison levels, Frozen, Petrifying, Blind, etc.)
5. Dungeon-tile behaviour (lava/water/shaft/golubria)
6. Unarmed Combat skill
7. Identification system

Gods deferred until user explicitly asks — do NOT pick those items
from the top of stack even if they seem like a natural next step.
