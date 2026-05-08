# Essence System Redesign — Implementation Spec

> **For agentic workers:** Use superpowers:subagent-driven-development or superpowers:executing-plans to implement task-by-task.

**Goal:** Replace the current 8 generic essences with 75 monster-themed essences (25 families × 3 variants), add helmet/gloves/boots equipment slots, and wire variant-based drop mechanics.

**Architecture:** Monster families each have 3 essence variants (A/B/C) of increasing rarity and power. Each essence has 2 positive + 1 negative effect adapted from DCSS mutations. Drop variant is determined by monster tier + is_boss + is_unique flags. Existing ESSENCES dict structure and Player/EssenceSystem apply/remove pipeline are preserved; only content changes + new passive_effect hooks.

**Reference:** `docs/dcss_mutation_reference.md` — full DCSS mutation list source.

---

## Part 1: New Equipment Slots (Helmet / Gloves / Boots)

### Files to change
- `scripts/entities/Player.gd` — add `equipped_helmet_id`, `equipped_gloves_id`, `equipped_boots_id` vars + equip/unequip API
- `scripts/systems/ItemRegistry.gd` — add helmet/gloves/boots item pool entries
- `scripts/ui/BagDialog.gd` — armor tab now shows helmet/gloves/boots (already shows armor + shield)
- `scripts/ui/PaperdollDialog.gd` (or StatusDialog) — show new slots
- `resources/items/` — new .tres files for helmets, gloves, boots
- Save/load migration — bump save_version, handle missing new slot fields

### Slot Rules
- **Helmet**: AC bonus. Some essences (Minotaur C, Orc C) block this slot.
- **Gloves**: small AC or hit bonus. Some essences (Troll C, Canine C) block this slot (claws).
- **Boots**: AC or EV bonus. Some essences (Centaur C, Serpent C) block this slot (hooves/tail).
- All three slots follow same equip/unequip pattern as existing armor/shield.

### Starting items (AC values)
| Item | AC | Tier |
|---|---|---|
| Leather Cap | +1 | 1 |
| Iron Helm | +2 | 2 |
| Great Helm | +3 | 3 |
| Leather Gloves | +0 (hit+1) | 1 |
| Iron Gauntlets | +1 | 2 |
| Leather Boots | +0 (ev+1) | 1 |
| Iron Greaves | +1 | 2 |

Randarts for all slots apply existing randart system.

---

## Part 2: Drop Mechanics

### Variant selection table
| Monster condition | Variant A | Variant B | Variant C |
|---|---|---|---|
| Tier 1–2, normal | 100% | 0% | 0% |
| Tier 3–4, normal | 60% | 40% | 0% |
| Tier 5–6, normal | 20% | 50% | 30% |
| `is_boss = true` (non-unique) | 0% | 0% | 100% |
| `is_unique = true` | 0% | 0% | 100% |

- Drop *whether* an essence falls: existing `drop_chance` (base 50%, overridden per monster, +10% for Essence faith).
- Bosses and uniques always drop when they drop (100% variant C, but drop_chance itself may still be < 100% for non-unique bosses — use `drop_chance_override` on the .tres).
- `essence_id` on monster.tres stays: if set, overrides the family lookup. If empty, derive from `essence_family` field (new field, string).

### New MonsterData field
Add `essence_family: String = ""` to MonsterData.gd. All monster .tres files get their family string. If `essence_family == ""`, no essence drops.

---

## Part 3: Essence Catalog (75 entries)

Convention: each entry shows `id | name | positive_1 | positive_2 | negative`.

Effect shorthand:
- `ac+N` = AC bonus N
- `ev+N` = EV bonus N  
- `sh+N` = Shield bonus N
- `str+N / int+N / dex+N` = stat bonus
- `hp+N%` = max HP percent bonus
- `mp+N%` = max MP percent bonus
- `rF / rC / rP / rElec / rN / rWill` = resist fire/cold/poison/elec/neg-energy/will
- `regen` = passive HP recovery each turn
- `mp_regen` = passive MP recovery
- `on_kill_hp` = heal HP on kill
- `on_kill_mp` = gain MP on kill
- `mana_shield` = damage split HP+MP
- `mana_link` = low MP → restore MP from kills/pain
- `powered_pain` = gain MP when taking damage
- `augment` = deal more damage/take less at high HP
- `bite` = bonus bite attack on melee
- `claw` = bonus claw attack on melee
- `kick` = bonus kick on melee
- `headbutt` = bonus headbutt on melee
- `poison_sting` = tail sting applies poison
- `weak_sting` = tail sting applies weak status
- `spiny` = retaliate damage when hit in melee
- `see_invis` = see invisible monsters
- `detect` = sense nearby monsters through walls
- `stealth+N` = stealth bonus (N tiers)
- `passive_map` = auto-reveal nearby tiles
- `hex+` = hex magic more effective
- `necro+` = death/necrotic magic more effective
- `efficient_mp1 / efficient_mp2` = spells cost -1/-2 MP
- `necrotic_touch` = melee deals necrotic damage
- `miasma` = emit poison cloud when hit
- `constrict` = chance to hold enemy in place
- `flight_ev` = EV+4 from magical flight
- `block_helmet / block_gloves / block_boots` = cannot equip that slot

Negative shorthand:
- `vuln_cold / vuln_fire` = -1 resist
- `cold_blooded` = cold attacks also slow you
- `scream` = alert monsters when hurt
- `attract` = pull monsters toward you
- `slow` = move speed reduced
- `no_stealth` = cannot be stealthy
- `inhibit_regen` = no HP regen when monsters visible
- `no_potion_half` = potions heal at 50%
- `no_potion` = potions do not heal HP
- `teleport` = occasional random teleport
- `str-N / int-N / dex-N` = stat penalty
- `hp-N%` = max HP reduction
- `mp-N%` = max MP reduction
- `no_jewelry` = cannot equip ring or amulet

---

### Family 1: Vermin
*Monsters: rat, bat, giant_cockroach, hornet, vampire_bat*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `vermin_a` | Vermin Essence | dex+2 | see_invis | scream |
| `vermin_b` | Swarm Essence | dex+4 + stealth+1 | claw | vuln_cold |
| `vermin_c` | Plague Essence | miasma | rP | no_stealth |

---

### Family 2: Canine
*Monsters: jackal, hound, wolf, warg*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `canine_a` | Pack Essence | bite | hp+10% | scream |
| `canine_b` | Fang Essence | bite (stronger) | regen | str-2 |
| `canine_c` | Alpha Essence | bite (strongest) + block_gloves | on_kill_hp | teleport |

---

### Family 3: Bear
*Monsters: black_bear, yak*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `bear_a` | Hide Essence | hp+10% | ac+1 | slow |
| `bear_b` | Brute Essence | hp+20% | ac+2 | attract |
| `bear_c` | Apex Essence | hp+30% | augment | slow |

---

### Family 4: Arachnid
*Monsters: scorpion, giant_wolf_spider*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `arachnid_a` | Venom Essence | poison_sting | dex+2 | vuln_cold |
| `arachnid_b` | Chitin Essence | poison_sting (stronger) | rP | str-2 |
| `arachnid_c` | Widow Essence | poison_sting (strongest) | dex+4 + stealth+1 | cold_blooded |

---

### Family 5: Serpent
*Monsters: adder, bog_serpent, viper_saint*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `serpent_a` | Fang Essence | bite | dex+2 | cold_blooded |
| `serpent_b` | Scale Essence | poison_sting | rP | vuln_cold |
| `serpent_c` | Viper Essence | constrict | ac+4 + rP + block_boots | cold_blooded |

---

### Family 6: Reptile
*Monsters: basilisk*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `reptile_a` | Lizard Essence | ac+2 | ac+1 (tough skin) | slow |
| `reptile_b` | Scale Essence | ac+4 | see_invis | no_stealth |
| `reptile_c` | Basilisk Essence | ac+6 | ev+3 | slow |

---

### Family 7: Goblinoid
*Monsters: goblin, kobold, hobgoblin*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `goblin_a` | Sneak Essence | stealth+1 | passive_map | str-3 |
| `goblin_b` | Skulk Essence | stealth+2 | dex+2 | hp-10% |
| `goblin_c` | Shadow Essence | stealth+3 | see_invis | hp-10% |

---

### Family 8: Orc
*Monsters: orc, orc_warrior, orc_priest, orc_wizard, orc_warchief*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `orc_a` | Warrior Essence | str+2 | ac+1 | int-2 |
| `orc_b` | Ironside Essence | str+4 | spiny | int-3 |
| `orc_c` | Warchief Essence | str+4 | augment | int-6 |

---

### Family 9: Gnoll
*Monsters: gnoll, gnoll_sergeant, gnoll_shaman, gnoll_warlord*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `gnoll_a` | Tracker Essence | detect | bite | scream |
| `gnoll_b` | Packmaster Essence | dex+2 | stealth+1 | scream |
| `gnoll_c` | Warlord Essence | see_invis | passive_map | attract |

---

### Family 10: Troll
*Monsters: troll, deep_troll*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `troll_a` | Troll Essence | regen | ac+1 | int-3 |
| `troll_b` | Deep Troll Essence | regen (fast) | claw | int-3 |
| `troll_c` | Ancient Troll Essence | regen (fast) | on_kill_hp | int-6 |

---

### Family 11: Ogre
*Monsters: ogre, two_headed_ogre, ogre_chieftain, ogre_mage*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `ogre_a` | Ogre Essence | hp+10% | claw | dex-3 |
| `ogre_b` | Chieftain Essence | hp+20% | str+4 | dex-3 |
| `ogre_c` | Mage-Killer Essence | str+4 | augment | no_jewelry |

---

### Family 12: Giant
*Monsters: cyclops, fire_giant, frost_giant, stone_giant, titan*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `giant_a` | Giant Essence | hp+10% | ac+2 | slow |
| `giant_b` | Colossus Essence | hp+20% | str+4 | slow |
| `giant_c` | Titan Essence | hp+30% | augment | slow |

---

### Family 13: Centaur
*Monsters: centaur*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `centaur_a` | Centaur Essence | kick | dex+2 | no_stealth |
| `centaur_b` | Charger Essence | kick (stronger) | hp+10% | no_stealth |
| `centaur_c` | Stampede Essence | kick (strongest) + block_boots | hp+20% | no_stealth |

---

### Family 14: Minotaur
*Monsters: minotaur*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `minotaur_a` | Horn Essence | headbutt | str+2 | int-3 |
| `minotaur_b` | Bull Essence | headbutt (stronger) | hp+10% | int-3 |
| `minotaur_c` | Labyrinth Essence | headbutt (strongest) + block_helmet | str+4 | int-6 |

---

### Family 15: Dragon
*Monsters: steam_dragon, swamp_dragon, fire_dragon, ice_dragon, wyvern*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `dragon_a` | Wyrm Essence | ac+2 | bite | no_stealth |
| `dragon_b` | Drake Essence | ac+4 | rP | no_stealth |
| `dragon_c` | Dragon Essence | ac+6 | flight_ev | no_stealth |

---

### Family 16: Elder Dragon
*Monsters: golden_dragon, bone_dragon*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `elder_dragon_a` | Ancient Essence | ac+4 | rWill+1 | no_stealth |
| `elder_dragon_b` | Legend Essence | ac+5 | ev+2 | no_stealth |
| `elder_dragon_c` | Apex Dragon Essence | ac+5 (iron-fused) | flight_ev | no_stealth |

---

### Family 17: Elemental
*Monsters: fire_elemental, earth_elemental*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `elemental_a` | Ember Essence | rF | ac+1 | mp-10% |
| `elemental_b` | Forge Essence | rF + rElec | efficient_mp1 | mp-10% |
| `elemental_c` | Core Essence | ac+5 (stone body) + petrify_immune | mp_regen | inhibit_regen |

---

### Family 18: Demon
*Monsters: crimson_imp, red_devil, ice_devil, balrug, executioner*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `demon_a` | Imp Essence | rF | necrotic_touch | attract |
| `demon_b` | Devil Essence | rF | rWill+1 | attract |
| `demon_c` | Balrug Essence | hex+ | rWill+2 | attract |

---

### Family 19: Deep Elf
*Monsters: deep_elf_archer, deep_elf_death_mage*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `elf_a` | Elf Essence | int+2 | efficient_mp1 | hp-10% |
| `elf_b` | Deep Elf Essence | int+4 | mp+10% | hp-10% |
| `elf_c` | Death Mage Essence | int+4 | efficient_mp2 | hp-20% |

---

### Family 20: Undead Basic
*Monsters: zombie, crypt_zombie, ghoul, mummy*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `undead_a` | Grave Essence | rP | ac+1 | inhibit_regen |
| `undead_b` | Crypt Essence | rP | rN | no_potion_half |
| `undead_c` | Plague Essence | rN (strong) | miasma | no_potion |

---

### Family 21: Undead Warrior
*Monsters: wight, skeletal_warrior*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `undead_warrior_a` | Wight Essence | ac+2 | str+2 | no_potion_half |
| `undead_warrior_b` | Bone Plate Essence | sh+4 | str+2 | no_potion_half |
| `undead_warrior_c` | Death Knight Essence | sh+8 | rN (strong) | no_potion |

---

### Family 22: Spirit
*Monsters: wraith, phantom, shadow_wraith, revenant*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `spirit_a` | Shade Essence | stealth+1 | powered_pain | str-2 |
| `spirit_b` | Wraith Essence | stealth+2 | mana_shield | str-2 |
| `spirit_c` | Revenant Essence | mana_shield | powered_pain (strong) | str-3 |

---

### Family 23: Vampire
*Monsters: vampire, vampire_bat, vampire_knight*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `vampire_a` | Blood Essence | regen | stealth+1 | inhibit_regen |
| `vampire_b` | Sanguine Essence | on_kill_hp | rC | inhibit_regen |
| `vampire_c` | True Vampire Essence | on_kill_hp (strong) | mana_link | inhibit_regen |

---

### Family 24: Lich
*Monsters: lich, ancient_lich, pale_scholar*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `lich_a` | Scholar Essence | int+2 | rN | no_potion_half |
| `lich_b` | Lich Essence | int+4 | mp_regen | no_potion_half |
| `lich_c` | Ancient Lich Essence | int+4 | necro+ (strong) | no_potion |

---

### Family 25: Construct
*Monsters: iron_golem, stone_warden, gargoyle*

| ID | Name | Positive 1 | Positive 2 | Negative |
|---|---|---|---|---|
| `construct_a` | Golem Essence | ac+2 | rElec | mp-10% |
| `construct_b` | Warden Essence | ac+3 | sh+4 | mp-10% |
| `construct_c` | Iron Essence | ac+5 | ev+4 + missile_resist | mp-20% |

---

## Part 4: Effect Implementation Map

Effects already implemented in EssenceSystem.gd (effect/penalty_effect fields):
- `stat_str`, `stat_int`, `stat_dex` → stat bonus/penalty
- `hp_max`, `hp_down` → max HP change
- `ac_bonus`, `ac_down` → AC change
- `ev_bonus`, `ev_down` → EV change (check if exists)
- `resist_fire`, `vuln_cold`, `resist_cold`, `vuln_fire` → resist change
- `on_kill_heal` → passive HP on kill
- `melee_fire`, `melee_chill` → elemental melee

**New passive_effects to implement** (in EssenceSystem + CombatSystem):
| passive_effect key | Behaviour |
|---|---|
| `bite` | On melee hit: deal bonus physical damage (scales with STR) |
| `bite_strong` | As above, higher damage |
| `bite_max` | As above, highest; blocks gloves slot |
| `claw` | Same as bite family |
| `kick` | Same as bite family; levels block boots |
| `headbutt` | Same as bite family; level 3 blocks helmet |
| `poison_sting` | On melee hit: apply poison 3 turns |
| `poison_sting_strong` | Apply poison 5 turns |
| `poison_sting_max` | Apply poison 8 turns |
| `weak_sting` | On melee hit: apply weak 2 turns |
| `constrict` | On melee hit: 30% chance enemy cannot move next turn |
| `spiny` | When hit in melee: deal 2 physical retaliation |
| `spiny_strong` | Retaliation 4 damage |
| `on_kill_hp` | Heal 3 HP on kill |
| `on_kill_hp_strong` | Heal 5 HP on kill |
| `on_kill_mp` | Gain 1 MP on kill |
| `regen` | Heal 1 HP every 5 turns |
| `regen_fast` | Heal 1 HP every 2 turns |
| `powered_pain` | Gain 1 MP whenever taking 5+ damage |
| `powered_pain_strong` | Gain 1 MP whenever taking 3+ damage |
| `mana_shield` | 50% of damage splits to MP (min 1 MP remaining) |
| `mana_link` | When MP = 0 and HP > 30%: heal 0 HP regen but restore 1 MP/turn |
| `augment` | When HP > 70%: +15% damage dealt, -10% damage taken |
| `miasma` | When hit in melee: 30% chance spawn poison cloud at attacker |
| `necrotic_touch` | Melee hits deal +3 necrotic (will-resisted) damage |
| `hex+` | Hex spell success rate +20% |
| `necro+` | Necrotic spell damage +15% |
| `efficient_mp1` | All spell MP costs -1 (min 1) |
| `efficient_mp2` | All spell MP costs -2 (min 1) |
| `mp_regen` | Restore 1 MP every 4 turns |
| `flight_ev` | EV +4 (magical flight) |
| `missile_resist` | 25% chance incoming ranged attacks miss |
| `see_invis` | See invisible monsters in FOV |
| `detect` | Sense all monsters within 5 tiles through walls |
| `passive_map` | Auto-reveal tiles within 3 tiles each turn |
| `passive_map_strong` | Auto-reveal tiles within 6 tiles |
| `petrify_immune` | Immune to petrification |

**New penalty_effects to implement:**
| penalty_effect key | Behaviour |
|---|---|
| `scream` | 20% chance on taking damage: alert all monsters in FOV |
| `attract` | Each turn: 10% chance pull one random off-screen monster 1 tile closer |
| `cold_blooded` | When hit by cold: also apply slow 1 turn |
| `slow` | Movement costs 1 extra turn every 3 moves |
| `no_stealth` | Monster detection range ignores player stealth |
| `inhibit_regen` | HP does not regenerate while any monster is in FOV |
| `no_potion_half` | Potion heal/buff effects at 50% value |
| `no_potion` | Potions do not restore HP (other effects still work) |
| `teleport` | 3% chance per turn to teleport to random floor position |
| `block_helmet` | Cannot equip helmet slot |
| `block_gloves` | Cannot equip gloves slot |
| `block_boots` | Cannot equip boots slot |
| `no_jewelry` | Cannot equip ring or amulet |

**Existing resist system:**
- `resist_fire` / `vuln_fire`: maps to existing `add_resist("fire", +1/-1)` capped ±3
- `resist_cold` / `vuln_cold`: same for cold
- `resist_poison` / `rP`: poison
- `resist_elec` / `rElec`: elec (if implemented)
- `rN` / `rN_strong`: negative energy → will resist +1/+2
- `rWill+N` → will bonus

---

## Part 5: Monster Family Assignment

Add `essence_family: String` to MonsterData.gd resource. Set per .tres:

| Family | Monsters |
|---|---|
| `vermin` | rat, bat, giant_cockroach, hornet, vampire_bat |
| `canine` | jackal, hound, wolf, warg |
| `bear` | black_bear, yak |
| `arachnid` | scorpion, giant_wolf_spider |
| `serpent` | adder, bog_serpent, viper_saint |
| `reptile` | basilisk |
| `goblin` | goblin, kobold, hobgoblin |
| `orc` | orc, orc_warrior, orc_priest, orc_wizard, orc_warchief |
| `gnoll` | gnoll, gnoll_sergeant, gnoll_shaman, gnoll_warlord |
| `troll` | troll, deep_troll |
| `ogre` | ogre, two_headed_ogre, ogre_chieftain, ogre_mage |
| `giant` | cyclops, fire_giant, frost_giant, stone_giant, titan |
| `centaur` | centaur |
| `minotaur` | minotaur |
| `dragon` | steam_dragon, swamp_dragon, fire_dragon, ice_dragon, wyvern |
| `elder_dragon` | golden_dragon, bone_dragon |
| `elemental` | fire_elemental, earth_elemental |
| `demon` | crimson_imp, red_devil, ice_devil, balrug, executioner |
| `elf` | deep_elf_archer, deep_elf_death_mage |
| `undead` | zombie, crypt_zombie, ghoul, mummy |
| `undead_warrior` | wight, skeletal_warrior |
| `spirit` | wraith, phantom, shadow_wraith, revenant |
| `vampire` | vampire, vampire_knight |
| `lich` | lich, ancient_lich, pale_scholar |
| `construct` | iron_golem, stone_warden, gargoyle |

Monsters without a family (manticore, ashen_magpie, sister_cinder, storm_hierophant, harrow_knight, sovereign_jelly, abyssal_sovereign, glacial_sovereign, ember_tyrant, blood_duke): assign unique essence or leave `essence_family = ""` for now.

---

## Part 6: Migration from Old Essences

Old essence IDs: `essence_fire`, `essence_cold`, `essence_might`, `essence_arcana`, `essence_swiftness`, `essence_vitality`, `essence_stone`.

Migration in `_apply_loaded_player_state`:
- Any old ID found in `essence_slots` or `essence_inventory` → remove it (no equivalent).
- Log: "Some essences from a previous version faded away."
- Bump `save_version` (currently tracked in SaveManager).

---

## Part 7: i18n

All 75 essence names + desc + passive_desc + penalty_desc → add to `i18n/translations.csv`.
Keys: `ESSENCE_<ID>_NAME`, `ESSENCE_<ID>_DESC`, `ESSENCE_<ID>_PASSIVE`, `ESSENCE_<ID>_PENALTY`.
