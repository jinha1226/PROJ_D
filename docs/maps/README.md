# Fixed Map Atlas

Use this image as the implementation reference for the fixed dungeon layouts:

- `fixed_map_atlas.svg`

It is a blockout, not final tile art. Claude Code should use it together with:

- `../rules/fixed_map_layout_designs.md`
- `../rules/map_and_branch_rules.md`
- `../../scripts/systems/ExpeditionFixedLayoutDesigns.gd`

Implementation priority:

1. Main Floor 1: Buried Catacombs
2. Main Floor 2: Green Lair
3. Main Floor 3: Orc Mines
4. Main Floor 4: Elven Halls
5. Main Floor 5: Shattered Abyss
6. Branches

The map image defines fixed spatial relationships. Monster spawns, patrols, chest contents, and temporary hazards still vary per visit.

## ASCII Implementation Maps

Runtime fixed layouts can now be authored as ASCII maps in `docs/maps/ascii/`.

Legend:

- `#`: wall
- `.` or `,`: floor
- `~`: shallow water or bog floor hazard
- `^`: lava or void crack floor hazard
- `+`: closed door
- `/`: open door
- `<`: player entry/up stair
- `>`: main goal/down stair/boss marker
- `B`: branch entrance

Each file must be exactly `96 x 96` characters. The layout dictionary field `ascii_map_path` points at the authored map. If the file is missing or empty, `MapGen.generate_fixed()` falls back to landmark carving.

## Authoring Direction

Each main floor should feel like a compressed zone, not a single ordinary room chain. Use the full 96x96 footprint and divide every fixed map into named sub-areas. A sub-area can be a room, plaza, mine yard, market, bridge, terrace, shoreline, camp, shrine, or shifting pocket.

- entry pocket: safe enough to orient the player
- route loop: at least two ways around the center
- pressure district: dense enemies, awkward sightlines, or hazardous terrain
- reward district: gold, equipment, magic, or rare consumables
- skill district: Lockpicking, Tracking, Survival, Magery, Tactics, or Stealth changes the route choice
- branch gate or final gate: visible and memorable landmark

The player-facing skill list stays at 9 skills. Fine-grained map concepts such as armories, libraries, vaults, crusher lanes, spore pockets, and shifting abyss rooms should be authored as internal tags and reward profiles, not as extra visible skills.

Do not force all authored maps into rectangular room layouts. Orc Mines can read as an open mining settlement with yards, sheds, lift platforms, and stockades. Elven Halls can read as a ruined underground village with terraces, archives, gardens, and plazas. Catacombs and Crypts can stay room-heavy; Lair, Swamp, Ice, and Abyss can be more organic.

When two or more districts are meant to feel like one place, merge them into a broad open area instead of connecting them with a narrow corridor. Good examples:

- Orc Mines: ore yard, crusher lane, pay shed, and armory can sit inside one large mining camp.
- Elven Halls: lower gardens, mirror court, sun terrace, and gallery can form one palace plaza.
- Lair and Swamp: several cave pockets can share one open shoreline or bog basin.
- Abyss: broken islands can be larger shared platforms with dangerous cracks cutting through them.
