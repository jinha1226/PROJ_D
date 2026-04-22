# Claude Code 작업 가이드

## 이 문서의 목적
Claude Code 세션을 시작할 때 참고할 지침.
어떤 순서로 개발하고, 어떻게 질문하면 효과적인지 정리.

---

## 프로젝트 시작 순서

### Step 1 — Godot 4 프로젝트 생성
```bash
# Godot 4 설치 후
# 새 프로젝트 생성: stone_and_depth
# 렌더러: Mobile (모바일 최적화)
# 화면 설정: Portrait, 1080×2340 기준
```

### Step 2 — 플러그인 설치
```
Godot 에디터 → AssetLib → "LPC Character Spritesheet" 검색 → 설치
```

### Step 3 — 디렉토리 구조 생성
```
docs/ 폴더를 참고해 01_PROJECT_OVERVIEW.md의 디렉토리 구조대로 생성
```

---

## Claude Code 세션별 작업 지침

### 세션 시작 시 항상 할 것
```
"docs/ 폴더의 관련 문서를 먼저 읽어줘. 
오늘은 [작업 내용]을 구현할 거야."
```

### M1 프로토타입 작업 순서

#### 1단계: 던전 생성기
```
"docs/06_DUNGEON_GENERATION.md를 읽고
DungeonGenerator.gd를 구현해줘.
우선 BSP 분할 + 방 + 복도 연결만. 
50×80 타일맵, WALL/FLOOR/STAIRS_DOWN만 있으면 돼."
```

#### 2단계: 타일맵 렌더링
```
"던전 생성기 결과를 Godot TileMap에 렌더링하는 코드 짜줘.
32×32 타일 기준. 세로형 화면."
```

#### 3단계: 플레이어 + 타일터치 이동
```
"docs/02_UI_UX.md의 터치 조작 섹션을 읽고
Player.gd와 TouchInput.gd를 구현해줘.
- 인접 타일 탭 → 이동 (8방향)
- 적 탭 → 이동 후 공격
- 롱프레스 → 자동탐험
턴 기반이야. 플레이어가 이동하면 1턴 소모."
```

#### 4단계: 기본 전투
```
"CombatSystem.gd 구현해줘.
DCSS 방식: ATK = weapon_damage + STR/2
DEF = AC. 피해 = max(1, ATK - DEF + rand(-2,2))
몬스터는 플레이어 인접 시 반격."
```

#### 5단계: 정수 시스템 기초
```
"docs/03_ESSENCE_SYSTEM.md 읽고
EssenceSystem.gd 구현해줘.
M1 범위: 슬롯 1개, STR/DEX/INT 보너스만.
오우거 정수(STR+8), 본나이트 정수(AC+4), 뱀 정수(DEX+4) 3종."
```

#### 6단계: 하단 HUD
```
"docs/02_UI_UX.md의 하단 HUD 섹션 보고
BottomHUD.tscn과 BottomHUD.gd 만들어줘.
퀵슬롯 4개 + 정수 슬롯 1개 + 휴식 버튼.
세로형 화면 하단 고정."
```

#### 7단계: 메타 성장 기초
```
"docs/04_META_PROGRESSION.md 읽고
MetaProgression.gd 구현해줘.
M1 범위: 룬 조각 저장/불러오기, 사망/클리어 결과 화면."
```

---

## 자주 쓸 Claude Code 프롬프트 패턴

### 새 기능 구현
```
"[파일명].md를 읽고 [기능명]을 구현해줘.
지금 단계는 M[번호]이니까 [범위] 내에서만.
기존 [관련파일.gd]와 연동되어야 해."
```

### 버그 수정
```
"[증상]이 발생해. 
관련 코드는 [파일명.gd]야.
원인 찾아서 수정해줘."
```

### 밸런스 조정
```
"플레이해보니 [문제점]이 있어.
docs/05_JOBS_AND_RACES.md의 수치를 참고해서
[무엇을] 조정해줘."
```

### DCSS 참고
```
"DCSS에서 [기능명]이 어떻게 동작하는지 설명해주고,
우리 게임에 맞게 Godot으로 구현해줘.
docs/[관련문서.md] 참고해서."
```

---

## 중요 설계 결정 사항 (변경 금지)

이 결정들은 확정됐으니 Claude Code에 다시 물어보지 말 것:

1. **세로형(Portrait) 고정** — 가로형으로 바꾸지 말 것
2. **턴제 유지** — 실시간으로 바꾸지 말 것
3. **타일터치 이동** — 조이스틱 방식 쓰지 말 것
4. **정수 슬롯은 항상 화면에 표시** — 팝업으로만 만들지 말 것
5. **파티 없음** — 솔플 유지
6. **Godot 4 + GDScript** — Unity나 C# 쓰지 말 것
7. **LPC 에셋** — 크레딧 표기 필수

---

## 라이선스 체크리스트

배포 전 반드시 확인:

- [ ] 인게임 Credits 화면에 CREDITS.csv 내용 표시 (CREDITS_LPC.md 있음, 화면 미구현)
- [x] 배포 패키지에 CREDITS.csv 포함 (CREDITS_LPC.md 커밋됨)
- [ ] credits 화면 또는 링크: "Sprites by: Johannes Sjölund (wulax), ..."
- [x] GPL v3 / CC-BY-SA 3.0 라이선스 텍스트 포함 (CREDITS_LPC.md)
- [ ] 수정된 LPC 에셋이 있다면 동일 라이선스로 공개 (미수정 상태)

---

## 참고 링크

- Universal LPC 제너레이터: https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/
- Godot LPC 플러그인: https://godotengine.org/asset-library/asset/1673
- OpenGameArt LPC: https://opengameart.org/content/lpc-dungeon-elements
- DCSS 소스 (참고용): https://github.com/crawl/crawl
- DCSS 위키: http://crawl.chaosforge.org/

---

## 파일 목록

| 파일 | 내용 |
|---|---|
| 01_PROJECT_OVERVIEW.md | 프로젝트 전체 개요, 디렉토리 구조 |
| 02_UI_UX.md | 세로형 UI 레이아웃, 터치 조작 전체 |
| 03_ESSENCE_SYSTEM.md | 정수 시스템 상세 설계 + GDScript 구조 |
| 04_META_PROGRESSION.md | 룬 조각·메타 업그레이드 트리 |
| 05_JOBS_AND_RACES.md | 직업·종족 전체 스탯·특성 |
| 06_DUNGEON_GENERATION.md | 던전 생성 알고리즘·브랜치 구조 |
| 07_TECH_AND_ASSETS.md | Godot 설정·LPC 에셋·Firebase·빌드 |
| 00_CLAUDE_CODE_GUIDE.md | 이 파일 — Claude Code 작업 가이드 |
