# Fixed Map Layout Designs

These are blockout designs for the fixed 96x96 maps. They are not final tile art. They define the structure that authored maps or constrained map generation should follow.

Use the existing `PROJ_D` dungeon tilesets. Do not invent a new visual tileset for the first pass.

Coordinate convention:

- map size: `96 x 96`
- origin: top-left
- player usually enters near the bottom
- main goal usually sits near the top
- branch entrances are fixed landmarks

Implementation data lives in:

- `scripts/systems/ExpeditionFixedLayoutDesigns.gd`

Visual atlas:

- `docs/maps/fixed_map_atlas.svg`

## Sub-Area Design Rules

Because each main floor compresses several old `PROJ_D` depths into one fixed mobile map, every main floor should be wider and more authored than a normal procedural level.

Each main floor should contain:

- 8-10 named sub-areas.
- 2-3 meaningful loops or shortcuts.
- 1 branch gate or final gate landmark.
- 1 high-value reward district with a visible risk.
- 1 skill-gated reward district or shortcut.
- 1 identity landmark that can be recognized immediately from the minimap shape.

Sub-areas do not need to be enclosed rooms. Treat them as authored districts. Depending on the theme, a district can be a plaza, mine yard, camp, bridge, platform, shelf, archive, garden, market, shoreline, cave pocket, or ritual ground. Rectangular rooms are appropriate for catacombs, crypts, libraries, vaults, and stores, but they should not dominate every floor.

Avoid making every district a separate room connected by a corridor. Some floors should merge multiple districts into one large readable space:

- Orc Mines should have a broad mine camp/ore yard where smaller sheds and hazards sit inside one open work area.
- Elven Halls should have a palace plaza where garden, terrace, mirror court, and gallery edges touch.
- Lair, Swamp, Ice Caves, and Abyss should use open basins, shelves, islands, or caverns more often than rectangular rooms.

Reward placement should sell the theme:

| Theme | Reward Rooms |
| --- | --- |
| Catacombs | pilgrim caches, sealed cells, scroll alcoves |
| Lair | hunter blinds, fungal potion pockets, safe shelters |
| Orc Mines | pay chests, locked armories, foreman stores |
| Elven Halls | libraries, reliquaries, wand archives |
| Abyss | rare broken caches, shifting rooms, memory wells |

Sub-area metadata lives in `ExpeditionFixedLayoutDesigns.gd` as landmark `role`, `district_style`, `reward_profile`, `skill_hook`, or `dynamic_rule` fields. These fields are intentionally lightweight so the first playable pass can use them for spawn and loot bias without adding another map format.

`monster_profile` is a district-level spawn hint, not a hard spawn list. It should bias the visit generator so repeated runs preserve the same ecology without forcing identical monster placement.

## Main Dungeon Floors

### Main Floor 1: Buried Catacombs

Purpose: first learnable dungeon. Short loops, simple locks, early undead hints, and a visible sealed underchurch.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/catacombs0.png`
- floor: `res://assets/tiles/individual/dngn/floor/dirt0.png`

Flow:

```text
Sealed Crypt Gate -- Undertaker Cells -- Upper Chapel / Main Exit
        |                    \          /
Broken Training Hall -- Ossuary Ring -- Bone Scriptorium
        |                    /
Entry Stair -------- Pilgrim Cache
```

Fixed landmarks:

- Entry: bottom center.
- Broken Training Hall: lower-left, first combat teaching space. Monster profile: vermin and weak humanoids.
- Pilgrim Cache: lower-right low-risk reward room with food, gold, or a scroll. Monster profile: vermin.
- Ossuary Ring: central loop, lets the player learn alternate paths. Monster profile: skeletons and grave slimes.
- Bone Scriptorium: upper-right scroll and map-lore pocket. Monster profile: undead casters and grave slimes.
- Undertaker Cells: upper-left locked side rooms. Monster profile: zombies and grave slimes.
- Sealed Crypt Gate: upper-left fixed branch entrance to Sunken Crypt. Monster profile: undead guards.
- Upper Chapel: upper-right main stage exit. Monster profile: stronger undead.

Design notes:

- The branch gate is visible early but not necessarily safe to enter.
- Lockpicking should have a low-risk door here.
- Tracking can mark old footprints around the ossuary.
- Keep the first floor readable: monster profiles should teach "vermin outside, undead deeper, slimes around old bodies and water."

### Main Floor 2: Green Lair

Purpose: organic cave with animal routes, water pressure, fungal risk, and survival route choices.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/lair0.png`
- floor: `res://assets/tiles/individual/dngn/floor/lair0.png`

Flow:

```text
Swamp Gate -------- Central Pool -------- Hunter Blind -- High Roost / Main Exit
      \                 |                      /
       \             Beast Den -- Fungal Grotto
        \               |
Root Entry ------ Moss Switchback
```

Fixed landmarks:

- Entry: lower-left. Monster profile: insects.
- Moss Switchback: lower-mid alternate route where Survival can mark safer footing. Monster profile: insects and small beasts.
- Beast Den: lower-middle, common monster pressure. Monster profile: beasts.
- Fungal Grotto: lower-right potion reward with poison/spore pressure. Monster profile: slimes and fungi.
- Central Pool: middle, water hazard and visibility break. Monster profile: amphibians and slimes.
- Swamp Gate: upper-left, fixed branch entrance. Monster profile: reptiles and poison beasts.
- Hunter Blind: upper-right ranged reward and Tracking clue point. Monster profile: insects and beasts.
- High Roost: upper-right, main stage exit. Monster profile: fliers and elite beasts.

Design notes:

- The center should have multiple short routes around water.
- Monster spawns can change between den, pool, and roost, but each district should keep its ecological bias.
- Survival can annotate safe water crossings.
- This floor should feel like a small ecosystem: insects near roots, beasts in dens, slimes near damp fungus, reptiles near the swamp gate, fliers in the roost.

### Main Floor 3: Orc Mines

Purpose: a broad mining settlement rather than a pure room dungeon: lift platforms, ore yards, barracks, sheds, locked stores, and equipment pressure.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/orc0.png`
- floor: `res://assets/tiles/individual/dngn/floor/orc0.png`

Flow:

```text
Smelter Yard -- Barracks Stockade -------- Foreman's Store / Main Exit
       \          |               /
        \      Ore Yard Loop -- Pay Chest -- Locked Armory
         \        |              /
Old Mine Lift -- Crusher Lane -- Frozen Breach
```

Fixed landmarks:

- Entry: lower-left.
- Ore Yard Loop: central open work yard with carts and broken rails.
- Crusher Lane: lower-right hazard corridor and fast route to the branch gate.
- Barracks Stockade: left-mid combat pressure, more camp than room.
- Pay Chest Office: mid-right gold-heavy locked shed.
- Locked Armory: right-mid equipment reward shed.
- Frozen Breach: lower-right, fixed branch entrance to Ice Caves.
- Smelter Yard: upper-left fire-risk side district.
- Foreman's Store: upper-right locked reward area and main exit route.

Design notes:

- This is the best place to make Lockpicking matter.
- The Pay Chest Office should be the clearest "money room" in the main route.
- The Locked Armory should bias toward weapons, armor, ammunition, and upgrade consumables.
- Fixed shortcut doors should reduce travel time on repeat visits.
- Ranged enemies can use long mine corridors.
- Monster ecology: orc workers and guards in the ore yard, warriors and priests in the stockade, constructs near crusher machinery, cold beasts near the ice breach, fire beasts near the smelter.

### Main Floor 4: Elven Halls

Purpose: a ruined underground elven village/palace district with sightlines, terraces, libraries, gardens, reliquaries, and magic pressure.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/elf-stone0.png`
- floor: `res://assets/tiles/individual/dngn/floor/marble_floor1.png`

Flow:

```text
Northern Sanctum / Main Exit
          |
Crystal Reliquary
    /      |       \
Silent Library -- Mirror Court -- Burning Mirror Gate
    |          \          |
Lower Gardens -- Southern Gallery -- Sun Terrace
```

Fixed landmarks:

- Entry: bottom center.
- Southern Gallery: first long sightline.
- Lower Gardens: lower-left ruined village/garden route with stealth cover.
- Sun Terrace: lower-right open terrace with wand/scroll rewards.
- Silent Library: left magic/stealth route with spellbooks and scrolls.
- Mirror Court: central plaza danger area.
- Crystal Reliquary: upper-mid elite reward room.
- Burning Mirror Gate: right, fixed branch entrance to Infernal Gate.
- Northern Sanctum: upper center, main stage exit.

Design notes:

- This stage should feel more authored and less natural.
- Sightlines matter: ranged/magic enemies can threaten from far away.
- Library rewards should bias toward spellbooks, scrolls, wands, and identification resources.
- Magery and Tactics should both reveal useful information here.
- Monster ecology: archers and scouts in open terraces, mages and animated books in libraries, illusions and elite guards in the Mirror Court, demons near the Burning Mirror Gate.

### Main Floor 5: Shattered Abyss

Purpose: final approach. No branch. Pressure funnels toward final boss while parts of the map feel unstable.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/abyss/abyss0.png`
- floor: `res://assets/tiles/individual/dngn/floor/depthstone_floor0.png`

Flow:

```text
Final Gate
   |       \
Memory Well -- Void Spine -- Time-Slip Gallery
   |             |              |
Rift Market -- Left Shard -- Right Shard
        \        |        /
          Last Descent / Entry
```

Fixed landmarks:

- Entry: bottom center.
- Left Shard and Right Shard: fragmented mid-map routes.
- Rift Market Ruin: weird rare consumable cache with dangerous spawns.
- Time-Slip Gallery: shifting sub-area that can reuse the old `PROJ_D` Abyss shift logic.
- Void Spine: narrow unstable central path.
- Memory Well: Tracking reward area and route preview landmark.
- Final Gate: upper center, opens final boss sequence.

Design notes:

- No branch entrance.
- The layout should be memorable and hostile.
- Temporary hazards can vary by visit, but the major island shapes stay fixed.
- The Time-Slip Gallery may alter local walls, doors, fog, or exits every fixed turn interval. Do not shift the whole map; only this authored pocket should move.
- Monster ecology: void beasts on the shards and spine, demons near the right shard and market ruin, phase beasts inside shifting pockets, memory echoes near the Memory Well.

## Branches

Branches are fixed too, but they can still be multi-floor. Each floor should keep its authored layout and use visit-based spawn variation.

### Sunken Crypt

Parent: Buried Catacombs.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/wall_stone_necropolis_1.png`
- floor: `res://assets/tiles/individual/dngn/floor/necro_squares00.png`
- entrance: `res://assets/tiles/individual/dngn/gateways/necropolis_portal.png`

Floor beats:

- outer tombs
- sealed royal vault
- lich chamber

Core structure:

- bottom entry
- side sealed tombs
- central tomb corridor
- upper boss chamber

Skills:

- Lockpicking opens tomb rooms and shortcut doors.
- Tracking reveals warded undead clusters.

Monster ecology:

- Sunken Crypt: zombies at the flooded entry, skeletons in outer tombs, grave slimes in flooded crypt water, undead casters near the lich antechamber.
- Blackfen Swamp: insects and amphibians near the reed entry, slimes in bog channels, reptiles and poison beasts in the reed maze, the serpent nest as the boss pocket.
- Ice Caves: cold beasts in breach tunnels, ice constructs near thin ice, safer vermin-only pressure around the warm shelter, glacial sovereign in the throne.
- Infernal Gate: fire beasts at the vestibule, demons in the ash barracks, demon mages in the cinder library and counter-ward, fire elementals around the lava crucible.

### Blackfen Swamp

Parent: Green Lair.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/wall_vines0.png`
- floor: `res://assets/tiles/individual/dngn/floor/swamp0.png`
- entrance: `res://assets/tiles/individual/dngn/gateways/enter_swamp.png`

Floor beats:

- reed maze
- sunken shrine
- serpent nest

Core structure:

- diagonal route from lower-left to upper-right
- central bog channel
- optional dry ridges
- serpent nest boss area

Skills:

- Survival marks safer water crossings.
- Tracking reveals serpent trails and ambush zones.

### Ice Caves

Parent: Orc Mines.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/ice_wall0.png`
- floor: `res://assets/tiles/individual/dngn/floor/ice0.png`
- entrance: `res://assets/tiles/individual/dngn/gateways/ice_cave_portal.png`

Floor beats:

- frozen breach tunnels
- reflective ice archive
- thin ice bridge
- glacial throne

Core structure:

- lower-right entry from mine breach
- middle thin-ice crossing with brittle ice cover
- side archive loops with long sightlines
- upper-left boss chamber

Skills:

- Defense helps absorb giant burst pressure.
- Survival identifies shelter points and cold-safe paths.
- Tactics marks reflective lanes where ranged enemies have advantage.

### Infernal Gate

Parent: Elven Halls.

Tiles:

- wall: `res://assets/tiles/individual/dngn/wall/volcanic_wall0.png`
- floor: `res://assets/tiles/individual/dngn/floor/lava00.png`
- entrance: `res://assets/tiles/individual/dngn/gateways/enter_hell1.png`

Floor beats:

- ember vestibule
- lava crucible
- tyrant dais

Core structure:

- bottom entry
- central lava cross
- side counter-ward rooms
- upper tyrant boss dais

Skills:

- Magery identifies counter-wards.
- Tactics marks safe attack windows near lava.

## Authoring Rule

Fixed means:

- wall/floor layout does not change
- branch gate position does not change
- major landmark positions do not change
- boss arena position does not change

Variable means:

- monster spawn positions
- patrol routes
- chest contents
- temporary hazard activation
- minor event activation

This keeps map mastery while preserving replay variation.
