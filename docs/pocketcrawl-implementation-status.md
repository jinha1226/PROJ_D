# PocketCrawl — 구현 현황 문서
> 작성일: 2026-04-30 | Godot 4 / GDScript 4 | MIT 라이선스

---

## 목차
1. [프로젝트 개요](#1-프로젝트-개요)
2. [아키텍처](#2-아키텍처)
3. [코어 시스템](#3-코어-시스템)
4. [컨텐츠](#4-컨텐츠)
5. [UI / UX](#5-ui--ux)
6. [DCSS 비교 분석](#6-dcss-비교-분석)

---

## 1. 프로젝트 개요

모바일 터치 우선 roguelike. DCSS(Dungeon Crawl Stone Soup)의 핵심 게임플레이를
15층 던전 + 4개 브랜치로 압축한 형태. 턴 기반, 영구사망, tile+glyph 혼용 렌더링.

**코드 규모**
| 파일 | 라인 수 |
|------|---------|
| Game.gd (메인 씬) | 2,480 |
| Player.gd | 1,131 |
| MagicSystem.gd | 558 |
| MapGen.gd | 500 |
| DungeonMap.gd | 415 |
| MonsterAI.gd | 416 |
| CombatSystem.gd | 443 |
| **합계 (주요)** | **~5,943** |

**컨텐츠 규모**
- 종족 10종 / 직업 14종
- 몬스터 85종 (보스 11종 포함)
- 아이템 110종
- 마법 91종
- 브랜치 4개 (각 4층 + 보스)

---

## 2. 아키텍처

```
Game.gd (씬 루트, ~2480줄)
├── TurnManager    (autoload) — 액터 큐, 플레이어/몬스터 턴 분리
├── CombatLog      (autoload) — 전투 메시지 스트림
├── GameManager    (autoload) — 세이브/로드, unlock, 타일 모드 토글
├── SpellRegistry  (autoload) — 마법 .tres 인덱스
├── ItemRegistry   (autoload) — 아이템 .tres 인덱스
├── MonsterRegistry(autoload) — 몬스터 .tres 인덱스
├── RaceRegistry   (autoload) — 종족 .tres 인덱스
├── ClassRegistry  (autoload) — 직업 .tres 인덱스
├── ZoneManager    (autoload) — 존/브랜치 설정
├── RacePassiveSystem (autoload) — 종족 패시브 훅
├── Status         (static class) — 상태이상 공용 로직
├── CombatSystem   (static class) — 데미지 계산, 근접/원거리/마법 공격
├── MagicSystem    (static class) — 마법 시전, 효과 처리
├── MonsterAI      (static class) — 몬스터 AI, 동선, 특수기
├── FieldOfView    (static class) — 시야 계산 (shadowcasting)
├── EssenceSystem  (static class) — 에센스 슬롯, 효과
├── FaithSystem    (static class) — 신앙 보너스/패널티
├── RingSystem     (static class) — 반지 효과
├── DungeonMap     (Node2D) — 타일 그리드, 시야, 시체, fog
├── MapGen         (static class) — BSP/Cave/Crypt 맵 생성
├── Player         (Node2D) — 플레이어 상태, 이동, 아이템, 스킬
├── Monster        (Node2D) — 몬스터 상태, ally 지원
└── UI layer — TopHUD, BottomHUD, 각종 Dialog
```

**턴 흐름**
```
플레이어 입력 → TurnManager.end_player_turn()
→ 몬스터 큐 순서대로 Monster.take_turn() 호출
  └─ MonsterAI.take_turn() → 이동/공격/특수기
→ 다시 플레이어 턴
```

---

## 3. 코어 시스템

### 3.1 맵 생성 (`MapGen.gd`)

| 스타일 | 알고리즘 | 사용 존 |
|--------|---------|---------|
| `bsp` | 이진 공간 분할 | Dungeon (B1–3), Orc Mines (B7–9) |
| `bsp_large` | BSP 대형 룸 | Elven Halls (B10–12), Infernal |
| `cave` | Cellular Automata | Lair (B4–6), Swamp, Ice Caves |
| `crypt` | 직선 복도+방 | Crypt (B13–15) |

환경 피해: 브랜치별 `env` 필드 (`poison`/`cold`/`fire`/`necro`) → 매 N턴 자동 데미지.

### 3.2 전투 (`CombatSystem.gd`)

**근접 공격 공식**
```
damage = weapon_damage_roll + strength_bonus - target.ac
         + skill_melee_bonus + status_bonus
hit_chance = base_hit - target.ev + skill_dodge_reduction
```

**원거리 공격**
- 화살/투석/볼트: `ranged` 카테고리 무기, 탄약 소모
- 사거리 1 이상에서 발사체 애니메이션 (spawn_spell_bolt)

**무기 브랜드** (ItemData.brand)
- flaming / freezing / venom / draining / holy / speed / vampiric 등 다수
- 브랜드별 원소 데미지 + 상태이상 부여

**방어**
- AC: 데미지 감소 (평균 ac/2)
- EV: 명중 회피 확률
- WL (Will): 상태이상 저항
- 방패: 블록 확률 (defense 스킬 + 신앙 보정)

### 3.3 마법 (`MagicSystem.gd`)

**효과 타입 (91종 마법)**
| effect | 설명 | 예시 |
|--------|------|------|
| `damage` | 단일 타겟 데미지 | Minor Flame, Shock |
| `aoe_damage` | 시야 내 전체 | Fireball, Ice Storm |
| `multi_damage` | N발 연속 | Magic Darts |
| `chain_damage` | 최대 3 바운스 | Chain Lightning |
| `drain` | 데미지+흡혈 | Vampiric Draining |
| `hold/sleep/fear/confusion/stun` | 상태이상 단일 | Hold Person |
| `aoe_status` | 상태이상 범위 | Mass Confusion |
| `instant_kill` | HP 임계 즉사 | Finger of Death |
| `summon` | 아군 소환 | Call Imp, Animate Dead |
| `buff_*` | 자신 버프 | Haste, Stoneskin |
| `blink/floor_travel` | 순간이동 | Blink, Gate |

**소환 시스템**
```
MagicSystem._SUMMON_TABLE: {
  "call_imp":         crimson_imp,  18턴
  "animate_dead":     시체→zombie,  20턴
  "summon_vermin":    rat × 3,      12턴
  "animate_skeleton": crypt_zombie, 20턴
  "animate_objects":  crimson_imp,  15턴
  "conjure_fey":      crimson_imp,  20턴
}
```

소환된 아군(`is_ally = true`)은:
- 녹색 tint 렌더링
- MonsterAI._take_ally_turn(): 가장 가까운 적 공격
- 플레이어 공격 타겟 불가
- 죽어도 XP/드랍 없음

**마법 파워 계산**
```
base = intelligence × (1 + magic_skill × 0.06) × armor_penalty
power = base + essence_bonus
final = power × faith_spell_damage_mult
```

**퀵슬롯 2단계 시전 (targeting)**
- `targeting == "self"` 또는 `"aoe"` → 즉시 시전
- `targeting in ["single", "auto", "nearest"]` → 2단계:
  1. 퀵슬롯 탭 → 사거리 범위 + 가장 가까운 적 노란 테두리 강조
  2. 그 적 탭 → 마법 발사 / 다른 곳 탭 → 취소

### 3.4 상태이상 (`Status.gd`)

단일 모듈에서 Player/Monster 양쪽 처리. `_dict_name()` 으로 dict 키 분기.

| 카테고리 | 상태 |
|---------|------|
| 데미지 DoT | poison, burning, diseased |
| 행동 불능 | frozen, paralyzed, sleeping, stunned |
| 행동 제한 | confused, feared |
| 버프 | hasted, stoneskin, mage_armor, blur, damage_boost, invulnerable |
| 특수 | time_stopped, magic_ward, weakened, wet |

### 3.5 AI (`MonsterAI.gd`)

**기본 AI 흐름**
```
take_turn():
  1. is_ally → _take_ally_turn() (가장 가까운 적 공격)
  2. 시야 내 플레이어 감지 → become_aware()
  3. 미감지: 무작위 이동
  4. 감지됨:
     a. 보스 특수기 체크 (telegraph → 다음 턴 발동)
     b. 원거리 공격 가능 → 사격
     c. 인접: 근접 공격
     d. 비인접: A* 경로탐색 이동
```

**보스 특수기** (MonsterData.attacks에 telegraphed 플래그)
- 1턴 예고 타일 표시 → 다음 턴 실제 발동
- warning_tiles: DungeonMap에 저장, 빨간 테두리 렌더링

### 3.6 스킬 시스템

**7개 스킬**: endurance, melee, ranged, magic, defense, agility, tool

- 최대 레벨 9, kill XP로 성장
- active_skills 배열에 등록된 스킬만 XP 수령
- MAX_SKILL_LEVEL 도달 시 XP 풀에서 제외

### 3.7 에센스 시스템

- Faith = "essence" 선택 시 활성화
- 슬롯 3개 (XL 1/8/16에 해금)
- 인벤토리 최대 4개 보유
- 몬스터 처치 시 드랍 (유니크 보스는 고정 에센스)

### 3.8 신앙 시스템

5개 신앙: **War** / **Arcana** / **Trickery** / **Death** / **Essence**

신전에서 선택, 이후 변경 불가. 스탯 곱/합 보정으로 플레이 스타일 분기.

### 3.9 시체 시스템

```
DungeonMap.corpses: Array[{pos, monster_id, tile_path, turns_left}]
```
- 몬스터 사망 시 100% 시체 생성 (40턴 후 소멸)
- 렌더링: tile_path 있으면 흐린 몬스터 타일, 없으면 `%` glyph
- `animate_dead`로 인접 시체 → zombie 소환

### 3.10 무기 소지 몬스터

18개 몬스터 타입이 무기 풀 보유 (orc, gnoll, minotaur, 등).

```
Game._roll_monster_weapon(monster):
  5% 확률: rare_pool에서 브랜드 무기
  95%: normal_pool에서 일반 무기
```
- 몬스터 공격력에 `weapon.damage / 2` 추가
- 사망 시 무기 드랍 (FloorItem으로 스폰)

---

## 4. 컨텐츠

### 4.1 종족 (10종)

| 종족 | 특징 패시브 |
|------|-----------|
| Human | adaptable (스킬 XP +10%) |
| Elf | 마법 XP 보너스, 낮은 HP |
| Dwarf | stone_sense (함정 탐지), AC 보너스 |
| Hill Orc | bloodthirst (처치 시 +HP) |
| Kobold | trapfinder, fleet (이동 패널티 없음) |
| Troll | regeneration (3턴당 +1 HP), 높은 HP |
| Minotaur | headbutt (근접 무기 추가 타격) |
| Spriggan | keen_eyes (시야+1), 낮은 HP |
| Gargoyle | stone_body (AC 보너스), 독 면역 |
| Vampire | blood_drain (공격 시 흡혈), 수면 면역 |

### 4.2 직업 (14종)

Fighter, Berserker, Crusher, Spearman, Ranger, Rogue, Mage, Conjurer, Enchanter, Ice Mage, Necromancer, Transmuter, Abjurer, Evoker

각 직업: 시작 장비, 초기 스킬, 시작 마법 정의.

### 4.3 존 구성

**메인 패스 (15층)**
```
B1–3   Dungeon       (BSP)
B4–6   Lair          (Cave/CA)
B7–9   Orc Mines     (BSP)
B10–12 Elven Halls   (BSP Large)
B13–14 Abyss         (Cave, 저주의 경로)
B15    [보스층 미구현]
```

**브랜치 (각 4층 + 보스)**
```
Swamp      (B4–6 입장, 독 환경)  → Bog Serpent
Ice Caves  (B7–9 입장, 냉기 환경) → Glacial Sovereign
Infernal   (B10–12 입장, 불꽃 환경) → Ember Tyrant
Crypt      (B13–15 입장, 사령 환경) → Ancient Lich
```

각 브랜치 완료 시: Rune + Essence + Ring 보상.

### 4.4 몬스터 (85종, 보스 11종)

11개 종족 그룹, 깊이별 min/max_depth로 등장 범위 제어.

**보스 목록**
Bog Serpent / Glacial Sovereign / Ember Tyrant / Ancient Lich /
Gnoll Warlord / Ogre Chieftain / Orc Warchief / Pale Scholar /
Sovereign Jelly / Stone Warden / Blood Duke

### 4.5 아이템 (110종)

카테고리: weapon / armor / potion / scroll / wand / ring / amulet / essence

- 무기: 근접 (검/도끼/지팡이 등) + 원거리 (활/투석기)
- 방어구: 로브~플레이트아머, 방패 별도
- 포션: 치유/버서크/저항/취소/투명화 등
- 스크롤: 식별/텔레포트/공포/소음/소각 등
- 완드: 각종 마법 (충전형)

---

## 5. UI / UX

### 5.1 터치 인터페이스

- **이동**: 빈 타일 탭 → 자동경로 탐색 + PathOverlay 표시
- **공격**: 몬스터 탭 → 즉시 공격 (원거리 무기 시 발사체)
- **마법**: 퀵슬롯 탭 → 2단계 타겟팅 (targeting spells)
- **자동탐험**: 전투/아이템 없을 시 RestButton 长press
- **확대/축소**: ZoomController (핀치 제스처)

### 5.2 PathOverlay

DCSS 오리지널 rltile 사용:
- `travel_path_from{1-8}.png` (8방향 방향 발자국)
- `cursor.png` (목적지 커서)
- 32×32 RGBA, 0.75 알파

### 5.3 SpellTargetOverlay

- 사거리: 연한 색조 fill
- 피격 예상 타일: 진한 fill + 컬러 테두리
- 선택된 타겟: **노란 테두리 + 황색 fill** (2단계 확인 대기)

### 5.4 HUD

- **TopHUD**: HP/MP 바 + 수치, 층 정보, 미니맵
- **BottomHUD**: 퀵슬롯 5개, 가방/스킬/마법/상태/도감/쉬기 버튼
- **StatusDialog**: HP/MP regen 턴당 표시 (`+X.XX/t`)
- **BestiaryDialog**: 처치한 몬스터 도감

---

## 6. DCSS 비교 분석

### ✅ PocketCrawl이 잘 하는 것

**모바일 터치 UX**
DCSS는 PC 키보드 중심 설계라 모바일 포팅이 불편하다. PocketCrawl은 처음부터 탭/스와이프 기반으로 설계되어 한 손 플레이 가능. 자동경로, 2단계 마법 타겟팅, 퀵슬롯 모두 터치 친화적.

**빠른 게임 루프**
DCSS는 일반 런 15~30시간. PocketCrawl은 15층 + 브랜치 선택형 구조로 1~2시간 런을 목표. 모바일 세션에 적합.

**코드 단순성**
DCSS는 C++ 50만+ 줄. PocketCrawl은 GDScript ~6천 줄로 핵심 로직을 구현. 시스템 추가/수정이 훨씬 빠름.

**스킬 시스템 간소화**
DCSS의 스킬 시스템은 27종 스킬 + 정교한 XP 배분 UI가 있어 신규 유저에게 진입장벽이 높다. PocketCrawl은 7종 + 활성화 토글로 직관적.

**신앙 시스템 단순화**
DCSS의 신 시스템(20종+)은 각 신마다 고유 메커니즘(Nemelex 카드덱, Jiyva 점액 등)이 있어 복잡하다. PocketCrawl 5종 신앙은 스탯 보정 위주로 이해하기 쉬움.

---

### ❌ DCSS가 우월한 것

**전략적 깊이 — 종족×직업 조합**
DCSS: 종족 30종 × 직업 28종 = 840 콤보, 각 조합이 플레이 스타일에 실질적 영향.
PocketCrawl: 10×14 = 140 콤보, 종족 패시브가 단순한 수치 보정 위주라 실제 플레이 차이가 작음.
> 미토르 headbutt, 트롤 regen 외에는 "숫자가 조금 다른" 수준.

**지형 상호작용**
DCSS: 물/용암/나무/유리/금속 타일이 각각 다른 전술적 의미를 가진다. 물 위에서 번개 마법 위험, 나무에 불지르기, 지형 파괴 등.
PocketCrawl: fog_tiles와 환경 피해 외에 지형 상호작용이 거의 없음. 모든 바닥은 동일하게 동작.

**몬스터 AI 다양성**
DCSS: 몬스터마다 고유 AI 플래그 (도망/공격/협력/지원 캐스터 등), 팩 행동, 원거리 유닛이 거리 유지하며 사격.
PocketCrawl: 기본 AI (이동+공격+도망) + 보스 특수기 정도. 팩 행동, 유닛 협력 없음.
> 예: DCSS의 오크 성직자는 다른 오크를 치유/버프. PocketCrawl 오크들은 각자 독립적으로 행동.

**아이템 식별 시스템**
DCSS: 포션/두루마리는 미식별 상태 (랜덤 이름), 사용해봐야 효과 파악.
PocketCrawl: **구현 완료.** GameManager.pseudonyms로 런마다 랜덤 이름 부여, 첫 사용 시 자동 식별, scroll_identify로 선택 식별. DCSS와 동일한 수준.

**레벨 디자인 — 특수 룸**
DCSS: 보물 방, 정원, 동물원, 신전 등 특수 방들이 각 층을 특색 있게 만듦.
PocketCrawl: 제단(신앙 선택)과 계단 외에 특수 룸 없음. 층마다 유사한 느낌.

**진행 연계**
DCSS: 룬 3개 → 범위 확장, 보주 회수 → 도주 구간 등 스토리 연계 진행.
PocketCrawl: 브랜치 룬 보상이 있으나 메타 진행에 영향이 미미함. B15 보스층 미구현.

**균형 — 마법 학교 전문화**
DCSS: 마법 학교(파괴/부활/변환 등)에 따라 마법서 선택이 달라지고 빌드 정체성 형성.
PocketCrawl: 91종 마법이 있으나 school 필드가 빌드 분기에 실질적 영향을 주지 않음. 어떤 직업이든 같은 마법을 쓸 수 있음.

**시야/조명 시스템**
DCSS: 어두운 던전, 횃불, 빛 생성 마법, 반지 효과로 시야 확장.
PocketCrawl: 고정 반경 shadowcasting. 시야 조작 아이템/마법이 전략적으로 활용되지 않음.

**사운드/피드백**
DCSS PC 버전: 몬스터별 사운드, 발소리로 감지, 경보 시스템.
PocketCrawl: 사운드 없음. 시각 피드백(빨간 tint, 숫자 등)만 존재.

---

### 📊 요약

| 항목 | DCSS | PocketCrawl |
|------|------|-------------|
| 세션 길이 | 15~30h | 1~2h 목표 |
| 종족/직업 조합 | 840+ | 140 |
| 몬스터 수 | 300+ | 85 |
| 마법 수 | 100+ | 91 |
| AI 복잡도 | ★★★★★ | ★★★☆☆ |
| 지형 상호작용 | ★★★★★ | ★★☆☆☆ |
| 터치 UX | ★★☆☆☆ | ★★★★★ |
| 신규자 진입장벽 | ★★★★★ | ★★★☆☆ |
| 빌드 다양성 | ★★★★★ | ★★★☆☆ |
| 아이템 신비성 | ★★★★★ | ★☆☆☆☆ |

**PocketCrawl의 포지션**: DCSS의 전략 깊이를 70% 수준으로 보존하면서, 모바일 세션에 맞는 속도와 터치 UX를 확보. 현재 가장 큰 약점은 아이템 식별 시스템 부재와 지형 상호작용의 빈약함.

---

## 7. 미구현/백로그

- [ ] B15 보스층 & 엔딩 조건
- [ ] 아이템 미식별 시스템 (포션/두루마리 랜덤 이름)
- [ ] 종족별 HP per level (현재 고정 수치)
- [ ] 지형 상호작용 확장 (물+번개, 나무+불)
- [ ] 팩 AI (몬스터 협력 행동)
- [ ] 사운드
- [ ] B15+ 승리 시 런샤드 시스템 (설계 완료)
