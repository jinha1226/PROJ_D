# Zone & Monster Expansion Design
**Date:** 2026-04-23  
**Status:** Approved

---

## 1. 던전 구조

**8존 × 3층 + 보스층 = 25층 (기존 유지)**

각 존은 고유한 맵 타일, 맵 생성 알고리즘, 몬스터 풀, 환경 피해를 가진다.

---

## 2. 존 상세 설계

### Zone 1 — Dungeon (층 1-3)
- **타일:** `floor/pebble_brown`, `wall/brick_brown`
- **맵 생성:** BSP (현재 방식) — 직사각형 방 + L형 복도
- **환경 피해:** 없음
- **몬스터 (기존):** rat, bat, kobold, goblin, hobgoblin, hound, jackal, giant_cockroach, hornet
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | killer_bee | killer bee | mon/animals/killer_bee.png | 1 | Giant Bee |
  | bombardier_beetle | bombardier beetle | mon/animals/bombardier_beetle.png | 2 | Giant Beetle |

---

### Zone 2 — Lair (층 4-6)
- **타일:** `floor/lair`, `wall/lair`
- **맵 생성:** Cellular Automata — 유기적 동굴, 불규칙한 벽
- **환경 피해:** 없음
- **몬스터 (기존 재배치):** wolf, warg, black_bear, adder, giant_wolf_spider, vampire_bat, yak, scorpion, centaur
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | crocodile | crocodile | mon/animals/alligator.png | 2 | Crocodile |
  | giant_lizard | giant lizard | mon/animals/komodo_dragon.png | 2 | Giant Lizard |
  | anaconda | anaconda | mon/animals/anaconda.png | 3 | Giant Constrictor Snake |
  | polar_bear | polar bear | mon/animals/polar_bear.png | 3 | Polar Bear |
  | hippogriff | hippogriff | mon/animals/hippogriff.png | 4 | Hippogriff |

---

### Zone 3 — Orc Mines (층 7-9)
- **타일:** `floor/orc`, `wall/wall_stone_orc`
- **맵 생성:** BSP (방 소형 + 좁은 통로) — 광산 느낌
- **환경 피해:** 없음
- **몬스터 (기존 재배치):** orc, orc_warrior, orc_priest, orc_wizard, gnoll, gnoll_sergeant, gnoll_shaman, troll, deep_troll, ogre, ogre_mage, two_headed_ogre, minotaur, cyclops, stone_giant
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | orc_knight | orc knight | mon/humanoids/orcs/orc_knight.png | 4 | Orc (variant) |
  | orc_warlord | orc warlord | mon/humanoids/orcs/orc_warlord.png | 5 | Orc (variant) |
  | ettin | ettin | mon/humanoids/giants/ettin.png | 5 | Ettin |

---

### Zone 4 — Swamp (층 10-12)
- **타일:** `floor/swamp`, `wall/wall_stone_lair` (보그 느낌)
- **맵 생성:** Cellular Automata + Water scatter — 물웅덩이 산재
- **환경 피해:** 독 (poison DoT) — 독성 늪 타일 위에서 매 턴 독 누적. 첫 층은 약하게, 2-3번째 층 풀강도
- **필요 저항:** `poison` (신규 원소 추가 필요)
- **몬스터 (기존 재배치):** swamp_dragon, wyvern, basilisk, steam_dragon, manticore
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | death_yak | death yak | mon/animals/death_yak.png | 3 | Giant Yak (variant) |
  | hydra | hydra | mon/dragons/hydra3.png | 4 | Hydra |
  | will_o_wisp | will-o'-wisp | mon/nonliving/will_o_the_wisp.png | 3 | Will-o'-Wisp |
  | giant_constrictor | giant constrictor | mon/animals/anaconda.png | 4 | Giant Constrictor Snake |

---

### Zone 5 — Crypt (층 13-15)
- **타일:** `floor/crypt`, `wall/crypt`
- **맵 생성:** BSP (긴 복도 + 작은 방) — 납골당/미로 느낌
- **환경 피해:** 음에너지 안개 (neg DoT) — 최대 HP 감소. 첫 층 약하게, 2-3번째 층 풀강도
- **필요 저항:** `neg` (신규 원소 추가 필요)
- **몬스터 (기존 재배치):** zombie, wight, mummy, ghoul, skeletal_warrior, phantom, revenant, wraith, vampire, vampire_knight, lich
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | ghost | ghost | mon/undead/ghost.png | 3 | Ghost |
  | shadow | shadow | mon/undead/shadow_wraith.png | 3 | Shadow |
  | mummy_priest | mummy priest | mon/undead/mummy_priest.png | 4 | Mummy (variant) |
  | ancient_champion | ancient champion | mon/undead/ancient_champion.png | 5 | Champion (undead) |

---

### Zone 6 — Ice Caves (층 16-18)
- **타일:** `floor/ice`, `wall/ice_wall`
- **맵 생성:** Cellular Automata (개방형) — 넓은 빙하 동굴
- **환경 피해:** 동상 (cold DoT + 이동속도 감소). 첫 층 약하게, 2-3번째 층 풀강도
- **필요 저항:** `cold` (기존 지원)
- **몬스터 (기존 재배치):** frost_giant, ice_dragon, ice_devil
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | ice_beast | ice beast | mon/animals/ice_beast.png | 3 | Remorhaz (SRD-adjacent) |
  | rime_drake | rime drake | mon/dragons/rime_drake.png | 4 | Drake (cold) |
  | freezing_wraith | freezing wraith | mon/undead/freezing_wraith.png | 4 | Wraith (cold variant) |
  | blizzard_demon | blizzard demon | mon/demons/blizzard_demon.png | 5 | Demon (cold) |

---

### Zone 7 — Elven Halls (층 19-21)
- **타일:** `floor/crystal_floor`, `wall/elf-stone`
- **맵 생성:** BSP (방 크게, 직선) — 웅장한 대형 홀
- **환경 피해:** 없음 (마법 罠 트랩은 별도 기능)
- **몬스터 (기존 재배치):** deep_elf_archer, deep_elf_death_mage, gargoyle, earth_elemental, fire_elemental, iron_golem
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | deep_elf_knight | deep elf knight | mon/humanoids/elves/deep_elf_knight.png | 4 | Elf (knight) |
  | deep_elf_sorcerer | deep elf sorcerer | mon/humanoids/elves/deep_elf_sorcerer.png | 5 | Elf (sorcerer) |
  | deep_elf_blademaster | deep elf blademaster | mon/humanoids/elves/deep_elf_blademaster.png | 5 | Elf (blademaster) |
  | deep_elf_annihilator | deep elf annihilator | mon/humanoids/elves/deep_elf_annihilator.png | 5 | Elf (annihilator) |
  | deep_elf_high_priest | deep elf high priest | mon/humanoids/elves/deep_elf_high_priest.png | 5 | Elf (high priest) |
  | air_elemental | air elemental | mon/nonliving/air_elemental.png | 4 | Air Elemental |
  | water_elemental | water elemental | mon/nonliving/water_elemental.png | 4 | Water Elemental |
  | flesh_golem | flesh golem | mon/nonliving/flesh_golem.png | 4 | Flesh Golem |
  | war_gargoyle | war gargoyle | mon/nonliving/war_gargoyle.png | 5 | Gargoyle (variant) |

---

### Zone 8 — Infernal (층 22-24)
- **타일:** `floor/lava`, `wall/hell`
- **맵 생성:** Cellular Automata + Lava scatter — 용암 웅덩이 산재
- **환경 피해:** 화염 (fire damage) — 용암 타일 밟으면 즉각 화염 피해. 첫 층 약하게, 2-3번째 층 풀강도
- **필요 저항:** `fire` (기존 지원)
- **몬스터 (기존 재배치):** crimson_imp, red_devil, balrug, executioner, fire_dragon, fire_giant, bone_dragon, ancient_lich, titan
- **신규 몬스터:**
  | id | 표시명 | 타일 | tier | SRD |
  |---|---|---|---|---|
  | lemure | lemure | mon/demons/lemure.png | 2 | Lemure |
  | hell_hound | hell hound | mon/animals/hell_hound.png | 3 | Hell Hound |
  | efreet | efreeti | mon/demons/efreet.png | 5 | Efreeti |
  | brimstone_fiend | brimstone fiend | mon/demons/brimstone_fiend.png | 5 | Pit Fiend (variant) |
  | iron_dragon | iron dragon | mon/dragons/iron_dragon.png | 5 | Dragon (iron) |
  | shadow_dragon | shadow dragon | mon/dragons/shadow_dragon.png | 5 | Shadow Dragon |
  | storm_dragon | storm dragon | mon/dragons/storm_dragon.png | 6 | Storm Dragon |

---

### Zone Boss — Floor 25
- **타일:** 특수 (golden + infernal 혼합)
- **맵 생성:** 단일 대형 보스 방
- **보스:** `golden_dragon` (기존 tier 6) — 단독 보스, 전용 대사/연출 포함
- **호위:** `titan` 2마리 (보스 방 초기 배치)

---

## 3. 신규 종족 (3종)

| id | 표시명 | 타일 | 특성 방향 |
|---|---|---|---|
| halfling | Halfling | mon/humanoids/halfling.png | 회피+, 스텔스 |
| dwarf | Dwarf | mon/humanoids/deep_dwarf.png | HP+, AC+, 마법저항 |
| spriggan | Spriggan | mon/humanoids/spriggans/spriggan.png | 속도++, HP- |

---

## 4. 신규 저항 원소 (2종)

| 원소 id | 존 | 환경 피해 유형 | 몬스터 공격 예시 |
|---|---|---|---|
| `poison` | Zone 4 Swamp | 독성 늪 타일 — 매 턴 poison DoT | hydra 독 bite, death yak |
| `neg` | Zone 5 Crypt | 음에너지 안개 — 최대 HP 감소 | wraith 생명력 흡수, ghost |

기존: `fire` (Zone 8), `cold` (Zone 6)

---

## 5. 환경 피해 규칙

- **첫 번째 존 층 (예: 10, 13, 16, 22층):** 환경 피해 강도 50%
- **두 번째, 세 번째 층 (예: 11-12, 14-15, 17-18, 23-24층):** 환경 피해 강도 100%
- 저항 보유 시 환경 피해 완전 면역
- 환경 피해는 `Status.resist_scale()` 기존 시스템으로 처리

---

## 6. 맵 생성 알고리즘 요약

| 존 | 알고리즘 | 파라미터 변경점 |
|---|---|---|
| Dungeon | BSP (현재) | 기본값 유지 |
| Lair | Cellular Automata | birth=5, death=4, iterations=4 |
| Orc Mines | BSP | MAX_ROOM_W=6, MAX_ROOM_H=5 (소형) |
| Swamp | CA + Water scatter | CA 후 floor 20% water 타일 변환 |
| Crypt | BSP | MAX_SPLIT_DEPTH=5 (긴 복도) |
| Ice Caves | CA | birth=4, death=5 (개방형) |
| Elven Halls | BSP | MIN_ROOM_W=6, MAX_ROOM_W=12, MAX_ROOM_H=10 (대형) |
| Infernal | CA + Lava scatter | CA 후 floor 15% lava 타일 변환 |
| Boss | 단일 방 | 맵 중앙에 20×15 고정 방 |

---

## 7. 수치 요약

- 기존 몬스터: 67개 (depth 전면 재배치)
- 신규 몬스터: **37개**
- 신규 종족: **3개** (halfling, dwarf, spriggan)
- 신규 저항 원소: **2개** (poison, neg)
- 신규 맵 생성 방식: **2개** (Cellular Automata, CA+Scatter)
