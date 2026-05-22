# Claude Code Handoff: First Boss Shrine Faith Flow

## Goal
The first major build-direction choice in PocketCrawl should happen after the first sector boss.
This should feel closer to DCSS than a plain menu popup, while still staying fast and readable on mobile.

The intended structure is:
- first sector ends in a shrine-like boss room
- player defeats the first boss
- shrine activates
- player chooses a faith path
- if the player chooses Essence, they immediately choose their first essence from class-appropriate options

This should become the standard first major progression event of a run.

---

## High-Level Experience

### Desired player feeling
The player should feel:
- "I cleared the first real test"
- "Now I must choose what kind of run this will become"
- "This is a major commitment, not just another item reward"

This is not meant to feel like random loot.
It is meant to feel like a defining moment.

---

## Core Sequence

### Step 1: Shrine Boss Room
The first sector boss should be placed in a special room with shrine/altar visuals.
This is not just a normal rectangular room.
It should visually communicate:
- sacred site
- ancient power
- a place of choice or judgment

Recommended room features:
- distinct floor tile set from normal rooms
- central altar / basin / sigil / shrine tile
- symmetric or semi-symmetric layout
- no clutter that obscures the center

The room should read instantly as special when discovered.

---

### Step 2: Boss Defeat Trigger
When the first sector boss dies:
- stop normal input briefly
- play a short pause / screen emphasis / log message
- activate the shrine choice flow

Suggested combat log / center text lines:
- "A greater power stirs."
- "The shrine awakens."
- "A path opens before you."

Use only one short line at a time.
Avoid lore-heavy wording here.

---

### Step 3: Shrine Activation Presentation
Before showing the actual faith choice UI, show a short transition.
The shrine should feel like it reacts to the boss death.

Recommended minimal presentation:
- center shrine tile glows, pulses, or flashes
- short camera focus or screen dim
- input paused for a brief beat
- then faith selection UI opens

Even if visual effects stay simple, this beat is important.
The player should feel that the room itself is responding.

---

## Faith Selection UI

### Timing
Faith selection happens immediately after first boss defeat.
Do not require the player to walk to another room or find a later altar.

### Presentation mode
Use a dedicated modal choice panel / popup.
This is preferable to requiring physical altar interaction after the boss dies.

Reason:
- more consistent on mobile
- clearer pacing
- avoids missed interactions or confusion

However, the room itself should still visually be a shrine so the event feels grounded in the world.

---

### Faith options shown
Show exactly these five choices:
- War
- Arcana
- Trickery
- Death
- Essence

These are the current compressed faith categories for PocketCrawl.

---

### UI content per option
Each option should show:
- name
- short description
- one-line build hint

Recommended content:

#### War
- Strength through steel and discipline.
- Best for front-line melee and defense.

#### Arcana
- Strength through memory, power, and spellcraft.
- Best for spellcasting and magical growth.

#### Trickery
- Strength through speed, deceit, and precise tools.
- Best for agility, ranged utility, and ambushes.

#### Death
- Strength through ruin, hunger, and the fall of others.
- Best for kill-chains, sustain, and risky aggression.

#### Essence
- Strength through stolen remnants and unstable transformation.
- Replaces divine favor with essence-based growth.

---

### Confirmation step
When a faith is tapped/selected, show a short confirm prompt.
This should reduce accidental commitment on mobile.

Recommended structure:
- header: "Choose this path?"
- selected faith name
- short consequence line

Examples:

#### War confirm
- "Swear yourself to War?"
- "You will strike harder and stand firmer, but magic will come slower."

#### Arcana confirm
- "Devote yourself to Arcana?"
- "Your spells will sharpen, but your body will not be spared."

#### Trickery confirm
- "Follow Trickery?"
- "You will thrive through timing, distance, and unfair fights."

#### Death confirm
- "Accept the mark of Death?"
- "Your victories will feed you, but peace will not."

#### Essence confirm
- "Walk the path of Essence?"
- "Forsake divine favor and bind yourself to monster remnants instead."

---

## Essence Path Special Rule

### Core rule
Essence is not just another god.
It is the special alternate faith path.

If the player chooses Essence:
- essence slots become active
- essence inventory system is enabled
- normal god powers are unavailable
- the player immediately chooses their first essence reward

If the player chooses any other faith:
- essence system stays disabled for now
- essence pickup interactions should not function as active build progression

---

## First Essence Choice Flow

### Timing
The first essence choice happens immediately after the player confirms the Essence path.
Do NOT drop a random essence item on the floor first.
The first essence should feel ceremonial and intentional.

### Presentation
Open a second modal choice panel after Essence is confirmed.
Header suggestion:
- "Choose your first essence"
- or "Bind your first essence"

Subtext suggestion:
- "Monster remnants answer your call. Choose what form your path will take."

---

### Candidate generation
The first essence should not be fully random.
It should offer class-appropriate candidates.

Recommended rule:
- show 3 candidates
- candidates are drawn from a class-weighted pool
- player chooses exactly 1

### Recommended candidate pools

#### Fighter
Primary pool:
- Stone
- Vitality
- Fury

#### Mage
Primary pool:
- Arcana
- Fire
- Cold

#### Rogue
Primary pool:
- Swiftness
- Venom
- Warding

#### Ranger (if active later)
Primary pool:
- Swiftness
- Venom
- Arcana or Fury depending on design direction

#### Hybrids / test characters
Use the closest class profile or provide a mixed candidate set.
For Archmage-like test starts:
- Arcana
- Cold
- Warding

---

### First essence reward rules
- player chooses 1 of 3
- chosen essence is granted immediately
- it should either:
  - enter essence inventory, or
  - auto-equip to the first open essence slot

Recommended v1:
- auto-equip into first open essence slot
- if player later wants to manage it, they can use the status screen

Reason:
- more immediate payoff
- less friction
- clearer tutorial impact

---

## Room / Map Design Requirements

### Shrine room identity
The first boss room should feel different from normal dungeon rooms.

Recommended tile / composition cues:
- special floor pattern
- central altar or shrine tile
- optional torch symmetry
- fewer random props than normal rooms
- boss placed so that the altar remains visible or becomes visible during the fight

### Optional visual variant for Essence
If possible, the shrine can react differently when Essence is chosen:
- altar dims
- center basin / cracked sigil / essence well glows instead
- or a separate central tile variant appears

This is optional but desirable.
It reinforces that Essence is not the same kind of faith.

---

## Input / UX Rules

### During faith event
While the shrine event is active:
- suspend normal movement input
- suspend auto-move / auto-explore
- suspend bag / skill / status interruptions unless explicitly allowed
- prevent accidental closure of the event without a choice

### Cancellation
The faith choice should not be cancellable.
This is a major run-defining event.
The player must choose one path.

### Information density
Keep each faith panel compact.
On the main selection surface, show:
- name
- 1 identity sentence
- 1 tactical sentence

Detailed text can live behind an inspect or expand control later.

---

## Save / State Rules

After the player chooses a faith:
- save player faith id
- save whether essence is allowed
- if Essence was chosen, save first essence state immediately
- mark the first faith event as completed so it never repeats

Suggested player state fields:
- faith_id
- faith_rank or faith_stage
- essence_enabled
- first_shrine_choice_done

---

## Edge Cases

### If player already has essence items somehow before first shrine
This should ideally not happen in normal play.
But if it does:
- choosing a normal faith disables use of those essences
- choosing Essence allows them normally

### If player somehow reaches shrine with a test/debug class
Use their class archetype to decide candidate essence pool.
If no archetype is available, fall back to a mixed safe pool.

### If a faith choice panel is interrupted by death or scene change
The event should resume or re-open before normal play continues.
The player should not be able to continue without choosing.

---

## Recommended Implementation Order

1. Add first-sector shrine room tag / special-room generation support
2. Add first sector boss defeat event hook
3. Add faith selection modal
4. Persist faith state on player/save
5. Gate essence system on Essence faith only
6. Add first essence selection modal after Essence confirm
7. Add class-weighted first-essence pools
8. Add shrine activation visuals/log text

---

## Summary
The first boss shrine event should serve as PocketCrawl's first major identity fork.

Final intended flow:
1. Player enters first shrine boss room
2. Player defeats first sector boss
3. Shrine activates
4. Faith selection UI appears
5. If Essence is chosen, first essence choice immediately follows
6. Run continues with its first major build commitment established

This structure preserves:
- DCSS-like faith importance
- mobile-friendly pacing
- strong early-run identity
- a clean place to introduce the Essence path without making it feel like random loot
