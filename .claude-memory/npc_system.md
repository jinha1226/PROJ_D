---
name: npc-system
description: "GOAP-driven NPC social system architecture, file map, known issues fixed, and next steps. Built 2026-05-22."
metadata: 
  node_type: memory
  type: project
  originSessionId: a7f5068a-779e-4b8a-9451-ffee6962834a
---

## 구현 완료 (2026-05-22, commits ee3466cf → b9193aa7)

### 전제 조건
- `scripts/entities/Actor.gd` — Player.gd 리팩토링 에이전트가 ~400줄 추출. 스탯/스킬/장비 변수 + 순수 로직. `NPCActor extends Actor`의 기반.

### 파일 맵

```
scripts/npc/
  NPCActor.gd          — extends Actor. TurnManager 인터페이스(pending_energy+take_turn),
                         FOV 인식(_update_perception), GOAP 루프, relations dict
  GOAPPlanner.gd        — static A* 플래너. world_state + goal → Array[NPCAction]
  NPCAction.gd          — base 액션 (preconditions/effects/cost/execute)
  NPCGoalSelector.gd    — utility 목표 선택 (생존/공격/동맹/아이템)
  NPCInfoDialog.gd      — 탭 시 GameDialog 팝업 (HP바 + 장비 목록 + Attack 버튼)
  ExplorerNPC.gd        — extends NPCActor. 황금색 "@" 글리프, HP 25, str 10, dex 12
  actions/
    NpcActionMoveToward.gd
    NpcActionMoveToLoot.gd
    NpcActionAttack.gd
    NpcActionFlee.gd
    NpcActionPickupItem.gd
    NpcActionProposePeace.gd
    NpcActionWait.gd
```

### 스폰 흐름
- `SpawnService._spawn_npcs_layer()` — Game.gd 초기화 시 NPC 컨테이너 레이어 생성
- `SpawnService._spawn_npcs_for_floor(10)` — `FloorLifecycle._generate_floor()` 내부, `_spawn_monsters_for_floor()` 직후 호출. depth < 1 또는 branch_zone != "" 이면 스킵
- 사망: `_on_npc_died()` → TurnManager.unregister → fade-out → queue_free
- 층 전환: `_clear_npcs()` — `_clear_floor_items()` 호출마다 같이 호출됨 (7곳)

### GOAP 월드 스테이트 키
```
has_enemy_in_sight, adjacent_to_enemy, enemy_is_dead,
hp_critical, has_loot_nearby, at_loot_pos, loot_collected,
has_potential_ally, ally_proposed, enemy_is_strong
```

### 소셜 관계 시스템
- `relations: Dictionary` — {instance_id: {trust, threat, loot_value}}
- trust > 0 = 동맹, trust < -0.3 = 적으로 인식
- 플레이어가 NPC 공격 시: `npc.set_relation(player, -1.0, 0.8)` → 다음 턴 반격

### 플레이어 ↔ NPC 전투
- 탭 → 정보창 (거리 무관)
- 인접 시 정보창에 "Attack" 버튼 표시
- 공격 공식: `randi_range(1, 4 + wpn_skill) + slay_bonus - ac/4` (CombatSystem 미통합)
- NPC가 플레이어 공격 시: Monster처럼 `take_damage(dmg)` 호출 (1인자 버전)

### 수정된 버그들
1. `Actor.compute_fov` 람다에 `in_bounds` 체크 추가 — 맵 가장자리 NPC의 tile_at OOB 크래시
2. `EssenceSystem.tick(self)` Player 타입 가드 — NPCActor에 tick 호출 시 타입 에러
3. `_spawn_npcs_for_floor` → `_generate_floor` 내부로 이동 — 빈 tiles 배열 접근 크래시
4. 이동 액션 `_is_pos_occupied()` 체크 — 몬스터/플레이어/NPC 위 이동 방지
5. `sign()` / `max()` / `Vector2i.sign()` 결과 Variant 추론 경고 → 명시 타입 선언
6. `Monster.take_damage()` 1인자 서명 맞춤

### 버그 수정 (2026-05-22)

**버그 1 (움직임 없음) 원인**: `NPCGoalSelector.select_goal()`이 적/루트 없으면 `{}` 반환 → wander 행동 없음.
**수정**: `NPCActor.take_turn()` — `goal.is_empty()` 시 `_wander()` 호출. `_wander()`는 33% 확률로 랜덤 인접 타일로 이동.

**버그 2 (반격 없음) 원인**: `_update_perception()`에서 `if _known_enemy == null:` 가드 때문에 FOV 안에 몬스터가 있으면 플레이어가 공격해도 `_known_enemy`가 플레이어로 교체되지 않음.
**수정**: 해당 가드 제거. 적대 플레이어(trust < -0.3)는 항상 `_known_enemy`를 덮어씀.

### 알려진 미구현/한계
- NPC 전투가 CombatSystem 미통합 (간단한 주사위 공식 사용)
- `NpcActionPickupItem`의 item_picked_up 시그널 Game.gd에서 미연결 (아이템 노드 제거 안 됨)
- ExplorerNPC 시작 장비 없음 → 정보창 "No equipment"
- 층 재방문 시 NPC 리스폰 없음 (층 전환마다 10명 새로 스폰만 됨)
- NPC가 계단을 인식하지 못함 (map 탐험 목표 없음)

### 다음 확장 포인트
- `ExplorerNPC._ready()`에 `equipped_weapon_id = "dagger"` 등 스타터 장비 세팅
- `goal_selector` 교체로 NPC 성격 차별화 (겁쟁이/공격적/탐욕스러운)
- CombatSystem에 actor-vs-actor 경로 추가 후 NpcActionAttack 교체
- MageNPC / ThiefNPC 등 concrete 타입 추가

**Why:** 독립적인 `scripts/npc/` 디렉토리로 Player.gd 리팩토링과 완전 분리. Actor 추출로 스탯/스킬/장비를 공유.
**How to apply:** 새 세션에서 NPC 관련 작업 시 이 파일 먼저 확인.
