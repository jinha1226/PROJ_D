# PocketCrawl Runtime Checklist

## Purpose
Use this checklist after substantial gameplay, progression, faith, essence, drop, or UI-facing system changes.

This is not a full QA matrix. It is the minimum runtime pass needed so major systemic changes do not remain only 'code-verified'.

## Session Metadata
- Date:
- Branch / commit:
- Main task:
- Runtime available in-session: yes / no

## Core Start Flow
- Main menu opens without missing UI or broken text.
- New game start flow still works.
- Race selection works.
- Class selection works.
- Test-only classes, if exposed, are clearly separated from normal classes.
- Run enters the dungeon scene without missing player state.

## Player / Progression
- Starting HP/MP match the intended class/race setup.
- Skills are shown correctly in the status/skills UI.
- Passive vs toggleable skill states are correct.
- Level-up still increases the intended stats/resources.
- Save/load preserves player HP, MP, stats, skills, equipment, faith, and essence state.

## First Sector / First Boss / Faith Flow
- First sector progresses normally.
- First boss encounter still spawns/activates correctly.
- Shrine room / altar / shrine-choice presentation still triggers at the intended time.
- Faith choice appears exactly once when intended.
- Choosing War / Arcana / Trickery / Death applies the intended state.
- Choosing Essence path (or equivalent alternate path) works and does not also apply normal-faith state.
- Fallback altar interaction does not duplicate or break the first-choice flow.

## Essence Flow
- Essence drop popup appears when expected.
- Inventory cap is enforced correctly.
- Replace / Take / Leave behavior works.
- Status panel shows current carried essence and equipped slots correctly.
- Locked slots remain locked until the intended unlock point.
- Equipping / removing / replacing essence updates stats and effects correctly.
- Non-Essence faith paths correctly disable or exclude essence usage if that rule is active.

## Combat / Magic / Tool Flow
- Melee combat still resolves normally.
- Ranged combat still resolves normally.
- Tool / wand / thrown-item flow still works.
- Spells still cast, target, and consume resources correctly.
- Kill rewards (XP, drops, triggers) still fire correctly.
- Shield block / defense / evasion logic still behaves plausibly.

## Drop / Economy
- Potion drops occur at the expected rough pace.
- Scroll drops occur at the expected rough pace.
- Equipment drops still occur and feel possible within the intended floor range.
- Wands / books / special drops still respect the intended rarity.
- Unique monsters still give their intended reward flow.

## UI / Explanation Surfaces
- Status screen text is readable and not mojibake/broken.
- Skills screen matches current system names and descriptions.
- Bestiary entries still render.
- Faith descriptions match actual behavior.
- Item / essence / system help text still matches the current rules.

## Auto-Move / Visibility / Map Flow
- Auto-move stops when enemies become visible.
- Visibility / awareness rules still feel consistent.
- Map size / compactness still feels within the intended direction.
- Stairs, shrine room, and boss room tiles still display correctly.

## Save / Load Risk Pass
Run at least one manual save/load check after any change touching:
- player progression
- inventory/equipment
- faith
- essence
- first-boss state
- map event state

## What Could Not Be Verified
- <list anything not runtime-tested>

## Notes / Regressions Found
- <list issues>
