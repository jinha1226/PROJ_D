# Item Detail Dialog Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** When the player taps an item row in the Bag, a detail popup opens showing a large thumbnail, item name/type, description, stat comparison with the equipped item (weapons/armor), and Use/Equip + Drop buttons.

**Architecture:** Create a new static class `ItemDetailDialog` that follows the same `GameDialog` popup pattern used throughout the UI. Modify `BagDialog._build_item_row()` to remove inline action buttons and make the entire row tappable — the tap opens `ItemDetailDialog`. After any action (equip/use/drop) the detail dialog closes itself and either closes BagDialog (equip/use) or repopulates it (drop).

**Tech Stack:** Godot 4.6 GDScript, `GameDialog` base popup, `UICards` helpers, `ItemRegistry`, `GameManager`.

---

## File Structure

| File | Change |
|------|--------|
| `scripts/ui/ItemDetailDialog.gd` | **Create** — new static class, full detail popup |
| `scripts/ui/BagDialog.gd` | **Modify** — remove inline buttons, wire row tap to ItemDetailDialog |

---

### Task 1: Create ItemDetailDialog.gd

**Files:**
- Create: `scripts/ui/ItemDetailDialog.gd`

- [ ] **Step 1: Create the file with the open() entry point and helpers**

```gdscript
class_name ItemDetailDialog extends RefCounted

const THUMB_SIZE := 72

## Opens the item detail popup.
## item_index: index into player.items[]
## player: the Player node
## bag_dlg: the BagDialog GameDialog (to close/repopulate after action)
## parent: node to add_child the new dialog to (typically the Game scene)
static func open(item_index: int, player: Player,
		bag_dlg: GameDialog, parent: Node) -> void:
	if item_index < 0 or item_index >= player.items.size():
		return
	var entry: Dictionary = player.items[item_index]
	var data: ItemData = ItemRegistry.get_by_id(String(entry.get("id", "")))
	if data == null:
		return
	var plus: int = int(entry.get("plus", 0))

	var dlg: GameDialog = GameDialog.create(GameManager.display_name_of(data.id)
			+ ("  +%d" % plus if plus > 0 else ""))
	parent.add_child(dlg)

	var body: VBoxContainer = dlg.body()
	if body == null:
		return
	body.add_theme_constant_override("separation", 14)

	body.add_child(_build_header(data, plus))
	body.add_child(_build_description(data))
	body.add_child(_build_stats_card(data, plus))

	var cmp := _build_comparison(data, plus, player)
	if cmp != null:
		body.add_child(cmp)

	body.add_child(_build_buttons(item_index, data, player, dlg, bag_dlg))
```

- [ ] **Step 2: Add `_build_header` — thumbnail + type pill**

```gdscript
static func _build_header(data: ItemData, plus: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Thumbnail (72×72)
	var thumb := Control.new()
	thumb.custom_minimum_size = Vector2(THUMB_SIZE, THUMB_SIZE)
	thumb.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if data.tile_path != "" and ResourceLoader.exists(data.tile_path):
		var rect := TextureRect.new()
		rect.texture = load(data.tile_path) as Texture2D
		rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		rect.anchor_right = 1.0
		rect.anchor_bottom = 1.0
		rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(rect)
	if GameManager.is_identified(data.id) and data.identified_tile_path != "" \
			and ResourceLoader.exists(data.identified_tile_path):
		var overlay := TextureRect.new()
		overlay.texture = load(data.identified_tile_path) as Texture2D
		overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		overlay.anchor_right = 1.0
		overlay.anchor_bottom = 1.0
		overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
		thumb.add_child(overlay)
	row.add_child(thumb)

	# Right side: kind pill + enchant label
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	right.add_theme_constant_override("separation", 6)

	var pill_row := HBoxContainer.new()
	pill_row.add_child(UICards.pill(_kind_label(data.kind), _kind_color(data.kind)))
	right.add_child(pill_row)

	if data.kind == "weapon" and data.category != "":
		right.add_child(UICards.dim_hint(data.category.capitalize(), 26))
	elif data.kind == "armor" and data.slot != "":
		right.add_child(UICards.dim_hint(data.slot.capitalize(), 26))

	row.add_child(right)
	return row
```

- [ ] **Step 3: Add `_build_description` — word-wrapped description text**

```gdscript
static func _build_description(data: ItemData) -> Control:
	var text: String = data.description if data.description != "" \
		else _effect_desc(data)
	var lbl := Label.new()
	lbl.text = text
	lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.78, 0.78, 0.85))
	return lbl

static func _effect_desc(data: ItemData) -> String:
	if not GameManager.is_identified(data.id):
		return "정체를 알 수 없다..."
	match data.effect:
		"heal":            return "HP +%d 회복" % data.effect_value
		"restore_mp":      return "MP +%d 회복" % data.effect_value
		"map_reveal":      return "현재 층 맵 공개"
		"blink":           return "단거리 순간이동"
		"cure":            return "독 치료"
		"teleport":        return "랜덤 순간이동"
		"enchant_weapon":  return "무기 +1 인챈트"
		"enchant_armor":   return "방어구 +1 인챈트"
		"berserk":         return "광란 상태 — 공격력 ↑, HP 소모"
		"identify":        return "아이템 감정"
		"study":           return "주문 습득 (마법책)"
		"might":           return "힘 일시 강화"
	return data.effect if data.effect != "" else "(설명 없음)"
```

- [ ] **Step 4: Add `_build_stats_card` — weapon/armor/consumable stats**

```gdscript
static func _build_stats_card(data: ItemData, plus: int) -> Control:
	var card := UICards.card(Color(0.5, 0.6, 0.8))
	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 6)
	card.add_child(vbox)

	match data.kind:
		"weapon":
			vbox.add_child(UICards.dim_hint("STATS", 22))
			var dmg_row := HBoxContainer.new()
			dmg_row.add_child(_stat_label("Damage"))
			dmg_row.add_child(UICards.accent_value("d%d" % (data.damage + plus), 30))
			vbox.add_child(dmg_row)
			if data.brand != "":
				var brand_row := HBoxContainer.new()
				brand_row.add_child(_stat_label("Brand"))
				brand_row.add_child(UICards.accent_value(data.brand.capitalize(), 30))
				vbox.add_child(brand_row)
		"armor":
			vbox.add_child(UICards.dim_hint("STATS", 22))
			var ac_row := HBoxContainer.new()
			ac_row.add_child(_stat_label("AC"))
			ac_row.add_child(UICards.accent_value("+%d" % (data.ac_bonus + plus), 30))
			vbox.add_child(ac_row)
			if data.ev_penalty > 0:
				var ev_row := HBoxContainer.new()
				ev_row.add_child(_stat_label("EV Penalty"))
				ev_row.add_child(UICards.accent_value("-%d" % data.ev_penalty, 30))
				vbox.add_child(ev_row)
		"potion", "scroll", "book":
			vbox.add_child(UICards.dim_hint("EFFECT", 22))
			vbox.add_child(UICards.accent_value(_effect_desc(data), 28))
		_:
			vbox.add_child(UICards.dim_hint("(기타 아이템)", 26))

	return card

static func _stat_label(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.custom_minimum_size = Vector2(160, 0)
	lbl.add_theme_font_size_override("font_size", 26)
	lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	return lbl
```

- [ ] **Step 5: Add `_build_comparison` — stat delta vs equipped item (weapon/armor only)**

```gdscript
## Returns a comparison card, or null if no comparison is applicable.
static func _build_comparison(data: ItemData, plus: int, player: Player) -> Control:
	if data.kind == "weapon":
		var ew: ItemData = ItemRegistry.get_by_id(player.equipped_weapon_id)
		if ew == null:
			return null
		var ew_plus: int = int(player.equipped_weapon_entry().get("plus", 0))
		var old_dmg: int = ew.damage + ew_plus
		var new_dmg: int = data.damage + plus
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint("vs 장착: %s" % ew.display_name, 22))
		vbox.add_child(_delta_row("Damage", old_dmg, new_dmg, "d%d", "d%d"))
		return card
	elif data.kind == "armor":
		var ea: ItemData = ItemRegistry.get_by_id(player.equipped_armor_id)
		if ea == null:
			return null
		var ea_plus: int = int(player.equipped_armor_entry().get("plus", 0))
		var old_ac: int = ea.ac_bonus + ea_plus
		var new_ac: int = data.ac_bonus + plus
		var card := UICards.card(Color(0.3, 0.7, 0.4))
		var vbox := VBoxContainer.new()
		vbox.add_theme_constant_override("separation", 6)
		card.add_child(vbox)
		vbox.add_child(UICards.dim_hint("vs 장착: %s" % ea.display_name, 22))
		vbox.add_child(_delta_row("AC", old_ac, new_ac, "+%d", "+%d"))
		if data.ev_penalty != ea.ev_penalty:
			vbox.add_child(_delta_row("EV Penalty",
					ea.ev_penalty, data.ev_penalty, "-%d", "-%d"))
		return card
	return null

## Builds one comparison row: "Damage   d5 → d10  (+5 ▲)"
static func _delta_row(stat: String, old_val: int, new_val: int,
		old_fmt: String, new_fmt: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var key_lbl := Label.new()
	key_lbl.text = stat
	key_lbl.custom_minimum_size = Vector2(140, 0)
	key_lbl.add_theme_font_size_override("font_size", 26)
	key_lbl.add_theme_color_override("font_color", Color(0.65, 0.65, 0.75))
	row.add_child(key_lbl)

	var old_lbl := Label.new()
	old_lbl.text = old_fmt % old_val
	old_lbl.add_theme_font_size_override("font_size", 26)
	old_lbl.add_theme_color_override("font_color", Color(0.55, 0.55, 0.55))
	row.add_child(old_lbl)

	var arrow := Label.new()
	arrow.text = " → "
	arrow.add_theme_font_size_override("font_size", 26)
	arrow.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	row.add_child(arrow)

	var delta: int = new_val - old_val
	var new_lbl := Label.new()
	new_lbl.text = (new_fmt % new_val) + ("  (+%d ▲)" % delta if delta > 0
			else ("  (%d ▼)" % delta if delta < 0 else "  (=)"))
	new_lbl.add_theme_font_size_override("font_size", 26)
	new_lbl.add_theme_color_override("font_color",
			Color(0.4, 1.0, 0.5) if delta > 0
			else (Color(1.0, 0.4, 0.4) if delta < 0 else Color(0.7, 0.7, 0.7)))
	row.add_child(new_lbl)

	return row
```

- [ ] **Step 6: Add `_build_buttons` — action (Equip/Use/Read) + Drop**

```gdscript
static func _build_buttons(item_index: int, data: ItemData, player: Player,
		detail_dlg: GameDialog, bag_dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)

	# Action button
	var action_btn := Button.new()
	action_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	action_btn.custom_minimum_size = Vector2(0, 72)
	action_btn.add_theme_font_size_override("font_size", 28)
	match data.kind:
		"weapon":
			if player.equipped_weapon_id == data.id:
				action_btn.text = "장착 중"
				action_btn.disabled = true
			else:
				action_btn.text = "장착"
				action_btn.pressed.connect(func():
					player.set_equipped_weapon(String(player.items[item_index].get("id","")))
					CombatLog.post("You equip %s." % data.display_name)
					detail_dlg.close()
					bag_dlg.close()
					TurnManager.end_player_turn())
		"armor":
			if player.equipped_armor_id == data.id:
				action_btn.text = "장착 중"
				action_btn.disabled = true
			else:
				action_btn.text = "장착"
				action_btn.pressed.connect(func():
					player.set_equipped_armor(String(player.items[item_index].get("id","")))
					CombatLog.post("You don %s." % data.display_name)
					detail_dlg.close()
					bag_dlg.close()
					TurnManager.end_player_turn())
		"book":
			action_btn.text = "읽기"
			action_btn.pressed.connect(func():
				player.use_item(item_index)
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
		_:
			action_btn.text = "사용"
			action_btn.pressed.connect(func():
				player.use_item(item_index)
				detail_dlg.close()
				bag_dlg.close()
				TurnManager.end_player_turn())
	row.add_child(action_btn)

	# Drop button
	var drop_btn := Button.new()
	drop_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	drop_btn.custom_minimum_size = Vector2(0, 72)
	drop_btn.add_theme_font_size_override("font_size", 28)
	drop_btn.text = "버리기"
	drop_btn.add_theme_color_override("font_color", Color(1.0, 0.5, 0.5))
	drop_btn.pressed.connect(func():
		player.drop_item(item_index)
		detail_dlg.close()
		BagDialog._populate(bag_dlg, player))
	row.add_child(drop_btn)

	return row
```

- [ ] **Step 7: Add kind label and color helpers**

```gdscript
static func _kind_label(kind: String) -> String:
	match kind:
		"weapon": return "무기"
		"armor":  return "방어구"
		"potion": return "포션"
		"scroll": return "스크롤"
		"book":   return "마법책"
		"gold":   return "골드"
		_:        return kind.capitalize()

static func _kind_color(kind: String) -> Color:
	match kind:
		"weapon": return Color(1.0, 0.75, 0.4)
		"armor":  return Color(0.55, 0.8, 1.0)
		"potion": return Color(0.5, 1.0, 0.6)
		"scroll": return Color(1.0, 0.95, 0.55)
		"book":   return Color(0.7, 0.55, 1.0)
		_:        return Color(0.75, 0.75, 0.75)
```

- [ ] **Step 8: Verify the file compiles (open Godot editor or run project, check for parse errors)**

Expected: no errors in Output panel referencing ItemDetailDialog.gd.

- [ ] **Step 9: Commit**

```bash
git add scripts/ui/ItemDetailDialog.gd
git commit -m "feat: ItemDetailDialog — thumbnail, stats, comparison, use/drop"
```

---

### Task 2: Wire BagDialog item rows to open ItemDetailDialog

**Files:**
- Modify: `scripts/ui/BagDialog.gd:115-173` — `_build_item_row` function

- [ ] **Step 1: Remove inline action buttons from `_build_item_row`**

Replace the entire `_build_item_row` function body. The new version removes the `btn_row` HBoxContainer and all the inline match/button logic, and instead makes the whole row tappable:

```gdscript
static func _build_item_row(data: ItemData, indices: Array, plus: int,
		player: Player, dlg: GameDialog) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	row.add_child(_make_thumbnail(data))

	var name_lbl := Label.new()
	var label_text: String = GameManager.display_name_of(data.id)
	if plus > 0:
		label_text += " +%d" % plus
	if data.kind == "weapon" and data.damage > 0:
		label_text += "  (d%d)" % (data.damage + plus)
	elif data.kind == "armor" and data.ac_bonus > 0:
		label_text += "  (+%d AC)" % (data.ac_bonus + plus)
	if indices.size() > 1:
		label_text += "  x%d" % indices.size()
	name_lbl.text = label_text
	name_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", _item_color(data.kind))
	row.add_child(name_lbl)

	# Chevron hint ">"
	var hint := Label.new()
	hint.text = "›"
	hint.add_theme_font_size_override("font_size", 36)
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.55))
	hint.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(hint)

	# Make entire row tappable
	var first: int = indices[0]
	row.mouse_filter = Control.MOUSE_FILTER_STOP
	row.gui_input.connect(func(ev: InputEvent) -> void:
		var tapped := false
		if ev is InputEventMouseButton \
				and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
			tapped = true
		elif ev is InputEventScreenTouch and ev.pressed:
			tapped = true
		if tapped:
			ItemDetailDialog.open(first, player, dlg, dlg.get_parent()))

	return row
```

- [ ] **Step 2: Remove now-unused `_action_btn`, `_equip_weapon`, `_equip_armor`, `_use_item`, `_drop_item` static functions from BagDialog.gd**

These are the functions at lines 176–224 in the original file. Delete them entirely — they are now handled exclusively inside ItemDetailDialog.

The only helper to keep: `_name_of` (still used by nothing now — delete it too).

After deletion, the BagDialog.gd static functions remaining are:
- `open`
- `_populate`
- `_equipped_row`
- `_make_thumbnail`
- `_build_item_row` (updated above)
- `_item_color`

- [ ] **Step 3: Verify the file compiles**

Open Godot editor or run the project. Check Output panel for parse errors referencing BagDialog.gd. Expected: no errors.

- [ ] **Step 4: Smoke test — open the bag in-game, tap an item row**

1. Run the project (F5) with Archmage, open the bag (tap the bag icon)
2. Tap any item row → ItemDetailDialog should open
3. Verify: thumbnail visible, item name in title, description text, stats card, comparison card (for weapons/armor), action button + drop button
4. Tap "사용"/"장착" → both dialogs close, item is used/equipped, turn ends
5. Open bag again, tap an item, tap "버리기" → detail dialog closes, bag stays open and shows updated inventory

- [ ] **Step 5: Commit**

```bash
git add scripts/ui/BagDialog.gd
git commit -m "feat: BagDialog rows tap to ItemDetailDialog, remove inline buttons"
```
