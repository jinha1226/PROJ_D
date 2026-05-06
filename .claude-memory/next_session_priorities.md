---
name: Next session priorities (post 2026-05-05 curation)
description: Roadmap for the next PROJ_D sessions after the 2026-05-05 environment curation. Read alongside audit_2026_05_05_baseline.md.
type: project
originSessionId: cfaf6ab0-f8e3-4cfe-9656-25c538ea3e05
---
## 컨텍스트

2026-05-05 PROJ_SS 세션에서 환경 큐레이션 완료. PROJ_D는 깨끗한 baseline(새 CLAUDE.md, 모듈 CLAUDE.md 5개, 감사 리포트, 갱신된 refactoring_todo.md)에서 출발할 수 있는 상태. 같은 날 다른 창에서 Phase 0(시체 시스템)도 완료됨 — `tile::corpsify` GDScript 포팅 + 핏자국 합성. audit L1도 부수적으로 해결.

## 다음 세션 진입 순서

### 1. Phase 1 ✅ 완료 (2026-05-06, commit e476e94f)

C1/C2/C3/C4 코드 fix 완료. 스모크 검증만 남음 — `docs/checklists/phase1_smoke_verification.md`.
검증 실패 시 회귀 fix 우선, 통과 시 Phase 2 진입.

세션 발견: C2는 prior commit b31ec598 시점에 이미 fix되어 있었고 audit 문서·메모리가 stale였음.
교훈: audit 항목 진입 전 **실제 코드부터 확인** (CLAUDE.md "behavior contradicts docs → read code first").

C3 구현 결정: `Player.resists`를 Array[tag]에서 **Dictionary[element → int]** 로 전환.
이전 stack-tag 모델은 EssenceSystem의 set-semantics(.has/.append/.erase)와 affix의 stack-semantics가 충돌.
Dict 모델이 단일 진실 소스 — 다음 세션에서 다시 Array로 되돌리지 말 것.

### 3. Phase 3 ✅ 완료 (2026-05-06, commit f0d28fc4)

- **H1**: 이전 세션에서 이미 closed (`AoeEffects.gd` 5 helper)
- **H2**: Faith 8 dead 키 + shield_block_bonus getter 제거. desc는 flavor 그대로 유지
- **H6**: `static var X = Engine.get_main_loop()...get_node_or_null` 패턴 14 파일 일괄 제거. ItemRegistry/ShrineDialog 인라인 케이스도 autoload 식별자로 교체
- **H7**: CombatSystem 데미지 파이프라인 재정리 — base → flat → mult → brand. skill flats/race/backstab가 mult chain 통과 → 고스킬에서 ~36% 데미지 상승. **밸런스 검증 필요**
- **H8**: TurnManager `_abort_actor_loop` 플래그, `Game._on_player_died`에서 set
- **H9**: 이미 closed (awareness 5필드 cache+restore)

세션 학습: audit 문서가 5건(C2/H4/H1/H9, getter 일부) stale 였음. 다음 세션은 audit 항목 진입 전 *코드 grep으로 실재 여부 먼저 확인*. CLAUDE.md 의 "behavior contradicts docs → read code first" 원칙 적용.

### 2. Phase 2 ✅ 완료 (2026-05-06, commit 99d2f4a2)

- H3 BagDialog 탭 필터: 6개 탭 + `__other__` catch-all (미래 kind 자동 처리)
- H4 ItemDetailDialog: 이전 commit e911eecb에서 이미 closed (entry-based)
- H5 `_damage_auto_target` 로그 raw→scaled 정정

다른 스펠 경로(drain/multi-darts/lightning/AOE)는 이미 scaled 로그였음.

### 3. 추가 감사 한 사이클 (Phase 1 끝나면 권장)

상업 출시 전 반드시:

- **모바일 성능 감사** — 프레임 타임, GC, 텍스처 메모리, 배터리. `_draw()` 외 hot path. import 설정.
- **UX/터치 감사** — 탭 타겟 크기(48dp+), 제스처 충돌, 한 손 조작, safe area, 가로/세로.
- **자산 라이선스 100% 검증** — 모든 `assets/**/*.png + 폰트 + 사운드`의 출처·라이선스 매핑. 특히 `oldproject/Universal-LPC-Spritesheet-Character-Generator/`는 CC-BY-SA 3.0 / GPL 3.0이고 CC0 아님 — 사용 중이면 share-alike 의무 발생.
- **Android 출시 준비** — target API, 권한 vs 실제, 64-bit, Play Console 정책 (광고/IAP 모델에 따라), privacy policy 필요 여부.

여유 있을 때:

- **밸런스 감사** — 약속(handoff 문서) ↔ 실제 데이터 ↔ 코드 적용 site 3자 cross-check. DCSS 원본 비교 (`oldproject/crawl/`). 사실상 안 쓰이는 콘텐츠 식별. SimulationBot 살리거나 새 sim 만들어 DPS/EHP/TtK 곡선.
- **데이터 ↔ 코드 일관성 감사 (B 트랙)** — 클래스 default actives, faith dead 키, wand quickslot, AOE stub, monster ai_flags, race aptitudes, item brand wire-up 등 cross-check. 추가로 ⓐ **각 스펠이 자기 타일/아이콘과 정확히 연결**되어 있는지 (`SpellData.tile_path` ↔ 실 파일 + UI 표시), ⓑ **스펠 효과가 description/help 텍스트 그대로 적용**되는지 (description 파싱 vs MagicSystem 분기 일치). 결과는 `docs/audits/2026-05-??-data-consistency.md` 별도 보존.
- **온보딩/학습곡선 감사** — 신규 유저 첫 30분 흐름, 툴팁 커버리지, 정보 과부하 지점.
- **크래시 내구성 감사** — null deref site, 누락 자산 fallback 일관성, 비정상 save 처리, 백그라운드 강제종료.

### 3.5. UI 폰트/레이아웃 개선 (사용자 명시 요청 2026-05-05)

사용자가 특히 개선 원함: **인벤토리(BagDialog), 스킬창(SkillsDialog), 상태창(StatusDialog)**, 그 외 dialog 일관성. 폰트 사이즈와 UI 구성을 모바일에 적절하게.

#### 감사 관점

- **폰트 사이즈** — Godot Theme 단일 소스로 관리되는지, 하드코딩된 `add_theme_font_size_override` 산재 여부. 모바일 가독성 기준(본문 16~18px, 제목 20~24px, 캡션 12~14px) 충족 여부. 한국어 폰트 렌더링 품질 (작은 사이즈에서 깨짐 여부)
- **탭 타겟 크기** — Android 권장 48dp 이상. 인벤토리 셀, 스킬 행, 액션 버튼 실측. 손가락으로 못 누르는 작은 버튼 식별
- **정보 위계** — 한 화면에 너무 많은 정보 vs 핵심 정보 강조. 폰트 weight/size/color로 위계 구분되어 있는지
- **일관성** — BagDialog · SkillsDialog · StatusDialog · MagicDialog · BestiaryDialog 사이의 헤더·여백·버튼 스타일 통일. 다이얼로그마다 패딩이 다른 문제
- **밀도/공백** — 모바일 작은 화면에 너무 빽빽하거나(피로) 너무 비어있는(스크롤 강제) 지점
- **한 손 조작** — 핵심 액션이 화면 위쪽 80% 영역에 있으면 두 손 강제 (오른손잡이 기준 우측 하단이 제일 닿기 좋음)
- **스크롤 vs 페이징** — 긴 리스트(인벤토리, 스킬)에서 어느 패턴이 일관되게 쓰이는지
- **색상 대비** — 배경 vs 텍스트 WCAG AA 기준 (4.5:1) 만족 여부, 색맹 안전성
- **모달 vs 비모달** — 다이얼로그가 핵심 정보 가리는지, 닫기/돌아가기 동선

#### 작업 단계 제안

1. **현재 상태 측정** — 5개 주요 다이얼로그 스크린샷 + 폰트/패딩/탭 타겟 측정. 일관성 매트릭스 작성
2. **Theme 단일화** — `assets/theme.tres` 또는 동등한 단일 Theme 리소스로 폰트 사이즈/색상/패딩 일괄 관리. 하드코딩 override 제거
3. **위계 재정립** — 각 다이얼로그에서 "유저가 첫 시선으로 봐야 할 것"을 정의하고 그 기준으로 폰트/색 재배치
4. **탭 타겟 정비** — 작은 버튼/셀 48dp+ 보장
5. **per-dialog 디테일** — Bag/Skills/Status 각각의 고유 문제 (예: 오늘 audit H3 — Bag 탭 필터 누락)와 같이 처리

#### 관련 파일

- `scripts/ui/BagDialog.gd`, `scenes/ui/BagDialog.tscn`
- `scripts/ui/SkillsDialog.gd`, `scenes/ui/SkillsDialog.tscn`
- `scripts/ui/StatusDialog.gd`, `scenes/ui/StatusDialog.tscn`
- `scripts/ui/MagicDialog.gd`, `BestiaryDialog.gd`, `ItemDetailDialog.gd` 등
- 공통 다이얼로그 베이스 (`GameDialog` 류) 위치 확인
- `assets/theme.tres` 또는 동등 Theme 리소스
- `docs/hud_mobile_layout.md` (이미 존재 — 먼저 읽고 합의된 가이드 있는지 확인)

#### Phase 2의 H3, H4와 병합 검토

H3 (Bag 탭 필터 누락), H4 (item_index stale)는 인벤토리 기능 버그. UI 개선과 같은 다이얼로그 건드리므로 함께 처리하면 효율적. 단, 기능 수정과 UI 재구성을 한 커밋에 섞지 말고 분리 (audit P1: refactor + 기능 변경 동시 금지 원칙).

권장 순서: H3/H4 기능 수정 → 단독 검증 → UI 재구성 별도 작업.

### 4. Phase 3 — 기능 정상화

H1 (AOE stub들 — `AoeEffects.gd` static helper) → H2 (Faith dead 8키 wire-up 또는 제거 + 텍스트 정렬) → H9 (monster awareness cache 직렬화) → H7/H8/H6.

### 5. Phase 4 — 구조 부채 (출시 후 또는 병행)

Game.gd 분해 (M1: FloorLifecycle / BranchManager / SaveMigration / EffectsLayer / MonsterFactory + 이미 식별된 CorpseService) — Phase 0에서 작성한 `_build_corpse_texture` + `_corpse_tex_cache`도 함께 CorpseService로 이전.

## How to apply

새 세션 시작 시:
1. CLAUDE.md → audit baseline 메모리 → 이 메모리 → `docs/refactoring_todo.md` Phase 1 위치 확인
2. F5 스모크: 시체 합성 정상 동작, 핏자국 위 어둡게 누운 몬스터 그래픽, 스파이더/스콜피온/곤충은 녹색 핏자국
3. C1부터 시작 — save 스키마는 단독 작업이라 다른 Critical과 분리
4. 단일 Critical 처리 → 검증 → 커밋 → 다음. Phase 1 다 묶어 한 PR로 가지 말 것

## 2026-05-05 추가 변경 (PROJ_SS 세션에서 직접 적용됨)

### Zone 타일 매칭 정비 (`ZoneManager.gd` + `DungeonMap.gd`)

**문제**: `DungeonMap.TERRAIN_BANDS` 가 depth 임계값 4단계로만 wall/floor 선택 → zone 정체성(lair/orc_mines/elven_halls)과 시각이 분리. 특히 elven_halls(10-12)가 *덩굴+핏자국 코블*(폐허 느낌)로 표시되어 정반대 분위기.

**수정**:
- `ZoneManager.MAIN_ZONES` 5개 zone 각각에 `wall`, `floor` 필드 추가 (zone-id 기반 단일 소스)
- `DungeonMap.TERRAIN_BANDS` 상수 제거 → `_FALLBACK_WALL`/`_FALLBACK_FLOOR` 단일 fallback
- `_load_atmosphere(depth)` 가 `ZoneManager.zone_for_depth(depth)`로 lookup
- B3 (depth 3) 마블/모자이크 신전 override는 유지
- Abyss exit_abyss 계단 override는 유지 (코드는 zone-id 한 번 비교로 단순화)

**적용된 타일**:
- dungeon (1-3): catacombs0 + dirt0 (변경 없음)
- lair (4-6): lair0 wall + lair0 floor (자연 동굴/야생)
- orc_mines (7-9): orc0 wall + orc0 floor (오크 광산)
- elven_halls (10-12): elf-stone0 + marble_floor1 (엘프 궁전)
- abyss (13-14): abyss/abyss0 + depthstone_floor0 (변경 없음, 단지 MAIN_ZONES로 통합)

**검증 필요 (다음 세션 F5 스모크)**:
- depth 4/7/10 진입 시 zone 전환이 시각적으로 명확한지
- B3 신전, abyss exit_abyss 그래픽 그대로인지
- 가지(swamp/ice_caves/infernal/crypt)는 영향 없음 (별도 코드 경로)

### 클래스 default actives + starter items 데이터화 (audit M3 부분 해결)

**문제**: `Game.gd._class_default_active_skills` / `_class_starter_items` 가 거대 match로 5개 클래스만 처리, 나머지 7개는 fallback `["blade"]` + 빈 인벤. fighter→fighting 누락(HP 성장 핵심 스킬 비활성).

**수정**:
- `ClassData.gd` 에 `default_active_skills: Array`, `starter_items: Array` 두 필드 추가
- 12개 `.tres` (warrior/berserker/crusher/spearman/archmage/conjurer/elementalist/enchanter/necromancer/summoner/rogue/ranger) 모두 적절한 값 채움. 모든 클래스에 `fighting` 포함
- `Game.gd` 두 함수를 데이터 우선 lookup으로 단순화 (거대 match 제거). 빈 데이터 폴백은 `["fighting"]`
- audit M3 부분 해결, audit L1처럼 추후 자동 정리될 부분도 줄어듦

### Rogue ↔ Ranger 차별화 (데이터만 수정)

**문제**: 둘 다 shortbow + leather_armor + agility/fighting/ranged 거의 동일. description은 rogue를 "trickster"라 부르지만 실제로는 약한 ranger.

**수정 (DCSS 모델 따라 패시브 없이 시작 패키지로 분리)**:

- **rogue**: 무기 dagger / skills agility 3 + blade 2 + tool 3 + fighting 1 / starter potion_healing + potion_invisible + scroll_blinking + scroll_shrouding → 잠입형 단도쟁이. invis/fog/blink로 unaware 상태 만든 뒤 기존 backstab 보너스 활용 (별도 패시브 없음 — DCSS 일관성)
- **ranger**: 무기 shortbow 유지 / skills ranged 4 + agility 2 + blade 1 + fighting 2 / starter dagger(백업) + potion_healing×2 + scroll_blinking → 카이팅 활쟁이

**검증 필요 (다음 세션 F5 스모크)**:
- 12개 클래스 모두 default active skills 올바르게 시작하는지 (특히 fighting 활성)
- 7개 클래스(berserker/crusher/spearman/conjurer/elementalist/enchanter/necromancer/summoner)가 이제 starter 아이템 받는지
- rogue 시작 시 단검 장착·invis/blink/shrouding 보유, ranger 시작 시 활 + 백업 단검 보유

## 2026-05-05 Skill+Class System 재설계 결정 (5+ 라운드 토론 종결)

### 비전 — PD 진입 친화 + DCSS 깊이
표면은 단순, 내면은 깊음. 입문 유저는 카테고리 5개만 보고 빌드 결정, 헤비 유저는 펼쳐서 ~30 sub-skill 미세 분배.

사용자 v1 디자인(5 카테고리 surface + DCSS 30 깊이) 의도가 v2 구현 단계에서 평탄화(16 flat)된 것을 *원래 비전으로 복원*.

### 스킬 시스템 — DCSS 풀복원, 계층 UI

```
Melee 카테고리:
  fighting, short_blades, long_blades, maces, axes, staves, polearms, unarmed
Ranged 카테고리:
  bows, crossbows, slings, throwing
Defense 카테고리:
  armour, dodging, stealth, shields
Magic 카테고리:
  spellcasting + 7 학파 (conjurations, hexes, charms, summonings, necromancy, translocations, transmutation)
  + 5 원소 (fire, ice, air, earth, poison)
Utility 카테고리:
  invocations, evocations
```

Total ~30 sub-skill. SkillsDialog 기본 카테고리 6줄 표시 + 펼치기로 sub-skill 표시.

작업 영향:
- `SkillRegistry` 30개 등록
- Race aptitude × 30 항목으로 확장 (DCSS 값 직접 참조 가능 — `oldproject/crawl/.../dat/species/`)
- 12 기존 클래스 `.tres` starting_skills 30 매핑 재구성
- SaveManager 30 스킬 직렬화 + 마이그레이션 (16 → 30 1:N 분배 룰 결정 필요)
- SkillsDialog UI 카테고리 그룹뷰 + 펼치기
- MagicSystem element-aware 데미지 계산
- ClassData에 `category: String` (skill category와 같은 6 값)

### 클래스 시스템 — 3 starter + advanced 풀

```
시작 노출 (default unlocked, 신규 .tres):
  Melee   ← 단순 검+사슬+버클러
  Magic   ← 단순 단검+로브+책 1
  Ranged  ← 단순 활+가죽+화살

Advanced 풀 (모두 is_starter=false, 카테고리 → 특화 2단계 선택):
  Melee:  warrior, berserker, crusher, spearman, +DCSS 추가 (gladiator 등 미래)
  Magic:  conjurer, fire_elementalist, ice_elementalist, air_elementalist, earth_elementalist,
          enchanter, necromancer, summoner, archmage(debug)
  Ranged: rogue (단검 잠입형 — 오늘 차별화 완료), ranger (활 카이팅형),
          +DCSS 추가 (assassin, brigand 미래)
  Other:  +DCSS 미래 추가 (wanderer, artificer 등)
```

기존 elementalist → 4 element 분리 (DCSS 충실). 각 starting_skills는 해당 element + spellcasting 강조.

ClassData 추가 필드:
- `category: String` (Melee/Magic/Ranged/Other)
- `is_starter: bool` (default unlocked 여부)

ClassSelect UI:
- starter 3개 큼직 그리드 기본
- 언락 클래스 있을 때 카테고리 탭 → 특화 그리드
- 카테고리 = 특화 클래스 = 새로 starter unlock한 캐릭터의 첫 진입 흐름

### 종족
- 현재 set 그대로
- aptitude 테이블만 30 항목으로 확장 (DCSS species 데이터 활용)

### 빌드 발견 — 초반 층 드랍 다양성

starter 3개는 단순 시드일 뿐. 1~3층에 *다양한 무기 종류 + 기본 스펠북 + 기본 도구* 드랍 → 플레이어가 시도하면서 자기 빌드 발견. *드랍 테이블 다양성 검증 필요* (별도 밸런스 트랙).

### 종결된 디자인 토론들

이번 세션에서 끝낸 것 — 다음 세션에서 *재토론 금지*:

- ✓ **elemental 단일 vs 분할** → fire/cold/air/earth/poison sub-skill로 자연 해결. 분할/hybrid/룬 등 모든 절충안 폐기
- ✓ **rogue ↔ ranger 차별화** → 데이터 분리 완료 (rogue=단검 잠입형, ranger=활 카이팅형)
- ✓ **class active skills + starter items** → ClassData 데이터화 완료 (12개 .tres 모두)
- ✓ **PD vs DCSS 피벗** → 계층화로 양쪽 다 잡음 (피벗 안 함)
- ✓ **패시브 vs 시작 패키지** → DCSS 모델 (시작 패키지로 정체성, 패시브는 berserker_regen 같은 예외만)
- ✓ **스킬 수 16 vs 5** → 표면 5/내면 30 계층으로 양쪽 만족

### 작업 순서 (의존성 정리)

```
1. Phase 1 Critical 4건 ★ 먼저
   특히 C1 save 스키마 — 어차피 변경하니 30 스킬 직렬화 함께 설계
2. 클래스 시스템 재구성 (간단)
   - 신규 starter .tres 3개 (Melee/Magic/Ranged)
   - 기존 12 .tres에 category + is_starter 필드 추가
   - elementalist → fire/ice/air/earth_elementalist 4분할
   - ClassSelect UI 두 단계 선택 흐름
3. 스킬 DCSS 30 풀복원 ★ 가장 큰 단일 작업, sub-step 분할 권장
   3a. SkillRegistry 30 등록 + 카테고리 태깅
   3b. Combat sub-skill 분해 (blade → short/long, hafted → maces/axes/staves, ranged → bows/crossbows/slings/throwing)
   3c. Magic sub-skill 분해 (학파 7 + 원소 5)
   3d. Defense sub-skill 분해 (agility → dodging/stealth)
   3e. Utility sub-skill 분해 (tool → invocations/evocations)
   3f. Race aptitude × 30 확장 (DCSS species 데이터 변환 — oldproject convert_dcss_species.py 재활용 검토)
   3g. 12 클래스 .tres starting_skills 재구성
   3h. SaveManager 30 스킬 직렬화 + 마이그레이션 (1:N 분배: 예 blade 6 → short 3, long 3)
4. SkillsDialog 카테고리 UI (UI 트랙과 합칠 수 있음)
5. MagicSystem element-aware 데미지 계산
6. 초반 드랍 테이블 다양성 검증 (별도 밸런스 트랙)
7. Phase 2 사용자 통증 (H3 인벤토리, H4 등)
8. 출시 전 감사 (성능/UX/자산/Android)
```

### 위험 / 주의

- **3번이 1~2주 단일 작업** — sub-step 단위로 끊어서 검증, 한 번에 가지 말기
- **DCSS aptitude 값 직접 활용** — oldproject `convert_dcss_species.py` 살리거나 새로 변환 스크립트. 자동화 안 하면 종족수 × 30 수기 입력 = 큰 노가다
- **save 마이그레이션 신중** — 1:N 분배 룰 결정 필요 (단순 복제 vs 균등 분할 vs 사용자 재분배 다이얼로그)
- **출시 일정 영향** — Critical 끝낸 뒤 ~1~2개월 추가. 받아들일 일정인지 확인
- **다음 세션 디자인 재토론 금지** — 이 섹션이 합의된 종결안. 구현만 진행

### 결정 종결 시각

2026-05-05. 다음 세션부터는 *구현 단계*. 디자인 변경 필요 시엔 *명시적 재오픈*하고 위 결정을 갱신.

### 클래스 시스템 재구성 완료 (Phase A + B 모두)

2026-05-05 PROJ_SS 세션에서 직접 적용. 게임 실행 시 F5 스모크로 검증 필요.

**최종 21개 클래스**:
```
Starter (is_starter=true, 3개): melee, magic, ranged
Advanced (is_starter=false, 18개):
  Melee:    fighter, berserker, monk, gladiator
  Magic:    wizard, conjurer, enchanter, necromancer, summoner,
            fire/ice/air/earth_elementalist, archmage(is_debug=true)
  Ranged:   hunter, brigand
  Other:    wanderer, artificer
```

**변경 사항**:
- 삭제: crusher, spearman, elementalist (DCSS 원조 아님 / 분할로 대체)
- Rename: warrior→fighter, ranger→hunter, rogue→brigand (DCSS 원조 명칭)
- elementalist 4분할: fire/ice/air/earth_elementalist (각 element 별 시작 스펠 차별화)
- 신규 starter 3: melee/magic/ranged (단순 시드, 초반 드랍으로 빌드 발견)
- 신규 advanced 5: wizard, monk, gladiator, wanderer, artificer (DCSS 풀 백그라운드 일부 미리 추가)
- ClassData.gd 새 필드: category, is_starter, is_debug
- 코드 7곳 ID 참조 갱신 (Game.gd / JobSelect.gd / ClassRegistry.gd / 시뮬레이터 / ShrineDialog.gd)

**검증 필요 (다음 세션 F5 스모크)**:
- Save 파일 존재 시 wipe 권장 (마이그레이션 안 함, 구 ID로 저장된 캐릭터는 로드 실패)
- ClassSelect 화면에서 starter 3개만 보이는지 (melee/magic/ranged)
- 각 starter로 게임 시작 → 무기·방어구·스킬 정상 적용 확인
- 언락 시스템이 advanced 클래스 보여주는지 (현재 모든 advanced는 unlocked=false 가정. 일부는 unlock_kind/trigger_id 가짐 — 트리거 발동 시 언락되는지 검증)
- archmage (is_debug=true) 일반 선택에서 숨겨지는지 — JobSelect UI가 is_debug 플래그 존중하는지 확인 필요 (없으면 추가 작업 항목)

**남은 작업** (이번에 안 한 것):
- JobSelect UI 두 단계 선택 흐름 (카테고리 → 특화) — 현재는 평면 리스트일 가능성. is_starter 플래그 사용해서 starter만 기본 표시, "더 보기" 누르면 unlocked advanced 노출하는 UI 작업
- is_debug 플래그를 JobSelect에서 존중 (archmage 숨김)
- Save 마이그레이션은 의도적으로 안 함 (사용자가 wipe OK)
- 미래 추가: dwarf 등 추가 종족, monster type 추가, Other 카테고리 더 (warper, hedge_wizard 등)

## 2026-05-06 Mastery + Action-Routed XP System 결정 (밸런스 토론 종결)

### 비전 — 초보·고수 양쪽 잡는 layered 시스템

```
표면: 카테고리 마스터리 (6개) — 누적 XP 기반 레벨, 광역 보너스
깊이: sub-skill 30개 — XP 기반 레벨, 특화 보너스
최종 효과 = 마스터리 보너스 + sub-skill 보너스 (중첩)

초보자 (active_skills 빈 상태로 시작):
  XP 라우팅 = 행동 기반 (단검 사용 → short_blades에 풀 XP)
  카테고리 누적 XP 자연 상승 → 마스터리 광역 보너스
  미드까지 진행 가능, 후반 한계 (sub-skill 분산되어 특화 약함)

고수 (SkillsDialog 매뉴얼 모드 → 일부 sub-skill active 토글):
  XP가 active 스킬에 비례 분배 (기존 동작)
  같은 시간에 1-2 sub-skill 9까지 → 특화 보너스 큼
  마스터리 + 특화 둘 다 → 후반 안정
```

### 카테고리 (5+1 분리 유지, 통합 안 함)

`Melee / Ranged / Magic / Defense / Agility / Utility` — Defense+Agility는 mechanically 반대 전략(tank ↔ evader)이라 분리 유지.

### 마스터리 공식 — 누적 XP 기반

```gdscript
# Player.gd
const MASTERY_XP_DELTA: Array = [60, 140, 275, 475, 750, 1150, 1700, 2450, 3500]

func get_category_total_xp(category: String) -> float:
    var total: float = 0.0
    for skill_id in SKILL_CATEGORIES.keys():
        if SKILL_CATEGORIES[skill_id] != category:
            continue
        var s: Dictionary = skills.get(skill_id, {})
        total += float(s.get("xp", 0.0))
        var lv: int = int(s.get("level", 0))
        for i in range(lv):
            total += float(SKILL_XP_DELTA[i])  # 이미 소비된 XP 합산
    return total

func get_category_mastery_level(category: String) -> int:
    var xp: float = get_category_total_xp(category)
    var level: int = 0
    var consumed: float = 0.0
    for delta in MASTERY_XP_DELTA:
        if xp >= consumed + float(delta):
            consumed += float(delta)
            level += 1
        else:
            break
    return min(level, 9)
```

이게 초보·고수 양쪽 같은 시간에 *같은 마스터리 레벨* 보장 (총 사용량 기준). 차이는 sub-skill 특화 깊이.

### 카테고리별 마스터리 효과 (튜닝 출발점)

```
Melee Mastery:    +0.5% 근접 데미지 / 레벨 (cap +4.5%)
Ranged Mastery:   +0.5% 사거리 데미지 / 레벨
Magic Mastery:    +0.5% 스펠 파워 / 레벨 (또는 -1 MP/3레벨)
Defense Mastery:  +0.5% 받는 데미지 감소 / 레벨 (tank-leaning)
Agility Mastery:  +1 EV / 3레벨 (evader-leaning)
Utility Mastery:  +0.5% 두루마리/완드/도구 효과 / 레벨

각 sub-skill = 별도 특화 보너스 (예: short_blades wielding 시 +1 acc & +1 dmg/level)
```

### XP 라우팅 (DCSS 모델)

```gdscript
func gain_skill_xp(action_skill: String, amount: float) -> void:
    if active_skills.is_empty():
        # 초보 디폴트 = 행동 기반 (단일 스킬에 풀 XP)
        if SKILL_IDS.has(action_skill):
            _add_xp(action_skill, amount)
    else:
        # 고수 매뉴얼 = active 스킬 비례 분배 (기존 동작)
        var per: float = amount / float(active_skills.size())
        for skill_id in active_skills:
            _add_xp(skill_id, per)

# caller 측 (CombatSystem / MagicSystem 등):
gain_skill_xp(Player.weapon_skill_for_item(weapon), amount)
gain_skill_xp(Player.progression_school_for(spell.school), amount)
gain_skill_xp("evocations", amount)  # 완드/도구 사용
```

### 캐릭터 생성 시 active_skills

**항상 빈 배열로 시작.** ClassData.default_active_skills는 *적용 안 함*, *권장 표시용*으로만 (SkillsDialog "Recommended for Fighter: ...").

```gdscript
# Game.gd 캐릭터 init:
player.set_active_skills([])  # 항상 빈 시작 — 초보 친화 디폴트
```

### SkillsDialog 두 모드

**Mastery View (기본 첫 화면)**:
- 6개 카테고리 카드 (마스터리 레벨 + 효과 요약 + 진행바)
- 각 카드 안 sub-skill 압축 요약 (level만)
- 카드 탭 시 sub-skill 디테일 팝업 또는 카테고리 탭으로 이동
- 하단 [✱ Manual ▸] 토글 버튼

**Manual 모드 (토글 진입)**:
- 동일 레이아웃 + sub-skill에 체크박스
- 체크 → active_skills 추가 → 비례 분배 모드
- 해제 → action-routed 복귀
- 상단 상태: "Auto (action-routed)" 또는 "Manual: 3 active"
- 하단 [◂ Mastery] 복귀

기존 ACTIVE 탭은 *Mastery View가 흡수*. 6 카테고리 탭(MELEE/RANGED/MAGIC/DEFENSE/AGILITY/UTILITY)은 sub-skill 디테일 보기로 유지.

### 작업 단계 (Issue 3 sub-step 2-7과 통합 트랙)

```
Step 1: Player.get_category_total_xp + get_category_mastery_level
        + MASTERY_XP_DELTA 상수
Step 2: gain_skill_xp 분기 (empty → action-routed / non-empty → 비례)
        caller 측 (Combat/Magic) action_skill 명시 호출로 변경
Step 3: 캐릭터 init에서 set_active_skills([]) 강제
        ClassData.default_active_skills는 데이터로 보존 (UI 권장 표시용)
Step 4: SkillsDialog 재작성
        - Mastery View 첫 화면 (6 카테고리 카드)
        - Manual 모드 토글 + 체크박스 UI
        - ACTIVE 탭 제거 (Mastery가 흡수)
        - 6 카테고리 탭 sub-skill 디테일
Step 5: CombatSystem / MagicSystem 데미지 계산에 마스터리 보너스 추가
        damage = base + sub_skill_bonus + mastery_bonus
Step 6: 카테고리별 마스터리 효과 정의 + 플레이어 텍스트
Step 7: Issue 3 sub-step 2-7 통합 — Race aptitude × 30, MagicSystem element-aware,
        나머지 .tres 정리, ShrineDialog 잔여 참조
Step 8: 밸런스 튜닝 — 구체 변경 (BalanceSimulator 시뮬 30회 검증)
        ▸ XP_CURVE 압축: 합 ~17,000 (현재 183,000에서 91% 압축)
          새 곡선: [0, 10, 25, 50, 90, 150, 230, 320, 420, 540,
                   650, 800, 980, 1190, 1430, 1700, 2000, 2330, 2690, 3080]
          MAX_XL = 20 유지 (광고 cap을 실제 도달 가능하게)
        ▸ env_damage dead code 청소 (Game.gd:2386 함수 + ZoneManager 필드/게터)
          이미 호출처 0, 동작 변화 없음. 단순 코드 정리.
        ▸ Rune 픽업 시 entry_depth × 100 XL XP 보너스
          rune_swamp 600 / rune_ice 900 / rune_infernal 1200 / rune_crypt 1500
          깊은 가지 = 더 큰 보상으로 후반 동기 부여
        ▸ 도달 XL 시뮬 목표 검증:
            노가지 14층: XL 12-13 (미드 wall)
            1가지 18층: XL 14-15 (빠듯)
            풀 4가지 30층: XL 19-20 (마스터)
        ▸ 마스터리 곡선도 함께 검증 (active_skills 0~3개 시나리오)
```

### 종결된 디자인 결정 (재오픈 금지 항목)

- ✓ Defense + Agility 분리 유지 (DCSS 패턴 + 빌드 정체성)
- ✓ Mastery 누적 XP 기반 (레벨 평균/합 아님)
- ✓ XP 라우팅: empty active → 행동 기반 / 비어있지 않음 → 비례 분배
- ✓ 신규 캐릭터는 항상 active_skills = [] (초보 친화)
- ✓ ClassData.default_active_skills = 권장 표시용 (자동 적용 안 함)
- ✓ SkillsDialog ACTIVE 탭 제거, Mastery View로 흡수 + Manual 토글
- ✓ Mastery 시스템과 Issue 3 (DCSS 30 split) 통합 트랙

### 결정 종결 시각

2026-05-06. 다음 세션부터 *구현 단계*. 디자인 변경 필요 시엔 *명시적 재오픈* 후 갱신.

## 2026-05-06 PROJ_SS 후속 세션 — Mastery 시스템 구현 완료

이 세션에서 Step 1~8 모두 적용 (F5 스모크 검증은 사용자가 추후 일괄 실시 예정).

### 완료된 단계

- **Step 1** ✓ Player.gd `MASTERY_XP_DELTA` + `get_category_total_xp()` + `get_category_mastery_level()`
- **Step 2** ✓ `grant_kill_skill_xp(amount, action_skill)` 분기 — empty active → action-routed full XP / non-empty → 비례 분배. CombatSystem 30-split fallout 정정 (`weapon_skill_for_item` 단일 진입점, dead `"ranged"`/`"blade"` skill_id 제거)
- **Step 3** ✓ 캐릭터 init `set_active_skills([])`. `["blade"]` fallback 전부 제거. ClassData.default_active_skills는 데이터 보존(자동 적용 안 함)
- **Step 4** ✓ SkillsDialog 재작성 — MASTERY 첫 화면 (6 카테고리 카드 + 진행바 + 효과 텍스트), ACTIVE 탭 → 상단 mode 배너로 흡수, 6 sub-skill 탭 유지. `_DESCRIPTIONS`/`_bonus_text` 30-split 키로 갱신
- **Step 5** ✓ CombatSystem mult chain에 `melee_mastery_dmg_mult` / `ranged_mastery_dmg_mult` 합산. `monster_attack_player`/`monster_ranged_attack_player`에 `defense_mastery_incoming_mult` 적용
- **Step 5(magic)** ✓ MagicSystem `_compute_power`에 `magic_mastery_power_mult` 곱
- **Step 6** ✓ 6개 mastery 효과 helper + Agility EV 보너스 (Player.refresh_ac_from_equipment). SKILL_CATEGORIES Defense/Agility 분리 (dodging/stealth → Agility)
- **Step 7 (부분)** ✓ Race aptitude 30-skill **runtime fallback** — `Player.aptitude_for(race, skill_id)` static helper가 LEGACY_SKILL_SPLIT 통한 legacy key lookup. .tres mass edit 없이 30 sub-skill 모두 정상 aptitude 적용
- **Step 8** ✓ XP_CURVE 압축 (sum ~17,000), env_damage dead code 제거 (Game._apply_branch_env_damage + ZoneManager.branch_env_damage/branch_env_element/필드), Rune 픽업 entry_depth × 100 XP 보너스 (`Player._rune_xp_bonus`)

### Step 7 잔여 (보류)

- `.tres` race 파일 직접 30-key 변환은 *DCSS 출처 vetting 필요* — runtime fallback이 currently 모든 신규 sub-skill에 부모 카테고리 aptitude 그대로 부여. fine-grained DCSS 값(예: short_blades vs long_blades 차이)이 필요하면 별도 트랙으로
- 12 클래스 .tres `starting_skills` legacy 키(blade/hafted) 그대로 — Game.gd remap이 LEGACY_SKILL_SPLIT 통해 처리하므로 동작 OK. 시각적 정리는 보류
- `default_active_skills` 데이터는 legacy 키 유지 — 현재 자동 적용 안 됨, "Recommended for X" UI 작업 시 같이 정리

### 다음 세션 진입 순서 권장

1. **F5 스모크 일괄** — 5월 5~6일 누적 변경 + 이번 세션 Mastery 시스템 통합 검증
   - 검증 항목 정리:
     - 신규 캐릭터: SkillsDialog MASTERY 탭 디폴트, mode 배너 "Auto", active 0개
     - 단검 공격 5킬 → `short_blades` xp 차오름 (legacy "blade" 아닌)
     - 스펠 캐스팅 → 학파 + spellcasting 양쪽 progression
     - SHORT_BLADES 탭 → 토글 → 배너 "Manual: 1 active"
     - Agility mastery 3 도달 → 장비 재장착 시 +1 EV
     - Rune 픽업 시 +600/900/1200/1500 XP 로그
     - Zone 전환 (depth 4/7/10/13)
     - 21 클래스 starter 3개만 노출 + archmage(is_debug) 숨김 (이건 별도 — UI 미구현일 수도)
2. **밸런스 시뮬** — BalanceSimulator 살리거나 새 sim. 도달 XL 검증 (목표: 노가지 14F XL 12-13 / 1가지 18F XL 14-15 / 풀 4가지 30F XL 19-20)
3. **JobSelect 두 단계 UI** — is_starter/is_debug 플래그 존중 (남은 작업)
4. **SaveManager 30 스킬 마이그레이션 1:N 분배** — 사용자 wipe-OK 결정이라 우선순위 낮음
5. **추가 감사** (성능/UX/자산 라이선스/Android) — 출시 전 필수
6. **Race aptitude .tres 직접 30-key 변환** — DCSS 출처 vetting 후 (현재 runtime fallback로 게임 정상 동작)

### Mastery 시스템 핵심 설계 메모 (재오픈 금지 — 다시 확인할 때 빠르게)

- 5+1 카테고리: `Melee / Ranged / Magic / Defense / Agility / Utility`
- Mastery 레벨 = 카테고리 누적 XP (소비분 + 미소비분 합) 기반, 0~9
- 효과 (linear): Melee/Ranged/Magic/Utility/Defense는 0.5%/lv, Agility는 EV +1 / 3lv
- XP 라우팅: empty active → action_skill에 풀 / non-empty → 비례. 신규 캐릭터 항상 empty
- `default_active_skills` 데이터는 권장 표시용으로만 보존, 자동 적용 안 함
- Mastery는 sub-skill 보너스와 **곱연산** (mult chain 통과). 9 mastery × 9 sub = 한 카테고리 max +4.5% × ~+(level×6%)

## 결정 보류 중인 것

- `oldproject/` archive 이동 — Phase 0 완료됐으니 시체 path 의존이 끊겼는지 다시 확인 후 archive 이동 가능. `Game.gd:35` 와 LPC generator 의존이 진짜 0인지 grep 후 결정.
- balance 감사를 Phase 1 직후 vs Phase 2 직후 어느 시점에 끼울지.
- 추가 감사 (성능/UX/자산/Android)를 어느 순서로 돌릴지 — 자산 라이선스가 가장 후속 영향 큼 (출시 직전 발견 시 재제작 필요).
