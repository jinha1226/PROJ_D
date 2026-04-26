# PocketCrawl - Current Skill and Progression

_Last updated: 2026-04-26_

This document tracks the current main-branch ruleset.
Older prototype ideas are not the source of truth anymore.

## Current Baseline

- Base classes: `Fighter`, `Mage`, `Rogue`
- Live skills: `melee`, `ranged`, `magic`, `defense`, `agility`
- Spell schools remain as spell categories only
- There are no per-school magic skills
- Old `dodge` / `stealth` split is retired

## XL and Skill Caps

- Max XL: `20`
- Max skill level: `9`
- Expected late-game XL around floor 25: `18-19`

## Skill XP Model

- Skill XP source: `kill XP`
- XP is distributed only to active skills
- At least one skill must remain active
- Curve intent:
  - `1-3`: fast
  - `4-6`: medium
  - `7-9`: slow

## Live Skill Roles

| Skill | Current role |
| --- | --- |
| `melee` | all close-range weapon offense |
| `ranged` | bows, thrown weapons, future ranged builds |
| `magic` | spell access, spell power, caster progression |
| `defense` | armor, shields, blocking, attrition |
| `agility` | EV, awareness pressure, ambush value |

## Base Class Starts

### Fighter

- Start skills: `melee 2`, `defense 1`
- Core feel: reliable frontline, shield/armor value, low-risk combat

### Mage

- Start skills: `magic 2`, `agility 1`
- Core feel: fragile caster, book-driven progression, MP economy

### Rogue

- Start skills: `melee 1`, `agility 2`
- Core feel: ambush, awareness control, dagger utility, evasive fighting

## Magic Rules

- `magic` is the only live spellcasting skill
- Schools are used for:
  - UI grouping
  - theme
  - spellbook identity
  - future item/passive hooks

### Spell Learning

- Higher `magic` unlocks higher spell levels
- Level-up spell offers do not start at `magic 1`
- Current direction:
  - one random candidate per school
  - choose one
  - books remain an alternate learning path

### Intelligence Gate

- Spell learning is also gated by `INT`
- Low-INT off-class characters should not become full casters just by dumping points into `magic`

## Awareness Model

- Enemies are either `unaware` or `aware`
- `agility` helps reduce detection pressure
- Ambush/backstab style damage is based on awareness state, not facing direction

## Injury Model

- Injury reduces effective max HP until treated
- It remains part of the current ruleset
- It is still under active balance tuning, especially for melee-heavy runs

## Not Current Baseline

The following are not current balance truth, even if files still exist:

- `Ranger` as a core start class
- school-specific magic skill growth
- old DCSS-like subclass tree as default progression
- separate `dodge` and `stealth` skills

These are future or disabled content unless explicitly reactivated.
