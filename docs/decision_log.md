# PocketCrawl Decision Log

This file records durable game-direction decisions that should not remain only in chat history.

## 2026-05 - Project Direction
PocketCrawl is treated as a mobile-friendly simplification of Dungeon Crawl Stone Soup, not a full clone and not a pure Pixel Dungeon-style gear escalator.

Implications:
- DCSS-flavored build identity matters.
- Mobile readability and compressed UI still matter.
- Systems may be simplified, but their strategic role should remain recognizable.

## 2026-05 - Split Skill Compression Direction
The project direction moved toward a split-but-compressed skill model instead of either mirroring DCSS one-to-one or collapsing too many growth axes together.

Current player-facing skill model:
- fighting
- unarmed
- blade
- hafted
- polearm
- ranged
- spellcasting
- elemental
- arcane
- hex
- necromancy
- summoning
- armor
- shield
- agility
- tool

Rationale:
- keep player-facing growth readable while restoring meaningful investment choices
- split melee, magic, and defense enough to avoid flat builds
- preserve throwing/evocation-style tactical play via tool
- map internally toward DCSS-style 27-scale expectations while keeping UI progression compact

## 2026-05 - Tool Exists To Preserve A Missing DCSS Axis
Tool is not just 'one more skill'. It exists to preserve a missing gameplay axis that otherwise gets lost when simplifying DCSS.

It is intended to cover the role-space of:
- throwing
- evocations
- device/utility combat solutions

Rationale:
- prevents Rogue and Ranger from collapsing into generic agility variants
- preserves tactical item/device play
- supports mobile simplification without deleting the whole axis

## 2026-05 - Faith Structure Direction
Faith is intended to become a major build choice again.

Current structure direction:
- War
- Arcana
- Trickery
- Death
- Essence (alternate/mobile-friendly path)

Rationale:
- four major faith categories preserve broad DCSS recognizability
- a fifth alternate path preserves PocketCrawl-specific flexibility
- not every DCSS god is copied directly; they are categorized and simplified

## 2026-05 - Essence As Alternate Path, Not Generic Side System
Essence should not behave like a completely separate always-on parallel system if faith is meant to be important.

Direction:
- Essence is treated as an alternate path comparable to faith, or as the defining feature of a special nonstandard path
- this keeps DCSS flavor stronger than having a large unrelated subsystem layered on top of faith

Rationale:
- preserves game identity
- avoids faith and essence fighting for the same design space
- still keeps the fun monster-essence idea alive

## 2026-05 - Resistance Compression
Resistance categories should be reduced to four major types:
- fire
- cold
- poison
- will

Rationale:
- fewer categories are easier to understand on mobile
- easier to communicate via UI/help text
- reduces balance surface area while keeping meaningful distinctions

## 2026-05 - First Major Build Choice Timing
Major path choice should happen after early play, not immediately at game start.

Direction:
- player starts with class/race only
- first sector / first-boss / shrine flow introduces the major path choice

Rationale:
- reduces upfront cognitive load
- gives the player minimal play context first
- makes the first major choice memorable and diegetic

## 2026-05 - Documentation Rule
Repeated discoveries should be promoted upward:
- code or chat discovery
- durable doc note
- if repeatedly needed, elevate into CLAUDE.md / checklists / templates

Rationale:
- prevents relearning the same system rules every session
- makes multi-session AI work viable

## 2026-05 - Fighting Remains HP-First With Small Melee Support
Fighting is no longer a pure HP-only stat.

Direction:
- Fighting remains primarily a survivability skill.
- Weapon skills remain the main source of attack scaling.
- Fighting adds only a small melee-only bonus to accuracy and damage.

Rationale:
- keeps the DCSS name and feel recognizable
- avoids making Fighting eclipse blade / hafted / polearm
- gives all melee builds a little shared combat foundation without flattening weapon identity

## Open / Not Yet Finalized
- final Fighting/HP model
- exact final faith implementation details
- final relationship between tool and Ranger/Rogue identity
- exact drop economy after post-faith-system rebalance

## 2026-05 - Randarts Use Full DCSS-Style Swing
- Random artifacts should not be curated toward “mostly good with one drawback”.
- They may roll all-positive, all-negative, or mixed packages.
- This is intentional and meant to support DCSS-style “brag item” moments and cursed-looking near-junk curiosities alike.

## 2026-05 - Item Flavor Leans Toward A Late-Age DCSS Tone
- PocketCrawl item descriptions should evoke a dungeon built on the ruins of an older Crawl age rather than read like neutral mechanical tooltips.
- Mechanical clarity stays, but descriptions can suggest that this world inherits the bones of DCSS centuries later.


## 2026-05-08 - Tile Production Uses Native 32x32 Workflow
- Final tile production should be authored directly for 32x32 gameplay use.
- PocketCrawl tile art should feel like a cleaner, slightly upgraded DCSS remaster rather than a new chibi or high-detail style.
- Front-facing composition is the default, especially for humanoids and player-usable body templates.
- Readability, silhouette, and overlay compatibility take priority over fine detail.

## 2026-05-08 - Item Art Uses Split Asset Roles
- Equipped gear overlays and dropped/inventory icons should be authored as separate assets.
- Select screens should be allowed to use optional dedicated menu portraits instead of scaling raw in-game body sprites.
- One sprite should not be forced to serve as gameplay body, equipped overlay, floor icon, and menu portrait at once.

## 2026-05-08 - Early Dungeon Walls Should Be Flatter Than First Test Pass
- The first generated B1-B2 wall pass had too much depth/extrusion and looked awkward when repeated vertically.
- Early dungeon walls should be closer to DCSS's flatter read, while still being slightly cleaner than the original tiles.
- Floor and wall tones should be pushed further apart so they do not visually merge on mobile.

## 2026-05-21 - Expedition Rework Phase 0 + Core Strip (3-item simplification)
Branch `expedition-rework` (not yet merged to `main`). Spec `docs/superpowers/specs/2026-05-21-expedition-rework-design.md`. Adapted from PROJ_G's `expedition_roguelike_proto` direction but scoped down per user to 3 core items: (1) shrine choice trigger removal, (2) 15→5 floor compression, (3) skill model rework. Town hub / turn budget / fixed-map authoring / starter shop deferred to a later session.

Phase 0 — Game.gd survivor extraction (5 commits, no behavior change). Game.gd shrunk 3721 → 2732 lines (-27%):
- `FloorLifecycle.gd` (4d37f457) — floor gen/cache/restore/top-up
- `SpawnService.gd` (cdd9a309) — generic monster/item spawning (boss/temple/branch spawners kept in Game.gd because their fate is dictated by later phases)
- `EffectsLayer.gd` (de51620b) — damage numbers, projectiles, spell bolts, corpse texture composition
- `SpellTargeting.gd` (cc8aaef5) — targeting flow + AOE helpers
- (`SaveMigration.gd` extraction skipped — no save-version bump this session)

Core changes:
- (2ee6860b) Depth-3 shrine choice trigger removed: `_spawn_b3_temple_boss`, `_place_b3_altars`, `_try_open_shrine_choice`, `_handle_first_shrine_boss_clear`, altar-tap branch in `_handle_tap`, `_B3_FAITH_IDS`. **FaithSystem.gd, ShrineDialog.gd, faith data on Player/SaveManager, race faith fields, and altar rendering infrastructure are KEPT as dormant code** per user preference — no reason to delete already-built work; without triggers it's unreachable from gameplay.
- (f068c831) 15 → 5 floor compression. Each PROJ_D theme collapses to a single PROJ_G depth: Catacombs (1), Lair (2), Orc Mines (3), Elven Halls (4), Abyss + final boss (5). Branch entrance ranges narrowed to single parent depths; branch floor count 4 → 3 (PROJ_G mobile spec). Crypt re-parented from Abyss (depths 13-15) to Catacombs (depth 1) per PROJ_G structure. Descent guard `depth >= 16` → `>= 6`. `_spawn_b15_boss_floor` renamed `_spawn_final_boss_floor`. Monster spawn depth bands untouched — high-band monsters are dormant data until balance pass.
- (450f7ad7) **Skill model: 9 visible + 30 hidden, dual-tier.** Player.SKILL_IDS is the PROJ_G 9-skill set (`weapon_mastery, archery, tactics, defense, magery, stealth, lockpicking, tracking, survival`) — the ONLY skills shown in UI/save/tutorials. `HIDDEN_SUBSKILL_IDS` preserves the 30+ DCSS sub-skills as silent per-bucket XP banks (`fighting, unarmed, short_blades, polearms, bows, crossbows, fire, ice, necromancy, …`). Every `grant_skill_xp("polearms", x)` dual-writes to BOTH `hidden_skills["polearms"]` AND the canonical `skills["weapon_mastery"]`. Hidden level-ups are silent (no UI log, no stat side effect). Save schema adds `hidden_skills` dict; migration from legacy saves preserves per-sub-skill data verbatim (no data loss). Visible buckets get max-of-old level + sum-of-old XP. New skills `tactics/lockpicking/tracking/survival` start at 0 (no XP source yet — balance pass will wire). DCSS mastery system stubbed to identity values (UI mastery cards render empty until UI sweep). `config/balance/skills.json` → `balance_v4_proj_g_9skill_dual_tier`. Design rationale: visible 9 carry 80% of performance after balance pass; hidden 30 carry 20% as narrow item-specific bonuses (e.g., dagger familiarity → only dagger attacks). Hidden values must NEVER gate equipment use — they only refine performance for what the player has actually been using.

Verification status: `godot --headless --check-only` passes (EXIT 0). F5 smoke verification pending — user will run end-to-end on next session.

Additional commits in the same session after the user reviewed the skill model and asked to finish the umbrella cleanup:

- (e4308804) **Job/Class system removed**. Deleted `resources/classes/*.tres` (9 files), `ClassRegistry.gd` + autoload, `JobSelect.gd` + scene, `ClassData.gd`. Removed `_apply_class_to_player`, `_class_starter_items`, `_class_default_active_skills` from Game.gd. `GameManager.selected_class_id` dropped from save (old saves still load; key ignored). RaceSelect now scene-changes directly to Game. New runs get a race-neutral starter kit (`dagger`, `leather_armor`, `potion_healing` ×2, `scroll_identify` ×2) — balance pass will refine per-race.

- (6d0bbce1) **Legacy umbrella skill names dropped from SKILL_REMAP**. Removed `blade`, `hafted`, `polearm`, `ranged`, `shield`, `agility`, `tool`, `elemental`, `arcane`, `hex`, `summoning` (11 entries). With class .tres files gone there are no remaining callers using umbrella ids; hidden sub-skill ids (`short_blades`, `polearms`, `fire`, `hexes`, etc.) are now the only legacy keys SKILL_REMAP recognises. CombatSystem `get_skill_level("agility")` (backstab) → `"stealth"`, `get_skill_level("shield")` (block) → `"defense"`, `get_skill_level("blade")` (parry) → `"weapon_mastery"` (item category check on `weapon.category == "blade"` retained — that's a data tag, not a skill id). Dagger swift-strike rewired from dead `skill_id == "blade"` gate to `weapon.category == "dagger"` + `weapon_mastery` level. MonsterAI stealth detection `get_skill_level("agility")` → `"stealth"`. RaceSelect.gd `_make_apt_row` rebuilt: 9-cell visible row aggregating hidden sub-skill aptitudes per race via averaging.

Final Game.gd line count: **2646** (3721 → 2646, -29% over session). Branch `expedition-rework` is 10 commits ahead of main. Deferred items still pending: town hub, turn budget, fixed authored 42×47 maps, character minimap memory, essence slot 1/6/14 unlock progression, race-specific starter shop, d100 combat formula rewrite, balance pass (XP rates, hidden-tier 20% contribution, the four new skills' XP sources).
