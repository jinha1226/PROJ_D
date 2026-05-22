# PocketCrawl - Current Concept Tables

_Last updated: 2026-04-26_

This file summarizes the current mainline game loop.

## Active Base Classes

| Class | Main skill | Secondary skill | Core feel |
| --- | --- | --- | --- |
| Fighter | `defense` | `melee` | stable frontline combat |
| Mage | `magic` | `agility` | spell choice and MP management |
| Rogue | `agility` | `ranged` | ranged pressure, awareness control, and trick tools |

## Active Skills

| Skill | Meaning now | Notes |
| --- | --- | --- |
| `melee` | all close-range weapon combat | Fighter backup and off-build support |
| `ranged` | bows, thrown, future ranged archetypes | Rogue support axis and future ranged core |
| `magic` | all spellcasting progression | schools are not growth axes |
| `defense` | armor, shields, attrition | Fighter anchor |
| `agility` | EV, detection pressure, ambush | Rogue anchor |

## Current Start Snapshot

| Class | HP | MP | STR | DEX | INT | Start skills |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| Fighter | 30 | 2 | 14 | 10 | 6 | `melee 2`, `defense 1` |
| Mage | 22 | 8 | 7 | 10 | 14 | `magic 2`, `agility 1` |
| Rogue | 25 | 3 | 10 | 14 | 10 | `ranged 1`, `agility 2` |

## Magic Structure

| Layer | Current rule |
| --- | --- |
| schools | spell categories only |
| progression | one shared `magic` skill |
| learning gate | `magic` level + `INT` |
| level-up offers | one random spell candidate per school |
| fallback acquisition | spellbooks |

## Awareness Structure

| State | Meaning |
| --- | --- |
| `unaware` | enemy has not detected the player |
| `aware` | enemy has detected the player |

| System piece | Current use |
| --- | --- |
| `agility` | lowers detection pressure and improves ambush payoff |
| Rogue | derives the most class value from `unaware` targets |
| ambush rule | based on awareness, not facing |

## Current Cleanup Rule

If old resource content conflicts with current mainline behavior:

1. `Fighter / Mage / Rogue` are the active starting classes
2. `melee / ranged / magic / defense / agility` are the live skills
3. spell schools are categories, not separate progression tracks
4. extra subclasses are future/disabled unless intentionally brought back
