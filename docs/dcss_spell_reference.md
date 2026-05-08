# DCSS Spell Reference

Source: `oldproject/crawl/crawl-ref/source/spl-data.h`
Purpose: Reference for future spell additions to PocketCrawl. Use DCSS spell data (name, level, school) as the baseline — do not invent spells not in this list.

## Currently Implemented in PocketCrawl

| Spell | School | DCSS Level | PocketCrawl Tier |
|-------|--------|------------|-----------------|
| Freeze | Ice | 1 | 1 |
| Pain | Necromancy | 1 | 1 |
| Shock | Air+Conjuration | 1 | 1 |
| Sleep | Hexes | 5 (DCSS) | 1 |
| Slow | Hexes | 1 | 1 |
| Sandblast | Earth | 1 | 1 |
| Foxfire | Fire+Conjuration | 1 | 1 |
| Animate Skeleton | Necromancy | axed (was L2) | 2 |
| Blink | Translocation | 2 | 2 |
| Call Imp | Summoning | 2 | 2 |
| Conjure Flame | Fire | axed (was L2) | 2 |
| Petrify | Earth+Alchemy | 4 | 2 |
| Scorch | Fire | 2 | 2 |
| Shroud of Golubria | Translocation | axed (was L2) | 2 |
| Static Discharge | Air+Conjuration | 2 | 2 |
| Confuse | Hexes | 3 | 3 |
| Cause Fear | Hexes | 4 (DCSS) | 3 |
| Lee's Rapid Deconstruction | Earth | 5 (DCSS) | 3 |
| Lightning Bolt | Air+Conjuration | 5 (DCSS) | 3 |
| Stone Arrow | Earth+Conjuration | 3 | 3 |
| Summon Vermin | Summoning | 5 (DCSS) | 3 |
| Swiftness | Air | 3 | 3 |
| Vampiric Draining | Necromancy | 3 | 3 |
| Airstrike | Air | 4 | 4 |
| Animate Dead | Necromancy | 4 | 4 |
| Ensorcelled Hibernation | Hexes+Ice | 2 (DCSS) | 4 |
| Lehudib's Crystal Spear | Earth+Conjuration | 8 (DCSS) | 4 |
| Monstrous Menagerie | Summoning | 7 (DCSS) | 4 |
| Ozocubu's Refrigeration | Ice | 7 (DCSS) | 4 |
| Polymorph | Hexes+Alchemy | 4 | 4 |
| Stoneskin | Earth+Transmutation | axed (was L4) | 4 |
| Death's Door | Necromancy | 9 (DCSS) | 5 |
| Fireball | Fire+Conjuration | 5 | 5 |
| Ignition | Fire | 8 (DCSS) | 5 |
| Malign Gateway | Summoning+Translocation | 7 (DCSS) | 5 |
| Shatter | Earth | 9 (DCSS) | 5 |
| Haste | Hexes | 6 (DCSS) | 5 |
| Haunt | Summoning+Necromancy | 7 (DCSS) | 5 |
| Mass Confusion | Hexes | 6 (DCSS) | 5 |
| Chain Lightning | Air+Conjuration | 9 | 7 |
| Fire Storm | Fire+Conjuration | 9 | 7 |
| Glaciate | Ice+Conjuration | 9 | 7 |

**Note on tier mapping:** PocketCrawl tier assignments in ItemRegistry.gd (`SPELL_POOL`) are the authority. The DCSS levels above are the source reference; PocketCrawl often scales them differently for the shorter XL-20 progression.

## PocketCrawl Tier Mapping

| DCSS Level | Typical PocketCrawl Tier |
|------------|--------------------------|
| 1–2 | 1–2 |
| 3–4 | 2–3 |
| 5–6 | 3–5 |
| 7–9 | 5–7 (capped) |

Actual tier assignment is in `scripts/systems/ItemRegistry.gd` SPELL_POOL — that is the authority.

## Not Yet Implemented (candidates for future updates)

Player-castable DCSS spells at levels 1–7 not yet in PocketCrawl, grouped by school.
Spells marked `monster` only in spl-data.h are excluded. Forgecraft school (new to recent DCSS) excluded as it has no analogue in PocketCrawl schools.

### Air

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Vhi's Electric Charge | 4 | Air+Translocation; gap-close + shock |
| Conjure Ball Lightning | 6 | Air+Conjuration; creates ball lightning ally |
| Dispersal | 6 | Translocation; AoE blink-away escape |
| Maxwell's Capacitive Coupling | 8 | Air; heavy delayed lightning nuke |

### Earth

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Dig | 4 | Earth; tunnel through walls |
| Passwall | 3 | Earth; phase through a single wall |
| Leda's Liquefaction | 4 | Earth+Alchemy; slows enemies in range |
| Borgnjor's Vile Clutch | 5 | Necromancy+Earth; immobilising roots |
| Tremorstone | 2 | Earth; AoE shockwave, no targeting |
| Fastroot | 5 | Hexes+Earth; root a target in place |
| Brom's Barrelling Boulder | 4 | Earth+Conjuration; line-piercing boulder |

### Fire

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Throw Flame | 2 | Fire+Conjuration; basic fire bolt |
| Sticky Flame | 4 | Fire+Alchemy; melee range ignite |
| Ignite Poison | 4 | Fire+Alchemy; converts poison to fire |
| Inner Flame | 3 | Hexes+Fire; make enemy explode on death |
| Starburst | 6 | Fire+Conjuration; AoE fire burst |
| Flame Wave | 4 | Fire+Conjuration; channeled expanding fire |

### Ice

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Throw Frost | 2 | Ice+Conjuration; basic cold bolt |
| Ozocubu's Armour | 3 | Ice; defensive ice sheath |
| Frozen Ramparts | 3 | Ice; AoE freeze walls/adjacent |
| Hailstorm | 3 | Ice+Conjuration; radial hail burst |
| Iceblast | 5 | Ice+Conjuration; large cold nova |
| Metabolic Englaciation | 5 | Hexes+Ice; AoE slow |

### Hexes

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Corona | 1 | Hexes; highlight enemy (glow) |
| Tukima's Dance | 3 | Hexes; animate enemy's weapon |
| Charm | 4 | Hexes; convert enemy to ally |
| Paralyse | 4 | Hexes; hard stop on enemy |
| Silence | 5 | Hexes+Air; prevent spellcasting |
| Discord | 8 | Hexes; AoE berserk confusion |
| Enfeeble | 7 | Hexes; mass weaken |
| Anguish | 4 | Hexes+Necromancy; pain link |
| Jinxbite | 2 | Hexes; self-buff hex curse |
| Sigil of Binding | 3 | Hexes; floor trap sigil |
| Yara's Violent Unravelling | 5 | Hexes+Alchemy; strip and explode enchantments |
| Vitrify | 5 | Hexes; petrify (silicate) |
| Fastroot | 5 | Hexes+Earth; root target |

### Necromancy

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Sublimation of Blood | 2 | Necromancy; convert HP to MP |
| Soul Splinter | 1 | Necromancy; low-level pain variant |
| Dispel Undead | 4 | Necromancy; anti-undead burst |
| Death Channel | 6 | Necromancy; create spectres on kill |
| Borgnjor's Revivification | 8 | Necromancy; full HP restore, takes max HP |
| Fugue of the Fallen | 3 | Necromancy; self-buff from slain nearby |
| Grave Claw | 2 | Necromancy; short range necrotic grasp |
| Infestation | 8 | Necromancy; mark for death beetles |
| Agony | 5 | Necromancy; halve enemy HP |
| Rimeblight | 7 | Necromancy+Ice; apply stacking rot |
| Curse of Agony | 5 | Necromancy; ranged agony |
| Hurl Torchlight | 4 | Conjuration+Necromancy; thrown ghostfire |

### Summoning

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Summon Small Mammal | 1 | Summoning; bats/rats ally |
| Summon Ice Beast | 3 | Ice+Summoning; frozen beast |
| Call Canine Familiar | 3 | Summoning; dog ally |
| Summon Forest | 5 | Summoning+Translocation; trees + Dryad |
| Summon Hydra | 7 | Summoning; hydra ally |
| Summon Mana Viper | 5 | Summoning+Hexes; antimagic snake |
| Eringya's Surprising Crocodile | 4 | Summoning; surprise croc from ground |
| Dragon's Call | 9 | Summoning; call dragon waves |
| Summon Cactus Giant | 6 | Summoning; cactus giant |

### Translocation

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Apportation | 1 | Translocation; pull item to you |
| Teleport Other | 3 | Translocation; teleport an enemy |
| Lesser Beckoning | 2 | Translocation; pull enemy closer |
| Gell's Gravitas | 3 | Translocation; gravity well, pull enemies |
| Warp Space | 5 | Translocation; area translocation field |
| Manifold Assault | 7 | Translocation; attack from all angles |
| Maxwell's Portable Piledriver | 3 | Translocation; ram target into wall |
| Gell's Gavotte | 6 | Translocation; swap + reposition |

### Alchemy (Poison/Transmutation — not a PocketCrawl school, remap to poison)

| Spell | DCSS Level | Notes |
|-------|-----------|-------|
| Mephitic Cloud | 3 | Alchemy+Conjuration+Air; poison cloud |
| Olgreb's Toxic Radiance | 4 | Alchemy; radiate poison AoE |
| Poisonous Vapours | 1 | Alchemy+Air; melee poison cloud |
| Mercury Arrow | 2 | Alchemy+Conjuration; slow + poison bolt |
| Irradiate | 5 | Conjuration+Alchemy; close-range mutation blast |
| Corrosive Bolt | 6 | Conjuration+Alchemy; corrosion bolt |
| Eringya's Noxious Bog | 6 | Alchemy; create swamp of poison |
| Fulsome Fusillade | 8 | Alchemy+Conjuration; chaotic fusillade |

### Mixed / Multi-school highlights (L1–5, not monster-only)

| Spell | Schools | DCSS Level | Notes |
|-------|---------|-----------|-------|
| Volatile Blastmotes | Fire+Translocation | 3 | Plant proximity mines |
| Thunderbolt | Air+Conjuration | 2 | Charging lightning bolt |
| Searing Ray | Conjuration | 2 | Channeled burn beam |
| Orb of Destruction | Conjuration | 7 | Slow-moving mega-orb |
| Iceblast | Ice+Conjuration | 5 | Explosive cold orb |
| Starburst | Fire+Conjuration | 6 | Radial fire burst |
| Plasma Beam | Fire+Air | 6 | Penetrating fire+lightning bolt |

---

*Spells marked `spflag::monster` only in spl-data.h are not listed (they are not player-castable in DCSS).*
*"axed" = removed from DCSS but kept for save-compatibility via AXED_SPELL macro.*
*Schools not in PocketCrawl (forgecraft, alchemy) noted — decide mapping before implementing.*
