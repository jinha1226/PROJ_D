# Equipment Slots (Helmet / Gloves / Boots) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add helmet, gloves, and boots equipment slots — each with 2–3 item tiers — so the game has 8 equipment slots total, enabling essence penalties like "block_helmet" in the future redesign.

**Architecture:** New slots follow the exact same pattern as the existing `armor`/`shield` slots in `Player.gd` — `equipped_*_id` var, `equipped_*_entry()`, `set_equipped_*()`, `refresh_ac_from_equipment()` inclusion. New `kind` values (`"helmet"`, `"gloves"`, `"boots"`) propagate into ItemRegistry, BagDialog, and SaveManager. No new systems; only additive changes.

**Tech Stack:** Godot 4.6, GDScript, `.tres` resource files.

---

## File Map

| File | Change |
|---|---|
| `resources/items/leather_cap.tres` | New — helmet tier 1 |
| `resources/items/iron_helm.tres` | New — helmet tier 2 |
| `resources/items/great_helm.tres` | New — helmet tier 3 |
| `resources/items/leather_gloves.tres` | New — gloves tier 1 |
| `resources/items/iron_gauntlets.tres` | New — gloves tier 2 |
| `resources/items/leather_boots.tres` | New — boots tier 1 |
| `resources/items/iron_greaves.tres` | New — boots tier 2 |
| `scripts/entities/Player.gd` | Add 3 vars, 3 entry(), 3 set_equipped_*(), update refresh_ac + unequip |
| `scripts/core/SaveManager.gd` | Bump SAVE_VERSION 3→4, save/load new slot IDs |
| `scripts/main/Game.gd` | Migration: read new slot IDs from save with "" fallback |
| `scripts/systems/ItemRegistry.gd` | Preloads, _ALL_ITEMS, equipment pick functions |
| `scripts/ui/BagDialog.gd` | Armor tab filter + _ALL_TAB_KINDS + equipped detection + kind color |
| `scripts/ui/StatusDialog.gd` | Show helmet/gloves/boots rows in equipment section |

---

## Task 1: New item .tres files

**Files:**
- Create: `resources/items/leather_cap.tres`
- Create: `resources/items/iron_helm.tres`
- Create: `resources/items/great_helm.tres`
- Create: `resources/items/leather_gloves.tres`
- Create: `resources/items/iron_gauntlets.tres`
- Create: `resources/items/leather_boots.tres`
- Create: `resources/items/iron_greaves.tres`

Template — copy from `resources/items/leather_armor.tres`, change `kind`, `id`, `display_name`, `tier`, `ac_bonus`, `description`. Use tile_path `""` for now (no art yet); glyph `]` for helmets, `"` for gloves, `(` for boots.

- [ ] **Step 1: Create leather_cap.tres**

```
[gd_resource type="Resource" script_class="ItemData" format=3]
[ext_resource type="Script" path="res://scripts/entities/ItemData.gd" id="1_idata"]
[resource]
script = ExtResource("1_idata")
id = "leather_cap"
display_name = "leather cap"
kind = "helmet"
tier = 1
tile_path = ""
glyph = "]"
glyph_color = Color(0.72, 0.54, 0.32, 1)
damage = 0
delay = 1.0
category = ""
brand = ""
ac_bonus = 1
ev_penalty = 0
encumbrance = 2
slot = "helmet"
effect = ""
effect_value = 0
plus = 0
description = "A simple cap of cured leather. It won't stop a sword, but it's better than nothing."
```

- [ ] **Step 2: Create iron_helm.tres**

```
id = "iron_helm"
display_name = "iron helm"
kind = "helmet"
tier = 2
glyph = "]"
glyph_color = Color(0.65, 0.7, 0.75, 1)
ac_bonus = 2
encumbrance = 4
slot = "helmet"
description = "A solid iron helmet. Protects the skull at the cost of some peripheral vision."
```
(all other fields same as leather_cap template above)

- [ ] **Step 3: Create great_helm.tres**

```
id = "great_helm"
display_name = "great helm"
kind = "helmet"
tier = 3
glyph = "]"
glyph_color = Color(0.75, 0.78, 0.85, 1)
ac_bonus = 3
encumbrance = 7
slot = "helmet"
description = "Full-faced plate steel. Offers serious protection, though you'll hear nothing coming."
```

- [ ] **Step 4: Create leather_gloves.tres**

```
id = "leather_gloves"
display_name = "leather gloves"
kind = "gloves"
tier = 1
glyph = "\""
glyph_color = Color(0.72, 0.54, 0.32, 1)
ac_bonus = 1
encumbrance = 1
slot = "gloves"
description = "Thin leather gloves. Protect the hands without limiting grip."
```

- [ ] **Step 5: Create iron_gauntlets.tres**

```
id = "iron_gauntlets"
display_name = "iron gauntlets"
kind = "gloves"
tier = 2
glyph = "\""
glyph_color = Color(0.65, 0.7, 0.75, 1)
ac_bonus = 2
encumbrance = 4
slot = "gloves"
description = "Heavy iron gauntlets. Your hands are armored; your enemies will feel it."
```

- [ ] **Step 6: Create leather_boots.tres**

```
id = "leather_boots"
display_name = "leather boots"
kind = "boots"
tier = 1
glyph = "("
glyph_color = Color(0.72, 0.54, 0.32, 1)
ac_bonus = 1
encumbrance = 2
slot = "boots"
description = "Sturdy travel boots. Protect the feet and muffle footsteps slightly."
```

- [ ] **Step 7: Create iron_greaves.tres**

```
id = "iron_greaves"
display_name = "iron greaves"
kind = "boots"
tier = 2
glyph = "("
glyph_color = Color(0.65, 0.7, 0.75, 1)
ac_bonus = 2
encumbrance = 5
slot = "boots"
description = "Plated leg armor. Heavier than boots but offers real protection below the knee."
```

- [ ] **Step 8: Commit**

```bash
git add resources/items/leather_cap.tres resources/items/iron_helm.tres resources/items/great_helm.tres resources/items/leather_gloves.tres resources/items/iron_gauntlets.tres resources/items/leather_boots.tres resources/items/iron_greaves.tres
git commit -m "feat(items): add helmet/gloves/boots item .tres files (7 items)"
```

---

## Task 2: Player.gd — new slot variables and API

**Files:**
- Modify: `scripts/entities/Player.gd`

Context: existing slots are `equipped_armor_id`, `equipped_shield_id` etc. at line ~100. `set_equipped_armor` at line ~1431 is the pattern to copy. `refresh_ac_from_equipment` at line ~736 adds armor/shield AC. `unequip_item_id` at line ~691 clears slots when an item is dropped.

- [ ] **Step 1: Add three new slot vars after line 104 (`var equipped_shield_id`)**

```gdscript
var equipped_helmet_id: String = ""
var equipped_gloves_id: String = ""
var equipped_boots_id: String = ""
```

- [ ] **Step 2: Add three entry() functions after `equipped_shield_entry()` (~line 720)**

```gdscript
func equipped_helmet_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_helmet_id:
			return entry
	return {}

func equipped_gloves_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_gloves_id:
			return entry
	return {}

func equipped_boots_entry() -> Dictionary:
	for entry in items:
		if entry.get("id", "") == equipped_boots_id:
			return entry
	return {}
```

- [ ] **Step 3: Add three set_equipped_*() functions after `set_equipped_shield()` (~line 1469)**

```gdscript
func set_equipped_helmet(id: String) -> void:
	if equipped_helmet_id != "":
		_remove_entry_affixes(equipped_helmet_entry())
	equipped_helmet_id = id
	if id != "":
		_apply_entry_affixes(equipped_helmet_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func set_equipped_gloves(id: String) -> void:
	if equipped_gloves_id != "":
		_remove_entry_affixes(equipped_gloves_entry())
	equipped_gloves_id = id
	if id != "":
		_apply_entry_affixes(equipped_gloves_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()

func set_equipped_boots(id: String) -> void:
	if equipped_boots_id != "":
		_remove_entry_affixes(equipped_boots_entry())
	equipped_boots_id = id
	if id != "":
		_apply_entry_affixes(equipped_boots_entry())
	_refresh_paperdoll()
	refresh_ac_from_equipment()
```

- [ ] **Step 4: Update `refresh_ac_from_equipment()` — add new slot AC after shield block (~line 748)**

Find the section that reads shield AC. After it, add:

```gdscript
	var helmet: ItemData = ItemRegistry.get_by_id(equipped_helmet_id) if ItemRegistry != null and equipped_helmet_id != "" else null
	if helmet != null:
		var helmet_plus: int = int(equipped_helmet_entry().get("plus", 0))
		total_ac += helmet.ac_bonus + helmet_plus

	var gloves: ItemData = ItemRegistry.get_by_id(equipped_gloves_id) if ItemRegistry != null and equipped_gloves_id != "" else null
	if gloves != null:
		var gloves_plus: int = int(equipped_gloves_entry().get("plus", 0))
		total_ac += gloves.ac_bonus + gloves_plus

	var boots: ItemData = ItemRegistry.get_by_id(equipped_boots_id) if ItemRegistry != null and equipped_boots_id != "" else null
	if boots != null:
		var boots_plus: int = int(equipped_boots_entry().get("plus", 0))
		total_ac += boots.ac_bonus + boots_plus
```

- [ ] **Step 5: Update `unequip_item_id()` — add three new unequip checks after shield (~line 700)**

```gdscript
	if id == equipped_helmet_id:
		set_equipped_helmet("")
	if id == equipped_gloves_id:
		set_equipped_gloves("")
	if id == equipped_boots_id:
		set_equipped_boots("")
```

- [ ] **Step 6: Verify in Godot — open game, F5, check no parse errors in output**

Expected: game starts normally, no "Identifier not found" errors.

- [ ] **Step 7: Commit**

```bash
git add scripts/entities/Player.gd
git commit -m "feat(player): add helmet/gloves/boots equipment slots"
```

---

## Task 3: SaveManager + migration

**Files:**
- Modify: `scripts/core/SaveManager.gd`
- Modify: `scripts/main/Game.gd`

Context: `SAVE_VERSION = 3` at line 41. Equipment is saved at lines ~71-75. `_apply_loaded_player_state` in Game.gd reads equipment fields from the save dict.

- [ ] **Step 1: Bump SAVE_VERSION in SaveManager.gd**

```gdscript
const SAVE_VERSION: int = 4
```

- [ ] **Step 2: Add new slots to the equipment save block (~line 71)**

```gdscript
		"helmet": player.equipped_helmet_id,
		"gloves": player.equipped_gloves_id,
		"boots": player.equipped_boots_id,
```
(add after `"shield": player.equipped_shield_id`)

- [ ] **Step 3: Add load for new slots in Game.gd `_apply_loaded_player_state`**

Find where `"armor"`, `"shield"` are read from the save dict. Add:

```gdscript
	var saved_helmet: String = String(data.get("equipped", {}).get("helmet", ""))
	if saved_helmet != "" and ItemRegistry.get_by_id(saved_helmet) != null:
		player.set_equipped_helmet(saved_helmet)

	var saved_gloves: String = String(data.get("equipped", {}).get("gloves", ""))
	if saved_gloves != "" and ItemRegistry.get_by_id(saved_gloves) != null:
		player.set_equipped_gloves(saved_gloves)

	var saved_boots: String = String(data.get("equipped", {}).get("boots", ""))
	if saved_boots != "" and ItemRegistry.get_by_id(saved_boots) != null:
		player.set_equipped_boots(saved_boots)
```

- [ ] **Step 4: Verify save/load round-trip — F5, equip a piece of armor, save (if save is hooked to a key or menu), reload, confirm no crash and equipped items are preserved**

Expected: no crash, old saves load cleanly with new slots empty.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/SaveManager.gd scripts/main/Game.gd
git commit -m "feat(save): bump save_version to 4, persist helmet/gloves/boots slots"
```

---

## Task 4: ItemRegistry — register new items

**Files:**
- Modify: `scripts/systems/ItemRegistry.gd`

Context: preload constants are at the top (~line 16-160). `_ALL_ITEMS` is an Array of all ItemData resources. `pick_floor_loot` at line ~540 controls loot table. `pick_equipment` and `pick_equipment_weighted` use a kind list.

- [ ] **Step 1: Add 7 preload constants after the last armor/shield preload**

```gdscript
const _LEATHER_CAP: Resource = preload("res://resources/items/leather_cap.tres")
const _IRON_HELM: Resource = preload("res://resources/items/iron_helm.tres")
const _GREAT_HELM: Resource = preload("res://resources/items/great_helm.tres")
const _LEATHER_GLOVES: Resource = preload("res://resources/items/leather_gloves.tres")
const _IRON_GAUNTLETS: Resource = preload("res://resources/items/iron_gauntlets.tres")
const _LEATHER_BOOTS: Resource = preload("res://resources/items/leather_boots.tres")
const _IRON_GREAVES: Resource = preload("res://resources/items/iron_greaves.tres")
```

- [ ] **Step 2: Add all 7 to `_ALL_ITEMS` array**

Find where armor/shield items are listed in `_ALL_ITEMS`. Add next to them:

```gdscript
	_LEATHER_CAP,
	_IRON_HELM,
	_GREAT_HELM,
	_LEATHER_GLOVES,
	_IRON_GAUNTLETS,
	_LEATHER_BOOTS,
	_IRON_GREAVES,
```

- [ ] **Step 3: Add new kinds to `pick_equipment` and `pick_equipment_weighted`**

In `pick_equipment` (~line 566):
```gdscript
func pick_equipment(depth: int) -> ItemData:
	return _pick_weighted(depth, ["weapon", "armor", "ring", "amulet", "shield", "helmet", "gloves", "boots"])
```

In `pick_equipment_weighted` (~line 569), update the `eq_kinds` array:
```gdscript
	var eq_kinds: Array[String] = ["weapon", "armor", "ring", "amulet", "shield", "helmet", "gloves", "boots"]
```

- [ ] **Step 4: Verify in Godot — F5, walk a few floors, confirm helmet/gloves/boots can appear as floor drops**

Expected: new item glyphs `]`, `"`, `(` occasionally appear on floors.

- [ ] **Step 5: Commit**

```bash
git add scripts/systems/ItemRegistry.gd
git commit -m "feat(items): register helmet/gloves/boots in ItemRegistry"
```

---

## Task 5: BagDialog — armor tab update

**Files:**
- Modify: `scripts/ui/BagDialog.gd`

Context: armor tab filter at line ~83 is `["armor", "shield"]`. `_ALL_TAB_KINDS` at line ~114 lists all known kinds. Equipped detection at line ~152 checks `equipped_armor_id` and `equipped_shield_id`. Kind→color map at line ~344.

- [ ] **Step 1: Extend armor tab filter (line ~83)**

```gdscript
		["armor", "shield", "helmet", "gloves", "boots"],   # 방어구
```

- [ ] **Step 2: Add new kinds to `_ALL_TAB_KINDS` (line ~114)**

```gdscript
	"weapon", "armor", "shield", "helmet", "gloves", "boots",
```
(add `"helmet"`, `"gloves"`, `"boots"` to the existing list)

- [ ] **Step 3: Update equipped item detection (~line 152) — add new slot checks**

```gdscript
			or sid == player.equipped_helmet_id \
			or sid == player.equipped_gloves_id \
			or sid == player.equipped_boots_id
```
(add after the `equipped_shield_id` check)

- [ ] **Step 4: Update kind→color map (~line 344) — add colors for new kinds**

```gdscript
		"helmet": return Color(0.65, 0.7, 0.75)
		"gloves": return Color(0.7, 0.65, 0.55)
		"boots":  return Color(0.6, 0.55, 0.45)
```

- [ ] **Step 5: Update equipped item check in item detail / use logic (~line 303)**

Find where `equipped_armor_id` and `equipped_shield_id` are checked to determine if an item is currently equipped. Add:

```gdscript
			or entry_id == player.equipped_helmet_id \
			or entry_id == player.equipped_gloves_id \
			or entry_id == player.equipped_boots_id
```

- [ ] **Step 6: Verify in Godot — F5, pick up a leather cap, open bag, confirm it appears in the armor tab with correct color, can be equipped/unequipped**

Expected: cap shows in armor tab, equipping it increases AC shown in status.

- [ ] **Step 7: Commit**

```bash
git add scripts/ui/BagDialog.gd
git commit -m "feat(ui): add helmet/gloves/boots to BagDialog armor tab"
```

---

## Task 6: StatusDialog — show new slots

**Files:**
- Modify: `scripts/ui/StatusDialog.gd`

Context: StatusDialog shows equipped items in a paperdoll/equipment section. Find where helmet/armor rows are built — search for `"Armor"` or `equipped_armor` in StatusDialog.gd to find the pattern.

- [ ] **Step 1: Read StatusDialog.gd to find where armor slot rows are built**

Run: `grep -n "armor\|Armor\|equipped" scripts/ui/StatusDialog.gd | head -30`

Identify the function that builds equipment rows (likely calls `_equipped_row` from BagDialog or a similar helper).

- [ ] **Step 2: Add helmet, gloves, boots rows using the same pattern as armor**

If the existing pattern is something like:

```gdscript
	rows.add_child(_equipped_row("Armor", armor_name, "AC +%d" % armor_ac))
```

Add after it:

```gdscript
	var helmet: ItemData = ItemRegistry.get_by_id(player.equipped_helmet_id) if player.equipped_helmet_id != "" else null
	var helmet_name: String = helmet.display_name if helmet != null else "—"
	var helmet_ac: int = (helmet.ac_bonus + int(player.equipped_helmet_entry().get("plus", 0))) if helmet != null else 0
	rows.add_child(_equipped_row("Helmet", helmet_name, "AC +%d" % helmet_ac if helmet != null else ""))

	var gloves_item: ItemData = ItemRegistry.get_by_id(player.equipped_gloves_id) if player.equipped_gloves_id != "" else null
	var gloves_name: String = gloves_item.display_name if gloves_item != null else "—"
	var gloves_ac: int = (gloves_item.ac_bonus + int(player.equipped_gloves_entry().get("plus", 0))) if gloves_item != null else 0
	rows.add_child(_equipped_row("Gloves", gloves_name, "AC +%d" % gloves_ac if gloves_item != null else ""))

	var boots_item: ItemData = ItemRegistry.get_by_id(player.equipped_boots_id) if player.equipped_boots_id != "" else null
	var boots_name: String = boots_item.display_name if boots_item != null else "—"
	var boots_ac: int = (boots_item.ac_bonus + int(player.equipped_boots_entry().get("plus", 0))) if boots_item != null else 0
	rows.add_child(_equipped_row("Boots", boots_name, "AC +%d" % boots_ac if boots_item != null else ""))
```

Adapt variable names to match what StatusDialog.gd actually uses — read the file first.

- [ ] **Step 3: Verify in Godot — F5, open status screen, confirm Helmet/Gloves/Boots rows appear with "—" when empty and correct names when equipped**

Expected: three new rows visible in the equipment section.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/StatusDialog.gd
git commit -m "feat(ui): show helmet/gloves/boots slots in StatusDialog"
```

---

## Task 7: Wire equip action in BagDialog item use

**Files:**
- Modify: `scripts/ui/BagDialog.gd`

Context: When a player taps "Use" on an armor/shield item, BagDialog calls `player.set_equipped_armor(id)` or `player.set_equipped_shield(id)`. Find this dispatch logic (search for `set_equipped_armor` in BagDialog.gd) and add cases for the three new kinds.

- [ ] **Step 1: Find the equip dispatch in BagDialog.gd**

Run: `grep -n "set_equipped" scripts/ui/BagDialog.gd`

- [ ] **Step 2: Add cases for helmet, gloves, boots**

The existing pattern is likely a match or if-chain on `data.kind`. Add:

```gdscript
			"helmet":
				player.set_equipped_helmet(entry_id if not is_equipped else "")
			"gloves":
				player.set_equipped_gloves(entry_id if not is_equipped else "")
			"boots":
				player.set_equipped_boots(entry_id if not is_equipped else "")
```

Where `is_equipped` = whether the item is currently in its slot (check `entry_id == player.equipped_helmet_id` etc).

- [ ] **Step 3: Verify — F5, pick up leather_cap, open bag, tap the cap, confirm it equips (AC increases, item shows as equipped in armor tab)**

- [ ] **Step 4: Also verify unequip — tap again, confirm it unequips and AC returns to previous value**

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/BagDialog.gd
git commit -m "feat(ui): wire equip/unequip for helmet/gloves/boots in BagDialog"
```

---

## Task 8: i18n for new items

**Files:**
- Modify: `i18n/translations.csv`

Context: item display names and descriptions come from `ItemData.display_name` and `ItemData.description` fields directly, so no CSV keys needed for those. However if any UI label keys reference "Armor", "Shield" slot names that need Korean equivalents, add them.

- [ ] **Step 1: Check if StatusDialog slot labels use i18n keys**

Run: `grep -n "Helmet\|Gloves\|Boots\|helmet\|gloves\|boots" scripts/ui/StatusDialog.gd`

If they use `LocaleManager.t("SLOT_HELMET")` style keys, add to translations.csv. If hardcoded English strings, add Korean equivalents.

- [ ] **Step 2: Add to translations.csv if needed**

```
SLOT_HELMET,Helmet,투구
SLOT_GLOVES,Gloves,장갑
SLOT_BOOTS,Boots,신발
```

- [ ] **Step 3: Commit**

```bash
git add i18n/translations.csv
git commit -m "feat(i18n): add helmet/gloves/boots slot name translations"
```

---

## Smoke Test Checklist

After all tasks complete, verify the full flow:

- [ ] Start a new run, walk until a helmet/gloves/boots drops on the floor
- [ ] Pick it up — appears in bag under armor tab with correct glyph color
- [ ] Equip it — AC increases by the item's ac_bonus
- [ ] Open status screen — correct slot row shows item name and AC
- [ ] Unequip — AC decreases back
- [ ] Save game (if save is accessible), reload — item is still equipped
- [ ] Old save (version 3) loads cleanly — no crash, new slots empty
- [ ] Drop an equipped helmet — slot clears, AC updates
