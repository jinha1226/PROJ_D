# Phase 1 Critical Fixes — Smoke Verification Checklist

작성: 2026-05-06 (Phase 1 commit 직후)
대상 commit: Phase 1 Critical (C1/C2/C3/C4)
사전 조건: 구 클래스 ID와 호환되지 않으므로 기존 `user://save.json` wipe 권장.

## A. C1 — 저장/재개 라운드트립

- [ ] 새 게임 시작 (melee/magic/ranged 중 하나)
- [ ] 1F에서 몬스터 1~2 처치 + 아이템 1~2 줍기
- [ ] 메뉴 → **Save & Main Menu**
- [ ] 메인 메뉴 → Continue
- [ ] **검증**: 죽인 몬스터 부활 X, 시체 위치/그래픽 보존, 드랍 아이템 보존, 안개·해저드 보존
- [ ] 같은 흐름을 가지 1F에서도 재현 (가지 진입 → 몬스터 1 죽이고 → Save & Main Menu → Continue)

## B. C2 — 어픽스 영구 잔존 (이미 수정됨, regression check)

- [ ] +HP / +slay 또는 +resist 가진 randart armor 장착 → Status 화면 수치 확인
- [ ] armor 버리기 → Status 수치 base로 복귀
- [ ] 같은 armor 재줍기·재장착·재버리기 3사이클 → 매번 수치 base로 정확히 복귀
- [ ] shield, weapon, ring, amulet 슬롯 동일 시나리오 (각 1회씩)

## C. C3 — 저항 누수 (Dict 모델로 교체)

- [ ] 시작 종족별 Status 화면 저항 카드 표시 확인:
  - [ ] troll: fire 카드 vulnerability(-) 표시
  - [ ] vampire: neg(necro?) 카드 + 표시
  - [ ] kobold/dwarf/gargoyle: poison 카드 + 표시
- [ ] resist_fire affix randart armor 장착 → fire 카드 +1 → 버리기 → 0 → 재장착 3사이클 후에도 0/+1 정확히 토글
- [ ] essence_serpent 장착·해제·재장착 → poison 카드 토글 정확
- [ ] **legacy save 마이그레이션**: 변경 전 세이브 있으면 로드해서 종족 저항 보존되는지 (없으면 skip)
- [ ] swamp 가지 1F: poison+ 종족이면 환경 데미지 차단, 일반 종족이면 데미지 발생

## D. C4 — 가지 몬스터/아이템 누수

- [ ] depth 4-7 가지 입구 진입 → 가지 1F에서 몬스터 1~2 살려둔 채 위로 이탈
- [ ] **검증**: 메인 던전 복귀 시 가지 몬스터(swamp의 frog/snake 등) 잔존 X
- [ ] 가지 재입장 → 살려둔 몬스터·아이템 그대로 (cache 정상 재구성)
- [ ] 가지 보스 처치 → 메인 던전 복귀 → 메인 던전 상태 정상

## E. 통합 회귀 — 비교적 깊은 흐름

- [ ] 1층 → 가지 진입 → 보스 처치 → 메인 복귀 → 신전(B3) 진입 → faith 선택 → 그 후 깊이 진행
- [ ] 위 전 과정에서 어느 시점이든 메뉴 Save → Continue 했을 때 진행 보존

---

## 결과 기록

| 섹션 | 통과 여부 | 메모 |
|---|---|---|
| A (C1) | ☐ | |
| B (C2) | ☐ | |
| C (C3) | ☐ | |
| D (C4) | ☐ | |
| E (통합) | ☐ | |

실패 항목 발견 시 `docs/audits/`에 회귀 리포트로 별도 정리.
