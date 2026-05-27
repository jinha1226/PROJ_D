---
name: project-skill-visibility-design
description: PROJ_D skill system — 8 visible skills + hidden sub-skill familiarity buckets. Verified 2026-05-27 from Actor.gd/Player.gd source.
metadata: 
  node_type: memory
  type: project
  originSessionId: 8f8bcc7d-e3af-4569-becb-10d0bb8b6e11
---

## Visible Skills (8) — Actor.gd SKILL_IDS

`weapon_mastery`, `archery`, `tactics`, `defense`, `magery`, `stealth`, `tracking`, `survival`

**lockpicking was removed.** Do not reference it.

Categories (Player.gd SKILL_CATEGORIES):
- Combat: weapon_mastery, archery, tactics
- Defense: defense
- Magic: magery
- Utility: stealth, tracking, survival

XP curve (Actor.gd SKILL_XP_DELTA): `[12, 28, 55, 95, 150, 230, 340, 490, 700]`, max level 9.

---

## Hidden Sub-skills — Actor.gd HIDDEN_SUBSKILL_IDS → SKILL_REMAP

XP dual-written to visible bucket AND hidden bucket on every action.

| Hidden sub-skill | → Visible bucket |
|-----------------|-----------------|
| fighting | tactics |
| unarmed | weapon_mastery |
| short_blades | weapon_mastery |
| long_blades | weapon_mastery |
| axes | weapon_mastery |
| staves | weapon_mastery |
| polearms | weapon_mastery |
| bows | archery |
| crossbows | archery |
| slings | archery |
| throwing | archery |
| armor | defense |
| shields | defense |
| dodging | stealth |
| spellcasting | magery |
| conjurations | magery |
| hexes | magery |
| summonings | magery |
| necromancy | magery |
| translocations | magery |
| transmutation | magery |
| element | magery |

---

## Weapon Category → Hidden Sub-skill (Player.gd weapon_skill_for_item)

| Item category | Hidden sub-skill |
|--------------|-----------------|
| dagger | short_blades |
| blade | long_blades |
| axe | axes |
| blunt | axes (same as axe!) |
| polearm | polearms |
| staff | weapon_mastery (direct, no sub-skill) |
| ranged (bow/longbow) | bows |
| ranged (crossbow) | crossbows |
| ranged (sling) | slings |
| ranged (javelin/dart/throw) | throwing |

---

## Spell School → Hidden Sub-skill (Player.gd progression_school_for)

| Spell school | Hidden sub-skill |
|-------------|-----------------|
| fire, cold, air, earth, poison | element |
| abjuration, evocation | element (grouped with elements!) |
| conjurations | conjurations |
| translocations | translocations |
| transmutation | transmutation |
| hexes, enchantment | hexes |
| necromancy | necromancy |
| summoning/summonings | summonings |

---

## Weapon Items (base only — branded variants excluded)

| Category | Items | Hidden sub-skill |
|----------|-------|-----------------|
| dagger | dagger(4/1.0), stiletto(5/0.8), dirk(6/0.8) | short_blades |
| blade | short_sword(5/1.0), arming_sword(7/1.2), long_sword(10/1.4), great_blade(10/1.4), bastard_sword(15/1.5) | long_blades |
| blunt | mace(8/1.25) | axes |
| axe | battle_axe(15/1.7) | axes |
| polearm | spear(6/1.0) | polearms |
| staff | staff(10/1.3) | weapon_mastery |
| ranged | shortbow(8/1.4), longbow(14/1.7), crossbow(16/1.9) | bows/crossbows |

Branded/special variants (flaming_sword, frost_dagger, venom_dagger, shock_mace, quick_blade, assassin_blade) exist in resources but user wants to review/remove.

---

## Talent System (3 talents as of 2026-05-27)

veteran: STR+1, HP+6, weapon_mastery apt 2, tactics apt 2
scout: DEX+1, HP+2, stealth apt 2, tracking apt 2
adept: INT+2, MP+4, magery apt 3

Survivor and Duelist were removed 2026-05-27.

**Why:** Reduced from 5 to 3 for clarity. Survivor/Duelist had overlapping identity with Veteran.
**How to apply:** Do not reference survivor or duelist talents; unknown ids fall back to veteran.
