# Monster AI Improvement — Design Spec
> 2026-04-30

## 목표

MonsterAI에 세 가지 행동 패턴 추가:
1. **Kiting** — 원거리 유닛이 preferred_range(3)를 유지하며 조금씩 후퇴
2. **Healer** — 지원 캐스터가 부상 아군을 우선 치유
3. **Summoner** — 전투 시작 1회 소환

## 스키마 변경

### MonsterData.gd
```gdscript
@export var ai_flags: Array = []     # ["kite", "healer", "summoner"]
@export var summon_pool: Array = []  # summoner 전용: ["orc", "orc_warrior"]
```

## 행동 설계

### kite
- `dist < 3` → `_kite_step()` 으로 거리 1 증가하는 방향 탐색
- 후퇴 가능하면 이동. preferred_range(3) 이상이면 이동 안 함
- 막혀서 후퇴 불가 → 원거리 공격 시도 → 실패 시 근접전
- take_turn()에서 `dist > 1` 분기 앞에 삽입 (원거리 공격 전에 먼저 체크)

### healer
- take_turn() 최초에 반경 6 내 비아군 몬스터 중 HP < 50% 탐색
- 대상 있으면 `target.hp += min(target.data.hp - target.hp, monster.data.hd * 3)` 후 턴 종료
- 대상 없으면 기존 AI 그대로

### summoner
- Monster에 `_summoned_once: bool = false` 플래그 추가
- 플레이어 감지 후 `_summoned_once == false` 일 때 1회 발동
- `summon_pool`에서 랜덤 1~2마리를 인접 빈 타일에 스폰
- Game.gd에 `spawn_monster_at(id, pos)` 함수 추가

## 적용 몬스터 (ai_flags + summon_pool)

| 몬스터 | ai_flags | summon_pool |
|--------|----------|-------------|
| deep_elf_archer | ["kite"] | — |
| centaur | ["kite"] | — |
| orc_priest | ["healer", "summoner"] | ["orc"] |
| gnoll_shaman | ["healer", "summoner"] | ["gnoll"] |
| gnoll_sergeant | ["healer"] | — |
| deep_elf_death_mage | ["summoner"] | ["zombie", "crypt_zombie"] |

## 구현 파일

1. `scripts/entities/MonsterData.gd` — ai_flags, summon_pool 필드 추가
2. `scripts/entities/Monster.gd` — _summoned_once 플래그 추가
3. `scripts/systems/MonsterAI.gd` — _kite_step(), healer 분기, summoner 분기
4. `scripts/main/Game.gd` — spawn_monster_at() 함수 추가
5. `resources/monsters/*.tres` — 해당 6개 몬스터에 ai_flags/summon_pool 추가
