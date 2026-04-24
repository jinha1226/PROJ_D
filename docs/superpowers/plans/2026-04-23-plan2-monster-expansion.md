# Monster Expansion Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 기존 67개 몬스터의 depth를 8존 구조에 맞게 재배치하고, 37개 신규 SRD 기반 몬스터를 추가한다.

**Architecture:** 모든 몬스터는 `.tres` 리소스 파일로 관리. `min_depth`/`max_depth`가 존 경계와 일치하도록 재설정. 신규 몬스터는 DCSS 타일 경로를 직접 참조. MonsterRegistry에 신규 몬스터 const + _ALL_MONSTERS 등록.

**Zone 경계:**
- Zone 0 Dungeon: depth 1-3
- Zone 1 Lair: depth 4-6
- Zone 2 Orc Mines: depth 7-9
- Zone 3 Swamp: depth 10-12
- Zone 4 Crypt: depth 13-15
- Zone 5 Ice Caves: depth 16-18
- Zone 6 Elven Halls: depth 19-21
- Zone 7 Infernal: depth 22-24
- Zone 8 Boss: depth 25

**Spec:** `docs/superpowers/specs/2026-04-23-zone-monster-expansion-design.md`

**의존성:** Plan 1 (Zone System) 완료 후 실행 권장 (독립 실행도 가능)

---

## 파일 구조

| 파일 | 변경 |
|---|---|
| `resources/monsters/*.tres` (67개) | **수정** — min_depth/max_depth 재설정 |
| `resources/monsters/*.tres` (37개 신규) | **신규** — 새 몬스터 리소스 |
| `scripts/systems/MonsterRegistry.gd` | **수정** — 37개 신규 const + _ALL_MONSTERS 추가 |

---

## .tres 파일 포맷 참조

모든 몬스터 .tres는 다음 포맷:
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://[고유ID]"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "[id]"
display_name = "[표시명]"
tier = [1-6]
hp = [수치]
hd = [주사위수]
ac = [방어]
ev = [회피]
speed = 10
sight_range = 8
attacks = [{"damage": N, "flavour": "[hit/bite/claw/sting]"}]
ranged_attack = {}
resists = []
min_depth = [존 시작]
max_depth = [존 끝]
weight = 10
xp_value = [수치]
is_boss = false
tile_path = "res://assets/tiles/individual/mon/[경로]/[파일명].png"
glyph = "[문자]"
glyph_color = Color([r], [g], [b], 1)
```

uid는 `"uid://b[몬스터id8자]"` 형식으로 고유하게 생성.

---

## Task 1: 기존 몬스터 depth 재배치

**Files:**
- Modify: `resources/monsters/*.tres` (67개)

**존별 배치 테이블 — 각 .tres의 min_depth/max_depth를 아래 값으로 수정:**

### Zone 0: Dungeon (1-3)
| 파일 | tier | min | max |
|---|---|---|---|
| rat.tres | 1 | 1 | 3 |
| bat.tres | 1 | 1 | 3 |
| giant_cockroach.tres | 1 | 1 | 3 |
| kobold.tres | 1 | 1 | 3 |
| goblin.tres | 2 | 1 | 3 |
| hobgoblin.tres | 2 | 2 | 3 |
| hound.tres | 1 | 1 | 3 |
| jackal.tres | 1 | 1 | 3 |
| hornet.tres | 2 | 2 | 3 |

### Zone 1: Lair (4-6)
| 파일 | tier | min | max |
|---|---|---|---|
| wolf.tres | 1 | 4 | 6 |
| warg.tres | 2 | 4 | 6 |
| black_bear.tres | 3 | 5 | 6 |
| adder.tres | 2 | 4 | 6 |
| giant_wolf_spider.tres | 2 | 4 | 6 |
| vampire_bat.tres | 2 | 4 | 5 |
| yak.tres | 2 | 4 | 6 |
| scorpion.tres | 2 | 4 | 6 |
| centaur.tres | 3 | 5 | 6 |

### Zone 2: Orc Mines (7-9)
| 파일 | tier | min | max |
|---|---|---|---|
| orc.tres | 2 | 7 | 9 |
| orc_warrior.tres | 3 | 7 | 9 |
| orc_priest.tres | 3 | 8 | 9 |
| orc_wizard.tres | 3 | 7 | 9 |
| gnoll.tres | 2 | 7 | 8 |
| gnoll_sergeant.tres | 3 | 8 | 9 |
| gnoll_shaman.tres | 3 | 8 | 9 |
| troll.tres | 4 | 8 | 9 |
| deep_troll.tres | 4 | 8 | 9 |
| ogre.tres | 3 | 7 | 9 |
| ogre_mage.tres | 5 | 9 | 9 |
| two_headed_ogre.tres | 4 | 8 | 9 |
| minotaur.tres | 3 | 7 | 9 |
| cyclops.tres | 4 | 8 | 9 |
| stone_giant.tres | 5 | 9 | 9 |

### Zone 3: Swamp (10-12)
| 파일 | tier | min | max |
|---|---|---|---|
| swamp_dragon.tres | 4 | 10 | 12 |
| wyvern.tres | 4 | 10 | 12 |
| basilisk.tres | 3 | 10 | 11 |
| steam_dragon.tres | 3 | 10 | 11 |
| manticore.tres | 4 | 11 | 12 |

### Zone 4: Crypt (13-15)
| 파일 | tier | min | max |
|---|---|---|---|
| zombie.tres | 2 | 13 | 14 |
| wight.tres | 3 | 13 | 15 |
| mummy.tres | 3 | 13 | 14 |
| ghoul.tres | 3 | 13 | 15 |
| skeletal_warrior.tres | 3 | 13 | 14 |
| phantom.tres | 3 | 13 | 14 |
| revenant.tres | 4 | 14 | 15 |
| wraith.tres | 4 | 14 | 15 |
| vampire.tres | 4 | 14 | 15 |
| vampire_knight.tres | 5 | 15 | 15 |
| lich.tres | 5 | 15 | 15 |

### Zone 5: Ice Caves (16-18)
| 파일 | tier | min | max |
|---|---|---|---|
| frost_giant.tres | 5 | 16 | 18 |
| ice_dragon.tres | 5 | 17 | 18 |
| ice_devil.tres | 5 | 16 | 18 |

### Zone 6: Elven Halls (19-21)
| 파일 | tier | min | max |
|---|---|---|---|
| deep_elf_archer.tres | 3 | 19 | 21 |
| deep_elf_death_mage.tres | 5 | 20 | 21 |
| gargoyle.tres | 3 | 19 | 20 |
| earth_elemental.tres | 3 | 19 | 20 |
| fire_elemental.tres | 4 | 19 | 21 |
| iron_golem.tres | 5 | 20 | 21 |

### Zone 7: Infernal (22-24)
| 파일 | tier | min | max |
|---|---|---|---|
| crimson_imp.tres | 2 | 22 | 23 |
| red_devil.tres | 4 | 22 | 24 |
| balrug.tres | 5 | 23 | 24 |
| executioner.tres | 6 | 24 | 24 |
| fire_dragon.tres | 5 | 22 | 24 |
| fire_giant.tres | 5 | 22 | 24 |
| bone_dragon.tres | 5 | 23 | 24 |
| ancient_lich.tres | 6 | 24 | 24 |

### Zone 8: Boss
| 파일 | tier | min | max |
|---|---|---|---|
| golden_dragon.tres | 6 | 25 | 25 |
| titan.tres | 6 | 25 | 25 |

- [ ] **Step 1: Zone 0-2 (Dungeon/Lair/Orc Mines) 몬스터 depth 재배치**

위 테이블의 Zone 0-2 해당 .tres 파일들의 `min_depth`/`max_depth` 값 수정.

- [ ] **Step 2: Zone 3-5 (Swamp/Crypt/Ice) 몬스터 depth 재배치**

- [ ] **Step 3: Zone 6-8 (Elven/Infernal/Boss) 몬스터 depth 재배치**

- [ ] **Step 4: 에디터에서 depth 1-25 순서로 이동, 각 존에서 적절한 몬스터 등장 확인**

- [ ] **Step 5: 커밋**
```bash
git add resources/monsters/
git commit -m "refactor: reassign monster depths to 8-zone structure"
```

---

## Task 2: Zone 0-1 신규 몬스터 (Dungeon + Lair)

**Files:**
- Create: `resources/monsters/killer_bee.tres`
- Create: `resources/monsters/bombardier_beetle.tres`
- Create: `resources/monsters/crocodile.tres`
- Create: `resources/monsters/giant_lizard.tres`
- Create: `resources/monsters/anaconda.tres`
- Create: `resources/monsters/polar_bear.tres`
- Create: `resources/monsters/hippogriff.tres`

- [ ] **Step 1: killer_bee.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bkillerbee01"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "killer_bee"
display_name = "killer bee"
tier = 1
hp = 8
hd = 2
ac = 2
ev = 12
speed = 12
sight_range = 6
attacks = [{"damage": 3, "flavour": "sting"}]
resists = ["poison"]
min_depth = 1
max_depth = 3
weight = 15
xp_value = 3
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/killer_bee.png"
glyph = "b"
glyph_color = Color(0.9, 0.8, 0.1, 1)
```

- [ ] **Step 2: bombardier_beetle.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bbombardier1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "bombardier_beetle"
display_name = "bombardier beetle"
tier = 2
hp = 14
hd = 3
ac = 4
ev = 5
speed = 8
sight_range = 6
attacks = [{"damage": 6, "flavour": "bite"}]
ranged_attack = {"damage": 5, "range": 3, "verb": "sprays", "flavour": "acid"}
resists = []
min_depth = 2
max_depth = 3
weight = 10
xp_value = 5
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/bombardier_beetle.png"
glyph = "b"
glyph_color = Color(0.6, 0.4, 0.1, 1)
```

- [ ] **Step 3: crocodile.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bcroc00001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "crocodile"
display_name = "crocodile"
tier = 2
hp = 22
hd = 4
ac = 6
ev = 4
speed = 8
sight_range = 7
attacks = [{"damage": 8, "flavour": "bite"}]
resists = []
min_depth = 4
max_depth = 6
weight = 12
xp_value = 6
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/alligator.png"
glyph = "l"
glyph_color = Color(0.3, 0.5, 0.2, 1)
```

- [ ] **Step 4: giant_lizard.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bgiantliz01"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "giant_lizard"
display_name = "giant lizard"
tier = 2
hp = 18
hd = 3
ac = 3
ev = 6
speed = 9
sight_range = 7
attacks = [{"damage": 6, "flavour": "bite"}]
resists = []
min_depth = 4
max_depth = 6
weight = 12
xp_value = 5
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/komodo_dragon.png"
glyph = "l"
glyph_color = Color(0.5, 0.4, 0.2, 1)
```

- [ ] **Step 5: anaconda.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://banaconda1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "anaconda"
display_name = "anaconda"
tier = 3
hp = 30
hd = 5
ac = 2
ev = 8
speed = 9
sight_range = 7
attacks = [{"damage": 10, "flavour": "bite"}, {"damage": 6, "flavour": "constrict"}]
resists = []
min_depth = 5
max_depth = 6
weight = 8
xp_value = 10
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/anaconda.png"
glyph = "s"
glyph_color = Color(0.4, 0.6, 0.2, 1)
```

- [ ] **Step 6: polar_bear.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bpolarbear1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "polar_bear"
display_name = "polar bear"
tier = 3
hp = 32
hd = 5
ac = 4
ev = 5
speed = 10
sight_range = 7
attacks = [{"damage": 10, "flavour": "claw"}, {"damage": 6, "flavour": "bite"}]
resists = ["cold"]
min_depth = 5
max_depth = 6
weight = 8
xp_value = 11
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/polar_bear.png"
glyph = "B"
glyph_color = Color(0.9, 0.95, 1.0, 1)
```

- [ ] **Step 7: hippogriff.tres 생성**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bhippogr01"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "hippogriff"
display_name = "hippogriff"
tier = 4
hp = 40
hd = 6
ac = 5
ev = 9
speed = 11
sight_range = 8
attacks = [{"damage": 12, "flavour": "claw"}, {"damage": 8, "flavour": "bite"}]
resists = []
min_depth = 6
max_depth = 6
weight = 6
xp_value = 16
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/hippogriff.png"
glyph = "H"
glyph_color = Color(0.8, 0.6, 0.3, 1)
```

- [ ] **Step 8: 커밋**
```bash
git add resources/monsters/killer_bee.tres resources/monsters/bombardier_beetle.tres resources/monsters/crocodile.tres resources/monsters/giant_lizard.tres resources/monsters/anaconda.tres resources/monsters/polar_bear.tres resources/monsters/hippogriff.tres
git commit -m "feat: Zone 0-1 new monsters (killer bee, beetle, croc, lizard, anaconda, polar bear, hippogriff)"
```

---

## Task 3: Zone 2-3 신규 몬스터 (Orc Mines + Swamp)

**Files:**
- Create: `resources/monsters/orc_knight.tres`
- Create: `resources/monsters/orc_warlord.tres`
- Create: `resources/monsters/ettin.tres`
- Create: `resources/monsters/death_yak.tres`
- Create: `resources/monsters/hydra.tres`
- Create: `resources/monsters/will_o_wisp.tres`
- Create: `resources/monsters/giant_constrictor.tres`

- [ ] **Step 1: orc_knight.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://borcknight1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "orc_knight"
display_name = "orc knight"
tier = 4
hp = 52
hd = 7
ac = 10
ev = 5
speed = 10
sight_range = 8
attacks = [{"damage": 14, "flavour": "hit"}]
resists = []
min_depth = 8
max_depth = 9
weight = 8
xp_value = 18
is_boss = false
tile_path = "res://assets/tiles/individual/mon/humanoids/orcs/orc_knight.png"
glyph = "o"
glyph_color = Color(0.8, 0.3, 0.1, 1)
```

- [ ] **Step 2: orc_warlord.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://borcwarlrd1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "orc_warlord"
display_name = "orc warlord"
tier = 5
hp = 70
hd = 9
ac = 12
ev = 6
speed = 10
sight_range = 8
attacks = [{"damage": 18, "flavour": "hit"}, {"damage": 10, "flavour": "hit"}]
resists = []
min_depth = 9
max_depth = 9
weight = 5
xp_value = 28
is_boss = false
tile_path = "res://assets/tiles/individual/mon/humanoids/orcs/orc_warlord.png"
glyph = "o"
glyph_color = Color(1.0, 0.2, 0.0, 1)
```

- [ ] **Step 3: ettin.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bettin0001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "ettin"
display_name = "ettin"
tier = 5
hp = 65
hd = 8
ac = 8
ev = 4
speed = 9
sight_range = 8
attacks = [{"damage": 16, "flavour": "club"}, {"damage": 16, "flavour": "club"}]
resists = []
min_depth = 9
max_depth = 9
weight = 5
xp_value = 25
is_boss = false
tile_path = "res://assets/tiles/individual/mon/humanoids/giants/ettin.png"
glyph = "G"
glyph_color = Color(0.7, 0.5, 0.3, 1)
```

- [ ] **Step 4: death_yak.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bdyak00001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "death_yak"
display_name = "death yak"
tier = 3
hp = 35
hd = 5
ac = 4
ev = 5
speed = 10
sight_range = 7
attacks = [{"damage": 12, "flavour": "gore"}]
resists = ["poison"]
min_depth = 10
max_depth = 11
weight = 10
xp_value = 12
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/death_yak.png"
glyph = "Y"
glyph_color = Color(0.3, 0.5, 0.2, 1)
```

- [ ] **Step 5: hydra.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bhydra0001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "hydra"
display_name = "hydra"
tier = 4
hp = 55
hd = 7
ac = 3
ev = 5
speed = 9
sight_range = 8
attacks = [{"damage": 10, "flavour": "bite"}, {"damage": 10, "flavour": "bite"}, {"damage": 10, "flavour": "bite"}]
resists = ["poison"]
min_depth = 11
max_depth = 12
weight = 7
xp_value = 22
is_boss = false
tile_path = "res://assets/tiles/individual/mon/dragons/hydra3.png"
glyph = "D"
glyph_color = Color(0.3, 0.6, 0.3, 1)
```

- [ ] **Step 6: will_o_wisp.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bwillowisp1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "will_o_wisp"
display_name = "will-o'-wisp"
tier = 3
hp = 18
hd = 3
ac = 0
ev = 14
speed = 12
sight_range = 8
attacks = [{"damage": 8, "flavour": "zap"}]
resists = ["elec", "fire"]
min_depth = 10
max_depth = 12
weight = 8
xp_value = 10
is_boss = false
tile_path = "res://assets/tiles/individual/mon/nonliving/will_o_the_wisp.png"
glyph = "w"
glyph_color = Color(0.7, 0.9, 1.0, 1)
```

- [ ] **Step 7: giant_constrictor.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bgconstr01"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "giant_constrictor"
display_name = "giant constrictor"
tier = 4
hp = 48
hd = 6
ac = 3
ev = 7
speed = 9
sight_range = 7
attacks = [{"damage": 12, "flavour": "bite"}, {"damage": 8, "flavour": "constrict"}]
resists = ["poison"]
min_depth = 11
max_depth = 12
weight = 7
xp_value = 18
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/anaconda.png"
glyph = "s"
glyph_color = Color(0.5, 0.7, 0.3, 1)
```

- [ ] **Step 8: 커밋**
```bash
git add resources/monsters/orc_knight.tres resources/monsters/orc_warlord.tres resources/monsters/ettin.tres resources/monsters/death_yak.tres resources/monsters/hydra.tres resources/monsters/will_o_wisp.tres resources/monsters/giant_constrictor.tres
git commit -m "feat: Zone 2-3 new monsters (orc knight/warlord, ettin, death yak, hydra, wisp, constrictor)"
```

---

## Task 4: Zone 4-5 신규 몬스터 (Crypt + Ice Caves)

**Files:**
- Create: `resources/monsters/ghost.tres`
- Create: `resources/monsters/shadow.tres`
- Create: `resources/monsters/mummy_priest.tres`
- Create: `resources/monsters/ancient_champion.tres`
- Create: `resources/monsters/ice_beast.tres`
- Create: `resources/monsters/rime_drake.tres`
- Create: `resources/monsters/freezing_wraith.tres`
- Create: `resources/monsters/blizzard_demon.tres`

- [ ] **Step 1: ghost.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bghost0001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "ghost"
display_name = "ghost"
tier = 3
hp = 22
hd = 4
ac = 0
ev = 12
speed = 10
sight_range = 8
attacks = [{"damage": 8, "flavour": "touch"}]
resists = ["neg", "poison"]
min_depth = 13
max_depth = 14
weight = 10
xp_value = 10
is_boss = false
tile_path = "res://assets/tiles/individual/mon/undead/ghost.png"
glyph = "G"
glyph_color = Color(0.8, 0.85, 1.0, 1)
```

- [ ] **Step 2: shadow.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bshadow0001"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "shadow"
display_name = "shadow"
tier = 3
hp = 20
hd = 3
ac = 0
ev = 13
speed = 10
sight_range = 8
attacks = [{"damage": 6, "flavour": "drain"}]
resists = ["neg", "cold"]
min_depth = 13
max_depth = 15
weight = 10
xp_value = 10
is_boss = false
tile_path = "res://assets/tiles/individual/mon/undead/shadow_wraith.png"
glyph = "G"
glyph_color = Color(0.3, 0.3, 0.4, 1)
```

- [ ] **Step 3: mummy_priest.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bmummypr01"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "mummy_priest"
display_name = "mummy priest"
tier = 4
hp = 42
hd = 6
ac = 6
ev = 4
speed = 8
sight_range = 8
attacks = [{"damage": 10, "flavour": "hit"}]
resists = ["neg", "poison", "fire"]
min_depth = 14
max_depth = 15
weight = 6
xp_value = 18
is_boss = false
tile_path = "res://assets/tiles/individual/mon/undead/mummy_priest.png"
glyph = "M"
glyph_color = Color(0.9, 0.8, 0.5, 1)
```

- [ ] **Step 4: ancient_champion.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bantchamp1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "ancient_champion"
display_name = "ancient champion"
tier = 5
hp = 60
hd = 8
ac = 12
ev = 5
speed = 10
sight_range = 8
attacks = [{"damage": 16, "flavour": "hit"}, {"damage": 10, "flavour": "hit"}]
resists = ["neg", "cold"]
min_depth = 15
max_depth = 15
weight = 5
xp_value = 25
is_boss = false
tile_path = "res://assets/tiles/individual/mon/undead/ancient_champion.png"
glyph = "W"
glyph_color = Color(0.7, 0.8, 0.9, 1)
```

- [ ] **Step 5: ice_beast.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bicebeast1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "ice_beast"
display_name = "ice beast"
tier = 3
hp = 30
hd = 5
ac = 3
ev = 7
speed = 10
sight_range = 7
attacks = [{"damage": 10, "flavour": "bite"}]
resists = ["cold"]
min_depth = 16
max_depth = 17
weight = 10
xp_value = 12
is_boss = false
tile_path = "res://assets/tiles/individual/mon/animals/ice_beast.png"
glyph = "B"
glyph_color = Color(0.7, 0.9, 1.0, 1)
```

- [ ] **Step 6: rime_drake.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://brimedrk1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "rime_drake"
display_name = "rime drake"
tier = 4
hp = 48
hd = 6
ac = 6
ev = 8
speed = 10
sight_range = 8
attacks = [{"damage": 12, "flavour": "bite"}]
ranged_attack = {"damage": 10, "range": 4, "verb": "breathes", "flavour": "cold"}
resists = ["cold"]
min_depth = 16
max_depth = 18
weight = 8
xp_value = 18
is_boss = false
tile_path = "res://assets/tiles/individual/mon/dragons/rime_drake.png"
glyph = "d"
glyph_color = Color(0.7, 0.9, 1.0, 1)
```

- [ ] **Step 7: freezing_wraith.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bfrzwrth1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "freezing_wraith"
display_name = "freezing wraith"
tier = 4
hp = 40
hd = 5
ac = 0
ev = 11
speed = 11
sight_range = 8
attacks = [{"damage": 10, "flavour": "touch"}]
resists = ["cold", "neg"]
min_depth = 17
max_depth = 18
weight = 7
xp_value = 18
is_boss = false
tile_path = "res://assets/tiles/individual/mon/undead/freezing_wraith.png"
glyph = "W"
glyph_color = Color(0.6, 0.85, 1.0, 1)
```

- [ ] **Step 8: blizzard_demon.tres**
```
[gd_resource type="Resource" script_class="MonsterData" format=3 uid="uid://bblizzdem1"]
[ext_resource type="Script" path="res://scripts/entities/MonsterData.gd" id="1_mdata"]
[resource]
script = ExtResource("1_mdata")
id = "blizzard_demon"
display_name = "blizzard demon"
tier = 5
hp = 62
hd = 8
ac = 5
ev = 8
speed = 11
sight_range = 8
attacks = [{"damage": 14, "flavour": "claw"}]
ranged_attack = {"damage": 12, "range": 4, "verb": "blasts", "flavour": "cold"}
resists = ["cold"]
min_depth = 18
max_depth = 18
weight = 5
xp_value = 26
is_boss = false
tile_path = "res://assets/tiles/individual/mon/demons/blizzard_demon.png"
glyph = "&"
glyph_color = Color(0.6, 0.8, 1.0, 1)
```

- [ ] **Step 9: 커밋**
```bash
git add resources/monsters/ghost.tres resources/monsters/shadow.tres resources/monsters/mummy_priest.tres resources/monsters/ancient_champion.tres resources/monsters/ice_beast.tres resources/monsters/rime_drake.tres resources/monsters/freezing_wraith.tres resources/monsters/blizzard_demon.tres
git commit -m "feat: Zone 4-5 new monsters (ghost, shadow, mummy priest, ancient champion, ice beasts)"
```

---

## Task 5: Zone 6-7 신규 몬스터 (Elven Halls + Infernal)

**Files:**
- Create: `resources/monsters/deep_elf_knight.tres`
- Create: `resources/monsters/deep_elf_sorcerer.tres`
- Create: `resources/monsters/deep_elf_blademaster.tres`
- Create: `resources/monsters/deep_elf_annihilator.tres`
- Create: `resources/monsters/deep_elf_high_priest.tres`
- Create: `resources/monsters/air_elemental.tres`
- Create: `resources/monsters/water_elemental.tres`
- Create: `resources/monsters/flesh_golem.tres`
- Create: `resources/monsters/war_gargoyle.tres`
- Create: `resources/monsters/lemure.tres`
- Create: `resources/monsters/hell_hound.tres`
- Create: `resources/monsters/efreet.tres`
- Create: `resources/monsters/brimstone_fiend.tres`
- Create: `resources/monsters/iron_dragon.tres`
- Create: `resources/monsters/shadow_dragon.tres`
- Create: `resources/monsters/storm_dragon.tres`

- [ ] **Step 1: Elven Halls 몬스터 9종 생성**

```
# deep_elf_knight.tres
id = "deep_elf_knight"  display_name = "deep elf knight"
tier = 4  hp = 45  hd = 6  ac = 10  ev = 10  speed = 10
attacks = [{"damage": 13, "flavour": "hit"}]
resists = []  min_depth = 19  max_depth = 21  weight = 8  xp_value = 18
tile_path = "res://assets/tiles/individual/mon/humanoids/elves/deep_elf_knight.png"
glyph = "e"  glyph_color = Color(0.5, 0.8, 0.6, 1)
uid = "uid://bdelknight1"

# deep_elf_sorcerer.tres
id = "deep_elf_sorcerer"  display_name = "deep elf sorcerer"
tier = 5  hp = 38  hd = 6  ac = 3  ev = 12  speed = 10
attacks = [{"damage": 6, "flavour": "hit"}]
resists = []  min_depth = 20  max_depth = 21  weight = 6  xp_value = 24
tile_path = "res://assets/tiles/individual/mon/humanoids/elves/deep_elf_sorcerer.png"
glyph = "e"  glyph_color = Color(0.7, 0.5, 1.0, 1)
uid = "uid://bdelsrcr01"

# deep_elf_blademaster.tres
id = "deep_elf_blademaster"  display_name = "deep elf blademaster"
tier = 5  hp = 50  hd = 7  ac = 8  ev = 14  speed = 11
attacks = [{"damage": 16, "flavour": "hit"}, {"damage": 12, "flavour": "hit"}]
resists = []  min_depth = 21  max_depth = 21  weight = 4  xp_value = 28
tile_path = "res://assets/tiles/individual/mon/humanoids/elves/deep_elf_blademaster.png"
glyph = "e"  glyph_color = Color(0.9, 0.9, 0.5, 1)
uid = "uid://bdelblade1"

# deep_elf_annihilator.tres
id = "deep_elf_annihilator"  display_name = "deep elf annihilator"
tier = 5  hp = 40  hd = 6  ac = 3  ev = 12  speed = 10
attacks = [{"damage": 6, "flavour": "hit"}]
resists = []  min_depth = 21  max_depth = 21  weight = 4  xp_value = 28
tile_path = "res://assets/tiles/individual/mon/humanoids/elves/deep_elf_annihilator.png"
glyph = "e"  glyph_color = Color(1.0, 0.3, 0.3, 1)
uid = "uid://bdelanni01"

# deep_elf_high_priest.tres
id = "deep_elf_high_priest"  display_name = "deep elf high priest"
tier = 5  hp = 45  hd = 6  ac = 5  ev = 10  speed = 10
attacks = [{"damage": 8, "flavour": "hit"}]
resists = []  min_depth = 20  max_depth = 21  weight = 5  xp_value = 24
tile_path = "res://assets/tiles/individual/mon/humanoids/elves/deep_elf_high_priest.png"
glyph = "e"  glyph_color = Color(1.0, 0.9, 0.7, 1)
uid = "uid://bdelhipr1"

# air_elemental.tres
id = "air_elemental"  display_name = "air elemental"
tier = 4  hp = 36  hd = 5  ac = 0  ev = 16  speed = 13
attacks = [{"damage": 10, "flavour": "buffet"}]
resists = ["elec"]  min_depth = 19  max_depth = 21  weight = 7  xp_value = 16
tile_path = "res://assets/tiles/individual/mon/nonliving/air_elemental.png"
glyph = "E"  glyph_color = Color(0.8, 0.95, 1.0, 1)
uid = "uid://bairelem1"

# water_elemental.tres
id = "water_elemental"  display_name = "water elemental"
tier = 4  hp = 42  hd = 6  ac = 2  ev = 8  speed = 9
attacks = [{"damage": 12, "flavour": "slam"}]
resists = ["cold"]  min_depth = 19  max_depth = 21  weight = 7  xp_value = 16
tile_path = "res://assets/tiles/individual/mon/nonliving/water_elemental.png"
glyph = "E"  glyph_color = Color(0.3, 0.5, 0.9, 1)
uid = "uid://bwaterele1"

# flesh_golem.tres
id = "flesh_golem"  display_name = "flesh golem"
tier = 4  hp = 55  hd = 7  ac = 9  ev = 4  speed = 8
attacks = [{"damage": 14, "flavour": "slam"}, {"damage": 14, "flavour": "slam"}]
resists = ["neg"]  min_depth = 20  max_depth = 21  weight = 6  xp_value = 20
tile_path = "res://assets/tiles/individual/mon/nonliving/flesh_golem.png"
glyph = "G"  glyph_color = Color(0.7, 0.5, 0.4, 1)
uid = "uid://bflshglm1"

# war_gargoyle.tres
id = "war_gargoyle"  display_name = "war gargoyle"
tier = 5  hp = 58  hd = 7  ac = 14  ev = 7  speed = 9
attacks = [{"damage": 15, "flavour": "claw"}, {"damage": 12, "flavour": "bite"}]
resists = ["elec"]  min_depth = 21  max_depth = 21  weight = 4  xp_value = 24
tile_path = "res://assets/tiles/individual/mon/nonliving/war_gargoyle.png"
glyph = "G"  glyph_color = Color(0.6, 0.6, 0.7, 1)
uid = "uid://bwargar01"
```

각 항목을 전체 .tres 포맷으로 생성 (위 포맷 참조).

- [ ] **Step 2: Infernal 몬스터 7종 생성**

```
# lemure.tres
id = "lemure"  display_name = "lemure"
tier = 2  hp = 18  hd = 3  ac = 3  ev = 6  speed = 8
attacks = [{"damage": 6, "flavour": "claw"}]
resists = ["fire"]  min_depth = 22  max_depth = 23  weight = 15  xp_value = 6
tile_path = "res://assets/tiles/individual/mon/demons/lemure.png"
glyph = "&"  glyph_color = Color(0.7, 0.4, 0.4, 1)
uid = "uid://blemure01"

# hell_hound.tres
id = "hell_hound"  display_name = "hell hound"
tier = 3  hp = 32  hd = 5  ac = 4  ev = 10  speed = 12
attacks = [{"damage": 10, "flavour": "bite"}]
ranged_attack = {"damage": 8, "range": 3, "verb": "breathes", "flavour": "fire"}
resists = ["fire"]  min_depth = 22  max_depth = 24  weight = 10  xp_value = 14
tile_path = "res://assets/tiles/individual/mon/animals/hell_hound.png"
glyph = "d"  glyph_color = Color(0.9, 0.3, 0.1, 1)
uid = "uid://bhellhnd1"

# efreet.tres
id = "efreet"  display_name = "efreeti"
tier = 5  hp = 65  hd = 8  ac = 6  ev = 9  speed = 11
attacks = [{"damage": 15, "flavour": "hit"}]
ranged_attack = {"damage": 14, "range": 5, "verb": "hurls", "flavour": "fire"}
resists = ["fire"]  min_depth = 23  max_depth = 24  weight = 6  xp_value = 26
tile_path = "res://assets/tiles/individual/mon/demons/efreet.png"
glyph = "&"  glyph_color = Color(1.0, 0.5, 0.1, 1)
uid = "uid://befreet01"

# brimstone_fiend.tres
id = "brimstone_fiend"  display_name = "brimstone fiend"
tier = 5  hp = 75  hd = 9  ac = 8  ev = 7  speed = 10
attacks = [{"damage": 18, "flavour": "claw"}, {"damage": 12, "flavour": "bite"}]
resists = ["fire"]  min_depth = 24  max_depth = 24  weight = 4  xp_value = 30
tile_path = "res://assets/tiles/individual/mon/demons/brimstone_fiend.png"
glyph = "&"  glyph_color = Color(0.8, 0.2, 0.0, 1)
uid = "uid://bbrmstn01"

# iron_dragon.tres
id = "iron_dragon"  display_name = "iron dragon"
tier = 5  hp = 80  hd = 9  ac = 16  ev = 5  speed = 9
attacks = [{"damage": 20, "flavour": "bite"}, {"damage": 14, "flavour": "claw"}]
resists = []  min_depth = 22  max_depth = 24  weight = 5  xp_value = 28
tile_path = "res://assets/tiles/individual/mon/dragons/iron_dragon.png"
glyph = "D"  glyph_color = Color(0.6, 0.6, 0.65, 1)
uid = "uid://birndrg01"

# shadow_dragon.tres
id = "shadow_dragon"  display_name = "shadow dragon"
tier = 5  hp = 75  hd = 8  ac = 8  ev = 10  speed = 11
attacks = [{"damage": 18, "flavour": "bite"}]
resists = ["neg", "cold"]  min_depth = 23  max_depth = 24  weight = 5  xp_value = 28
tile_path = "res://assets/tiles/individual/mon/dragons/shadow_dragon.png"
glyph = "D"  glyph_color = Color(0.3, 0.2, 0.4, 1)
uid = "uid://bshaddrg1"

# storm_dragon.tres
id = "storm_dragon"  display_name = "storm dragon"
tier = 6  hp = 90  hd = 10  ac = 10  ev = 9  speed = 11
attacks = [{"damage": 22, "flavour": "bite"}]
ranged_attack = {"damage": 18, "range": 5, "verb": "blasts", "flavour": "elec"}
resists = ["elec"]  min_depth = 24  max_depth = 24  weight = 3  xp_value = 35
tile_path = "res://assets/tiles/individual/mon/dragons/storm_dragon.png"
glyph = "D"  glyph_color = Color(0.5, 0.7, 1.0, 1)
uid = "uid://bstrmdrg1"
```

- [ ] **Step 3: 커밋**
```bash
git add resources/monsters/deep_elf_*.tres resources/monsters/air_elemental.tres resources/monsters/water_elemental.tres resources/monsters/flesh_golem.tres resources/monsters/war_gargoyle.tres resources/monsters/lemure.tres resources/monsters/hell_hound.tres resources/monsters/efreet.tres resources/monsters/brimstone_fiend.tres resources/monsters/iron_dragon.tres resources/monsters/shadow_dragon.tres resources/monsters/storm_dragon.tres
git commit -m "feat: Zone 6-7 new monsters (deep elves, elementals, golems, infernal)"
```

---

## Task 6: MonsterRegistry 업데이트

**Files:**
- Modify: `scripts/systems/MonsterRegistry.gd`

- [ ] **Step 1: 신규 37개 몬스터 const 추가**

기존 패턴대로 섹션별 const 추가:
```gdscript
# ── Zone 0: Dungeon ───────────────────────────────────────────────────────────
const _KILLER_BEE: Resource = preload("res://resources/monsters/killer_bee.tres")
const _BOMBARDIER_BEETLE: Resource = preload("res://resources/monsters/bombardier_beetle.tres")

# ── Zone 1: Lair ──────────────────────────────────────────────────────────────
const _CROCODILE: Resource = preload("res://resources/monsters/crocodile.tres")
const _GIANT_LIZARD: Resource = preload("res://resources/monsters/giant_lizard.tres")
const _ANACONDA: Resource = preload("res://resources/monsters/anaconda.tres")
const _POLAR_BEAR: Resource = preload("res://resources/monsters/polar_bear.tres")
const _HIPPOGRIFF: Resource = preload("res://resources/monsters/hippogriff.tres")

# ── Zone 2: Orc Mines ─────────────────────────────────────────────────────────
const _ORC_KNIGHT: Resource = preload("res://resources/monsters/orc_knight.tres")
const _ORC_WARLORD: Resource = preload("res://resources/monsters/orc_warlord.tres")
const _ETTIN: Resource = preload("res://resources/monsters/ettin.tres")

# ── Zone 3: Swamp ─────────────────────────────────────────────────────────────
const _DEATH_YAK: Resource = preload("res://resources/monsters/death_yak.tres")
const _HYDRA: Resource = preload("res://resources/monsters/hydra.tres")
const _WILL_O_WISP: Resource = preload("res://resources/monsters/will_o_wisp.tres")
const _GIANT_CONSTRICTOR: Resource = preload("res://resources/monsters/giant_constrictor.tres")

# ── Zone 4: Crypt ─────────────────────────────────────────────────────────────
const _GHOST: Resource = preload("res://resources/monsters/ghost.tres")
const _SHADOW: Resource = preload("res://resources/monsters/shadow.tres")
const _MUMMY_PRIEST: Resource = preload("res://resources/monsters/mummy_priest.tres")
const _ANCIENT_CHAMPION: Resource = preload("res://resources/monsters/ancient_champion.tres")

# ── Zone 5: Ice Caves ─────────────────────────────────────────────────────────
const _ICE_BEAST: Resource = preload("res://resources/monsters/ice_beast.tres")
const _RIME_DRAKE: Resource = preload("res://resources/monsters/rime_drake.tres")
const _FREEZING_WRAITH: Resource = preload("res://resources/monsters/freezing_wraith.tres")
const _BLIZZARD_DEMON: Resource = preload("res://resources/monsters/blizzard_demon.tres")

# ── Zone 6: Elven Halls ───────────────────────────────────────────────────────
const _DEEP_ELF_KNIGHT: Resource = preload("res://resources/monsters/deep_elf_knight.tres")
const _DEEP_ELF_SORCERER: Resource = preload("res://resources/monsters/deep_elf_sorcerer.tres")
const _DEEP_ELF_BLADEMASTER: Resource = preload("res://resources/monsters/deep_elf_blademaster.tres")
const _DEEP_ELF_ANNIHILATOR: Resource = preload("res://resources/monsters/deep_elf_annihilator.tres")
const _DEEP_ELF_HIGH_PRIEST: Resource = preload("res://resources/monsters/deep_elf_high_priest.tres")
const _AIR_ELEMENTAL: Resource = preload("res://resources/monsters/air_elemental.tres")
const _WATER_ELEMENTAL: Resource = preload("res://resources/monsters/water_elemental.tres")
const _FLESH_GOLEM: Resource = preload("res://resources/monsters/flesh_golem.tres")
const _WAR_GARGOYLE: Resource = preload("res://resources/monsters/war_gargoyle.tres")

# ── Zone 7: Infernal ──────────────────────────────────────────────────────────
const _LEMURE: Resource = preload("res://resources/monsters/lemure.tres")
const _HELL_HOUND: Resource = preload("res://resources/monsters/hell_hound.tres")
const _EFREET: Resource = preload("res://resources/monsters/efreet.tres")
const _BRIMSTONE_FIEND: Resource = preload("res://resources/monsters/brimstone_fiend.tres")
const _IRON_DRAGON: Resource = preload("res://resources/monsters/iron_dragon.tres")
const _SHADOW_DRAGON: Resource = preload("res://resources/monsters/shadow_dragon.tres")
const _STORM_DRAGON: Resource = preload("res://resources/monsters/storm_dragon.tres")
```

- [ ] **Step 2: _ALL_MONSTERS 배열에 신규 37개 추가**

기존 `_ALL_MONSTERS` 배열 끝에 추가:
```gdscript
# zone 0
_KILLER_BEE, _BOMBARDIER_BEETLE,
# zone 1
_CROCODILE, _GIANT_LIZARD, _ANACONDA, _POLAR_BEAR, _HIPPOGRIFF,
# zone 2
_ORC_KNIGHT, _ORC_WARLORD, _ETTIN,
# zone 3
_DEATH_YAK, _HYDRA, _WILL_O_WISP, _GIANT_CONSTRICTOR,
# zone 4
_GHOST, _SHADOW, _MUMMY_PRIEST, _ANCIENT_CHAMPION,
# zone 5
_ICE_BEAST, _RIME_DRAKE, _FREEZING_WRAITH, _BLIZZARD_DEMON,
# zone 6
_DEEP_ELF_KNIGHT, _DEEP_ELF_SORCERER, _DEEP_ELF_BLADEMASTER,
_DEEP_ELF_ANNIHILATOR, _DEEP_ELF_HIGH_PRIEST,
_AIR_ELEMENTAL, _WATER_ELEMENTAL, _FLESH_GOLEM, _WAR_GARGOYLE,
# zone 7
_LEMURE, _HELL_HOUND, _EFREET, _BRIMSTONE_FIEND,
_IRON_DRAGON, _SHADOW_DRAGON, _STORM_DRAGON,
```

- [ ] **Step 3: 에디터 실행 — 각 층 이동하며 신규 몬스터 등장 확인**

- [ ] **Step 4: 커밋**
```bash
git add scripts/systems/MonsterRegistry.gd
git commit -m "feat: register 37 new monsters in MonsterRegistry"
```

---

## 완료 기준

- [ ] 기존 67개 몬스터가 올바른 존 범위에서만 등장
- [ ] 신규 37개 몬스터가 지정 존에서 등장
- [ ] 보스(golden_dragon, titan)는 depth 25에서만 등장
- [ ] MonsterRegistry.all.size() == 104
