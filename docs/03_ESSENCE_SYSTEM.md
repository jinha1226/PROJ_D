# 정수(Essence) 시스템 설계

## 개념
몬스터를 처치하면 해당 몬스터의 **정수(Essence)**를 흡수할 수 있다.
정수를 슬롯에 장착하면 그 몬스터의 특성이 플레이어 능력에 합산된다.
정수는 런 중 언제든 교체 가능 — 이것이 핵심 빌드 메카닉이다.

---

## 정수 슬롯

### 슬롯 수
- 시작: 2슬롯
- 메타 업그레이드 "정수 학습 I": 3슬롯
- 메타 업그레이드 "정수 학습 II": 4슬롯 (최대)

### 슬롯 동작 규칙
- 장착: 소지 정수 목록에서 선택 → 즉시 효과 적용
- 교체: 기존 정수 제거 → 새 정수 장착 (1턴 소모)
- 해제: 슬롯을 비울 수 있음 (효과 즉시 소멸)
- 정수는 소지 목록에서 꺼내 슬롯에 넣는 방식 (인벤토리 아이템처럼 관리)

---

## 정수 데이터 구조 (GDScript Resource)

```gdscript
# resources/essences/EssenceData.gd
class_name EssenceData
extends Resource

@export var id: String                    # "ogre_essence"
@export var display_name: String          # "오우거 정수"
@export var description: String
@export var essence_type: EssenceType     # GIANT, UNDEAD, NATURE, ...
@export var rarity: Rarity               # COMMON, UNCOMMON, RARE, LEGENDARY
@export var icon: Texture2D

# 스탯 보너스 (장착 시 플레이어 스탯에 직접 합산)
@export var str_bonus: int = 0
@export var dex_bonus: int = 0
@export var int_bonus: int = 0
@export var hp_bonus: int = 0
@export var armor_bonus: int = 0
@export var evasion_bonus: int = 0

# 특수 효과 (패시브)
@export var special_effects: Array[SpecialEffect] = []

# 드롭 몬스터 목록
@export var source_monsters: Array[String] = []

# 드롭 확률 (0.0 ~ 1.0)
@export var drop_chance: float = 0.3

enum EssenceType { GIANT, UNDEAD, NATURE, ELEMENTAL, ABYSS, DRAGON }
enum Rarity { COMMON, UNCOMMON, RARE, LEGENDARY }
```

---

## 정수 계열 & 효과 목록

### 거인계 (GIANT)
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 오우거 정수 | STR+8 | 근접 피해 +15% | 오우거 | COMMON |
| 트롤 정수 | STR+6, HP+20 | HP 재생 +1/턴 | 트롤 | UNCOMMON |
| 오크 정수 | STR+5 | 무기 공격속도 +1 | 오크 | COMMON |
| 거인 정수 | STR+12, HP+30 | — | 거인 보스 | RARE |

### 언데드계 (UNDEAD)
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 좀비 정수 | HP+15 | 독 저항 +30% | 좀비 | COMMON |
| 본나이트 정수 | AC+4 | 뼈 갑옷 (피격 시 일정확률 방어) | 본나이트 | UNCOMMON |
| 유령 정수 | EV+6 | 이동 시 소음 없음 | 유령 | UNCOMMON |
| 리치 정수 | INT+8, HP-10 | 주문 마나 소모 -20% | 리치 보스 | RARE |

### 자연계 (NATURE)
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 뱀 정수 | DEX+4 | 공격에 독 부여 (10% 확률) | 독사 | COMMON |
| 거미 정수 | DEX+3 | 거미줄 트랩 설치 가능 | 거미 | COMMON |
| 독개구리 정수 | DEX+2 | 독 피해 +50% | 독개구리 | COMMON |
| 드라이어드 정수 | HP+10, DEX+3 | 숲 타일에서 HP 재생 | 드라이어드 | UNCOMMON |

### 원소계 (ELEMENTAL)
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 화염정령 정수 | INT+6 | 공격에 화염 피해 추가 | 화염정령 | UNCOMMON |
| 냉기정령 정수 | INT+5 | 공격에 냉기(슬로우) 부여 | 냉기정령 | UNCOMMON |
| 번개정령 정수 | INT+7 | 번개 연쇄 공격 (5% 확률) | 번개정령 | RARE |

### 심연계 (ABYSS)
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 공허 정수 | STR+4, INT+4 | 공격에 저주 부여 | 공허충 | UNCOMMON |
| 나락 정수 | 전체 스탯+3 | 어둠 속 시야 +2 | 나락악마 | RARE |
| 심연 정수 | 전체 스탯+6 | 어둠 형태 변환 | 심연 보스 | LEGENDARY |

### 용계 (DRAGON) — 희귀
| 정수명 | 주 효과 | 특수 효과 | 드롭처 | 희귀도 |
|---|---|---|---|---|
| 어룡 정수 | STR+5, INT+5 | 수중 이동 가능 | 어룡 보스 | RARE |
| 화룡 정수 | STR+8, INT+4 | 화염 브레스 능력 획득 | 화룡 보스 | RARE |
| 고룡 정수 | 전체 스탯+10 | 용 변신 (전설 특수 능력) | 최종 보스 | LEGENDARY |

---

## 시너지 시스템

같은 계열 정수를 2개 이상 장착 시 시너지 보너스 발동.

```gdscript
# systems/EssenceSystem.gd
const SYNERGIES = {
  EssenceType.GIANT: {
    2: {"name": "거인의 힘", "effect": "근접 피해 +25% 추가"},
    3: {"name": "거인 변환", "effect": "체형 변환: HP+50, STR+10, 이동속도-1"},
  },
  EssenceType.UNDEAD: {
    2: {"name": "불사의 의지", "effect": "사망 시 1회 HP10으로 부활"},
    3: {"name": "언데드화", "effect": "독·냉기 완전 면역, 음식 불필요"},
  },
  EssenceType.NATURE: {
    2: {"name": "독의 친화", "effect": "독 완전 면역, 독 공격 피해 +30%"},
    3: {"name": "자연의 화신", "effect": "매 턴 HP+2 재생, 함정 감지"},
  },
  EssenceType.ELEMENTAL: {
    2: {"name": "원소 친화", "effect": "모든 원소 저항 +40%"},
    3: {"name": "원소 폭발", "effect": "공격 시 랜덤 원소 추가 피해"},
  },
  EssenceType.ABYSS: {
    2: {"name": "심연의 눈", "effect": "어둠 속 완전 시야"},
    3: {"name": "어둠 형태", "effect": "은신 이동 가능, 암습 피해 2배"},
  },
  EssenceType.DRAGON: {
    2: {"name": "용의 혈통", "effect": "화염·냉기 저항 +50%"},
    3: {"name": "용 변신", "effect": "완전 변신: 비행, 브레스 공격, 전 스탯+15"},
  },
}
```

---

## 정수 흡수 UI 흐름

```
몬스터 처치
    ↓
확률 체크 (drop_chance)
    ↓ (드롭 성공 시)
화면 하단에 알림 팝업 (2초)
"오우거 정수 획득! [장착] [보관]"
    ↓
[장착] 선택 → 슬롯 선택 팝업
[보관] 선택 → 소지 목록에 추가 (최대 10개 보관)
    ↓ (소지 목록 10개 초과 시)
"정수 보관함이 가득 찼습니다. 버릴 정수를 선택하세요."
```

---

## 정수와 직업의 상성

직업별로 특정 계열 정수 장착 시 보너스 배율 적용.

| 직업 | 상성 계열 | 보너스 |
|---|---|---|
| 바바리안 | 거인계 | 효과 +20% |
| 마법사 | 원소계 | 효과 +20% |
| 도적 | 자연계 | 효과 +20% |
| 사령술사 | 언데드계 | 효과 +20% |
| 드루이드 | 자연계, 원소계 | 효과 +15% |
| 드래곤킨 종족 | 용계 | 효과 +30% |

---

## 구현 우선순위

### M1 프로토타입
- [ ] 정수 슬롯 1개
- [ ] 정수 장착/해제
- [ ] STR/DEX/INT 보너스 적용
- [ ] 오우거 정수, 본나이트 정수, 뱀 정수 (3종)

### M2 알파
- [ ] 정수 슬롯 3개
- [ ] 시너지 시스템 (2개 계열)
- [ ] 정수 보관함 (최대 10개)
- [ ] 전체 COMMON/UNCOMMON 정수
- [ ] 정수 교체 UI

### M3 이후
- [ ] RARE/LEGENDARY 정수
- [ ] 직업 상성 보너스
- [ ] 정수 도감 (발견한 정수 기록)
