# 브랜치 던전 & 던전 구조 재설계

**작성일:** 2026-04-27  
**상태:** 승인됨

---

## 배경

저항 시스템이 fire / cold / poison / will 4종으로 단순화되면서 neg(음속) 저항을 요구하던 Crypt 존이 의미를 잃었다. 기존 8존 메인 경로를 정리하고, 저항 테마 존들을 선택적 브랜치로 분리한다.

---

## 메인 경로 (16층)

| 존 | 층 | 맵 생성 | 환경피해 | 비고 |
|---|---|---|---|---|
| Dungeon | 1–3 | BSP | 없음 | 기존 유지 |
| Lair | 4–6 | CA | 없음 | 기존 유지 |
| Orc Mines | 7–9 | BSP tight | 없음 | 기존 유지 |
| Elven Halls | 10–12 | BSP large | 없음 | 기존 유지 |
| Depths | 13–15 | BSP long | 없음 | Crypt 계승 (neg 환경피해 제거) |
| **Final Boss** | 16 | 단일 대형 방 | — | 보스 + 타이탄 2 |

### Depths 존

- Crypt의 ghost, shadow, mummy priest, ancient champion 몬스터 그대로 재사용
- neg 환경피해만 제거 (분위기/몬스터 구성 유지)
- 맵: BSP long (긴 복도, MAX_SPLIT_DEPTH=5)
- 타일: 기존 Crypt 에셋 사용

---

## 브랜치 구조

### 공통 규칙

- 각 브랜치: **4층** (일반 3층 + 보스층 1)
- 입구: 해당 구간 메인 층에 계단 형태로 랜덤 배치 (한 입구만 생성)
- 브랜치 클리어 후 원래 층으로 귀환 가능 (stairs_up)
- 환경피해: 첫 층 50%, 2층 이후 100% — 해당 저항으로 완전 무효화

### Swamp Branch

| 항목 | 내용 |
|---|---|
| 저항 | poison |
| 입구 위치 | Lair 구간 (4–6층 중 랜덤) |
| 환경피해 | 독 DoT |
| 맵 생성 | CA + Water scatter (20% water tiles) |
| 보스 | 신규 유니크: **Bog Serpent** |
| 보상 | 독 브랜드 스크롤 (무기 또는 방어구, 랜덤) + `essence_plague` |

### Ice Caves Branch

| 항목 | 내용 |
|---|---|
| 저항 | cold |
| 입구 위치 | Orc Mines/Elven Halls 구간 (7–12층 중 랜덤) |
| 환경피해 | 냉기 DoT |
| 맵 생성 | CA open (넓은 동굴) |
| 보스 | 신규 유니크: **Glacial Sovereign** |
| 보상 | 냉기 브랜드 스크롤 (무기 또는 방어구, 랜덤) + `essence_glacial` |

### Infernal Branch

| 항목 | 내용 |
|---|---|
| 저항 | fire |
| 입구 위치 | Elven Halls/Depths 구간 (10–15층 중 랜덤) |
| 환경피해 | 화염 DoT |
| 맵 생성 | CA + Lava scatter (15% lava tiles) |
| 보스 | 신규 유니크: **Ember Tyrant** |
| 보상 | 화염 브랜드 스크롤 (무기 또는 방어구, 랜덤) + `essence_infernal` |

---

## 브랜드 스크롤 효과

### 무기 브랜드 (현재 장착 무기에 적용, 덮어쓰기)

| 브랜드 | 효과 |
|---|---|
| 독 브랜드 | 공격 시 독 5턴 추가 |
| 냉기 브랜드 | 공격 시 40% 확률 빙결 1턴 |
| 화염 브랜드 | 공격 시 화염 +4 피해 |

### 방어구 브랜드 (현재 장착 방어구에 적용, 덮어쓰기)

| 브랜드 | 효과 |
|---|---|
| 독 브랜드 | poison 저항 + 피독 상태일 때 매 턴 HP 1 회복 |
| 냉기 브랜드 | cold 저항 + 피격 시 20% 확률 공격자 빙결 1턴 |
| 화염 브랜드 | fire 저항 + 피격 시 20% 확률 공격자 화상(burning) 2턴 |

**규칙:**
- 무기/방어구에 브랜드는 하나만 유지 (덮어쓰기)
- 장착 무기/방어구 없으면 적용 불가 (메시지 표시)
- 브랜드 스크롤은 인벤토리 보관 가능 (즉시 사용 불필요)

---

## 유니크 에센스 3종

### essence_plague (Swamp 보스 드롭)
- **효과:** 독 상태인 적에게 피해 +20%, 독 면역
- **패널티:** WL -1
- **공명:** essence_venom과 조합 시 독 지속시간 +2턴

### essence_glacial (Ice Caves 보스 드롭)
- **효과:** cold 저항, 피격 시 20% 공격자 빙결 1턴
- **패널티:** DEX -1
- **공명:** essence_cold와 조합 시 빙결 확률 +20%

### essence_infernal (Infernal 보스 드롭)
- **효과:** 화염 공격/스펠 피해 +25%, fire 저항
- **패널티:** cold 취약
- **공명:** essence_cinder와 조합 시 화염 스펠 +4 추가 파워

---

## 업적 & 보상

| 조건 | 보상 |
|---|---|
| 브랜치 1개 클리어 | 룬 +35 |
| 브랜치 3개 모두 클리어 (1런) | 룬 +120 + 타이틀 "The Delver" |
| Swamp 클리어 + 최종 클리어 | 타이틀 "The Poisoner" |
| Ice Caves 클리어 + 최종 클리어 | 타이틀 "The Frozen" |
| Infernal 클리어 + 최종 클리어 | 타이틀 "The Infernal" |
| 3개 브랜치 + 최종 클리어 (1런) | 타이틀 "True Delver" |

---

## 데이터 구조 변경

### ZoneManager
- `branch_zone_id: String` — 현재 브랜치 존 ("" = 메인)
- `branch_origin_depth: int` — 브랜치 입장 전 메인 층
- `branches_cleared: Array[String]` — 이번 런에 클리어한 브랜치 목록

### GameManager (settings.json에 추가)
- `titles: Array[String]` — 획득한 타이틀 목록

### ItemData (기존 확장)
- `brand: String` — 무기/방어구에 부여된 브랜드 id ("", "venom", "freezing", "flaming")

### 신규: BrandScroll 아이템 종류
- `item kind = "brand_scroll"`, `brand_target = "weapon" | "armor" | "random"`
- `brand_element = "venom" | "freezing" | "flaming"`

---

## 범위 밖 (이번 구현 제외)

- 타이틀 UI 표시 (메인 메뉴 / 결과 화면)
- 브랜치 전용 BGM
- 브랜치 내 특수 상점
