# PocketCrawl - Drop Table Handoff For Claude Code

_Last updated: 2026-04-27_

This file is a focused implementation handoff for item-drop economy work.
It should be used together with:

- `D:\PROJ_D\docs\balance\claude_code_balance_handoff.md`
- `D:\PROJ_D\docs\balance\skill_and_progression.md`
- `D:\PROJ_D\docs\balance\game_concept_tables.md`

This document reflects the latest agreed direction from conversation, even where the code may not yet match it.

## 1. Drop Philosophy

PocketCrawl currently wants:

- smaller / more compact floors
- fewer total encounters
- more meaningful individual fights
- stronger consumable planning
- earlier build identity through gear, books, and essences

That means the drop economy should **not** behave like a sparse DCSS floor.
Because floors are smaller and fights are fewer, the player must still reliably see:

- potions
- scrolls
- some equipment
- a few milestone upgrades per sector

The goal is:

- consumables drive moment-to-moment survival
- equipment shapes the build
- books open magic routes
- essences act like a second build axis

## 2. Definitions

### Floor

One dungeon level.

### Sector

Three consecutive floors.

Recommended interpretation:

- Sector 1 = floors 1-3
- Sector 2 = floors 4-6
- Sector 3 = floors 7-9
- etc.

Use sector logic for guaranteed milestone drops.

## 3. Agreed Baseline Drop Table

These are the latest agreed target numbers.

### Floor Random Drops

| Category | Amount per floor |
|---|---:|
| Potions | 1-3 |
| Scrolls | 1-3 |
| Equipment | 1-2 |

### Sector Guaranteed Drops

| Category | Amount per 3-floor sector |
|---|---:|
| Enchant weapon scroll | 1 |
| Enchant armor scroll | 1 |
| Wands | 1-2 |
| Healing potions | 2-3 |
| Essences | 2 |

## 3A. Unique Monster Essence Rule

This was explicitly requested and should be treated as intended direction.

### General Rule

Normal monsters and unique monsters should not use the same essence reward model.

Recommended split:

- normal monsters = routine build-material essence sources
- unique monsters = special run-defining essence sources

### Unique Monster Drop Intent

DCSS-style uniques should feel rewarding in a way that is visible and memorable.
In PocketCrawl, that means:

- unique monsters should usually drop an essence
- that essence should often be special
- the essence should feel stronger or stranger than routine monster essences

### Recommended Unique Essence Rule

For monsters marked as unique:

- if the monster has a dedicated unique essence, drop it at **very high chance**
- if the monster has no dedicated unique essence yet, use a higher-tier essence table

Recommended probabilities:

- normal unique: `80%` chance to drop its special essence
- major unique / floor-boss style unique: `100%` chance

### Design Rule For Unique Essences

Unique essences should **not** just be bigger stat sticks.

Preferred structure:

- strong identity effect
- meaningful drawback
- strong synergy / resonance potential

Good examples of design direction:

- unusual passive
- build-defining conditional effect
- stronger resonance hook
- special utility not found on normal essences

Bad direction:

- normal essence but with bigger numbers only

### Why This Matters

The essence system is currently standing in for part of the “god system” feeling.
Unique monsters dropping memorable essences helps create:

- run identity
- rare build pivots
- meaningful elite encounters

This is one of the easiest ways to make essences feel important without flooding the dungeon with random power.

## 4. Important Design Intent Behind These Numbers

### Potions and scrolls should be common early

Reason:

- the player should identify them through use
- early floors should support planning and adaptation
- they are the main tactical pressure-release valves

Potions and scrolls should feel more common than:

- books
- wands
- thrown utility items

### Books should be meaningfully rarer

Reason:

- books unlock or expand magic routes
- books should feel like build-defining drops, not routine drops

Books should be **rarer than potions, scrolls, and usually rarer than wands**.

### Wands should matter, but not replace core combat

Reason:

- wands are powerful tactical tools
- they should be used at key moments, not spammed every fight

Implementation note:

- lower starting charges
- strong wands should often appear with very few charges

### Essences should be visible and meaningful

Reason:

- essence is standing in for part of the “god system” feeling
- essences should appear often enough that resonance and inventory choice matter

But:

- they should not flood the player every floor
- inventory cap should continue to force decisions

That is why `2 essences per 3-floor sector` is currently preferred over `1 essence every floor`.

Also note:

- sector guarantees cover the baseline essence economy
- unique-monster drops are a separate premium reward channel
- do not count special unique essence drops as the only way the player sees essences

## 5. Equipment Drop Direction

Current equipment structure already uses `tier`.

Important:

- do **not** make equipment generation strictly linear by depth
- allow occasional higher-tier early finds
- keep DCSS-like surprise value

### Recommended Tier Weight Model

This is the current recommended direction for equipment generation.

#### Floors 1-2

| Tier | Weight |
|---|---:|
| T1 | 70 |
| T2 | 25 |
| T3 | 5 |
| T4 | 0 |
| T5 | 0 |

#### Floors 3-5

| Tier | Weight |
|---|---:|
| T1 | 20 |
| T2 | 50 |
| T3 | 25 |
| T4 | 5 |
| T5 | 0 |

#### Floors 6-8

| Tier | Weight |
|---|---:|
| T1 | 5 |
| T2 | 20 |
| T3 | 45 |
| T4 | 25 |
| T5 | 5 |

#### Floors 9+

| Tier | Weight |
|---|---:|
| T2 | 10 |
| T3 | 25 |
| T4 | 40 |
| T5 | 25 |

### Why This Model

This keeps:

- depth progression
- occasional early excitement
- less rigid “always replace at next tier” behavior

This should be paired with the broader balance direction of **softening tier gaps**, not making every tier a huge linear upgrade.

## 6. Books

Books are intentionally **not** part of the common floor-random table above.

Recommended book logic:

- low baseline floor chance
- can appear as part of equipment/build reward logic
- should be notably rarer than scrolls and potions

Suggested target:

- average about `1 book per 2-3 floors`
- never more common than wands

Books should feel like:

- “this run might branch into magic”

not like:

- “another routine consumable”

## 7. Wands

Wands should be less common than scrolls/potions and more charge-limited.

Recommended role:

- tactical swing tool
- emergency answer
- setup tool for Rogue / Mage

Suggested wand charge direction:

- weak / utility wand: `3-4` charges
- strong wand: `1-3` charges

Do not compensate low frequency by giving huge charge pools.

## 8. Thrown / Utility Items

Thrown items and utility tools should be less common than scrolls/potions.

Suggested relative rarity:

- potions / scrolls = common
- thrown utility = uncommon
- wands = uncommon to rare
- books = rare

Thrown tools are especially relevant if Rogue continues leaning toward a ranged / utility identity.

## 9. Recommended Implementation Order

For Claude Code, the cleanest implementation order is:

1. establish sector tracking
2. apply guaranteed sector drops
3. rebalance floor-random drop counts
4. rebalance equipment tier weights
5. reduce book frequency
6. lower wand charge counts
7. validate actual per-floor totals in play

## 10. Implementation Notes

### A. Sector guarantees should not depend on RNG rarity

Do not “maybe” spawn the guaranteed milestone drops.
They should be injected by sector accounting.

### B. Guarantee does not mean all on one floor

Good implementation:

- distribute guaranteed sector drops across the three floors
- avoid giant loot spikes unless intentionally tied to special rooms/events

### B2. Unique essence drops should sit on top of the baseline economy

Do not use unique essence drops as an excuse to reduce baseline essence presence too far.

Preferred interpretation:

- sector guarantee provides the baseline
- unique encounters provide spikes

### C. Healing potions in the guaranteed table are for sustain pacing

This is partly replacing some of the pressure that hunger or injury might otherwise create.

If injury is later removed or heavily reduced, guaranteed healing remains useful.

### D. Equipment totals may need slight upward adjustment on compact floors

If floors are compact and fights are fewer, `1-2 equipment per floor` may still feel low.
If testing shows that equipment variety is too sparse, try:

- `1-3 equipment per floor`

before making tier weights more generous.

## 11. Current Open Questions

These were discussed but are not fully locked yet.

### Q1. Is `1-2 equipment per floor` enough on compact maps?

Likely answer:

- maybe not
- playtest may push this to `1-3`

### Q2. Should upgrade scroll supply be increased later?

Current recommendation:

- first soften tier progression
- do **not** solve all gear problems by flooding upgrade scrolls

### Q3. Should equipment tiers be softened further?

Current recommendation:

- yes, likely
- especially for weapons

This document does not change the weapon data directly, but the drop table should assume tier progression will become less harsh over time.

## 12. Short Summary

Claude Code should implement the drop economy using these principles:

- common potions and scrolls
- rarer books
- low-charge wands
- meaningful essence frequency
- special essence spikes from unique monsters
- equipment that still progresses by depth, but with occasional early higher-tier surprises
- guaranteed sector milestone drops to prevent starvation on compact floors

If a change makes the game feel:

- loot-starved
- over-reliant on early upgrade luck
- too linear in equipment progression
- or too flooded with books

then it is likely drifting away from the intended direction.
