---
name: PocketCrawl pending backlog
description: Next-session task list — bugs, features, and major design work confirmed by user
type: project
originSessionId: cbad590a-8beb-4eb1-bd29-f361f6be2fd2
---
## 대규모 작업 완료 이력

### Zone & Monster Expansion ✅ DONE (main에 머지)
- 8존×3층+보스, 38몬스터, CA맵, 환경피해, EssenceSystem poison/neg

### 이전 세션 완료 ✅ (2026-04-24)
- 스킬, 마법, 종족 패시브, 직업 선택, 에센스, Bestiary 등 다수

### 이번 세션 완료 ✅ (2026-04-25)

#### 마법 시스템
- **아머 마법 패널티**: 로브=×1.0, 가죽=×0.85, 체인=×0.65, 기타=×0.5
  - MagicSystem._armor_spell_mult() + MagicDialog stat line에 ⚠-X% 표시
- **스킬 기반 마법 게이팅**: xl_required → spell_level ≤ 학파스킬로 변경
  - MagicDialog locked 조건, MagicSystem cast 체크 모두 반영
  - 잠금 메시지: "Evocation skill 3 required"
- **Fog Cloud 구현**: DungeonMap.fog_tiles, add_fog(), tick_fog(), is_opaque() 연동
  - 반경 3칸, 8턴 지속, 파란 반투명 오버레이, 층 이동 시 초기화
  - Game.gd _on_player_turn_started에서 tick_fog() 매 턴 호출

#### 밸런스 리워크
- **플레이어 기본 HP**: 30 → 22, 레벨업 HP 5+str/5 → 3+str/5
- **몬스터 데미지 공식**: randi(1, base) → randi(base×0.6, base×1.5) (최솟값 대폭 상승)
- **대기 HP 회복 제거** → 부상 시스템으로 대체
- **스킬 XP 임계값**: ×0.65 (35% 감소, 레벨업 빠르게)
- **층 아이템 드롭**: 4~8개 → 2~4개
- **아크메이지 시작 아이템**: 22개 → 3개 (healing, magic potion, identify scroll)
- **회복 포션**: 10 → 15 HP (포션이 더 소중해짐)

#### 부상(Injury) 시스템
- `player.injury: int` — 피해 받을 때 ceil(damage/2) 누적
- 대기 회복: `hp_max - injury`까지만 회복 (injury 쌓이면 대기 회복 상한 낮아짐)
- `heal()` (포션): injury도 같이 제거 + HP를 hp_max까지 회복 가능
- `heal_injury()` (붕대): injury만 제거, cleared/2만큼 HP 소폭 회복
- HP 바 표시: injury 있으면 `HP 15/22 ⚕-8` 형태
- SaveManager/Game.gd 저장·로드 연동
- **붕대 아이템** 신규 추가 (`bandage.tres`, effect="bandage", value=10)
  - ItemRegistry 등록, 층 드롭 풀 포함

#### balance JSON 업데이트
- config/balance/spells.json: power_formula, armor_spell_penalty, magic_missile 수치
- config/balance/core_rules.json: armor_magic_interaction 규칙
- config/balance/player_stats.json: base_hp 22, hp_regen wait=0

---

## 미완료 / 다음 작업

### 즉시 처리 필요
- **Bestiary 버튼 연결**: BottomHUD .tscn 씬에서 _on_bestiary_pressed 버튼 wiring (에디터 작업)
- **Reach 시스템**: Spearman 직업 있지만 polearm 2칸 공격 로직 미구현
- **Ranger 무기**: 현재 mace 임시 — short_bow 아이템 없음

### 설계 논의 중
- **디아블로식 affix 아이템**: 노말/매직/레어 등급, 랜덤 접두·접미사
- **마을 시스템**: 상점 + 동료 영입

### 기존 버그 (대기)
1. 몬스터 공격 속도 — MonsterAI.gd, TurnManager.gd
2. 아이스 마법책 읽기 불가 — Player.gd, ItemRegistry.gd
3. 계단 올라가기 불가 + 층간 상태 유지 — Game.gd, GameManager.gd
4. 미감정 포션/스크롤 시스템
5. 밝힌 맵 터치로 멀리 이동 (auto-walk)
