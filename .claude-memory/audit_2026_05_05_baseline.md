---
name: PocketCrawl 2026-05-05 codebase audit baseline
description: Full-codebase audit found 4 Critical / 9 High / 11 Medium / 5 Low issues. Read before picking next task — Phase 1 Critical bugs override prior backlog priorities. Full report in docs/audits/.
type: project
---

## 요약

2026-05-05 세션에서 PROJ_D 전체 감사 수행. **현 상태로 출시 시 플레이어 진행 누적 손상 거의 확정.** 시체 렌더링 버그는 빙산의 일각이었고, save 누수·스탯 영구 누수·전투 결과 좌우 버그 다수.

전체 리포트: `D:/PROJ_D/docs/audits/2026-05-05-codebase-audit.md`

## Critical 4건 (출시 차단)

- **C1**: `SaveManager.save_run`이 GameManager의 가지/층 캐시·맵 동적 상태(신단·시체·구름·몬스터·아이템) 전혀 직렬화 안 함. 모바일 백그라운드→복귀 시 진행 손실. 위치: `scripts/core/SaveManager.gd:34-80`
- **C2**: `Player.drop_item` 의 armor 분기가 `set_equipped_armor("")` 안 부르고 직접 대입 → randart 어픽스 보너스 영구 잔존. weapon/ring/amulet은 정상, armor·shield만 비대칭. 위치: `Player.gd:547-565, 1132-1135`
- **C3**: `_apply_resist_mod` 의 +/- 분기가 동일 동작 → rFire+++ 가 +1, equip/unequip 반복 시 마이너스 저항 누적. 위치: `Player.gd:1274-1281`
- **C4**: 가지(branch) 1층에서 위로 빠져나갈 때 `_clear_monsters()` 안 부름 → 가지 몬스터 메인 던전에 누수. 위치: `Game.gd:1741-1761`

## High 9건 (요약)

- **H1**: 다수 스크롤/완드(scroll_fear/fog/silence/immolation 폴백, wand_fear/digging) 가 stub 호출만 하고 효과 없음 — 자동 식별까지 진행. `Player.gd:386-440, 458-466`
- **H2**: Faith 데이터 8개 키가 코드에서 미참조 (war 신앙의 +20% 방어/+8% 차단 등 광고와 실제 불일치). `FaithSystem.gd:5-67`
- **H3**: 인벤토리 탭 필터에 shield/wand/throwing/essence 누락 — 사용자가 "아이템창 문제"로 호소한 직접 원인. `BagDialog.gd:69-71`
- **H4**: ItemDetailDialog의 `item_index` closure가 stale — 사용 시 잘못된 아이템 처리 위험. `ItemDetailDialog.gd:291-407`
- **H5**: 스펠 데미지 로그가 raw 값, 실 적용은 저항 후 scaled 값 → 12 떴는데 6 깎이는 식. `MagicSystem.gd:368-388`
- **H6**: `static var X = Engine.get_main_loop()...get_node_or_null(/root/X)` 패턴 19개 파일. autoload 섀도잉, SimulationBot은 깨져있음. autoload 이름은 GDScript 4에서 자동 글로벌이라 redundant.
- **H7**: 데미지 파이프라인의 곱셈/덧셈 보너스 한 곳에 누적 — backstab이 곱셈 의도였는지 덧셈 의도였는지 불명. `CombatSystem.gd:111-123`
- **H8**: 플레이어 사망 후에도 `actors.duplicate()` 루프가 계속 → 죽은 뒤 데미지 로그 추가 출력. `TurnManager.gd:22-44`
- **H9**: 몬스터 awareness/last_known_player_pos 가 cache 직렬화 안 됨 → 도망쳤다 돌아오면 backstab 무한 익스플로잇. `Game.gd:1078-1089`

## 꼬임의 패턴 7가지 (반복 부채)

1. **Game.gd 3112줄 god-object** — 클래스 적용·세이브 마이그레이션·시체 매핑·가지 관리·HUD·시각효과 다 한 곳에
2. **5 슬롯 중 armor/shield만 affix 해제 비대칭** ← C2의 뿌리
3. **데이터 정의됐는데 안 읽는 키들** (Faith 8개, ItemData encumbrance) ← H2의 뿌리
4. **save 스키마가 Player만 보고 GameManager/map 누락** ← C1·H9의 뿌리
5. **UI가 시스템 상태 직접 변형 + TurnManager 직접 호출** (CLAUDE.md 위반)
6. **로그/효과 시점 vs 실 적용 시점 불일치** ← H5
7. **`static var = get_node_or_null` 19개 파일 redundant 패턴** ← H6

## 권장 작업 순서

```
Phase 0 — 시체 시스템 정리 (이미 진단 완료)
  - oldproject/...UNUSED/ 의존 제거 (CC0 라이선스 문제는 없으나 GPL 트리에서 분리)
  - _corpse_shape_for_monster 폴백 humanoid_medium → null + 글리프 폴백
  - (선택) CorpseService 추출

Phase 1 — Critical 4건 (출시 절대 차단)
  C1 → C2 → C3 → C4

Phase 2 — 사용자 통증 직접 해소
  H3 (인벤토리 탭) → H4 (item_index) → H5 (로그 정렬)

Phase 3 — 기능 정상화
  H1 (AOE stub) → H2 (Faith dead data) → H9 (awareness 직렬화)

Phase 4 — 구조 부채 (출시 후도 가능)
  Game.gd 분해 / CorpseService / UI→시스템 정리
```

## 백로그_pocketcrawl.md 와의 관계

`backlog_pocketcrawl.md` 는 2026-04-27 시점의 백로그. 오늘 감사 결과의 Critical/High 가 *그 백로그보다 우선*. 새 작업 진입 전:
1. Phase 0 → 1 우선
2. 기존 backlog는 Phase 4 이후 또는 병행 진행
3. balance 핸드오프(`docs/balance/claude_code_*_handoff.md`)는 여전히 밸런스 작업 시 authoritative

## How to apply

새 세션이 작업 시작 전에:
- 이 메모리 + `pocketcrawl_state.md` 둘 다 먼저 읽기
- `backlog_pocketcrawl.md` 헤더의 "감사 우선" 노트 확인
- 풀 리포트 필요 시 `docs/audits/2026-05-05-codebase-audit.md`
- Phase 0/1 미완료 상태에서 Phase 4 구조 작업으로 점프 금지 — Critical 회귀 위험
