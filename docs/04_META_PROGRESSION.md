# 메타 성장 시스템

## 개념
Vampire Survivors 방식. 런이 끝나면 성공/실패 모두 **룬 조각(Rune Shards)** 획득.
룬 조각으로 영구 능력치 강화 및 콘텐츠 해금. 죽어도 뭔가 남는다.

---

## 룬 조각 획득

| 조건 | 획득량 |
|---|---|
| 런 클리어 (B15F 도달 + 오브 회수) | ×10~20 (층수·브랜치 비례) |
| 사망 | ×1~5 (도달 층수 비례, 최소 1) |
| 일반 보스 처치 | ×3 추가 |
| 브랜치 보스 처치 | ×5 추가 |
| 데일리 챌린지 참여 | ×5 |
| 데일리 챌린지 클리어 | ×10 추가 |
| 첫 런 클리어 (생애 최초) | ×20 보너스 |
| 특정 직업 첫 클리어 | ×5 보너스 |

---

## 메타 업그레이드 트리

### 카테고리: 생존
| ID | 이름 | 비용 | 효과 | 선행 조건 |
|---|---|---|---|---|
| surv_1 | 생존력 I | 5 | 시작 HP +10% | 없음 |
| surv_2 | 생존력 II | 15 | 시작 HP +20% | surv_1 |
| surv_3 | 생존력 III | 30 | 시작 HP +30% | surv_2 |
| food_1 | 시작 식량 | 6 | 런 시작 시 식량 +1 | 없음 |
| potion_1 | 시작 포션 | 8 | 런 시작 시 HP 포션 1개 | surv_1 |
| armor_1 | 초기 방어구 | 12 | 시작 AC +2 | surv_1 |

### 카테고리: 탐험
| ID | 이름 | 비용 | 효과 | 선행 조건 |
|---|---|---|---|---|
| exp_1 | 탐험가의 직감 | 8 | 시작 시 계단 위치 1개 공개 | 없음 |
| exp_2 | 지도 학습 | 15 | 각 층 진입 시 주변 3타일 자동 탐색 | exp_1 |
| exp_3 | 던전 감각 | 25 | 함정 감지 확률 +30% | exp_2 |
| store_1 | 상점 친화 | 10 | 시작 골드 +50 | 없음 |

### 카테고리: 정수
| ID | 이름 | 비용 | 효과 | 선행 조건 |
|---|---|---|---|---|
| ess_1 | 정수 학습 I | 10 | 정수 슬롯 3번째 해금 | 없음 |
| ess_2 | 정수 학습 II | 30 | 정수 슬롯 4번째 해금 (최대) | ess_1 |
| ess_3 | 정수 기억 | 20 | 마지막 런 정수 조합 기억·재사용 가능 | ess_1 |
| ess_4 | 정수 친화 | 15 | 정수 드롭 확률 +10% | ess_1 |

### 카테고리: 직업 해금
| ID | 이름 | 비용 | 해금 내용 | 선행 조건 |
|---|---|---|---|---|
| job_mage | 마법사 해금 | 25 | 마법사 직업 플레이 가능 | 없음 |
| job_necro | 사령술사 해금 | 35 | 사령술사 직업 플레이 가능 | job_mage |
| job_priest | 신관 해금 | 30 | 신관 직업 플레이 가능 | 없음 |
| job_hunter | 사냥꾼 해금 | 20 | 사냥꾼 직업 플레이 가능 | 없음 |
| job_smith | 대장장이 해금 | 25 | 대장장이 직업 플레이 가능 | 없음 |
| job_bard | 음유시인 해금 | 40 | 음유시인 직업 플레이 가능 | job_priest |

### 카테고리: 종족 해금
| ID | 이름 | 비용 | 해금 내용 | 선행 조건 |
|---|---|---|---|---|
| race_elf | 엘프 해금 | 20 | 엘프 종족 선택 가능 | 없음 |
| race_naga | 나가 해금 | 35 | 나가 종족 선택 가능 | 냉동굴 브랜치 클리어 |
| race_undead | 언데드 해금 | 40 | 언데드 종족 선택 가능 | 망자의 묘 클리어 |
| race_beast | 수인족 해금 | 30 | 수인족 종족 선택 가능 | race_elf |
| race_dragon | 드래곤킨 해금 | 60 | 드래곤킨 종족 선택 가능 | 보스 5회 처치 |

### 카테고리: 콘텐츠 해금
| ID | 이름 | 비용 | 해금 내용 | 선행 조건 |
|---|---|---|---|---|
| branch_tomb | 망자의 묘 | 30 | 망자의 묘 브랜치 개방 | 없음 |
| branch_abyss | 심연 브랜치 | 0 | 심연 브랜치 개방 | 런 1회 클리어 |
| daily | 데일리 챌린지 | 40 | 데일리 모드 해금 | 없음 |
| ghost | 유령 시스템 | 20 | 다른 플레이어 유령 조우 | 없음 |

---

## 데이터 구조

```gdscript
# systems/MetaProgression.gd
class_name MetaProgression
extends Node

const SAVE_FILE = "user://meta_save.json"

var rune_shards: int = 0
var unlocked: Dictionary = {}   # { upgrade_id: true }
var stats: Dictionary = {}      # 현재 적용된 메타 스탯

func get_start_hp_bonus() -> float:
    var bonus = 1.0
    if unlocked.get("surv_1"): bonus += 0.10
    if unlocked.get("surv_2"): bonus += 0.20
    if unlocked.get("surv_3"): bonus += 0.30
    return bonus

func get_essence_slot_count() -> int:
    if unlocked.get("ess_2"): return 4
    if unlocked.get("ess_1"): return 3
    return 2

func is_job_unlocked(job_id: String) -> bool:
    # 기본 직업은 항상 해금
    const DEFAULT_JOBS = ["barbarian", "explorer", "warrior", "rogue", "druid"]
    if job_id in DEFAULT_JOBS: return true
    return unlocked.get("job_" + job_id, false)

func add_rune_shards(amount: int) -> void:
    rune_shards += amount
    save()

func purchase_upgrade(upgrade_id: String) -> bool:
    var cost = UPGRADE_COSTS[upgrade_id]
    if rune_shards < cost: return false
    if not _check_prerequisites(upgrade_id): return false
    rune_shards -= cost
    unlocked[upgrade_id] = true
    save()
    return true
```

---

## 런 종료 화면 (결과 화면)

### 클리어 시
```
┌──────────────────────────┐
│  ⚔️ 던전 클리어!           │
│                          │
│  도달 층수: B15F           │
│  처치 몬스터: 142마리       │
│  소요 턴: 1,847턴          │
│                          │
│  💎 룬 조각 획득: +18       │
│  (클리어 +12, 보스 +6)     │
│                          │
│  총 보유: 847 💎           │
│                          │
│  [메타 업그레이드] [다시 도전] │
└──────────────────────────┘
```

### 사망 시
```
┌──────────────────────────┐
│  💀 B8F에서 쓰러졌습니다    │
│                          │
│  킬러: 화염 정령            │
│  도달 층수: B8F            │
│  처치 몬스터: 67마리        │
│                          │
│  💎 룬 조각 획득: +4        │
│  (B8F 도달 +3, 첫 죽음 +1) │
│                          │
│  총 보유: 124 💎           │
│                          │
│  [메타 업그레이드] [다시 도전] │
└──────────────────────────┘
```

---

## 구현 우선순위

### M1 프로토타입
- [ ] 룬 조각 획득/저장 기본 구조
- [ ] 사망/클리어 시 결과 화면

### M2 알파
- [ ] 메타 업그레이드 트리 UI
- [ ] 생존·정수 카테고리 업그레이드
- [ ] 직업 2개 해금 (마법사, 신관)

### M3 이후
- [ ] 전체 업그레이드 트리
- [ ] 종족 해금
- [ ] 데일리 챌린지 연동
