# 기술 스택 & 그래픽 에셋

## 엔진: Godot 4

### 버전
- Godot 4.3 이상 권장
- GDScript 사용 (C# 아님 — Claude Code 지원 더 안정적)

### 핵심 Godot 기능 활용
```
TileMap        — 던전 타일 렌더링
AnimatedSprite2D — LPC 스프라이트 애니메이션
Camera2D       — 플레이어 추적, 줌 인/아웃
CanvasLayer    — HUD (게임 카메라와 독립)
Resource (.tres) — 직업·종족·정수·아이템 데이터
JSON           — 세이브 데이터, 메타 진행
SceneTree      — 씬 전환 (게임→메타화면→게임)
```

### 플러그인
- **LPC Character Spritesheet Plugin** (Godot Asset Library ID: 1673)
  - Universal LPC 스프라이트 임포트 자동화
  - 설치: AssetLib에서 "LPC Character Spritesheet" 검색
  - 용도: LPC 스프라이트시트 → AnimatedSprite2D 자동 변환

---

## 그래픽 에셋

### Universal LPC Spritesheet

**라이선스**: GPL v3.0 / CC-BY-SA 3.0 듀얼 라이선스
**상업 사용**: 가능 (크레딧 표기 필수)
**크레딧 의무**: 인게임 Credits 화면에 CREDITS.csv 내용 표시

**제너레이터 URL**: https://liberatedpixelcup.github.io/Universal-LPC-Spritesheet-Character-Generator/

**포함 애니메이션**:
- walk (4방향 × 9프레임)
- slash (4방향 × 6프레임)
- thrust (4방향 × 8프레임)
- spellcast (4방향 × 7프레임)
- shoot (4방향 × 13프레임)
- hurt (1방향 × 6프레임)
- idle (추가 확장판)
- run (추가 확장판)

**스프라이트 크기**: 64×64px per frame (기본), 일부 무기 오버사이즈

### 캐릭터 스프라이트 생성 방법
```
1. 제너레이터 접속
2. 종족/직업에 맞는 레이어 선택:
   - Body: 종족 체형 (human/dwarf/orc 등)
   - Head: 종족 머리
   - Hair: 헤어스타일
   - Outfit: 직업 의상 (전사=갑옷, 마법사=로브 등)
   - Weapon: 직업 무기 (도끼/지팡이/활 등)
3. Export as PNG (스프라이트시트) + JSON (애니메이션 메타데이터)
4. Godot LPC 플러그인으로 임포트
5. 정수 장착 시 색상 변화: Shader로 팔레트 스왑 구현
```

### 정수 장착 시각 표현
```gdscript
# 정수 계열별 색상 오버레이 (Shader 적용)
const ESSENCE_COLORS = {
    EssenceType.GIANT:    Color(0.8, 0.2, 0.2, 0.3),  # 붉은빛
    EssenceType.UNDEAD:   Color(0.5, 0.2, 0.8, 0.3),  # 보라빛
    EssenceType.NATURE:   Color(0.2, 0.7, 0.2, 0.3),  # 초록빛
    EssenceType.ELEMENTAL:Color(0.2, 0.4, 0.9, 0.3),  # 파란빛
    EssenceType.ABYSS:    Color(0.1, 0.0, 0.2, 0.5),  # 어두운 보라
    EssenceType.DRAGON:   Color(0.9, 0.7, 0.1, 0.4),  # 금빛
}
# 시너지 발동 시: 파티클 이펙트 추가
```

### 던전 타일셋
**소스**: OpenGameArt LPC 던전 타일
- https://opengameart.org/content/lpc-dungeon-elements
- 라이선스: CC-BY-SA 3.0 (동일 라이선스)
- 타일 크기: 32×32px

**타일 구성**:
```
dungeon/  — 기본 돌벽·바닥
forest/   — 숲 브랜치용 나무·풀
mine/     — 광산 브랜치용 광물·돌
tomb/     — 묘지 브랜치용 뼈·석관
tower/    — 마법사 탑 마법진·수정
abyss/    — 심연 브랜치 어둠·공허
```

### 몬스터 스프라이트
**소스 우선순위**:
1. OpenGameArt LPC 몬스터 팩 (라이선스 동일)
2. AI 생성 (Midjourney) → 픽셀 변환 → 수작업 polish
3. LPC 캐릭터 제너레이터로 휴머노이드 몬스터 생성

**필요 몬스터 수 (M1~M2)**:
- 쥐, 박쥐, 고블린, 코볼트 (티어1)
- 오크, 좀비, 독사, 트롤 (티어2)
- 각 브랜치 보스 2종

---

## 세이브 시스템

### 세이브 파일 구조
```
user://
├── meta_save.json      # 메타 진행 (룬 조각, 해금 목록)
├── run_save.json       # 현재 런 상태 (앱 종료 시 자동저장)
└── settings.json       # 설정 (볼륨, 줌, 터치 설정)
```

### 런 세이브 데이터
```json
{
  "version": "1.0",
  "run": {
    "job": "barbarian",
    "race": "human",
    "depth": 8,
    "turn": 1247,
    "stats": { "hp": 145, "hp_max": 200, "mp": 54, "mp_max": 120 },
    "base_stats": { "str": 18, "dex": 12, "int": 8 },
    "essence_slots": ["ogre_essence", "boneknight_essence", null],
    "essence_inventory": ["snake_essence", "troll_essence"],
    "equipment": { "weapon": "war_axe", "armour": "leather_armour" },
    "inventory": [...],
    "skills": { "axes": 8, "armour": 5, "fighting": 6 },
    "god": "trog",
    "piety": 45,
    "dungeon_seed": 1234567890
  }
}
```

---

## Firebase 연동 (최소화)

### 사용 용도
1. **데일리 시드 배포**: 매일 자정 새 시드 번호 업로드
2. **점수판**: 데일리 챌린지 점수 저장 (닉네임 + 점수)
3. **유령 데이터**: 사망 위치·직업·정수 조합 저장

### 사용 안 하는 것
- 계정 인증 (익명 ID만 사용)
- 실시간 동기화
- 인게임 구매

### Godot Firebase 연동
```gdscript
# HTTP 요청으로 직접 Firebase REST API 호출
# 별도 SDK 불필요 — 단순 GET/POST

func get_daily_seed() -> int:
    var http = HTTPRequest.new()
    add_child(http)
    http.request("https://your-project.firebaseio.com/daily_seed.json")
    # ...
```

---

## 빌드 설정

### Android
- 최소 SDK: Android 8.0 (API 26)
- 타겟 SDK: Android 14 (API 34)
- 화면 방향: portrait 고정
- 패키지명: com.yourname.stonedepth

### iOS
- 최소 버전: iOS 14
- 화면 방향: portrait 고정

### Steam PC
- Windows / macOS / Linux
- 화면 방향: 세로형 유지 (창 크기 고정 or 세로 레이아웃)
- 키보드 추가 지원: 방향키, WASD 이동 / Space 휴식 / i 인벤토리

---

## 성능 목표

| 항목 | 목표 |
|---|---|
| 프레임 | 60fps (Android 중급 이상) |
| 로딩 시간 | 층 전환 < 1초 |
| 메모리 | < 200MB |
| APK 크기 | < 100MB |

### 최적화 포인트
- TileMap 청크 단위 렌더링 (화면 밖 타일 비활성화)
- 몬스터 AI: 플레이어 시야 밖 몬스터는 간소화 AI
- 스프라이트: 아틀라스 텍스처로 묶기
