# Stone & Depth — 프로젝트 개요

## 한 줄 설명
Shattered Pixel Dungeon의 모바일 조작감 + DCSS의 직업 다양성·던전 깊이 + 정수 빌드 시스템을 가진 **세로형 턴제 로그라이트 RPG**

---

## 핵심 레퍼런스
| 게임 | 가져올 것 | 버릴 것 |
|---|---|---|
| DCSS | 직업×종족 다양성, 분기 던전 구조, 신 시스템, 밸런스 수치 참고 | PC 전용 조작, 높은 진입장벽, 퍼마데스 |
| Shattered Pixel Dungeon | 세로형 터치 조작, 심플 HUD, 모바일 UX | 직업 4개 한계, 단조로운 탐험 |
| Vampire Survivors | 런 후 영구 메타 성장, 해금 구조 | 방치형 전투 (우리는 턴제 유지) |
| 던전 앤 스톤 (웹소설) | 정수 시스템 아이디어 | — |

---

## 확정 스펙
- **엔진**: Godot 4 (GDScript)
- **화면 방향**: 세로형 (Portrait) 고정
- **플랫폼**: Android / iOS / Steam PC
- **장르**: 턴제 로그라이트 RPG (Roguelite)
- **세션 길이**: 1런 약 20~30분
- **그래픽**: Universal LPC Spritesheet (GPL3/CC-BY-SA)
- **백엔드**: Firebase 무료 티어 (데일리 시드·점수판만)

---

## 핵심 차별화 3가지
1. **정수 시스템** — 몬스터 처치 시 정수 흡수, 슬롯 장착으로 빌드 변화. 언제든 교체 가능.
2. **DCSS급 직업 다양성** — 초기 6직업에서 메타 성장으로 최대 20직업 해금
3. **VS식 메타 성장** — 죽어도 룬 조각 획득 → 영구 강화·해금

---

## 디렉토리 구조 (목표)
```
stone_and_depth/
├── project.godot
├── docs/                  ← 이 문서들
├── scenes/
│   ├── main/
│   │   ├── Game.tscn       # 메인 게임 씬
│   │   └── UI.tscn         # HUD 전체
│   ├── dungeon/
│   │   ├── DungeonMap.tscn
│   │   ├── Tile.tscn
│   │   └── Room.tscn
│   ├── entities/
│   │   ├── Player.tscn
│   │   └── Monster.tscn
│   └── ui/
│       ├── BottomHUD.tscn
│       ├── EssenceSlot.tscn
│       ├── QuickSlot.tscn
│       └── Popup.tscn
├── scripts/
│   ├── core/
│   │   ├── GameManager.gd
│   │   ├── TurnManager.gd
│   │   └── SaveManager.gd
│   ├── dungeon/
│   │   ├── DungeonGenerator.gd
│   │   ├── RoomGenerator.gd
│   │   └── BranchManager.gd
│   ├── entities/
│   │   ├── Player.gd
│   │   ├── Monster.gd
│   │   ├── MonsterAI.gd
│   │   └── Stats.gd
│   ├── systems/
│   │   ├── EssenceSystem.gd
│   │   ├── MetaProgression.gd
│   │   ├── CombatSystem.gd
│   │   └── ItemSystem.gd
│   └── ui/
│       ├── BottomHUD.gd
│       ├── TouchInput.gd
│       └── PopupManager.gd
├── resources/
│   ├── jobs/              # 직업 데이터 (.tres)
│   ├── races/             # 종족 데이터
│   ├── monsters/          # 몬스터 데이터
│   ├── essences/          # 정수 데이터
│   └── items/             # 아이템 데이터
└── assets/
    ├── sprites/           # LPC 스프라이트
    ├── tiles/             # 던전 타일
    └── audio/
```

---

## 개발 단계 (마일스톤)
| 단계 | 기간 | 목표 |
|---|---|---|
| M1 프로토타입 | 1~2개월 | 던전 생성 + 타일터치 이동 + 정수 1개 |
| M2 알파 | 3~4개월 | 정수 시너지 + 직업 6개 + 브랜치 2개 + 메타 성장 |
| M3 베타 | 5~6개월 | 직업 12개 + Android 빌드 + 데일리 챌린지 |
| M4 EA | 7~8개월 | Steam EA + 구글플레이 출시 |
| M5 v1.0 | 10~12개월 | iOS + 직업 20개 + 코스메틱 |
