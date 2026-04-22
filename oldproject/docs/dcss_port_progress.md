---
name: DCSS port progress 2026-04-20
description: Snapshot of which DCSS systems have been ported from github.com/crawl/crawl and what remains. Check before resuming porting work.
type: project
originSessionId: bae6094b-d58f-4ab0-a2ee-8b749d2d51bc
---
## Licensing decision (2026-04-20)

User chose **"GPL-compliant open distribution + GPL source, App Store OPEN"**.

Rules adopted for ports:
- Numbers/stats from DCSS → copy freely (facts, not copyrightable).
- Algorithms → reimplement in GDScript (no line-by-line translation).
- C++ function names / comments / flavor text → NOT copied, we author our own.
- GPL source of our project goes public (Google Play + F-Droid + web build).
- To keep App Store viable we avoid copying DCSS expression (text/code), only facts.

**Why:** Apple App Store terms are incompatible with GPL obligations (FairPlay DRM adds restrictions GPL forbids). Copying DCSS's creative expression would force GPL; copying facts-only (numbers, rules) keeps us App Store-eligible under Oracle v. Google precedent.

**How to apply:** New systems port DATA (numbers) from DCSS source freely. Algorithms get reimplemented in GDScript with our own naming/structure. Flavor text, descriptions, comments → author from scratch.

## DCSS source location
`/mnt/d/PROJ_D/crawl/` — cloned `git clone https://github.com/crawl/crawl.git`.

## Completed DCSS ports

- **Map gen** → `scripts/dungeon/DCSSLayout.gd` ports `dgn_build_basic_level` from `crawl-ref/source/dgn-layouts.cc`. Three trails + L-joins + random rooms. Broken Hyper engine removed.
- **Vaults** → `scripts/dungeon/DesParser.gd` parses `.des` files; 125 minivaults loaded from `assets/dcss_des/`.
- **Monsters data** → `assets/dcss_mons/monsters.json` (667 monsters from `crawl-ref/source/dat/mons/*.yaml` via `tools/convert_dcss_mons.py`).
- **Monster lookup** → `scripts/dungeon/MonsterRegistry.gd` (fetch(id), merges DCSS extended fields onto hand-tuned `resources/monsters/*.tres`).
- **Monster spawn table** → `assets/dcss_mons/population.json` (948 entries × 40 branches from `crawl-ref/source/mon-pick-data.h` via `tools/convert_dcss_population.py`). `scripts/dungeon/MonsterPopulation.gd` picks weighted-random by (branch, depth) with FLAT/PEAK/SEMI/FALL/RISE shape curves. Our 5 branches map to DCSS branches via `_BRANCH_MAP`; global depth → branch-local 1..5 via `branch_local_depth`.
- **Spawner** → `scripts/dungeon/MonsterSpawner.gd` uses MonsterPopulation → MonsterRegistry → MonsterData pipeline. Fallback pool kept for safety.
- **Species aptitudes** → `assets/dcss_species/aptitudes.json` (35 species from `crawl-ref/source/dat/species/*.yaml` via `tools/convert_dcss_species.py`). `scripts/core/RaceRegistry.gd` overlays DCSS aptitudes + base stats onto `resources/races/*.tres` at fetch time. Skill key mapping: DCSS `short_blades` → our `short_blade`, `maces_and_flails` → `mace`, `fire_magic` → `fire`, `ranged_weapons` → `bow`, `summoning` → `summonings`.

## NOT YET PORTED (next session priority order)

1. **Skill XP curves** from `crawl-ref/source/skills.cc` — `skill_exp_needed` function gives XP thresholds per level. DCSS curve is exponential; apply our mobile 1.5× multiplier as per user preference.
2. **Weapon/armour stats** from `crawl-ref/source/item-prop.cc` (3800 LOC). Fields: weapon damage/accuracy/speed, armour AC/encumbrance. Likely extract via Python parser scanning the `Weapon_prop[]` and `Armour_prop[]` arrays.
3. **Spell data** from `crawl-ref/source/spl-data.h` (88 KB, structured macros). Damage formulas, ranges, noise, schools.
4. **Monster AI** from `crawl-ref/source/mon-behv.cc` (behaviour state machine) + `mon-act.cc` (action selection). Largest scope — state machine (ATTACK/FLEE/WANDER/SEEK/SLEEP), pathfinding, target selection.
5. **Mutations** from `crawl-ref/source/mutation-data.h` (76 KB). For demonspawn/mummy/vine_stalker etc.

## Other pending threads

- **Item identify UI dedup** — done this session (`scripts/core/GameBootstrap.gd:_on_identify_one_requested`).
- **Vault SUBST/KMONS support** — `DesParser.gd` currently rejects vaults with non-basic glyphs. Extending this unlocks ~100 more mini_features vaults.
- **Editor class_map regen** required after adding new class_name scripts — run `godot --headless --editor --quit` once, else scripts can't be referenced by name.

## Test scripts in tools/

- `tools/render_maps.gd` — ASCII dump of DCSSLayout output (no DungeonGenerator needed)
- `tools/render_integrated.gd` — full pipeline render via DungeonGenerator
- `tools/test_mon_registry.gd` — sample monster lookups showing merged stats
- `tools/test_population.gd` — weighted-pick simulation per (branch, depth)
- Python converters: `convert_dcss_mons.py`, `convert_dcss_population.py`, `convert_dcss_species.py` — rerun to regenerate JSON when DCSS source updates.
