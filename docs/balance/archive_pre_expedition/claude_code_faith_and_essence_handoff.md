# Claude Code Handoff: Faith + Essence System

## Goal
PocketCrawl keeps the core DCSS identity while simplifying for mobile.
The game should use a small set of faiths as a major build-direction system.
Essence should not replace faith globally; instead, it should exist as a special alternative path.

Final direction:
- 4 standard faiths based on compressed DCSS categories
- 1 special mobile-only faith that enables essence use
- Standard faiths and essence use are mutually exclusive

---

## Final Faith Structure

Total faiths: 5

1. War
2. Arcana
3. Trickery
4. Death
5. Essence

Interpretation:
- War / Arcana / Trickery / Death are the "traditional" faith routes
- Essence is the special alternate route for PocketCrawl

---

## Core Rule: Essence Access

### Standard Faiths
If the player follows any of these:
- War
- Arcana
- Trickery
- Death

Then:
- essence slots are disabled
- essence inventory cannot be equipped
- essence-related popup choices should be blocked or auto-converted to ignore/leave state

### Essence Faith
If the player follows Essence:
- essence slots are active
- essence inventory works normally
- resonance bonuses apply
- standard faith powers are unavailable

### Switching / Mutual Exclusivity
Rule:
- Standard faiths and essence use are mutually exclusive
- Choosing Essence means no other god powers
- Choosing another god disables essence use

Recommended implementation behavior:
- If player joins War/Arcana/Trickery/Death while equipped essences exist:
  - unequip all essences
  - move them to essence inventory if capacity allows
  - if capacity is exceeded, drop the excess or force a choose-one popup
- If player leaves a normal god and joins Essence:
  - essence slots reactivate
  - existing carried essences become usable again

---

## Faith 1: War

### DCSS compression source
Primarily inspired by:
- Okawaru
- Trog
- small portion of The Shining One's straightforward combat stability

### Theme
- melee
- defense
- front-line combat
- stable, reliable progression

### Best-fit builds
- Fighter
- melee-heavy hybrids

### Passive bonuses
- melee final damage: +10%
- defense skill effectiveness: +20%
- shield block chance: +8%
- if injury system still exists, injury gain: -20%

### Faith powers / milestones
1. Battle Focus
   - first 5 turns of a fresh combat: hit +2
2. War Cry
   - activated effect
   - for 8 turns: melee damage +25%, EV -2
3. Stand Firm
   - while HP <= 35%: incoming damage -2 once per turn

### Penalties / restrictions
- magic skill XP gain: -25%
- spell MP cost: +20%

### Intended play feel
- easiest and most stable faith
- highly readable front-line power spike
- supports PocketCrawl Fighter identity strongly

---

## Faith 2: Arcana

### DCSS compression source
Primarily inspired by:
- Vehumet
- Sif Muna
- tiny amount of spell-focused Ashenzari feel

### Theme
- pure spellcasting
- MP efficiency
- easier access to higher spell power and learning

### Best-fit builds
- Mage
- caster hybrid

### Passive bonuses
- spell damage/effect output: +12%
- max MP: +4
- spell learning INT requirement: -2
- magic skill XP gain: +20%

### Faith powers / milestones
1. Arcane Memory
   - when a level-up spell choice appears, add +1 extra candidate
2. Mana Surge
   - while MP <= 30%, spell power gains additional +15%
3. Spell Echo
   - 15% chance that low-level spells cost 0 MP

### Penalties / restrictions
- melee final damage: -10%
- heavy armor reduces MP regeneration further
- defense XP gain: -15%

### Intended play feel
- most direct caster faith
- smoother spell learning and progression
- physically fragile compared to War

---

## Faith 3: Trickery

### DCSS compression source
Primarily inspired by:
- Dithmenos
- parts of Nemelex utility feel
- parts of Uskayaw mobility/tempo feel
- small Gozag-style tactical freedom flavor

### Theme
- agility
- tools
- ranged utility
- ambush / mobility / opportunism

### Best-fit builds
- Rogue
- Ranger
- wand / thrown / tactical hybrid

### Passive bonuses
- agility effectiveness: +20%
- tool effectiveness: +25%
- ranged final damage: +10%
- 20% chance to avoid consuming a wand charge
- monster detect range against player: -1

### Faith powers / milestones
1. Fade Step
   - active effect
   - for 4 turns, distant enemies detect player at -2 range
2. Dirty Trick
   - first strike on unaware target: +40% damage
3. Quick Hands
   - tool / wand / thrown / scroll actions gain reduced action cost feel
   - implementation can be simplified into a small speed bonus or partial free-action behavior

### Penalties / restrictions
- shield block chance: -6%
- heavy armor adds extra EV burden
- no direct front-line durability support

### Intended play feel
- makes Rogue/Ranger materially different from Fighter
- gives meaning back to tool gameplay in a simplified mobile system
- rewards planning, spacing, and opportunistic combat

---

## Faith 4: Death

### DCSS compression source
Primarily inspired by:
- Makhleb
- Yredelemnul
- Kikubaaqudgha
- small amount of Lugonu risk-reward flavor

### Theme
- on-kill sustain
- draining / decay
- dangerous but rewarding offense

### Best-fit builds
- aggressive Fighter
- dark Mage
- sustain hybrid

### Passive bonuses
- on kill: HP +3
- on kill: MP +1
- necrotic / death-themed damage: +15%
- will +1
- bonus damage vs undead: +10%

### Faith powers / milestones
1. Blood Feast
   - active effect
   - for 6 turns, kills restore an additional +3 HP
2. Grave Touch
   - melee or spell hit: 20% chance to weaken target for 2 turns
3. Last Harvest
   - if HP <= 25%, killing an enemy grants 50% incoming damage reduction for that turn

### Penalties / restrictions
- healing potion efficiency: -20%
- weaker interaction with holy / cleansing effects
- stability is lower than War

### Intended play feel
- the faith for snowballing through kills
- rewards aggression and controlled risk
- should feel strong when chaining fights correctly, but less safe than War

---

## Faith 5: Essence

### Role
This is the PocketCrawl-specific alternate path.
It is treated like a special mobile faith route rather than a generic no-faith state.

It should be approximately comparable in power to a normal faith overall,
but with more variance and more build-expression through essence combinations.

### Theme
- godless / alternate / anti-orthodox route
- absorbs monster essence instead of receiving divine power
- more flexible, less stable

### Best-fit builds
- any build that wants adaptable, drop-driven power
- especially hybrid runs

### Passive bonuses
- essence inventory capacity: +1
  - if baseline is 2, Essence faith users can carry 3
- resonance effects: +25%
- essence penalties reduced by 20%
- unique essence drop rate: +15%
- normal essence drop rate slightly increased

### Faith powers / milestones
1. Attunement
   - earlier slot unlock pacing or effectively easier access to 2-slot builds
2. Resonance
   - 2-essence resonance counts as a stronger resonance tier
3. Essence Overflow
   - while resonance is active, gain +10% damage or +10% equivalent defensive power
   - final implementation can split by build type if preferred

### Penalties / restrictions
- cannot use any standard god powers
- more run-to-run variance
- drop-dependent progression

### Intended play feel
- the most flexible route
- strongest build expression through monster-derived powers
- should feel equal in overall value to a normal faith, but less stable and more opportunistic

---

## Relative Balance Target

The five routes should feel comparable but different:

- War: strongest stability and easiest execution
- Arcana: highest pure caster support
- Trickery: highest tactical / mobility / tool expression
- Death: strongest kill-snowball and sustain potential
- Essence: strongest variance and customization

Target relationship:
- War is the safest
- Arcana is the cleanest for Mage
- Trickery is the sharpest skill-expression route
- Death is the most volatile combat faith
- Essence is the most flexible but least guaranteed

Important:
Essence should NOT be a weaker placeholder.
Because it replaces normal faiths, it should be approximately competitive overall.
Its tradeoff is variance, not lower ceiling.

---

## Integration With Current PocketCrawl Systems

### Skills
Current simplified skill philosophy still works:
- melee
- ranged
- magic
- defense
- agility
- tool (if the design reintroduces it)

Faiths should amplify these broad roles rather than adding lots of micro-rules.

### Classes
Recommended association:
- Fighter -> War
- Mage -> Arcana
- Rogue -> Trickery
- Ranger or tactical hybrid -> Trickery
- aggressive hybrid / dark caster -> Death
- custom/adaptive run -> Essence

### Resistance system
Use the simplified resistance structure already agreed:
- fire
- cold
- poison
- will

Faiths should not explode this into too many niche resist systems.

---

## Implementation Notes For Claude Code

### Data needed
A faith/god data structure should contain:
- id
- display_name
- description
- passive modifiers
- milestone/ability list
- penalties/restrictions
- whether essence is allowed

Suggested fields:
- allows_essence: bool
- passive_damage_mult
- passive_defense_mult
- passive_block_bonus
- passive_mp_bonus
- passive_int_req_reduction
- passive_detect_range_mod
- passive_on_kill_hp
- passive_on_kill_mp
- passive_resonance_mult
- passive_essence_penalty_reduction
- skill_xp_modifiers
- spell_cost_mult
- potion_heal_mult
- milestone_abilities[]

### High-priority behavior rules
1. Joining a standard faith disables essence use
2. Joining Essence faith enables essence use
3. Essence faith increases effective value of existing essence systems
4. Standard faiths should not require too many buttons or complex rituals on mobile
5. Each faith should have 1-3 strong identity powers, not a long list of minor bonuses

### Recommended rollout order
1. Add faith data model and player faith state
2. Implement faith selection flow (altar or first-offer system)
3. Implement passive bonuses for all 5 faiths
4. Gate essence system behind Essence faith only
5. Add 1 active/milestone power per faith first
6. Expand to 2nd/3rd powers after the basic loop feels right

---

## Design Principle Summary
PocketCrawl is not trying to clone all of DCSS complexity.
It should compress DCSS identity into a form that feels strong on mobile.

Faith is one of the most important sources of direction in DCSS.
Therefore PocketCrawl should keep faith as a major system.

Essence can remain, but only if it is reframed as a special alternate faith path rather than a universal extra system.

This keeps:
- stronger DCSS identity
- simpler balance surface
- clearer class/fight/build differentiation
- a unique PocketCrawl hook through Essence faith

---

## UI / Flavor Text Pack

Use the faith names directly for readability:
- War
- Arcana
- Trickery
- Death
- Essence

### General UI Structure
Recommended selection UI fields per faith:
- title
- short_desc
- altar_line
- join_confirm
- status_line

---

### War

**Short Description**
- Strength through steel and discipline.
- Fight head-on, hold your ground, and break the enemy line.

**Altar Line**
- A blood-red standard hangs above a weathered altar.
- The air smells of iron, sweat, and old victories.

**Selection UI Text**
- War favors melee, defense, and steady conquest.
- Grants stronger frontline combat, block, and survivability.
- Penalizes magical growth and spell efficiency.

**Join Confirmation**
- Swear yourself to War?
- You will strike harder, stand firmer, and walk a soldier's path.

**Status Line**
- Faith: War
- The clash of steel answers your prayer.

---

### Arcana

**Short Description**
- Strength through memory, insight, and spellcraft.
- Shape battle with study, will, and gathered power.

**Altar Line**
- Blue runes drift over a cold stone lectern.
- Half-heard words echo from an unseen archive.

**Selection UI Text**
- Arcana favors magic, mana, and spell learning.
- Grants stronger spells, more MP, and easier spell access.
- Penalizes direct melee strength and martial resilience.

**Join Confirmation**
- Devote yourself to Arcana?
- Your mind will sharpen, but your flesh will not be spared.

**Status Line**
- Faith: Arcana
- The runes remember your name.

---

### Trickery

**Short Description**
- Strength through speed, misdirection, and cunning tools.
- Win by striking first, moving fast, and never fighting fair.

**Altar Line**
- A lacquered mask rests on a low altar beside scattered knives.
- Candlelight flickers where no wind should reach.

**Selection UI Text**
- Trickery favors agility, tools, ranged attacks, and opportunistic fighting.
- Grants better mobility, stronger tool use, and ambush advantages.
- Penalizes shields and heavy front-line play.

**Join Confirmation**
- Follow Trickery?
- Let others march in lines. You will survive by wit and timing.

**Status Line**
- Faith: Trickery
- Every shadow looks one step deeper.

---

### Death

**Short Description**
- Strength through ruin, hunger, and the fall of others.
- Grow stronger as enemies die around you.

**Altar Line**
- Black wax drips over a cracked altar ringed with pale bones.
- A low pulse answers from somewhere beneath the floor.

**Selection UI Text**
- Death favors kill chaining, draining power, and dangerous momentum.
- Grants health and mana on kill, stronger death magic, and aggressive sustain.
- Penalizes ordinary healing and safe, stable play.

**Join Confirmation**
- Accept the mark of Death?
- Your victories will feed you, but peace will not.

**Status Line**
- Faith: Death
- The fallen leave strength in your hands.

---

### Essence

**Short Description**
- Strength through stolen remnants and unruly change.
- Refuse the gods and grow by binding monster essence to yourself.

**Altar Line**
- No idol stands here. Only a hollow basin filled with dim, shifting light.
- Fragments of many dead things turn within it like embers in water.

**Selection UI Text**
- Essence is an alternate faith path.
- It allows essence use, stronger resonance, and more flexible build shaping.
- You gain no standard divine powers, and your growth depends on what the dungeon yields.

**Join Confirmation**
- Walk the path of Essence?
- Forsake the gods. Take power where you can find it.

**Status Line**
- Faith: Essence
- No god claims you. The dungeon itself will answer.

---

## Compact Button / Menu Labels

If UI space is tight, use these one-line descriptions:

- War: Frontline combat and defense.
- Arcana: Spell power and mana growth.
- Trickery: Mobility, tools, and ambush.
- Death: Kill sustain and dangerous power.
- Essence: Flexible essence-based path.

---

## First-Time Help Text

Recommended helper text shown on first faith selection:

- Choose a faith to define your run.
- Standard faiths grant stable divine power.
- Essence is a special path that replaces divine gifts with monster-bound growth.

