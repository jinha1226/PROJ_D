# 레퍼런스: 타 게임 스킬/탤런트 시스템

PocketCrawl 스킬/탤런트 설계 참고용. 2026-05-29 수집.

---

## Shattered Pixel Dungeon

### 구조
- 클래스 선택 (5개) → 서브클래스 선택 (중반) → 티어별 탤런트 선택
- T1~T2: 레벨업마다 포인트 적립 후 투자
- T3: 서브클래스 선택 후 해금
- T4: 영웅 능력(고정) + 3개 서브탤런트 선택
- 클래스당 약 16개 탤런트, 5개 클래스 → 전체 약 80개+

### Warrior
- **T1**: Hearty Meal, Armsmaster's Intuition, Test Subject, Iron Will
- **T2**: Iron Stomach, Restored Willpower, Runic Transference, Lethal Momentum, Improvised Projectiles
- **T3 (Berserker)**: Enraged Catalyst
- **T3 (Gladiator)**: Cleave
- **T4 (Heroic Leap)**: Body Slam, Impact Wave, Double Jump
- **T4 (Shockwave)**: Expanding Wave, Striking Wave, Shock Force
- **T4 (Endure)**: Sustained Retribution, Shrug It Off, Even The Odds

### Mage
- **T1**: Empowering Meal, Scholar's Intuition, Tested Hypothesis, Backup Barrier
- **T2**: Energizing Meal, Energizing Upgrade, Wand Preservation, Arcane Vision, Shield Battery
- **T3 (Battlemage)**: Mystical Charge
- **T3 (Warlock)**: Soul Eater
- **T4 (Elemental Blast)**: Blast Radius, Elemental Power, Reactive Barrier
- **T4 (Wild Magic)**: Wild Power, Fire Everything, Conserved Magic
- **T4 (Warping Beacon)**: Telefrag, Remote Beacon, Longrange Warp

### Rogue
- **T1**: Cached Rations, Thief's Intuition, Sucker Punch, Protective Shadows
- **T2**: Energizing Meal, Mystical Upgrade, Wide Search, Silent Steps, Rogue's Foresight
- **T3 (Assassin)**: Assassin's Reach
- **T3 (Freerunner)**: Projectile Momentum
- **T4 (Smoke Bomb)**: Hasty Retreat, Body Replacement, Shadow Step
- **T4 (Death Mark)**: Fear The Reaper, Deathly Durability, Double Mark
- **T4 (Shadow Clone)**: Shadow Blade, Cloned Armor, Perfect Copy

### Huntress
- **T1**: Nature's Bounty, Survivalist's Intuition, Followup Strike, Nature's Aid
- **T2**: Invigorating Meal, Restored Nature, Rejuvenating Steps, Heightened Senses, Durable Projectiles
- **T3 (Sniper)**: Shared Enchantment
- **T3 (Warden)**: Durable Tips
- **T4 (Spectral Blade)**: Fan of Blades, Projecting Blades, Spirit Blades
- **T4 (Nature's Power)**: Growing Power, Nature's Wrath, Wild Momentum
- **T4 (Spirit Hawk)**: Eagle Eye, Go For The Eyes, Swift Spirit

### Duelist *(v2.0)*
- **T1**: Focused Meal, Duelist's Intuition, Aggressive Barrier
- **T2**: Liquid Agility, Weapon Recharging, Swift Equip, Lethal Haste, Precise Assault
- **T3 (Champion)**: Combined Lethality
- **T3 (Monk)**: Flurry of Blows, Cleanse, Dash, Focus
- T4: Challenge / Elemental Strike / Feint (서브탤런트 이름 미확인)

### Cleric *(v3.0, 2025)*
- 탤런트 포인트 = 주문 언락 방식 (다른 클래스와 구조 다름, 총 30개+ 주문)
- **T1**: Holy Intuition, Shield of Light, Detect Curse, Satiated Spells, Light Reading
- **T2**: Bless, Sunray, Recall Inscription, Divine Sense, Searing Light
- **T3 (Priest)**: Radiance, Holy Lance, Hallowed Ground, Mnemonic Prayer, Cleanse
- **T3 (Paladin)**: Smite, Lay on Hands, Cleanse

> 모든 클래스 T4 공통: **Heroic Energy**

---

## Caves of Qud

### 구조
- 스킬 포인트로 트리 언락 → 트리 내 개별 스킬 구매
- 클래스 없음 — 완전 자유 조합
- 위키 기준 총 **152개** 개별 스킬 / 약 25개 트리

### 무기 트리

| 트리 | 주요 스킬 |
|------|-----------|
| **Axe** | Charging Strike, Cleave, Dismember, Hook and Drag, Decapitate, Berserk! |
| **Long Blade** | Lunge, Dueling Stance, Swipe, En Garde!, Improved Stance ×3 |
| **Short Blade** | Jab, Bloodletter, Hobble, Shank, Pointed Circle, Rejoinder |
| **Cudgel** | Bludgeon, Conk, Backswing, Slam, Demolish |
| **Bow and Rifle** | Draw a Bead, Steady Hands, Suppressive Fire, Sure Fire, Wounding Fire, Ultra Fire |
| **Pistol** | Akimbo, Sling and Run, Disarming Shot, Dead Shot, Fastest Gun in the Rust |
| **Multiweapon Fighting** | Flurry, Multiweapon Expertise, Multiweapon Mastery |
| **Single Weapon Fighting** | Opportune Attacks, Weapon Expertise, Penetrating Strikes, Weapon Mastery |

### 전투/이동 트리

| 트리 | 주요 스킬 |
|------|-----------|
| **Acrobatics** | Swift Reflexes, Spry, Jump, Tumble |
| **Tactics** | Charge, Juke, Swipe, Sprint |
| **Shield** | Block, Shield Slam, Swift Blocking, Staggering Block, Shield Wall |

### 생존/유틸 트리

| 트리 | 주요 스킬 |
|------|-----------|
| **Endurance** | Shake It Off, Poison Tolerance, Weathered, Calloused, Longstrider |
| **Self-Discipline** | Meditate, Lionheart, Iron Mind, Mind Over Body |
| **Wayfaring** | Wilderness Lore ×7종, Mind's Compass, Pathfinding |
| **Physic** | Staunch Wounds, Nostrums, Amputate Limb, Apothecary |

### 사회/제작 트리

| 트리 | 주요 스킬 |
|------|-----------|
| **Persuasion** | Menacing Stare, Intimidate, Snake Oiler, Inspiring Presence |
| **Tinkering** | Disassemble, Scavenging, Tinker I, Tinker II, Tinker III, Gadget Inspector |
| **Cooking and Gathering** | Meal Preparation, Harvestry, Butchery, Carbide Chef |
| **Customs and Folklore** | Tactful, Trash Divining |

---

## PocketCrawl 설계 메모

- **PD 방향**: 클래스 정체성 중심, 좁고 깊은 탤런트. 탤런트 수는 적지만 빌드를 확실히 갈라놓음.
- **CoQ 방향**: 넓고 자유로운 조합. 무기별 전용 트리가 세분화되어 있음.
- PocketCrawl은 클래스 없음 → PD보다 CoQ에 가까운 범용 구조가 맞음.
- 현재 에센스가 드라마틱한 빌드 변환 담당 → 탤런트는 PD식 단순 패시브 보정으로 가는 게 역할 분리에 유리.
- 스킬 그라인드 축소 + 탤런트 확장 방향 검토 중 (2026-05-29).
