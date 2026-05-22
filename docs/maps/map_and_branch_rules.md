# Map And Branch Rules

The map system should reuse the useful parts of `PROJ_D`, but the campaign structure should change to fit the new town and expedition loop.

## What To Reuse

Good migration targets:

- `MapGen.gd`: BSP, cave, large BSP, crypt-style generators.
- `DungeonMap.gd`: tile storage, walkability, FOV integration points, stairs, branch entrance tile.
- `ZoneManager.gd`: branch data shape and branch monster pool idea.

Reference copy:

- `scripts/systems/ZoneManager.proj_d_reference.gd`

New clean rule layer:

- `scripts/systems/ExpeditionZoneRules.gd`

## Main Change

`PROJ_D` is a 15-floor continuous dungeon crawl with side branches. The new game keeps the main-dungeon descent structure, but compresses it from 15 floors into 5 fixed main floors.

Every main dungeon theme becomes one fixed main floor:

- `PROJ_D` dungeon depths 1-3 -> Main Floor 1: Catacombs
- `PROJ_D` lair depths 4-6 -> Main Floor 2: Lair
- `PROJ_D` orc mines depths 7-9 -> Main Floor 3: Orc Mines
- `PROJ_D` elven halls depths 10-12 -> Main Floor 4: Elven Halls
- `PROJ_D` abyss depths 13-14 -> Main Floor 5: Abyss, then final boss

This is still a dungeon made of floors. It is not five separate unrelated expeditions. Each compressed floor represents the whole theme band from `PROJ_D`.

The full layout of each theme should be fixed. Re-entering the same dungeon theme should not reroll walls, rooms, corridors, exits, vault positions, or major landmarks. Only visit content should vary:

- monster spawn positions
- patrol groups
- chest contents
- minor event activation
- temporary hazards

Branch entrance positions are fixed. If a main floor has a branch, the main gate location should always be in the same place on that floor layout. The area around the gate can change per visit.

This makes each theme learnable while preserving replay variation.

Exploration memory is character-bound. If a character reveals part of a minimap, that revealed record remains on that character's later visits to the same area. If the character dies, the minimap record dies with that character. Town progress can persist, but explored tiles should not become account-wide knowledge.

The new game should be town-first, then dungeon-floor based:

1. Player starts in town.
2. Player enters the main dungeon or a discovered branch.
3. Each dungeon visit has a turn budget.
4. The character returns automatically when the budget expires.
5. Death deletes the character.
6. Town progress, discovered branches, and account-level unlocks persist.

Branches can still have fixed physical entrances on their parent main floors. Once discovered, the town UI may also allow direct preparation or fast travel later, but the world structure should treat them as branches attached to main floors.

## Area Model

Each expedition area needs:

- `id`
- `name`
- `main_floor`
- `source_depth_range`
- `layout_id`
- `layout_seed`
- `static_layout`
- `persistent_exploration`
- `exploration_persistence`
- `map_style`
- `wall_tile`
- `floor_tile`
- `danger`
- `turn_budget`
- `monster_tags`
- `hazards`
- `reward profile`
- `skill hooks`

Main route areas are the 5 compressed dungeon floors. Branches are sharper optional challenge floors with stronger identity.

## Main Dungeon Floors

First pass:

- Main Floor 1: Buried Catacombs
  - source: `PROJ_D` depths 1-3
  - style: BSP
  - role: starter ruin expedition
  - branch: Sunken Crypt

- Main Floor 2: Green Lair
  - source: `PROJ_D` depths 4-6
  - style: cave
  - role: first organic/beast pressure
  - branch: Blackfen Swamp

- Main Floor 3: Orc Mines
  - source: `PROJ_D` depths 7-9
  - style: BSP
  - role: weapon pressure, armor pressure, locked loot
  - branch: Ice Caves

- Main Floor 4: Elven Halls
  - source: `PROJ_D` depths 10-12
  - style: large BSP
  - role: ranged, magic, elite threats
  - branch: Infernal Gate

- Main Floor 5: Shattered Abyss
  - source: `PROJ_D` depths 13-14
  - style: cave
  - role: unstable endgame expedition into final boss
  - branch: none

## Branches

First branch set inherited from `PROJ_D`:

- Blackfen Swamp
  - source: `swamp`
  - parent: Main Floor 2, Green Lair
  - fixed entrance: Green Lair swamp gate
  - unlock: after reaching Main Floor 2
  - reward: `essence_plague`
  - pressure: poison, bog water, ambush beasts

- Ice Caves
  - source: `ice_caves`
  - parent: Main Floor 3, Orc Mines
  - fixed entrance: Orc Mines ice gate
  - unlock: after reaching Main Floor 3
  - reward: `essence_glacial`
  - pressure: cold, burst damage, slow terrain

- Infernal Gate
  - source: `infernal`
  - parent: Main Floor 4, Elven Halls
  - fixed entrance: Elven Halls infernal gate
  - unlock: after reaching Main Floor 4
  - reward: `essence_infernal`
  - pressure: fire, lava, aggressive enemies

- Sunken Crypt
  - source: `crypt`
  - parent: Main Floor 1, Buried Catacombs
  - fixed entrance: Catacombs crypt gate
  - unlock: after reaching Main Floor 1
  - reward: `essence_undeath`
  - pressure: undead, sealed tombs, magic threats

`PROJ_D` rune and faith reward logic should not be ported. Branch boss rewards should be essence-first.

## Skill Integration

The branch system should justify non-damage skills.

- Tracking reveals monster density, boss hints, hidden exits, and branch objectives.
- Survival improves safe return, status cleanup, and expedition recovery.
- Lockpicking opens sealed vaults, shortcut doors, and high-value chests.
- Stealth enables optional avoidance and better first strikes.
- Defense matters in branches with burst attackers and dangerous terrain.
- Tactics can reveal positional threats and improve risky branch fights.

Avoid making these skills passive percentage decorations only. Each one should change route choices or risk decisions.

## Character Minimap Memory

Minimap memory should be stored on the character, not on the town.

Recommended structure:

```gdscript
character.map_memory[layout_id] = {
	"explored_tiles": {},
	"known_doors": {},
	"known_landmarks": {},
	"known_hazards": {},
	"known_resource_nodes": {},
	"last_monster_signs": {},
}
```

Rules:

- Revealed minimap tiles persist between expeditions for the same character.
- A new character starts with blank minimap memory.
- Character permadeath deletes map memory.
- Fixed layouts make this memory meaningful.
- Per-visit monster spawns should not permanently reveal exact enemy positions.

Survival controls minimap detail quality:

- Survival 0-29: revealed floor shape, seen doors.
- Survival 30-54: landmarks, locked doors, vault marks.
- Survival 55-79: hazard notes, resource notes, safer route notes.
- Survival 80-100: old monster signs, likely patrol paths, suggested return routes.

This gives Survival a strong exploration identity without turning it into a pure combat stat.

## Map Generation Requirements

For the first playable version:

- Main route uses `MapGen.generate_styled`.
- Area config chooses map style by main floor.
- Main dungeon has 5 floors, not 15 floors.
- Each compressed main floor should be denser than an old `PROJ_D` floor because it represents an entire theme band.
- Each main floor should use a fixed layout seed or authored layout file.
- Do not call fresh random map generation for every visit.
- Use a separate spawn seed for per-visit monster placement.
- Branch entrance locations are fixed parts of each stage layout.
- Shattered Abyss has no branch; clearing Main Floor 5 should lead toward the final boss sequence.
- Branch maps use 3 floors, not 4, to fit mobile sessions.
- Final branch floor removes downward stairs and spawns the boss.
- Branch clear marks the branch complete and grants essence reward.
- Existing branch entrance tile support can be kept, but should unlock town access instead of forcing immediate side-branch entry.

## Turn Budget

Turn budget is the mobile replacement for hunger.

Baseline:

- Main Floor 1: 240 turns
- Main Floor 2: 260 turns
- Main Floor 3: 270 turns
- Main Floor 4: 290 turns
- Main Floor 5: 300 turns
- branches: 170-190 turns per floor

The timer should create pressure without forcing constant rush play. It should be visible before expedition launch.

## Implementation Notes

Do not wire `ExpeditionZoneRules.gd` directly into old `Game.gd`.

Build a new `ExpeditionState` first:

- selected area id
- current main floor
- branch floor, only when inside a branch
- turn budget
- turns spent
- visit index
- generated seed
- collected loot
- character map memory updates
- temporary expedition flags

Then make map generation consume:

```gdscript
var style := ExpeditionZoneRules.map_style_for_area(area_id, main_floor)
var layout_seed := ExpeditionZoneRules.layout_seed_for_area(area_id, main_floor)
map.generate(layout_seed, false, style)
```

Monster placement should consume a different seed:

```gdscript
var spawn_seed := ExpeditionZoneRules.spawn_seed_for_visit(area_id, main_floor, visit_index)
spawn_monsters_for_visit(spawn_seed)
```

Faith, rune title rewards, old branch cache, and old continuous-depth assumptions should be treated as migration references only.
