# PocketCrawl - Balance Handoff For Claude Code

_Last updated: 2026-04-27_

This file is a practical handoff for continuing balance work from the current `main` branch.
Use this together with:

- `D:\PROJ_D\docs\balance\skill_and_progression.md`
- `D:\PROJ_D\docs\balance\game_concept_tables.md`
- `D:\PROJ_D\docs\balance\balance_master.json`

This document is intentionally opinionated and reflects the latest live direction, not old prototype ideas.

## 1. Current Direction

The project is no longer trying to be a direct DCSS port.
The current target is:

- mobile-readable
- faster floor pacing
- compact tactical decisions
- strong item and essence identity
- fewer systems, but each system must matter

Current live structure:

- Core classes: `Fighter`, `Mage`, `Rogue`
- Core skills: `melee`, `ranged`, `magic`, `defense`, `agility`
- Spell schools exist as spell categories only
- Essence system is intended to replace the "god system" feeling
- Graphics direction is back to DCSS tiles for now

## 2. Recent Live Changes Already Applied

These are already in `main` and should be treated as current baseline:

### Camera / Sight / Range

- Default in-game zoom is tighter
- Player base sight was reduced from `8` to `6`
- Monster effective detection was reduced slightly
- Most spell ranges were globally reduced by `1`

### Floor Pressure / Drops

- Potion / scroll / wand / essence drop rates were already increased recently
- Books were made relatively less common than before

### Map / Encounter Direction

First pass was already applied toward:

- smaller map footprint
- fewer monsters
- higher individual threat
- faster XP gain

Current implementation changed:

- map size from `35x50` to `30x42`
- monster count down
- item count slightly preserved
- low-XP trash weighting reduced in early floors
- combat XP gain multiplied up

This is only a first pass and needs play validation.

## 3. Biggest Current Balance Problems

These are the major live issues reported in play and conversation.

### A. Early game still needs stronger tactical pressure

Problem:

- Old structure felt too roomy and too safe
- Many weak enemies created cleanup gameplay instead of meaningful tension

Current direction:

- compact floors
- fewer enemies
- each fight matters more
- faster level gain

Still needs testing:

- Did tension go up enough?
- Did floors become too empty?
- Did XP go up too fast?

### B. Rogue identity is still not fully solved

Current direction:

- Rogue should be `ranged + agility`
- Not a pure melee backstab class
- More "tool / positioning / awareness control" than frontliner

Open questions:

- Is Rogue now distinct enough from Fighter?
- Does Rogue have enough early kill pressure?
- Are consumables doing enough to support Rogue identity?

Likely next tuning areas:

- ranged opening damage
- thrown/tool support
- awareness manipulation items
- agility scaling

### C. Injury system still risks punishing melee too much

Design intent:

- Replace hunger pressure with attrition pressure
- Encourage resource use and careful descent

Risk:

- If injury mostly punishes "being in melee", Fighter becomes unfairly taxed

What to keep:

- injury should remain meaningful

What to avoid:

- injury becoming a straight anti-melee tax

Likely next tuning areas:

- injury accumulation rate
- defense-based injury mitigation
- healing / bandage recovery curve
- floor-to-floor sustain expectation

### D. Magic hybrid access needs careful gating

Current desired rule:

- Mage starts with spell choice access
- Fighter / Rogue must learn their first spell from a book
- After first spellbook access, later `magic` level-ups can offer spell choices
- INT requirement should limit higher-level spell access

Current target INT formula:

- `required_int = 7 + spell_level * 2`

Needs validation:

- too strict for hybrids?
- too permissive for low-INT builds?
- do books appear at the right pace?

### E. Essence system is promising but still under-tuned

Current intended identity:

- not just stat sticks
- should affect actual play decisions
- should feel like a "build axis", not minor loot

Current good ideas already accepted:

- slot unlocks by level
- resonance / synergy combinations
- each essence should have a downside
- inventory size should stay limited so pickups are meaningful

Needs continued work:

- make effects matter without becoming mandatory
- improve synergy visibility
- make penalties readable and worth the trade

## 4. Agreed Design Decisions

These decisions were explicitly converged on and should not be casually undone.

### Core Class Intent

- `Fighter = defense main, melee support`
- `Mage = magic main, agility secondary`
- `Rogue = ranged main, agility support`

### Skill Growth Goal

With 5 live skills, the target is:

- two real core skills can reach `8-9`
- one support skill typically reaches `3-5`
- others remain low

This is important.
Do not drift toward "everyone levels everything".

### Spell Learning Model

- one `magic` skill only
- no per-school magic skills
- schools remain for category / books / theme
- books can teach school bundles
- level-up spell offers should remain school-aware

### Essence Philosophy

- essence should be stronger than a small stat trinket
- but weaker than "replace your whole class"
- best target is: "a second build axis that changes how the run feels"

### Map Philosophy

Do not go full old wide-open crawl.

Preferred target:

- more compact than current old builds
- slightly larger than Pixel Dungeon
- less wasted traversal
- more meaningful room-to-room decision making

## 5. Specific Next Balance Tasks

These are the best next tasks for Claude Code.

### Priority 1: Validate new compact-floor tuning

Files most likely involved:

- `D:\PROJ_D\scripts\dungeon\DungeonMap.gd`
- `D:\PROJ_D\scripts\dungeon\MapGen.gd`
- `D:\PROJ_D\scripts\main\Game.gd`
- `D:\PROJ_D\scripts\systems\MonsterRegistry.gd`
- `D:\PROJ_D\scripts\systems\CombatSystem.gd`

Questions to answer:

- Are floors now short enough?
- Are there still too many trivial fights?
- Are early encounters dangerous enough?
- Is XP pacing now too fast or close to right?

### Priority 2: Re-tune drop economy around the new floor shape

Because:

- smaller floors mean fewer total event nodes
- if encounter count drops, per-floor loot expectations can drift fast

Check and tune:

- potion frequency
- scroll frequency
- wand frequency
- book rarity
- essence drop chance

Desired feel:

- early consumables should be plentiful enough to identify and plan around
- books should be meaningful, not routine
- wands and thrown tools should matter but not flood the run

### Priority 3: Make Rogue genuinely satisfying

Current risk:

- Rogue may still feel like a weaker Fighter with slightly different numbers

What to explore:

- stronger early ranged identity
- better interaction with `agility`
- better utility item loop
- awareness manipulation as part of class fantasy

Avoid:

- returning Rogue to fragile front-melee stealth tax

### Priority 4: Injury fairness pass

Goal:

- keep pressure
- remove frustration

Things to test:

- per-hit injury rate
- defense scaling against injury
- consumable healing vs injury restoration
- whether Fighter is unfairly starved compared to Mage

### Priority 5: Essence resonance pass

Best next sub-steps:

- verify the current resonances are visible in play
- make sure every major essence has a readable upside and downside
- ensure resonance bonuses are worth aiming for
- ensure inventory cap still creates meaningful pickup decisions

## 6. Things To Avoid

These are common traps for the next pass.

### Avoid wide maps with many weak enemies

This creates cleanup play and dull turns.

### Avoid making every class a hybrid generalist

The 5-skill system only works if specialization remains strong.

### Avoid solving every problem with raw stat buffs

Especially for essence work.
Preference should be:

- conditional effects
- encounter-shaping effects
- support for a play pattern

over:

- flat universal efficiency

### Avoid pushing books too common again

Books are build-defining rewards.
They should not feel as common as scrolls or potions.

## 7. Recommended Working Order

If Claude Code continues from here, the cleanest order is:

1. play-validate compact map + enemy density
2. retune early drop economy against the smaller floors
3. fix Rogue feel
4. re-tune injury fairness
5. deepen essence resonance effects

## 8. Short Summary

PocketCrawl should currently feel like:

- tighter than older versions
- more dangerous room-to-room
- more dependent on consumable timing
- less like a full DCSS simulation
- more like a compact, tactical mobile dungeon crawler with meaningful build identity

If future changes make the game:

- more sprawling
- more cleanup-heavy
- more generic across classes
- or more dependent on flat stat inflation

then the project is likely drifting away from the current intended direction.
