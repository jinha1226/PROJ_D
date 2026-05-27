# Map Art Direction Handoff

Purpose: keep the current small maps for system testing, but use this document when moving to authored/fixed maps. The goal is not just larger rooms; each floor should read as a place with sub-regions, props, and terrain accents.

Asset roots to reuse first:
- Terrain: `assets/tiles/individual/dngn/floor`, `dngn/floor/grass`, `dngn/wall`, `dngn/wall/abyss`, `dngn/water`
- Props: `dngn/decor`, `dngn/trees`, `dngn/statues`, `dngn/traps`, `dngn/vaults`, `dngn/shops`, `dngn/doors`
- Item dressing: `item/gold`, `item/gem`, `item/book`, `item/parchment`, `item/essence`, `item/weapon`, `item/armour`

## Global Rules

- Use 3 layers per authored map: base floor/wall, feature terrain, props/items.
- Keep collision simple: most props should be visual-only floor dressing unless they clearly read as blocking, such as trees, statues, columns, shelves, sealed vault doors.
- Every map needs 3-5 named sub-regions so a player can say "I am in the orchard" or "I reached the ore vault".
- Avoid making all spaces room/corridor. Mix rooms, broken halls, plazas, caves, yards, forests, and fenced pockets.
- Treasure areas should have a visual tell before the reward: stronger flooring, torches/fountains/statues, crates, gold piles, bookshelves, crystals, or sealed doors.
- Mobile readability: keep a 2-3 tile clear path through dense decoration; do not scatter one-tile props evenly everywhere.

## Main 1F - Broken Entry Catacombs

Theme: the first floor is an old public burial level converted into a monster nest.

Sub-regions:
- Entry Hall: cleaner stone floor, cracked pillars, two broken statues near spawn. Low threat, tutorial-safe.
- Vermin Warrens: dirtier floor pockets, webs/cobweb trap visuals, small side holes, insects and rats.
- Slime Drain: green/toxic water accents along one edge, broken fountain, slime-heavy spawns.
- Beast Kennel: larger open pen with bones/meat cache decor, beasts and gnolls.
- Sealed Reliquary: small locked-looking vault room with decorative floor, one chest/scroll/gem reward.

Tile notes:
- Base: flat dungeon floor and flatter early walls.
- Props: `decor/dry_fountain`, `decor/blood_fountain`, `statues/crumbled_column_*`, `traps/cobweb_*`, `decor/cache_of_meat_*`.
- Terrain accents: shallow water/toxic bog only in small pools, not full rivers.

## Main 2F - Overgrown Lair Approach

Theme: dungeon stone breaks into a damp underground garden and beast route.

Sub-regions:
- Rooted Plaza: large open area with grass patches and scattered trees as blockers.
- Fungal Bend: mushrooms/plant monsters, poison puddles, narrow but organic paths.
- Hunter Camp: ruined camp with food cache, a few weapon drops, humanoid/animal mix.
- Old Shrine Garden: flower patches, fountain, one optional altar-like visual; no full faith trigger unless re-enabled.
- Sinkhole Edge: jagged cave edge with water/mud, ambush monsters around bends.

Tile notes:
- Use `dngn/floor/grass`, `dngn/trees/tree*`, `mangrove*`, `decor/flower_patch_*`, `decor/garden_patch`, `water/toxic_bog*`.
- Trees should form clumps of 4-10 tiles, leaving clear paths and sight breaks.
- Place loot near camps/gardens, not randomly in plain halls.

## Main 3F - Orc Mine Settlement

Theme: not just a mine: a hostile underground work town with production, storage, and guard posts.

Sub-regions:
- Ore Works: rough cave tunnels, dark stone, ore/gem item dressing, miners/blast enemies.
- Barracks Yard: broad open training square, weapon racks, armor/weapon loot chance, orc warriors.
- Storehouse: crates/food/gold, many small item piles, guarded but not boss-level.
- Vault/Pay Office: locked-looking compact room, gold/gem-heavy, stronger guards.
- Forge Shrine: fire/lava or glowing floor accents, axes/maces/staves visual emphasis, priest/wizard support.

Tile notes:
- Props: `statues/orcish_idol`, `decor/cache_of_meat_*`, `decor/cache_of_baked_goods_*`, `item/gold`, `item/gem`, weapon/armour floor drops.
- Layout: use wide mine caverns plus built rectangular rooms. Avoid only tunnels.
- Gameplay: vault/storehouse should telegraph high reward with higher risk.

## Main 4F - Elven Village / Arcane Quarter

Theme: an underground elven enclave, more like a village campus than a dungeon floor.

Sub-regions:
- Moonwell Plaza: fountain/water center, open sightlines, elegant patrols.
- Library: shelves implied by blocking rows/statues/book item dressing, magic books/parchment/spellpage rewards.
- Garden Walk: trees, flowers, narrow scenic paths, archers use sightlines.
- Training Court: clean rectangular yard with statues/dummies, blademasters/archers.
- Warded Study: small rooms with trap sigils/teleporter visuals, high magic loot.

Tile notes:
- Props: `decor/sparkling_fountain*`, `decor/blue_fountain*`, `decor/flower_patch_*`, `statues/statue_archer`, `statues/statue_sword`, `traps/binding_sigil`, `teleporter.png`.
- Loot identity: books, parchment, wands, staves, essence.
- Layout: more open courtyards and diagonal garden paths; fewer cramped corridors.

## Main 5F - Crypt

Theme: the dungeon tightens into sealed burial architecture. This floor should feel narrower and more dangerous than Elven Halls, with reliable choke points and one or two retreat loops.

Sub-regions:
- Charnel Walk: first tight corridor, teaches pressure from narrow halls.
- Tomb Loop: central loop with alternate routes and door decisions.
- Necromancer Study: magic pressure pocket with undead casters.
- Grief Archive: book/ring/identification reward room.
- Ossuary Vault: visible high-risk treasure room.
- Burial Chapel: last safe prep zone before the abyss.
- Grave Cathedral: large combat hall landmark.
- Vault Gate: fixed branch entrance to Vault, visually distinct from the crypt rooms.

Tile/prop notes:
- Use `wall_stone_necropolis_1`, `floor/necro_squares00`, crumbled columns, gravestone variants, dry fountains, and grave/ossuary dressing.
- Reward identity: necromancy books, charms, rings, essence of undeath, identification items.
- Layout should be solemn and readable: long halls, tomb chambers, narrow side crypts, and one clear exit route.

## Main 6F - Abyssal Breach / Final Route

Theme: the dungeon is collapsing into a shifting void. This floor can justify changing tiles over time.

Sub-regions:
- Stable Rim: normal dungeon floor, last safe preparation area.
- Fracture Field: broken islands, abyss wall palette, teleport/dispersal trap visuals.
- Starwater Basin: strange water pools, tentacle/abyss monsters, risky shortcuts.
- Shifting Maze: uses existing timed map-change behavior; floor chunks rotate or open/close.
- Final Seal: ritual arena with statues, sigils, boss entrance, high contrast floor.

Tile notes:
- Use `dngn/wall/abyss`, `water/starwater_*`, `traps/dispersal`, `traps/teleport*`, `statues/statue_zot_*`, `mon/tentacles/*` if needed as environmental blockers/props.
- Make the unstable area visually distinct before it changes, and keep it wide enough for multi-enemy movement rather than a single-file corridor.
- Do not fill the whole map with chaos. Keep one stable path plus optional dangerous shortcuts.

## Branch - Swamp / Bog

Sub-regions: mangrove maze, toxic bog, drowned shrine, beast island, supply wreck.

Tile/prop notes:
- Use `water/toxic_bog*`, `trees/mangrove*`, dead trees, flower/garden patches sparingly.
- Water/bog should create soft pathing pressure but not constant annoyance.
- Reward identity: potions, rings, poison/earth/ice spell pages, survival-themed loot.

## Branch - Ice / Crystal

Sub-regions: frozen lake, reflective archive, rime pillar field, sealed armory, boss cave.

Tile/prop notes:
- Use ice/block/rime pillar statue assets, blue/sparkling fountains, crystal/gem item dressing.
- Strong straight sightlines for archers/casters, but with ice-block cover islands.
- Reward identity: cold spells, gems, armour, staves.

## Branch - Infernal / Forge

Sub-regions: lava forge, chain bridge, demon barracks, ash chapel, treasure furnace.

Tile/prop notes:
- Use demonic trees, fire/orb statues, blood fountains, fire/hell-themed traps.
- Add visible heat zones before damage hazards.
- Reward identity: branded weapons, armour, fire spells, high-risk gold.

## Branch - Vault

Sub-regions: gold hall, ledger office, reliquary stack, guard reserve, treasury core.

Tile/prop notes:
- Use golden statues, vault signage, reliquary shelves, ledger desks, and guarded treasure dressing.
- Reward identity: gold, gems, rings, high-value consumables, and elite guard drops.
- Layout should feel compact and deliberate: short halls, guarded rooms, and a visible central reward route.

## Implementation Notes

- Start by adding a map-dressing pass after base generation, before monster/item placement.
- Store sub-region rectangles or masks in map metadata so spawners can bias monsters/loot by region.
- Add a small tile alias table first, not hard-coded paths scattered through generation:
  - `forest_tree`, `dead_tree`, `mangrove`, `flower`, `garden`, `fountain_blue`, `fountain_dry`
  - `orc_idol`, `crumbled_column`, `binding_sigil`, `teleporter`, `starwater`, `toxic_bog`
  - `gold_pile`, `book_stack`, `gem_pile`, `weapon_rack`
- First implementation target: decorative-only props and themed loot bias. Add blocking props/hazards after turn budget and pathfinding are tested.
