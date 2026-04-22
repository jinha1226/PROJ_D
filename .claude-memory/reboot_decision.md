---
name: Clean-room reboot decision 2026-04-25
description: User decided PROJ_D stays as GPL DCSS port for fan distribution; new commercial project will be clean-room reboot avoiding all DCSS code/data/tiles/names
type: project
originSessionId: 6c44e27d-87b3-44e6-9d3e-08a7276b21d8
---
## Decision (2026-04-25)

User wants to ship PROJ_D as a GPL DCSS fan port (itch.io + Ko-fi, minimal
revenue expected, ~80% content parity). Beyond that, pivot to a **completely
new Godot project** for commercial/donation potential without GPL tangling.

## Why clean-room

- PROJ_D is irreversibly GPL v2+ (DCSS source + data + tiles → derivative).
- Can distribute under GPL but can't relicense, can't charge commercially
  with any leverage (buyers re-upload).
- New project = new license (MIT / proprietary / whatever user picks).
- All DCSS-inspired game mechanics (ideas) are NOT copyrighted — can
  replicate the feel without copying any code.

## What must NOT carry over

- Any `scripts/**/*.gd` file from PROJ_D — especially `Beam.gd`,
  `FieldOfView.gd`, `SpellCast.gd`, `PlayerDefense.gd`, `CombatSystem.gd`,
  `MonsterAI.gd`, `SpellRegistry.gd`.
- Any `assets/dcss_*` data file.
- Any `resources/monsters/*.tres` referring to DCSS monsters.
- Any DCSS-specific name (god / unique monster / unrand artefact).
- Any tile from DCSS's rltiles tree.

## What DOES carry over (knowledge, not code)

- Godot 4 project structure and autoload patterns.
- Mobile UI lessons (quickslot, 2-tap targeting, sub-tabs).
- Data-model choice (.tres per entity beats giant JSON).
- Balance intuitions (HP tiers, damage curves, encounter density).
- Pitfalls to avoid — full list in the guide document.

## Reference document

Full implementation guide: `/mnt/d/PROJ_D/docs/clean_room_reboot_guide.md`.
Contains:
- Legal firewall rules
- Project layout
- Data model
- Week-by-week build order (MVP in 4 weeks)
- UI patterns
- Mobile optimizations
- Balance cheat sheet
- Asset sources (Kenney, OpenGameArt CC0, etc.)
- 13 pitfalls learned the hard way

**How to apply**: When the user opens a session in the new project directory
(e.g., `/mnt/d/NEW_PROJ/` or similar), first step is to read that guide. It
is self-contained — a fresh session reading just that guide can bootstrap
the project.

## Why not keep extending PROJ_D for commercial

User considered it. Math:
- PROJ_D at 80% parity → itch.io donation potential ~10-100k KRW/year.
- Pushing to 99% parity costs 5-7 more sessions.
- Hard ceiling: GPL means anyone can redistribute, killing commercial sales.
- Fresh project same effort but keeps commercial option open.

## Pitfall for next session

User's intuition on effort is usually right — my "2-3 week" estimates were
inflated because I assumed per-entity custom code for things DCSS handles
data-driven. For the new project: trust user's "one session" estimates for
data porting, inflate only for novel game-design work.
