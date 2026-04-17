# Town Hub + Companion System (Phase C / D plan)

마을 허브와 영구 동료 시스템 설계 메모. 던전 시스템 마무리 후 착수.

## 핵심 원칙

- **동료도 영구 사망** (소환 essence 동료와 분리). DCSS 신 시스템 아님.
- **동료의 종족 / 직업 / 스킬 / 스탯 시스템은 플레이어와 동일** —
  Catfolk Monk, Hill Orc Berserker 등 그대로 동료로 채용 가능.
  → `RaceData` / `JobData` / `SkillSystem` / `Stats` 재활용.
- **마을은 허브**, 던전 진입 → 클리어 / 사망 → 마을 복귀.
- 마을은 PROJ_B의 town hub UI 개념 차용 (CanvasLayer 오버레이).

## 마을 시설

| 시설 | 기능 |
|---|---|
| **상점** | gold로 무기 / 방어구 / 포션 / 두루마리 / 책 구매 |
| **창고** | 인벤 ↔ 창고 양방향. 골드 보관. 영구 |
| **동료 길드** | gold + essence shard로 영구 동료 채용. 종족/직업 선택 가능 |
| **던전 선택** | BRANCH_TILESETS 8종을 잠금 트리로 노출 |
| **상태** | 플레이어 + 동료들 스탯 / 장비 / 스킬 확인 |

## 동료 데이터

```gdscript
# Companion (기존 파일 확장)
@export var race_id: String       # human / hill_orc / ... — RaceData 로드
@export var job_id: String        # fighter / wizard / ... — JobData 로드
var stats: Stats                  # 플레이어와 동일 Stats 클래스
var skill_state: Dictionary       # SkillSystem.init_for_player 결과
var equipped_weapon_id: String
var equipped_armor: Dictionary    # 슬롯 매핑
var learned_spells: Array[String]
var lifetime: int = 0             # 0 = 영구 (마을 채용), > 0 = essence 소환

# 사망 시 마을 길드에서 빠짐. 영구 사망. 부활 없음.
```

## 동료 채용 흐름

1. 마을 → 길드 진입
2. 후보 동료 3~5명 표시 (랜덤 종족 + 직업 + 시작 장비)
3. 골드 + essence shard 비용 (강한 직업일수록 비쌈)
4. 채용 → `GameManager.hired_companions` 배열에 추가
5. 던전 진입 시 자동 소환 (시작 위치 플레이어 인접)
6. 던전 내 사망 시 → 영구 제거, 메시지 표시

## 던전 선택 (BRANCH_TILESETS 활용)

| Branch | Depth | 잠금 조건 |
|---|---|---|
| main (crypt) | D:1-5 | 시작부터 |
| mine | D:6-10 | clear D:5 |
| forest | D:11-15 | clear D:10 |
| swamp | D:16-20 | clear D:15 |
| volcano | D:21-25 | clear D:20 |
| crystal / sandstone | 보너스 브랜치 | TBD |

## Run 종료 처리

- **클리어** (D:25 보스 처치) → 마을 복귀, 보상, 메타 progression
- **사망** → 모든 인벤토리 / 골드 소실. 창고 + 길드 동료는 유지. 마을로 복귀
  - PROJ_B의 "제자 계승" 메커니즘은 채용하지 않음 (단순화)

## TODO 순서

1. 던전 시스템 마무리 (현재 작업 중)
2. Companion 클래스 확장: 종족/직업/스탯/스킬/장비 통합
3. 마을 씬 + UI 인프라
4. 4개 시설 구현 (상점은 ItemRegistry 재활용)
5. 동료 채용 + 자동 소환
6. 사망/클리어 흐름 연결
