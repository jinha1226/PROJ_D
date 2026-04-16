# 진행 현황 (Progress Log)

마지막 업데이트: 2026-04-16

---

## ✅ M1 프로토타입 — 대부분 완료

### 코어 시스템
- [x] Godot 4.6 프로젝트 셋업, 세로형 1080×2340 Mobile 렌더러
- [x] 자동 로드: `GameManager`, `TurnManager`, `SaveManager`, `BodyParts`, `ItemDatabase`, `PlayerData`, `SpriteGenerator`
- [x] 턴 플로우: `TurnManager.start_player_turn` / `end_player_turn`, 몬스터 actor 등록
- [x] 세이브/로드: JSON 기반 (`user://meta_save.json`)

### 던전
- [x] BSP 분할 + L-복도 + BFS 도달성 보정 (50×80)
- [x] FLOOR/WALL/STAIRS_DOWN 타일, `_draw()` 원시 렌더
- [x] 다음 층 이동 (stairs_tapped → depth++ → regen)
- [x] 몬스터 깊이 스케일 스폰 (depth 1–3 쥐/고블린, 4+ 오크 합류)

### 엔티티 & 전투
- [x] Player: grid 이동 8방향, HP/MP/STR/DEX/INT/AC/EV
- [x] Monster: 그룹/레지스트리, greedy 8-dir AI, 시야 내 추격
- [x] CombatSystem: DCSS식 공식 + 스킬 보정
- [x] 3 몬스터 종 (rat, goblin, orc)

### 정수 시스템 (M1 범위)
- [x] 슬롯 1개, 장착/해제, 스탯 합산
- [x] 정수 3종 (오우거/본나이트/뱀)
- [x] 몬스터 사망 시 `drop_chance` 드롭, 보관함 최대 10
- [x] 교체 팝업 UI

### 메타 진행
- [x] 룬 조각 획득/저장 (사망·클리어별)
- [x] 결과 화면 (사망/클리어), 재도전 버튼

### UI
- [x] TopHUD: HP/MP/층수/가방·미니맵·스킬 버튼
- [x] BottomHUD: 퀵슬롯 4 + 정수슬롯 1 + 휴식
- [x] PopupManager (아이템/정수교체/레벨업)
- [x] ResultScreen

### LPC 스프라이트 파이프라인
- [x] PROJ_B 포트 (LPCSpriteLoader, LPCDefLoader, 기본 34 def)
- [x] 신규 def 46개 (waraxe/katana/halberd 등 무기 19, 방어구 8, 바디 7, 악세 12)
- [x] 캐릭터 프리셋 16개 (직업 6, 몬스터 9, rat skip)
- [x] CharacterSprite + AnimatedSprite2D 런타임 합성
- [x] walk/slash/hurt/idle 애니메이션 훅 (이동/공격/피격/기본)
- [x] ULPC 5,331 PNG 미러링 → `assets/ulpc/`

### DCSS 스킬 시스템 (M1 범위)
- [x] 26 스킬 카탈로그 (무기 10, 방어 4, 마법 10, 기타 2)
- [x] WeaponRegistry (장착 무기 → 스킬 매핑)
- [x] XP 획득: 몬스터 처치 시 장착 무기 + fighting + armour에 분배
- [x] 레벨업 커브 `30 * 1.5^(level-1)`, 최대 Lv.27
- [x] 훈련 on/off 토글
- [x] 전투 공식 스킬 반영 (ATK/effective_AC)
- [x] SkillsScreen (탭 필터, 훈련 체크박스, XP 바)
- [x] TopHUD 현재 무기 스킬 힌트
- [x] 레벨업 플로팅 토스트

### CI/CD
- [x] GitHub Actions: Godot 4.6.2 web export + Pages 배포
- [x] 단일스레드 WASM (GH Pages 호환)
- [x] 모바일 viewport meta, pinch-zoom 방지
- [x] 자동 Pages enablement

### 문서 & 라이선스
- [x] CREDITS_LPC.md
- [x] README.md
- [x] .gitignore, .gitattributes

---

## 🐛 현재 알려진 버그 (수정 진행 중)

1. **한글 폰트 미지원** — Godot 기본 폰트에 CJK 없음, 박스로 렌더
2. **BottomHUD 미노출** — 상단 HUD는 보이는데 하단이 안 보임 (레이아웃 버그)
3. **몬스터 조우 시 프리즈** — 전투 진입 시점 무응답 상태

→ 버그 수정 agent 병렬 진행 중, 완료 시 자동 커밋 푸시.

---

## ⚠️ M1 미완 항목

- [ ] **아이템 시스템 기초** — 포션/스크롤/무기 드롭, 줍기, 인벤토리. 현재 빈 상태.
- [ ] **레벨업 팝업 연동** — 팝업 UI는 있지만 실제 경험치→레벨업 트리거 미구현 (플레이어 레벨은 항상 1)
- [ ] **인게임 Credits 화면** — 파일은 있지만 UI 없음
- [ ] **휴식 버튼 동작** — 버튼은 있지만 자동 대기 로직 미연결
- [ ] **원거리 공격** — 퀵슬롯에 활 등록 시 원거리 탭 흐름 미구현
- [ ] **허기/식량** — 완전 미구현 (M2로 미룸 검토)
- [ ] **FOV / 시야 제한** — 현재 맵 전체 가시, 안개 없음

---

## 🎯 다음 우선순위 제안

### 단기 (현재 sprint, 1~2주)
1. **현재 버그 3개 수정** (진행 중)
2. **플레이 흐름 검증** — 실제로 B1F→B2F→…→사망→재도전 루프 탄탄하게 돌아가는지
3. **레벨업 팝업 연동** — XP 풀 → 플레이어 레벨 → 스탯 선택 팝업 발화
4. **Credits 화면** — 타이틀에서 접근 가능하게. 법적 리스크 선제 차단.

### 중기 — M2 알파 진입 (2~4주)
5. **아이템 시스템** — 포션/스크롤/무기/갑옷 드롭 + 인벤토리 화면 + 장비 교체. 아이템 교체로 스킬 방향 바뀌는 "빌드 자유도" 실체화.
6. **정수 슬롯 확장 + 시너지** — 슬롯 3개, 2개 시너지(거인/언데드) 구현, 보관함 UI
7. **메타 업그레이드 트리 UI** — 생존·정수·직업해금 카테고리 구매
8. **직업 2개 해금** — 마법사, 신관 (스킬 테이블 + 시작 장비 + 주문 시스템 1차)

### M2 후반 (4~8주)
9. **브랜치 2개** — 숲(F:1~4), 광산(M:1~4) + 각 전용 타일/몬스터/보스
10. **Vault 시스템** — 기본 5종 (십자, 보물방, 몬스터굴, 신전, 상점)
11. **FOV 시스템** — 플레이어 시야 기반 맵 가시 (언데드·심연 브랜치 필수)
12. **주문/마법 시스템** — 마법사 직업 필수. spellcasting + 원소 학파 3종.

### 타일/그래픽 작업 (사용자 수동)
- 던전 타일셋 실제 적용 (현재 `_draw()` 원시 렌더 대체)
- 메인 메뉴·타이틀 화면
- 사운드·BGM

---

## 기술 부채 & TODO

- LPC def 9개가 `"stub": true` — 소스 파일 누락 (club, katana, scimitar, boomerang, legion_chest, body_skeleton, body_zombie, horns_small, tail_snake, wings_dragon, beard_braided)
- `greatsword.json`이 longsword 스키마 복사본 (PROJ_B 기존 버그, 미수정)
- 몬스터 프리셋 중 rat는 비휴머노이드라 skip — OpenGameArt에서 개별 시트 필요
- Monster.take_turn에 turn당 Timer 생성 누수 (polish 필요)
- TurnManager.end_player_turn → start_player_turn 동기 재진입 — 버그 수정 agent 검토 중
- FOV/시야 시스템 부재 — 언데드/심연 브랜치 구현 전 필수
- Image-rendering 스무딩 이슈 가능성 (1px 픽셀 아트 → filter off 확인 필요)

---

## 레포 / 배포

- GitHub: https://github.com/jinha1226/PROJ_D
- Pages (활성화 시): https://jinha1226.github.io/PROJ_D/
- 빌드 시간: push 후 약 5~10분 (ULPC 임포트 때문)
