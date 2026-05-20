---
name: project-skill-visibility-design
description: "PROJ_D skill system design — 9 visible PROJ_G skills carry 80% of performance, 30+ hidden DCSS-style familiarity buckets carry the remaining 20%. Decided 2026-05-21."
metadata: 
  node_type: memory
  type: project
  originSessionId: ae9b7462-a38a-4a0b-9765-08fe3229d2e0
---

PocketCrawl's skill system has two tiers by design:

**Visible (PROJ_G 9-skill set):** Weapon Mastery, Archery, Tactics, Defense, Magery, Stealth, Lockpicking, Tracking, Survival. Shown in UI, tutorials, toasts, character sheet. Each level contributes ~80% of the player's actual performance in that domain.

**Hidden (30+ DCSS sub-skill familiarities):** blade, dagger, axe, polearm, staves, bows, crossbows, slings, throwing, fire, ice, hex, necromancy, summoning, armor, shield, etc. These grow silently as the player uses specific items/spells. Each contributes ~20% of performance as a *narrow* bonus (e.g., dagger familiarity only boosts dagger attacks, not all melee).

**Why:** User decided (2026-05-21) this is the right shape for a commercial launch:
1. Onboarding is gated by 9 skills — new players never face 30+ choices
2. Heavy users get DCSS-style depth as "you got better at the thing you actually used"
3. Marketing message: "deep build variety" (true, just hidden)
4. Expansion-pack reserve: a future "Master Mode" can expose the hidden tier for veterans
5. Hidden values are **narrow** boosts only, never gates — equipment use is never blocked by a 0 in a hidden bucket

**How to apply:**
- UI/tutorial/save displays only the 9 visible skills.
- XP grants from actions write to BOTH the canonical 9-skill bucket AND the hidden familiarity bucket simultaneously.
- Combat/spell formulas reference visible_skill * 0.8 + hidden_familiarity * 0.2 (after balance pass).
- Hidden familiarity is always narrow: dagger familiarity boosts only dagger attacks, never broad melee.
- Save format must persist both tiers — collapsing on save would erase the design's identity reward.

**Forbidden anti-patterns (per user):**
- Don't make a high hidden value gate a low one (e.g., "your Defense is 40 but shield_familiarity is 0 so the shield does nothing")
- Don't let hidden values exceed 20% of effect — "secretly 30 skills" feeling
- Don't expose hidden buckets in default UI; reserve for an opt-in "Details" screen if ever

Related: PROJ_G 9-skill spec in `/mnt/d/PROJ_G/expedition_roguelike_proto/docs/rules/mobile_skill_balance_rules.md`. Current implementation lives in `Player.SKILL_IDS` (visible) and will gain `HIDDEN_SUBSKILL_IDS` when option-A from 2026-05-21 lands.
