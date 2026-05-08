# PocketCrawl Item Art Pipeline

## Principle
Item art should be split by use case rather than forcing one sprite to serve every role.

The project should treat item visuals as at least two asset families:

1. **Equipped overlay sprites**
2. **Ground / inventory item sprites**

Menu portraits can optionally become a third family later if needed.

## 1. Equipped Overlay Sprites
These are the assets drawn on top of humanoid bodies.

They must follow strict slot rules:
- `body` for armor / robes
- `hand1` for main-hand weapons
- `hand2` for shields / offhand items
- future: `head`, `cloak`, `boots`, etc.

### Requirements
- Final resolution should match gameplay tile logic.
- Transparent background is mandatory.
- Alignment matters more than individual flourish.
- Silhouette must work on top of the standardized humanoid body template.
- Equipment overlays should not repaint large body zones unnecessarily.

### Fighter starter example
- `chain_mail` -> body overlay
- `short_sword` -> hand1 overlay
- `buckler` -> hand2 overlay

## 2. Ground / Inventory Item Sprites
These are independent item icons used when the object is:
- on the floor
- in the inventory
- in loot / item popups

### Requirements
- Transparent background.
- Shape should instantly communicate item type.
- These sprites do not need to match humanoid overlay alignment.
- Readability matters more than realism.

Example:
- a dropped sword should read like a sword icon
- an equipped sword should be positioned to fit a humanoid hand slot

## 3. Menu / Select Portraits
Select screens should not rely on raw in-game 32x32 body tiles scaled up.

Use optional dedicated portrait paths for:
- races
- classes

This keeps:
- gameplay sprite readability
- menu presentation quality

from fighting each other.

## Data Path Strategy
### RaceData
- `base_sprite_path`: in-game base body
- `menu_portrait_path`: optional select/menu portrait

### ClassData
- `menu_portrait_path`: optional class-specific portrait
- fallback remains race base + starter gear layering

## Recommended Production Order
1. Finalize humanoid body templates
2. Build starter gear overlays for a few core classes
3. Build matching floor/inventory icons for the same gear
4. Add separate menu portraits only when the layered in-game version looks too rough

## Current Decision
PocketCrawl should support separate assets for:
- in-game humanoid body bases
- equipped item overlays
- dropped / inventory item icons
- optional menu portraits

Do not force one sprite to solve all four roles.
