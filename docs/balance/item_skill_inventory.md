# Item & Skill Inventory
_Last verified: 2026-05-27 (post mace-removal, staff wizardry bonus added)_

---

## 무기 — 기본

| ID | 카테고리 | 데미지 | 딜레이 | 히든 서브스킬 |
|----|---------|--------|--------|--------------|
| dagger | dagger | 4 | 1.0 | short_blades |
| stiletto | dagger | 5 | 0.8 | short_blades |
| dirk | dagger | 6 | 0.8 | short_blades |
| short_sword | dagger | 5 | 1.0 | short_blades |
| arming_sword | blade | 7 | 1.2 | long_blades |
| long_sword | blade | 10 | 1.4 | long_blades |
| great_blade | blade | 10 | 1.4 | long_blades |
| bastard_sword | blade | 15 | 1.5 | long_blades |
| battle_axe | axe | 15 | 1.7 | axes |
| spear | polearm | 6 | 1.0 | polearms |
| staff | staff | 10 | 1.3 | weapon_mastery (직접) |
| shortbow | ranged | 8 | 1.4 | bows |
| longbow | ranged | 14 | 1.7 | bows |
| crossbow | ranged | 16 | 1.9 | crossbows |
| throwing_knife | thrown | - | - | throwing |
| javelin | thrown | - | - | throwing |

**staff 특이사항**: 장착 시 wizardry_bonus +2 (MP비용 감소 ~16%, 마법위력 +8). `Player.gd:_STAFF_WIZARDRY_BONUS`.

## 무기 — 브랜드 (드롭 전용, 제거 예정)

| ID | 기반 카테고리 | 브랜드 / 특성 |
|----|------------|-------------|
| flaming_sword | dagger | flaming |
| frost_dagger | dagger | freezing |
| venom_dagger | dagger | venom |
| quick_blade | dagger | 딜레이 0.7 (빠름) |
| assassin_blade | dagger | 스텔스 배수 보너스 |

> 브랜드 무기 전체 제거가 예정된 별도 태스크.

---

## 방어구 — 바디

| ID | AC | EV 페널티 | 인카m |
|----|-----|---------|------|
| robe | +1 | 0 | 0 |
| leather_armor | +2 | 0 | 5 |
| ring_mail | +4 | 0 | 8 |
| troll_leather | +4 | 0 | 3 |
| scale_mail | +6 | -1 | 11 |
| chain_mail | +5 | -2 | 12 |
| plate_mail | +10 | -2 | 22 |

## 방어구 — 방패

| ID | 블록 확률 |
|----|---------|
| buckler | 10% |
| round_shield | 16% |
| kite_shield | 20% |
| tower_shield | 22% |

## 방어구 — 부위별

| 슬롯 | 아이템 |
|------|-------|
| 투구 | leather_cap, iron_helm, great_helm |
| 장갑 | leather_gloves, iron_gauntlets |
| 부츠 | leather_boots, iron_greaves |

---

## 반지 / 목걸이

| ID | 이름 | 효과 |
|----|------|------|
| ring_str | Ring of Might | STR +2 |
| ring_dex | Ring of Swiftness | DEX +2 |
| ring_int | Ring of Intelligence | INT +2 |
| ring_protection | Ring of Protection | AC +3 |
| ring_slaying | Ring of Slaying | slay_bonus +3 |
| ring_wizardry | Ring of Wizardry | wizardry_bonus +2 |
| ring_fire_resist | Ring of Fire Resistance | fire 저항 +1 |
| ring_cold_resist | Ring of Cold Resistance | cold 저항 +1 |
| ring_poison_resist | Ring of Poison Resistance | poison 저항 +1 |
| ring_necro_resist | Ring of Necromantic Warding | necro 저항 +1 |
| ring_ember | Ring of Embers | fire 저항 변형 |
| ring_glacier | Ring of the Glacier | cold 저항 변형 |
| ring_bog | Ring of the Bog | poison 저항 변형 |
| ring_undeath | Ring of Undeath | necro 저항 변형 |
| amulet_life | Amulet of Life | HP +20 |
| amulet_magic | Amulet of the Archmage | MP +8 |
| amulet_str | Amulet of Might | STR +3 |

---

## 소모품

### 포션

| ID | 효과 |
|----|------|
| potion_healing | HP 회복 |
| potion_magic | MP 회복 |
| potion_might | STR 임시 증가 |
| potion_haste | 하스트 |
| potion_resistance | 저항 임시 |
| potion_berserk | 버서크 |
| potion_cure_poison | 독 해제 |
| potion_invisible | 투명화 |
| potion_agility | DEX/EV 임시 |
| potion_brilliance | INT 임시 |
| potion_cancellation | 버프 해제 |
| potion_experience | XP 획득 |
| potion_confusion | (적) 혼란 |
| potion_degeneration | 능력치 저하 |
| potion_paralysis | 마비 |
| potion_poison | 독 |
| potion_liquid_flame | 화염 |
| potion_toxic_gas | 독 가스 |

### 두루마리

| ID | 효과 |
|----|------|
| scroll_identify | 감정 |
| scroll_teleport | 텔레포트 |
| scroll_magic_mapping | 지도 공개 |
| scroll_blinking | 블링크 |
| scroll_enchant_weapon | 무기 강화 |
| scroll_enchant_armor | 방어구 강화 |
| scroll_fear | 공포 |
| scroll_brand | 브랜드 부여 |
| scroll_immolation | 화염 폭발 |
| scroll_fog | 안개 |
| scroll_shrouding | 은신막 |
| scroll_silence | 침묵 |
| scroll_noise | 소음 |
| scroll_curse | 저주 |
| scroll_torment | 고통 |
| scroll_vulnerability | 취약 |
| scroll_upgrade | 업그레이드 |

### 완드

| ID | 효과 |
|----|------|
| wand_fire | 화염 |
| wand_frost | 냉기 |
| wand_lightning | 번개 |
| wand_teleport | 텔레포트 |
| wand_fear | 공포 |
| wand_haste | 하스트 |
| wand_digging | 굴착 |

### 투척 / 기타

| ID | 종류 |
|----|------|
| throwing_knife | 투척 |
| javelin | 투척 |
| bomb | 폭탄 |
| smoke_bomb | 연막탄 |
| poison_flask | 독 플라스크 |
| bandage | 붕대 (HP 소량 회복) |

---

## 스킬

### 가시 스킬 (8개)

| ID | 카테고리 | 역할 |
|----|---------|------|
| weapon_mastery | Combat | 근접무기 전반 데미지/명중 |
| archery | Combat | 원거리 |
| tactics | Combat | 전투 일반 + HP 성장 |
| defense | Defense | 방어구/방패 효율 |
| magery | Magic | 마법 전반 |
| stealth | Utility | 은신, 회피 |
| tracking | Utility | 탐색, 몬스터 인식 |
| survival | Utility | 생존 |

XP 커브 (누적): `[12, 28, 55, 95, 150, 230, 340, 490, 700]` / 최대 레벨 9

### 히든 서브스킬 → 가시 버킷 매핑

| 서브스킬 | → 가시 버킷 |
|---------|-----------|
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

### 무기 카테고리 → 서브스킬

| 무기 카테고리 | 서브스킬 |
|------------|---------|
| dagger | short_blades |
| blade | long_blades |
| axe | axes |
| polearm | polearms |
| staff | weapon_mastery (직접) |
| ranged bow/longbow | bows |
| ranged crossbow | crossbows |
| ranged sling | slings |
| thrown | throwing |

### 재능 (3개)

| ID | 이름 | 스탯 | 스킬 적성 |
|----|------|------|---------|
| veteran | Veteran | STR+1, HP+6 | weapon_mastery apt 2, tactics apt 2 |
| scout | Scout | DEX+1, HP+2 | stealth apt 2, tracking apt 2 |
| adept | Adept | INT+2, MP+4 | magery apt 3 |

apt 배율: `pow(1.2, apt)` — apt 2 = XP +44%, apt 3 = XP +73%

---

## 마법 (42종)

| 레벨 | 이름 | 학파 | MP |
|------|------|------|-----|
| 1 | Foxfire | fire | 1 |
| 1 | Scorch | fire | 2 |
| 1 | Shock | air | 1 |
| 1 | Freeze | cold | 1 |
| 1 | Sandblast | earth | 1 |
| 1 | Pain | necromancy | 1 |
| 1 | Slow | hexes | 1 |
| 1 | Sleep | enchantment | 2 |
| 2 | Conjure Flame | fire | 2 |
| 2 | Static Discharge | air | 2 |
| 2 | Blink | translocation | 2 |
| 2 | Shroud of Golubria | translocation | 4 |
| 2 | Petrify | earth | 4 |
| 2 | Animate Skeleton | summoning | 2 |
| 2 | Call Imp | summoning | 2 |
| 3 | Lightning Bolt | air | 6 |
| 3 | Stone Arrow | earth | 3 |
| 3 | Lee's Rapid Deconstruction | earth | 6 |
| 3 | Swiftness | translocation | 3 |
| 3 | Vampiric Draining | necromancy | 3 |
| 3 | Confuse | hexes | 3 |
| 3 | Cause Fear | hexes | 5 |
| 3 | Summon Vermin | summoning | 6 |
| 4 | Airstrike | air | 8 |
| 4 | Lehudib's Crystal Spear | earth | 8 |
| 4 | Ozocubu's Refrigeration | cold | 8 |
| 4 | Animate Dead | necromancy | 4 |
| 4 | Vampiric Draining (4) | necromancy | - |
| 4 | Stoneskin | abjuration | 6 |
| 4 | Polymorph | transmutation | 6 |
| 4 | Ensorcelled Hibernation | hexes | 6 |
| 4 | Monstrous Menagerie | summoning | 8 |
| 5 | Fireball | fire | 5 |
| 5 | Ignition | fire | 10 |
| 5 | Shatter | earth | 10 |
| 5 | Death's Door | necromancy | 10 |
| 5 | Malign Gateway | summoning | 10 |
| 6 | Haste | transmutation | 6 |
| 6 | Haunt | necromancy | 6 |
| 6 | Mass Confusion | hexes | 6 |
| 9 | Chain Lightning | evocation | 9 |
| 9 | Fire Storm | fire | 9 |
| 9 | Glaciate | cold | 9 |

**학파 목록**: fire / cold / air / earth / necromancy / hexes / enchantment / summoning / translocation / transmutation / abjuration / evocation (12개)

---

## 정리 메모

- **mace 제거됨** (2026-05-27): mace.tres, shock_mace.tres 삭제. 몬스터 풀 → spear/battle_axe 대체.
- **브랜드 무기 5종** (flaming_sword, frost_dagger, venom_dagger, quick_blade, assassin_blade): 드롭 전용이지만 제거 예정.
- **학파 정리 논의 중**: evocation/abjuration/enchantment가 element 버킷 외에 혼재. 마법 리뷰 예정.
