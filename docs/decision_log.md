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
