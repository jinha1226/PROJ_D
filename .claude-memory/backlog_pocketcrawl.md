---
name: PocketCrawl pending backlog
description: Next-session task list — bugs and features confirmed by user, prioritized
type: project
originSessionId: 4ef3547a-3218-4269-9499-1aa01792eeef
---
작업 대기 항목 (우선순위 순):

## 버그 수정

### 1. 몬스터 공격 속도
- 증상: 적이 플레이어보다 공격을 훨씬 덜 함
- 확인 필요: TurnManager.end_player_turn() → actors 순회 구조는 정상으로 보임
- 확인 포인트: MonsterAI._random_step()에 randf()>0.5 스킵 있음 (시야 밖 한정), 시야 내 몬스터가 공격 안 하는 경우 다른 원인 있을 수 있음
- 파일: scripts/systems/MonsterAI.gd, scripts/core/TurnManager.gd

### 2. 아이스 마법책(스크롤) 읽기 불가
- 증상: 아이스 마법책을 주웠지만 사용(읽기)이 안 됨
- 확인 필요: ItemData.kind 값, Player.use_item() 로직, 아이템 레지스트리의 spellbook kind 처리
- 파일: scripts/entities/Player.gd (use_item), scripts/systems/ItemRegistry.gd, 관련 .tres 아이템 리소스

### 4. 계단 올라가기 불가 + 층간 상태 유지
- 증상: 계단 내려가기는 되지만 올라가기 안 됨
- 원하는 동작: 계단 오르내려도 이미 탐색한 층의 몬스터/아이템/맵 상태가 유지됨
- 구현 방향: GameManager에 per-floor 상태 저장 (explored dict, monster list, item list), 층 이동 시 저장/복원
- 파일: scripts/main/Game.gd (_generate_floor, stairs 처리), scripts/core/GameManager.gd

## 신규 기능

### 3. 미감정 포션/스크롤 시스템
- 동작: 줍는 순간 "알 수 없는 포션 A" / "알 수 없는 스크롤 B" 형태로 저장
- 식별 스크롤 사용 시 해당 턴 인벤토리의 아이템 선택 후 식별
- UI: 미감정 상태엔 기본 아이콘/이름, 식별 후엔 실제 이름이 오른쪽 하단에 표기
- 구현 포인트: GameManager.identified_items: Dictionary 전역 관리, ItemData에 unidentified_name 필드 추가, BagDialog에 미감정 표시 처리

### 5 (원래 3). 밝힌 맵 터치로 멀리 이동 (auto-walk)
- 동작: 이미 explored된 타일을 탭하면 플레이어가 자동으로 경로를 따라 이동
- 중단 조건: 몬스터 시야에 들어오면 중단
- 구현 방향: A* 또는 BFS pathfinding, _handle_tap()에서 멀리 있는 explored 타일 탭 감지 → auto-walk 루프 시작
- 파일: scripts/main/Game.gd (_handle_tap, 새 _auto_walk 로직)

**Why:** 사용자가 다음 세션에서 이어서 작업할 수 있도록 컨텍스트 보존
**How to apply:** 세션 시작 시 이 메모리 확인 후 바로 구현 시작
