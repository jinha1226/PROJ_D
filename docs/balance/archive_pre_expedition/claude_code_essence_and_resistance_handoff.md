# PocketCrawl - Essence And Resistance Handoff For Claude Code

_Last updated: 2026-04-27_

This file captures the latest agreed direction for:

- core essence system design
- resistance simplification
- unique-monster special essence rewards
- concrete unique essence roster

Use together with:

- `D:\PROJ_D\docs\balance\claude_code_balance_handoff.md`
- `D:\PROJ_D\docs\balance\claude_code_drop_table_handoff.md`
- `D:\PROJ_D\docs\balance\game_concept_tables.md`

## 1. High-Level Direction

The essence system is no longer just a minor passive bonus system.
It is intended to cover part of the emotional/design space that DCSS gods used to cover.

That means essences should provide:

- run identity
- build pivots
- meaningful tradeoffs
- synergy goals

At the same time, the project should avoid:

- too many resistance types
- over-detailed status/sub-resistance bookkeeping
- unreadable mobile complexity

Therefore the current agreed direction is:

- simplify resistance types to a small core set
- make essences stronger in play-pattern terms, not just in raw stats
- make unique-monster essences special, memorable, and often build-defining

## 2. Final Resistance Direction

The resistance set should be reduced to exactly these four:

- `fire`
- `cold`
- `poison`
- `will`

### Why These Four

These are the most readable and useful axes for this project:

- `fire`: common, intuitive, easy to telegraph
- `cold`: natural counterpart to fire
- `poison`: classic roguelike sustain/threat axis
- `will`: mental / control defense axis

### What `will` Covers

`will` should act as the resistance/check axis for:

- fear
- sleep
- confusion
- paralysis / stun style effects where applicable
- hostile mental or control magic

This keeps mind-affecting resistance readable without introducing many separate sub-resists.

### Resistances To Remove / Fold Away

The system should not continue expanding around many narrow resist categories.

Reduce or fold away:

- electricity
- acid
- holy / unholy
- negative energy as a separate resist category
- disease / bleed style separate defenses

These can still exist as damage/effect flavors, but should not each become their own full player resistance axis unless a later redesign truly needs them.

### Implementation Direction

Claude Code should aim for:

- player resist array / tags using only the 4 core types
- item / race / essence / spell references updated to those 4 types
- legacy or obsolete resist labels removed or aliased cleanly

## 3. Essence Philosophy

Essences should not be just flat stat gems.

Preferred essence structure:

- one strong identity
- one useful passive or conditional play effect
- one meaningful downside

Best essences should make the run feel different, not just more efficient.

Examples of good effect types:

- on-kill sustain
- attack conversion or added effect
- awareness/detection manipulation
- spell-study or casting access help
- incoming damage smoothing
- specific resonance hooks

Examples of weaker design directions:

- “+2 stat” with no gameplay twist
- bland universal power with no real tradeoff

## 4. Essence Inventory / Slot Direction

Agreed current structure:

- slots unlock over progression
- inventory capacity should remain limited
- player should have to decide whether to take, replace, or leave essences

Essence inventory should stay decision-based, not hoard-based.

This is important and should not be quietly loosened.

## 5. Unique Monster Essence Reward Direction

DCSS-style uniques should have a strong reward identity.
In PocketCrawl, that reward identity should often be:

- a special essence

### Agreed Rule

For monsters marked as unique:

- dedicated unique essence should drop at **very high chance**
- normal unique target: around `80%`
- major unique / boss-style unique target: `100%`

### Why

This makes unique encounters:

- memorable
- build-shaping
- worth preparing for

and supports the “essence as god-like progression axis” goal.

## 6. Unique Essence Design Rules

Unique essences should be:

- stronger than common essences in identity
- not just stronger in raw numbers

Each unique essence should ideally include:

- one strong signature effect
- one meaningful drawback
- one strong synergy or resonance hook

Unique essences should feel like:

- “this run now bends in a different direction”

not like:

- “this is just a better common essence”

## 7. Recommended Common Essence Tier Roles

To keep the system readable, common essences should roughly fall into three roles:

### Normal

- basic build shaping
- common resistance hooks
- entry-level tradeoffs

### Rare

- stronger identity
- stronger conditional effects
- more noticeable downside

### Unique

- tied to unique monsters
- stronger play-pattern change
- major resonance hook

Important:

- do not let “unique” just mean bigger numbers

## 8. Resistance Mapping Guidance For Existing Essences

When updating existing essences to the 4-resistance model, use these simplifications:

- `essence_fire` -> `fire`
- `essence_cold` -> `cold`
- `essence_venom` -> `poison`
- `essence_warding` -> `will`

Possible support pairings:

- `essence_arcana` helps with `will`-related spell/control play
- `essence_stone` does not need its own resist type; it should focus on damage smoothing / AC identity instead
- `essence_swiftness` should influence detection / agility identity, not add another resist axis

## 9. Suggested Unique Spawn Cadence

Target structure for an 8-sector run:

- 3 floors per sector
- 1 signature unique encounter per sector
- optional 1 alternate mini-unique in later sectors if the run needs more variety

Recommended first pass:

- exactly 1 featured unique per sector
- 8 total headline unique monsters

This keeps the system readable and ensures each unique drop matters.

## 10. Sector / Floor Placement Table

| Sector | Floors | Unique Monster | Role | Essence ID | Drop |
|---|---|---|---|---|---:|
| 1 | 2-3 | `Ashen Magpie` | trickster caster | `essence_gloam` | 80% |
| 2 | 4-6 | `Sister Cinder` | fire caster / pressure | `essence_cinder` | 80% |
| 3 | 7-9 | `Viper Saint` | poison assassin | `essence_serpent` | 80% |
| 4 | 10-12 | `Stone Warden` | armored sentinel | `essence_bastion` | 100% |
| 5 | 13-15 | `Harrow Knight` | fear / will breaker | `essence_dread` | 80% |
| 6 | 16-18 | `Blood Duke` | drain / sustain | `essence_bloodwake` | 100% |
| 7 | 19-21 | `Storm Hierophant` | arcane artillery | `essence_tempest` | 80% |
| 8 | 22-24 | `The Pale Scholar` | endgame controller | `essence_pale_star` | 100% |

## 11. Detailed Unique Essence Table

Below, “primary effect” should be treated as the main passive identity.
“Secondary effect” is the supporting bonus.
“Penalty” should always be visible in the UI.

### 11.1 `essence_gloam`

| Field | Value |
|---|---|
| Display name | Gloam Essence |
| Dropped by | Ashen Magpie |
| Floors | 2-3 |
| Theme | stealth / awareness / spell trickery |
| Primary effect | unaware targets take `+35%` damage from your first hit |
| Secondary effect | enemy detection radius against player `-1` |
| Bonus stat | `WILL +1` |
| Penalty | `HP max -3` |
| Resist | none |
| Suggested resonance | `Gloam + Swiftness = first hit also applies weaken for 2 turns` |

Implementation notes:

- best for Rogue or hybrid Mage
- should feel like the first identity-warping essence in the run

### 11.2 `essence_cinder`

| Field | Value |
|---|---|
| Display name | Cinder Essence |
| Dropped by | Sister Cinder |
| Floors | 4-6 |
| Theme | fire pressure |
| Primary effect | melee and fire spells deal `+2 fire damage` |
| Secondary effect | `fire+` |
| Bonus stat | `INT +1` |
| Penalty | `cold-` |
| Resist | fire |
| Suggested resonance | `Cinder + Arcana = fire spells gain +15% damage and +1 range` |

Implementation notes:

- early-mid Mage pivot essence
- still useful for melee hybrids if fire rider damage is noticeable

### 11.3 `essence_serpent`

| Field | Value |
|---|---|
| Display name | Serpent Essence |
| Dropped by | Viper Saint |
| Floors | 7-9 |
| Theme | poison opener / assassin pressure |
| Primary effect | first hit on an unaware target applies poison for `5 turns` |
| Secondary effect | all weapon hits gain `25%` chance to apply poison for `3 turns` |
| Bonus stat | `DEX +1` |
| Penalty | `WILL -1` |
| Resist | `poison+` |
| Suggested resonance | `Serpent + Swiftness = unaware opener also gains +25% damage` |

Implementation notes:

- core Rogue-style unique essence
- should strongly support the ranged/agility/tool identity

### 11.4 `essence_bastion`

| Field | Value |
|---|---|
| Display name | Bastion Essence |
| Dropped by | Stone Warden |
| Floors | 10-12 |
| Theme | direct mitigation |
| Primary effect | incoming damage `-2` |
| Secondary effect | `AC +2` |
| Bonus stat | `WILL +1` |
| Penalty | `EV -2` |
| Resist | none |
| Suggested resonance | `Bastion + Vitality = gain +1 injury protection or, if injury removed, +3 healing from potions` |

Implementation notes:

- should feel very strong when taken
- drawback must matter, especially for Rogue

### 11.5 `essence_dread`

| Field | Value |
|---|---|
| Display name | Dread Essence |
| Dropped by | Harrow Knight |
| Floors | 13-15 |
| Theme | fear / control |
| Primary effect | attacks have `20%` chance to inflict fear for `2 turns` |
| Secondary effect | hostile fear/confuse/sleep checks against player are reduced via `will+1` |
| Bonus stat | `WILL +1` |
| Penalty | `STR -1` |
| Resist | will |
| Suggested resonance | `Dread + Warding = feared enemies deal -2 damage for 2 turns` |

Implementation notes:

- gives a non-damage route to late-mid builds
- should especially help cautious or control-oriented play

### 11.6 `essence_bloodwake`

| Field | Value |
|---|---|
| Display name | Bloodwake Essence |
| Dropped by | Blood Duke |
| Floors | 16-18 |
| Theme | sustain through killing |
| Primary effect | on kill, heal `5 HP` |
| Secondary effect | on kill, gain `+20% damage` for `2 turns` |
| Bonus stat | `HP max +5` |
| Penalty | healing potion effectiveness `-20%` |
| Resist | none |
| Suggested resonance | `Bloodwake + Fury = on-kill buff becomes 3 turns` |

Implementation notes:

- should feel like a run-defining sustain choice
- penalty prevents it from becoming purely upside sustain stacking

### 11.7 `essence_tempest`

| Field | Value |
|---|---|
| Display name | Tempest Essence |
| Dropped by | Storm Hierophant |
| Floors | 19-21 |
| Theme | ranged / arcane burst |
| Primary effect | ranged attacks and offensive spells gain `+15%` damage |
| Secondary effect | wand charges are effectively `+1` when picked up, or first use from full is free once per wand |
| Bonus stat | `INT +1`, `DEX +1` |
| Penalty | `AC -1` |
| Resist | none |
| Suggested resonance | `Tempest + Arcana = reduce learned spell INT requirement by 3 total instead of 2` |

Implementation notes:

- very good for Mage and tool-heavy Rogue
- should not outclass every other late essence on raw defense

### 11.8 `essence_pale_star`

| Field | Value |
|---|---|
| Display name | Pale Star Essence |
| Dropped by | The Pale Scholar |
| Floors | 22-24 |
| Theme | endgame control / high-risk power |
| Primary effect | your hostile control effects gain `+1 turn` duration |
| Secondary effect | learned spell INT requirement `-2`, and control spells gain `+10%` power |
| Bonus stat | `INT +2`, `WILL +1` |
| Penalty | `HP max -6`, `fire-` |
| Resist | will |
| Suggested resonance | `Pale Star + Arcana = spell study INT requirement total -4` |

Implementation notes:

- should be one of the strongest identity essences in the game
- the HP/fire drawback must be visible and real

## 12. Optional Alternate / Mini-Unique Roster

If more than 8 uniques are desired later, these can be added as alternates without becoming the main featured sector unique.

| Floors | Unique Monster | Essence ID | Role |
|---|---|---|---|
| 5-7 | `Mud Prophet` | `essence_bog_mind` | poison / will hybrid |
| 11-13 | `The Chain Widow` | `essence_rattle` | anti-melee disruptor |
| 17-19 | `Ivory Duelist` | `essence_edge` | precision melee |
| 20-22 | `Frost Bride` | `essence_glacier` | cold control |

These should only be used after the core 8 are stable.

## 13. Suggested Unique Essence Tiering

Unique essences do not need the same rarity interpretation as common essence icons.

Recommended:

- common essence tiers stay `normal / rare / unique`
- unique-monster essences are all treated as `unique`
- some can be “greater unique” internally if needed, but do not add a fourth visible rarity color unless the UI really needs it

## 14. Resonance Planning

Current recommendation is to keep resonance readable.
Do not explode the number of resonance combinations.

Good target:

- each unique essence has `1-2` obvious pairings
- not every combination needs a payoff

Recommended core resonance pairs from this roster:

| Pair | Effect |
|---|---|
| `Gloam + Swiftness` | first unaware hit also weakens target for 2 turns |
| `Cinder + Arcana` | fire spells `+15%` damage and `+1` range |
| `Serpent + Swiftness` | unaware opener gains `+25%` damage |
| `Bastion + Vitality` | potion healing `+3` or injury mitigation if injury remains |
| `Dread + Warding` | feared enemies deal `-2` damage |
| `Bloodwake + Fury` | on-kill damage surge lasts `3 turns` |
| `Tempest + Arcana` | spell study INT requirement total `-3` |
| `Pale Star + Arcana` | spell study INT requirement total `-4`, control spells `+15%` power |

## 15. Recommended Data Shape For Claude Code

Each unique essence should ideally define:

- `id`
- `display_name`
- `source_unique_id`
- `tier = unique`
- `primary_effect`
- `secondary_effect`
- `bonus_stats`
- `resists`
- `penalty`
- `resonance_tags`

Each unique monster should define:

- `is_unique = true`
- `unique_essence_id`
- `min_depth`
- `max_depth`
- `drop_chance_override`

## 16. Recommended First Implementation Order

Claude Code should implement in this order:

1. collapse resistance handling to `fire / cold / poison / will`
2. update current essence data to use only those four resist types where applicable
3. define which monsters count as unique for drop logic
4. add unique-monster special essence drop handling
5. add the 8 featured unique monsters as resources
6. add the 8 unique essences
7. add the floor placement table
8. implement only the most important resonance pairs first

## 17. What To Avoid

### Avoid overgrowing resistance complexity again

Do not reintroduce five more resist categories just because individual monsters or spells have flavorful damage types.

### Avoid making unique essences pure stat jackpots

They should be more interesting, not just larger.

### Avoid making essence inventory infinite or painless

Meaningful pickup decisions are part of the system identity.

### Avoid making every essence universally useful

Tradeoffs are important.
Some essences should be clearly better for some builds than others.

## 18. Short Summary

Current agreed direction:

- player resistance system should be only `fire / cold / poison / will`
- essence system should feel strong enough to matter like a secondary run-defining axis
- unique monsters should very often drop special essences
- unique essences should be identity-heavy and downside-bearing, not just inflated stat boosts

If future changes make the essence system:

- hoardable with no friction
- mostly flat stats
- or too disconnected from actual play patterns

then it is likely drifting away from the intended design.
