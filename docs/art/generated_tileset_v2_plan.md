# Generated Tileset V2 Plan

- Runtime cell size: `32x32`
- Rendering model: strict paper-doll layers
- Race bases must be bare-body bases only, not full outfits
- Layer bounds are recorded from the current in-game assets and must be preserved

## Active Races
- human
- orc
- elf
- kobold
- troll
- tiefling

## Phase 1 Overlays
- body: robe, leather_armor, chain_mail
- hand1: dagger, short_sword, mace, spear, bow, staff
- hand2: buckler, round_shield

## Rules
- Every sprite must be authored directly inside a 32x32 cell.
- Transparent background only.
- No full-character outfits in race base sheets.
- Use the template PNGs in `assets/generated_tileset_v2/templates/`.
