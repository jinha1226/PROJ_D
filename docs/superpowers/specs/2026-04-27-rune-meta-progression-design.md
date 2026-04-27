# 룬 메타 진행 시스템 설계

**작성일:** 2026-04-27  
**상태:** 승인됨

---

## 개요

매 플레이 후 **룬(Rune)**을 획득하고, 다음 플레이 시작 전 룬을 소비해 **시작 에센스**를 선택하는 메타 진행 시스템.  
영구 스탯 업그레이드 없음 — 유일한 혜택은 에센스를 가지고 던전에 진입하는 것.

---

## 룬 획득 (매 플레이 종료 시)

### 점수 공식

```
score = kills × 1 + items_collected × 1 + xl × 3 + depth × 2
        + (클리어 보너스: +50)
```

- **kills**: 처치한 몬스터 수 (`player.kills`, 기존 추적 중)
- **items_collected**: 획득한 아이템 수 (`player.items_collected`, 신규 추가)
- **xl**: 캐릭터 레벨 (`player.xl`, 기존)
- **depth**: 도달한 최대 층 (`GameManager.depth`, 기존)
- **클리어 조건**: 25층 진입 (24층 보스 처치 후)

룬 획득량 = score (1:1)

### 특성

- 사망해도 진행으로 인정 (룬 획득)
- 지출하지 않은 룬은 영구 누적
- `settings.json`에 저장 (이미 `rune_shards` 키로 저장 중 → 변수명 `rune_shards` 유지)

---

## 룬 지출 (캐릭터 생성 플로우)

### 플로우

```
메인 메뉴 → 종족 선택 → 직업 선택 → 에센스 선택 → 게임 시작
```

에센스 선택 화면은 직업 선택 완료 직후 삽입 (신규 씬: `EssenceSelect.tscn`).

### 에센스 선택 화면

- 상단: 현재 보유 룬 표시 (`◆ 47`)
- 에센스 카드 목록: 이름 / 효과 설명 / 비용
  - 잔액 부족 시 카드 비활성화
- "에센스 없이 시작" 버튼 (0 룬, 항상 활성)
- 선택 확정 시 룬 차감 후 게임 진입

### 에센스 비용 (초안)

에센스 세기를 3단계로 분류:

| 티어 | 비용 | 예시 에센스 |
|------|------|------------|
| 1 | 15 룬 | serpent, cinder |
| 2 | 35 룬 | gloam, bloodwake, tempest |
| 3 | 70 룬 | bastion, dread, pale_star |

> **참고:** 구체적 배치는 플레이테스트 후 조정. `EssenceData` 리소스에 `rune_cost: int` 필드 추가.

---

## UI 변경사항

### 메인 메뉴 (`MainMenu.gd`)

- 기존 "You have X rune shards" 안내 문구 → 상단 룬 잔액 배지로 교체 (`◆ X`)

### 결과 화면 (`ResultScreen.gd`)

- 이미 `shards_gained` / `shards_total` 표시 구현됨
- 점수 공식만 `Game.gd`에서 교체 (기존: `depth*2 + xl*3` → 새 공식)
- 라벨 텍스트 "Rune Shards" → "룬" 또는 "Rune" 로 통일

---

## 코드 변경 목록

### 1. `scripts/entities/Player.gd`
- `items_collected: int = 0` 추가
- 아이템 획득 시 (`_pick_up_item`) `items_collected += 1`

### 2. `scripts/core/GameManager.gd`
- `selected_starting_essence_id: String = ""` 추가
- `start_new_run()`에서 `selected_starting_essence_id` 초기화하지 않음 (EssenceSelect에서 설정)
- `spend_runes(cost: int) -> bool` 추가 (잔액 부족 시 false 반환)

### 3. `scripts/main/Game.gd`
- `_on_player_died()` 점수 공식 교체
- 클리어 감지: 25층 진입 시 victory + 클리어 보너스 포함 결과 화면 호출
- 플레이어 초기화 시 `selected_starting_essence_id` 가 있으면 `EssenceSystem.equip(player, id)` 호출

### 4. `scripts/menu/JobSelect.gd`
- 직업 확정 후 `Game.tscn` 대신 `EssenceSelect.tscn`으로 전환

### 5. `scenes/menu/EssenceSelect.tscn` + `scripts/menu/EssenceSelect.gd` (신규)
- 에센스 목록 렌더링
- 룬 잔액 확인 및 차감
- 선택 → `GameManager.selected_starting_essence_id` 설정 → 게임 진입

### 6. `resources/essences/*.tres`
- `EssenceData` 리소스에 `rune_cost: int` 필드 추가
- 각 에센스 `.tres` 파일에 비용 값 기재

---

## 데이터 구조 변경

```gdscript
# EssenceData (기존 필드에 추가)
@export var rune_cost: int = 0

# GameManager (신규 필드)
var selected_starting_essence_id: String = ""

# Player (신규 필드)
var items_collected: int = 0
```

---

## 범위 밖 (이번 구현 제외)

- 에센스 언락 시스템 (현재 모두 선택 가능)
- 룬 소비 내역 로그
- 에센스 비용 밸런싱 상세 (플레이테스트 후)
