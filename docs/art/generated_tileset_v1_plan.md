# Generated Tileset V1 Plan

## Goal
Build an original pixel-art tileset for PocketCrawl that preserves the current
paper-doll system and mobile readability without depending on DCSS-specific art.

Reference mood board:
- [concept_board_v1.png](/D:/PROJ_D/assets/generated_tileset_v1/reference/concept_board_v1.png)

## Hard Constraints
- Final runtime sprite size: `32x32`
- View: `top-down roguelike`, not isometric
- Mobile readability first
- Strong silhouettes over decorative detail
- Original designs only; do not mirror existing DCSS tile shapes directly

## Visual Rules
- Dark fantasy dungeon palette
- High-contrast outlines around actors and items
- Background tiles stay muted; interactive objects get brighter accents
- Player classes should read instantly:
  - fighter: steel/bronze + shield bulk
  - mage: violet/blue + staff orb
  - rogue: green/brown + bow/light gear
- Item categories should read instantly:
  - potion: bottle silhouette + colored fill overlay
  - scroll: parchment rectangle + rune/effect overlay
  - book: thicker block silhouette with spine highlight
  - wand: thin rod + bright tip
  - essence: crystal core + school/element accent

## Runtime Structure
Current player renderer expects layered `32x32` PNG assets:
- base body sprite
- body armor overlay
- hand1 weapon overlay
- hand2 shield overlay

Relevant runtime paths:
- `assets/tiles/individual/player/base`
- `assets/tiles/individual/player/body`
- `assets/tiles/individual/player/hand1`
- `assets/tiles/individual/player/hand2`

## Race Base Targets
Active races to redraw first:
- human
- orc
- elf
- kobold
- troll
- tiefling

Each race should ship with:
- one neutral base silhouette
- optional male/female variants only if visually worth keeping

## Class Read Targets
Core class looks must remain readable even before armor upgrades:
- Fighter: broad stance, visible shield arm
- Mage: robe-first silhouette, staff read from a distance
- Rogue: light body silhouette, ranged/trickster posture

## First Overlay Set
Armor overlays:
- robe
- leather_armor
- chain_mail

Hand1 overlays:
- dagger
- short_sword
- mace
- spear
- bow
- staff

Hand2 overlays:
- buckler
- round_shield

## Item Pipeline
Potion and scrolls should use the current two-part composition direction:

Potion:
- `base bottle image`
- `effect marker / fill color image`

Scroll:
- `base parchment image`
- `effect rune / seal image`

This allows fast variation without needing a unique full icon for every subtype.

## Environment Priority
Phase 1 environment tiles:
- floor
- cracked floor
- wall
- door
- stairs down
- stairs up
- chest
- altar
- pillar
- trap
- water
- lava

## Monster Priority
Phase 1 monsters:
- goblin
- skeleton
- bat
- slime
- wolf
- orc
- spider
- cultist
- fire elemental
- ice wraith
- gargoyle
- troll

## Production Order
1. Race bases
2. Class-defining hand overlays
3. Core armor overlays
4. Potion / scroll base + effect layers
5. Core monster sheet
6. Core dungeon tile sheet

## Done Criteria For V1
- 6 active race bases replaced
- core class overlays replaced
- potion/scroll layered icon system ready
- 12 monsters replaced
- 12 environment tiles replaced
- all new sprites remain readable in combat at phone scale
