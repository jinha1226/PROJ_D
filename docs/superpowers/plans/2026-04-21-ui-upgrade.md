# UI Upgrade Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Unify all dialog chrome under a single `GameDialog` class, upgrade the big-4 gameplay dialogs (Bag / Skills / Magic / Map) with section-headers and selected card highlights, and split the Skills ACTIVE tab into `Training` / `Learned` sub-sections that reshuffle on toggle.

**Architecture:** Introduce two new modules — `GameDialog` (CanvasLayer popup with dim / panel / scroll / bottom-Close) and `UICards` (static style helpers for section headers, cards, accent values, pills). All ~12 `AcceptDialog.new()` call-sites in `GameBootstrap.gd` migrate to `GameDialog.create(title, size)`. The Status window's existing card vocabulary becomes the reference, and its inline helpers move into `UICards` as a side effect of the migration.

**Tech Stack:** Godot 4 / GDScript. Existing `GameTheme` palette reused. No test framework — verification is running the project and confirming visual / interaction behaviour per task.

**Source spec:** `docs/superpowers/specs/2026-04-21-ui-upgrade-design.md`

---

## File Structure

**New:**
- `scripts/ui/GameDialog.gd` — popup class (CanvasLayer root).
- `scenes/ui/GameDialog.tscn` — scene wiring Dim + Window + Body + CloseButton.
- `scripts/ui/UICards.gd` — static helpers: `section_header`, `card`, `accent_value`, `dim_hint`, `pill`.

**Modified:**
- `scripts/core/GameBootstrap.gd` — every `AcceptDialog.new()` call-site replaced with `GameDialog.create(...)`; Status card helpers delegated to `UICards`; Skills `_build_skill_rows` routes through `_build_active_tab` for the new split; Bag adds an Equipped card grid; Magic adds school pills; Map adds section header + legend.

**Unchanged:** `scripts/ui/GameTheme.gd`, everything outside `scripts/core/` + `scripts/ui/`.

---

## Task 1: GameDialog scaffold

**Files:**
- Create: `scripts/ui/GameDialog.gd`
- Create: `scenes/ui/GameDialog.tscn`

- [ ] **Step 1: Create `scripts/ui/GameDialog.gd`**

```gdscript
class_name GameDialog
extends CanvasLayer

signal closed

const _DEFAULT_CLOSE_TEXT := "Close"

var _on_close_cb: Callable = Callable()
var _window_rect: Rect2 = Rect2()
var _closed: bool = false

@onready var _dim: ColorRect = $Dim
@onready var _window: PanelContainer = $Dim/Window
@onready var _title_label: Label = $Dim/Window/Margin/VBox/TitleRow/TitleLabel
@onready var _body_vbox: VBoxContainer = $Dim/Window/Margin/VBox/Body/BodyVBox
@onready var _close_button: Button = $Dim/Window/Margin/VBox/CloseButton

static func create(title: String, size: Vector2i) -> GameDialog:
	var scene: PackedScene = load("res://scenes/ui/GameDialog.tscn")
	var dlg: GameDialog = scene.instantiate()
	dlg.call_deferred("_apply_initial", title, size)
	return dlg

func _apply_initial(title: String, size: Vector2i) -> void:
	_title_label.text = title
	_window.custom_minimum_size = Vector2(size.x, size.y)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_dim.gui_input.connect(_on_dim_input)
	_close_button.pressed.connect(close)

func body() -> VBoxContainer:
	return _body_vbox

func set_close_text(text: String) -> void:
	_close_button.text = text

func set_on_close(cb: Callable) -> void:
	_on_close_cb = cb

func close() -> void:
	if _closed:
		return
	_closed = true
	if _on_close_cb.is_valid():
		_on_close_cb.call()
	closed.emit()
	queue_free()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		close()
		accept_event()

func _on_dim_input(event: InputEvent) -> void:
	var is_click := false
	if event is InputEventMouseButton and event.pressed:
		is_click = true
	elif event is InputEventScreenTouch and event.pressed:
		is_click = true
	if not is_click:
		return
	var pos: Vector2 = event.position if "position" in event else Vector2.ZERO
	if not _window.get_global_rect().has_point(pos):
		close()
		accept_event()
```

- [ ] **Step 2: Create `scenes/ui/GameDialog.tscn`**

In the Godot editor:
1. New Scene → `CanvasLayer` root, rename to `GameDialog`, attach `GameDialog.gd`.
2. Set `layer = 100` on the CanvasLayer (render above gameplay).
3. Add `ColorRect` child named `Dim`:
   - `anchors_preset = 15` (full rect)
   - `color = Color(0, 0, 0, 0.6)`
   - `mouse_filter = STOP`
4. Inside `Dim`, add `PanelContainer` named `Window`:
   - `anchors_preset = 8` (center)
   - `custom_minimum_size = Vector2(900, 1200)` (placeholder; overridden by `create()`)
5. Inside `Window`, add `MarginContainer` named `Margin`, margins 16 each side.
6. Inside `Margin`, add `VBoxContainer` named `VBox`, `theme_override_constants/separation = 16`.
7. Inside `VBox`, add children in order:
   - `HBoxContainer` named `TitleRow` → inside it `Label` named `TitleLabel` (text "Title", font_size 52, custom color `(1.0, 0.85, 0.40)`, size_flags_horizontal EXPAND_FILL).
   - `ScrollContainer` named `Body`, `size_flags_vertical = EXPAND_FILL`, `custom_minimum_size = Vector2(0, 600)`, `horizontal_scroll_mode = DISABLED` → inside it `VBoxContainer` named `BodyVBox`, `size_flags_horizontal = EXPAND_FILL`, `theme_override_constants/separation = 12`.
   - `Button` named `CloseButton`: text "Close", `font_size = 40`, `custom_minimum_size = Vector2(0, 96)`, `size_flags_horizontal = EXPAND_FILL`.
8. Save scene.

- [ ] **Step 3: Smoke-test**

Run Godot, open the project. Verify the scene compiles. In a throwaway test scene, add a `Node` script:

```gdscript
func _ready() -> void:
	var dlg := GameDialog.create("Test Dialog", Vector2i(900, 1200))
	add_child(dlg)
	var lbl := Label.new()
	lbl.text = "Hello"
	lbl.add_theme_font_size_override("font_size", 40)
	dlg.body().add_child(lbl)
```

Expected: dim background, centered panel, gold title, body label, full-width bottom Close. Clicking outside or pressing ESC closes. Clicking inside the panel does not close.

- [ ] **Step 4: Commit**

```bash
git add scripts/ui/GameDialog.gd scenes/ui/GameDialog.tscn
git commit -m "feat: GameDialog popup scaffold (dim/panel/scroll/close)"
```

---

## Task 2: UICards helpers

**Files:**
- Create: `scripts/ui/UICards.gd`

- [ ] **Step 1: Create `scripts/ui/UICards.gd`**

```gdscript
class_name UICards
extends Object

const GOLD := Color(1.0, 0.85, 0.40)
const HINT := Color(0.78, 0.78, 0.85)
const ACCENT_GOLD := Color(0.85, 0.72, 0.30)

static func section_header(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 52)
	lbl.add_theme_color_override("font_color", GOLD)
	return lbl

static func card(tint: Color) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.15, tint.g * 0.15, tint.b * 0.15, 0.8)
	sb.border_color = tint
	sb.border_width_left = 3
	sb.border_width_top = 3
	sb.border_width_right = 3
	sb.border_width_bottom = 3
	sb.corner_radius_top_left = 6
	sb.corner_radius_top_right = 6
	sb.corner_radius_bottom_left = 6
	sb.corner_radius_bottom_right = 6
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 12
	sb.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", sb)
	return panel

static func accent_value(text: String, size: int = 42) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", ACCENT_GOLD)
	return lbl

static func dim_hint(text: String) -> Label:
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 34)
	lbl.modulate = HINT
	return lbl

static func pill(text: String, tint: Color) -> Control:
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(tint.r * 0.25, tint.g * 0.25, tint.b * 0.25, 0.9)
	sb.border_color = tint
	sb.border_width_left = 2
	sb.border_width_top = 2
	sb.border_width_right = 2
	sb.border_width_bottom = 2
	sb.corner_radius_top_left = 10
	sb.corner_radius_top_right = 10
	sb.corner_radius_bottom_left = 10
	sb.corner_radius_bottom_right = 10
	sb.content_margin_left = 10
	sb.content_margin_right = 10
	sb.content_margin_top = 4
	sb.content_margin_bottom = 4
	panel.add_theme_stylebox_override("panel", sb)
	var lbl := Label.new()
	lbl.text = text
	lbl.add_theme_font_size_override("font_size", 28)
	lbl.add_theme_color_override("font_color", tint)
	panel.add_child(lbl)
	return panel

# Canonical per-school colours used by Magic pills.
const SCHOOL_COLOURS := {
	"conjurations": Color(0.95, 0.95, 1.00),
	"hexes":        Color(0.75, 0.50, 1.00),
	"charms":       Color(1.00, 0.65, 0.85),
	"necromancy":   Color(0.60, 0.30, 0.70),
	"summonings":   Color(0.50, 0.95, 0.55),
	"translocations": Color(0.55, 1.00, 0.85),
	"fire":         Color(1.00, 0.55, 0.25),
	"ice":          Color(0.55, 0.85, 1.00),
	"earth":        Color(0.75, 0.55, 0.30),
	"air":          Color(0.70, 0.85, 1.00),
	"poison":       Color(0.75, 0.95, 0.35),
}

static func school_colour(school: String) -> Color:
	return SCHOOL_COLOURS.get(school, Color(0.70, 0.70, 0.70))
```

- [ ] **Step 2: Smoke-test**

Run Godot, open the project. The new class registers. No visible change.

- [ ] **Step 3: Commit**

```bash
git add scripts/ui/UICards.gd
git commit -m "feat: UICards static helpers (section_header/card/pill/accent_value)"
```

---

## Task 3: Migrate Status dialog to GameDialog

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — `_on_status_pressed` (~line 4421) and helpers `_status_section_header`, `_status_attr_card`.

- [ ] **Step 1: Replace AcceptDialog construction**

In `_on_status_pressed`, replace lines 4429-4438 (AcceptDialog setup + scroll) and the popup_centered + signal wiring at 4468-4474, plus the manual bottom-Close at 4461-4466 which becomes redundant.

Replace the entire `_on_status_pressed` body from `var dlg := AcceptDialog.new()` through `dlg.popup_centered(Vector2i(960, 1800))` with:

```gdscript
	var dlg := GameDialog.create("Status", Vector2i(960, 1800))
	popup_mgr.add_child(dlg)
	_status_dlg = dlg
	dlg.set_on_close(func():
		if _status_dlg == dlg: _status_dlg = null)

	var vb: VBoxContainer = dlg.body()
	_status_build_header(vb)
	_status_build_vitals(vb)
	_status_build_piety(vb)
	_status_build_attributes(vb)
	_status_build_combat(vb)
	_status_build_equipment(vb)
	_status_build_rings(vb)
	_status_build_resistances(vb)
	_status_build_trait(vb)

	if essence_system != null and essence_system.slots.size() > 0:
		vb.add_child(_status_section_header("Essences"))
		for i in essence_system.slots.size():
			vb.add_child(_build_essence_row(i, dlg))
```

Note: `_build_essence_row` currently takes `AcceptDialog`. Update its parameter type to `GameDialog` (same-file edit — search for `_build_essence_row(` signature and change the type).

- [ ] **Step 2: Delegate card helpers to UICards**

Replace `_status_section_header` body (the entire function body):

```gdscript
func _status_section_header(text: String) -> Label:
	return UICards.section_header(text)
```

Replace `_status_attr_card` body (entire body — currently builds its own StyleBoxFlat). Keep the outer signature (`label`, `value`, `tint`):

```gdscript
func _status_attr_card(label: String, value: int, tint: Color) -> Control:
	var panel: PanelContainer = UICards.card(tint)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = label
	name_lbl.add_theme_font_size_override("font_size", 40)
	name_lbl.add_theme_color_override("font_color", tint)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(name_lbl)
	var val_lbl := Label.new()
	val_lbl.text = str(value)
	val_lbl.add_theme_font_size_override("font_size", 56)
	val_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(val_lbl)
	return panel
```

- [ ] **Step 3: Update `_close_all_dialogs`**

Find `_close_all_dialogs` and make sure it handles both `AcceptDialog` and `GameDialog` for `_status_dlg` (and any other refs touched later). Since `_status_dlg` is still declared `var _status_dlg: AcceptDialog = null`, update its type:

```gdscript
var _status_dlg: GameDialog = null
```

Inside `_close_all_dialogs`, replace `if is_instance_valid(_status_dlg): _status_dlg.queue_free()` with:

```gdscript
	if _status_dlg != null and is_instance_valid(_status_dlg):
		_status_dlg.close()
```

- [ ] **Step 4: Verify in Godot**

Run the project, open Status. Verify:
- Single bottom-Close button (no top-right OK as previously).
- All cards render identically (STR/DEX/INT tint unchanged).
- Section headers stay gold 52pt.
- ESC / tap-outside / Close all dismiss.

- [ ] **Step 5: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "refactor: Status dialog uses GameDialog + UICards"
```

---

## Task 4: Skills dialog migration + ACTIVE split

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — `_open_skills_dialog`, `_on_skill_training_toggled`, `_skills_dlg` type.

- [ ] **Step 1: Change `_skills_dlg` type**

Find `var _skills_dlg: AcceptDialog = null` (and `_skills_swipe_dlg`) and change to `GameDialog`:

```gdscript
var _skills_dlg: GameDialog = null
var _skills_swipe_dlg: GameDialog = null
```

- [ ] **Step 2: Rewrite `_open_skills_dialog`**

Replace the entire function body (currently line 2635ish to 2723) with:

```gdscript
func _open_skills_dialog(category: String = "active") -> void:
	if _skills_dlg != null and is_instance_valid(_skills_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	if player == null:
		return
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null:
		return

	var dlg := GameDialog.create("Skills", Vector2i(960, 1500))
	popup_mgr.add_child(dlg)
	_skills_dlg = dlg
	dlg.set_on_close(func():
		if _skills_dlg == dlg: _skills_dlg = null)

	var vb: VBoxContainer = dlg.body()

	var tabs_hbox := HBoxContainer.new()
	tabs_hbox.add_theme_constant_override("separation", 4)
	for cat in _SKILL_CATEGORIES:
		var tb := Button.new()
		tb.text = _SKILL_CATEGORY_LABELS.get(cat, cat)
		tb.custom_minimum_size = Vector2(0, 80)
		tb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tb.toggle_mode = true
		tb.button_pressed = (cat == category)
		tb.add_theme_font_size_override("font_size", 44)
		tb.pressed.connect(_on_skills_tab.bind(cat, dlg))
		tabs_hbox.add_child(tb)
	vb.add_child(tabs_hbox)

	_skills_swipe_dlg = dlg
	_skills_swipe_category = category
	vb.mouse_filter = Control.MOUSE_FILTER_PASS
	vb.gui_input.connect(_on_skills_swipe_input)

	var rows := VBoxContainer.new()
	rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	rows.add_theme_constant_override("separation", 4)
	vb.add_child(rows)

	var state: Dictionary = {}
	if "skill_state" in player and player.skill_state is Dictionary:
		state = player.skill_state

	if category == "active":
		_build_active_tab(rows, state)
	else:
		var any_shown := false
		for skill_id in SkillSystem.SKILL_IDS:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			if cat_id != category:
				continue
			var entry: Dictionary = state.get(skill_id, {})
			rows.add_child(_build_skill_row(skill_id, cat_id, entry))
			any_shown = true
		if not any_shown:
			rows.add_child(UICards.dim_hint("No skills in this category."))
```

- [ ] **Step 3: Add `_build_active_tab` helper**

Place right after `_open_skills_dialog`:

```gdscript
func _build_active_tab(rows: VBoxContainer, state: Dictionary) -> void:
	var training_ids: Array = []
	var learned_ids: Array = []
	for skill_id in SkillSystem.SKILL_IDS:
		var entry: Dictionary = state.get(skill_id, {})
		var is_training: bool = bool(entry.get("training", false))
		var lv: int = int(entry.get("level", 0))
		if is_training:
			training_ids.append(skill_id)
		elif lv > 0:
			learned_ids.append(skill_id)
	if training_ids.is_empty() and learned_ids.is_empty():
		var hint := UICards.dim_hint("No skills trained yet.\nEnable skills in the other tabs.")
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		rows.add_child(hint)
		return
	if not training_ids.is_empty():
		rows.add_child(UICards.section_header("Training"))
		for skill_id in training_ids:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))
	if not learned_ids.is_empty():
		rows.add_child(UICards.section_header("Learned"))
		for skill_id in learned_ids:
			var cat_id: String = String(SkillSystem.SKILL_CATEGORY.get(skill_id, ""))
			rows.add_child(_build_skill_row(skill_id, cat_id, state.get(skill_id, {})))
```

- [ ] **Step 4: Trigger rebuild on toggle when ACTIVE is open**

Modify `_on_skill_training_toggled`:

```gdscript
func _on_skill_training_toggled(pressed: bool, skill_id: String) -> void:
	if skill_system == null or player == null:
		return
	skill_system.set_training(player, skill_id, pressed)
	if _skills_swipe_category == "active" and _skills_dlg != null and is_instance_valid(_skills_dlg):
		var cat: String = _skills_swipe_category
		_skills_dlg.close()
		_open_skills_dialog(cat)
```

- [ ] **Step 5: Update `_on_skills_tab`**

```gdscript
func _on_skills_tab(cat: String, dlg: GameDialog) -> void:
	dlg.close()
	_open_skills_dialog(cat)
```

- [ ] **Step 6: Verify in Godot**

Open Skills. Ensure ACTIVE is the default tab. With a fresh character (nothing trained), verify empty-state hint.

Train Axe → check the box. Verify:
- "Training" gold header appears with Axe row underneath.
- "Learned" header does not appear.

Uncheck Axe. Verify:
- "Training" header disappears.
- "Learned" header appears with Axe row (checkbox unchecked).

Re-check Axe. Verify it moves back to "Training".

Switch to WEAPON tab then back to ACTIVE — state persists, rows render correctly.

- [ ] **Step 7: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "feat: Skills ACTIVE tab splits into Training / Learned; uses GameDialog"
```

---

## Task 5: Bag dialog migration + Equipped card grid

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — `_on_bag_pressed`, `_build_equipped_section` (or its replacement), handlers that take `AcceptDialog`.

- [ ] **Step 1: Change `_bag_dlg` type**

```gdscript
var _bag_dlg: GameDialog = null
```

- [ ] **Step 2: Rewrite `_on_bag_pressed` header + tabs**

Replace lines 3629-3670 (from `var dlg := AcceptDialog.new()` through the end of the cat_tabs loop) with:

```gdscript
	var dlg := GameDialog.create("Bag", Vector2i(960, 1700))
	popup_mgr.add_child(dlg)
	_bag_dlg = dlg
	dlg.set_on_close(func():
		if _bag_dlg == dlg: _bag_dlg = null)
	var vb: VBoxContainer = dlg.body()

	var cat_tabs := HBoxContainer.new()
	cat_tabs.add_theme_constant_override("separation", 4)
	for cat in _BAG_CATEGORIES:
		var tab_btn := Button.new()
		tab_btn.text = cat.to_upper()
		tab_btn.custom_minimum_size = Vector2(0, 64)
		tab_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tab_btn.add_theme_font_size_override("font_size", 44)
		if cat == _bag_category:
			tab_btn.modulate = Color(1.0, 1.0, 0.75)
			tab_btn.disabled = true
		tab_btn.pressed.connect(func():
			_bag_category = cat
			dlg.close()
			_on_bag_pressed())
		cat_tabs.add_child(tab_btn)
	vb.add_child(cat_tabs)
```

- [ ] **Step 3: Remove the tail of `_on_bag_pressed`**

Delete lines from `popup_mgr.add_child(dlg)` through `dlg.popup_centered(...)` at 3772-3779 — they became redundant (popup_mgr.add_child was moved earlier; close semantics come from GameDialog).

- [ ] **Step 4: Rewrite `_build_equipped_section` as card grid**

Find the current `_build_equipped_section(vb)` callsite at ~line 3675 and function. Replace its entire body with:

```gdscript
func _build_equipped_section(vb: VBoxContainer) -> void:
	vb.add_child(UICards.section_header("Equipped"))
	var grid := HBoxContainer.new()
	grid.add_theme_constant_override("separation", 8)
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_child(_equipped_card("Weapon",
			player.equipped_weapon_id,
			WeaponRegistry.display_name_for(player.equipped_weapon_id),
			Color(1.00, 0.70, 0.40)))
	var body_armor: Dictionary = player.equipped_armor.get("body", {})
	grid.add_child(_equipped_card("Body",
			String(body_armor.get("id", "")),
			String(body_armor.get("name", "—")),
			Color(0.65, 0.80, 0.95)))
	var ring_name := "—"
	if player.equipped_rings.size() > 0:
		ring_name = String(player.equipped_rings[0].get("name", "—"))
	grid.add_child(_equipped_card("Ring",
			"",
			ring_name,
			Color(0.85, 0.80, 0.95)))
	var amulet_name := "—"
	if not player.equipped_amulet.is_empty():
		amulet_name = String(player.equipped_amulet.get("name", "—"))
	grid.add_child(_equipped_card("Amulet",
			"",
			amulet_name,
			Color(1.00, 0.90, 0.30)))
	vb.add_child(grid)
```

And add the new helper `_equipped_card`:

```gdscript
func _equipped_card(slot: String, _id: String, name: String, tint: Color) -> Control:
	var panel: PanelContainer = UICards.card(tint)
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(col)
	var slot_lbl := Label.new()
	slot_lbl.text = slot
	slot_lbl.add_theme_font_size_override("font_size", 30)
	slot_lbl.add_theme_color_override("font_color", tint)
	slot_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(slot_lbl)
	var name_lbl := Label.new()
	name_lbl.text = name
	name_lbl.add_theme_font_size_override("font_size", 36)
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(name_lbl)
	return panel
```

- [ ] **Step 5: Update `_on_bag_use` / `_on_bag_equip` / `_on_bag_drop` signatures**

Each currently takes `dlg: AcceptDialog`. Change parameter type to `dlg: GameDialog` and replace `dlg.queue_free()` with `dlg.close()` in each function body. Search-and-replace is safe because only these handlers accept the dialog ref.

- [ ] **Step 6: Update `_open_bag_filtered`**

```gdscript
func _open_bag_filtered(category: String) -> void:
	_bag_category = category if category != "" else "all"
	if _bag_dlg != null and is_instance_valid(_bag_dlg):
		_bag_dlg.close()
	_on_bag_pressed()
```

- [ ] **Step 7: Verify in Godot**

Open Bag. Verify:
- "Equipped" gold section header.
- 4 cards in a horizontal row: Weapon / Body / Ring / Amulet, each showing current slot contents.
- Tab swipe still works.
- Equip / Use / Drop buttons still work; bag refreshes after each.
- Single bottom Close.

- [ ] **Step 8: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "feat: Bag dialog uses GameDialog + Equipped card grid"
```

---

## Task 6: Magic dialog migration + school pills

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — `_open_magic_dialog`, `_magic_dlg` type.

- [ ] **Step 1: Change `_magic_dlg` type**

```gdscript
var _magic_dlg: GameDialog = null
```

- [ ] **Step 2: Rewrite `_open_magic_dialog`**

Start of function (dialog construction) — replace the AcceptDialog block with:

```gdscript
	var dlg := GameDialog.create("Magic", Vector2i(960, 1500))
	popup_mgr.add_child(dlg)
	_magic_dlg = dlg
	dlg.set_on_close(func():
		if _magic_dlg == dlg: _magic_dlg = null)
	var vb: VBoxContainer = dlg.body()
	vb.add_child(UICards.section_header("Known Spells"))
```

End of function (popup_centered + signal wiring + manual close button if any) — delete.

- [ ] **Step 3: Add school pills to each spell row**

Inside the spell-row-building loop (find where each spell row is constructed; typically a `HBoxContainer` with a cast button and labels), prepend pills:

```gdscript
	var pill_row := HBoxContainer.new()
	pill_row.add_theme_constant_override("separation", 4)
	for school in SpellRegistry.get_schools(spell_id):
		pill_row.add_child(UICards.pill(String(school).substr(0, 3).to_upper(),
				UICards.school_colour(school)))
	row.add_child(pill_row)
```

And wrap the power / fail display using `accent_value`:

Replace the existing power/fail label construction with:

```gdscript
	var power_lbl: Label = UICards.accent_value("Pow %d" % power, 36)
	row.add_child(power_lbl)
	var fail_lbl: Label = UICards.accent_value("Fail %d%%" % fail, 36)
	row.add_child(fail_lbl)
```

(Preserve variable names `power` / `fail` from the existing code.)

- [ ] **Step 4: Update callsites that reference `_magic_dlg.queue_free`**

Replace with `_magic_dlg.close()`. Also find `dlg.queue_free` inside `_open_magic_dialog` body (any cast handlers) → `dlg.close()`.

- [ ] **Step 5: Verify**

Open Magic. Verify:
- Gold "Known Spells" section header.
- Each spell row has colored school pills on the left (e.g. Fireball → FIR orange pill; Iron Shot → CON white + EAR brown pills).
- Power/Fail numbers in gold.
- Single bottom Close; outside-tap closes.

- [ ] **Step 6: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "feat: Magic dialog uses GameDialog + school pills + accent values"
```

---

## Task 7: Map (minimap) dialog migration

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — `_on_minimap_pressed` (~line 5170), `_map_dlg` type.

- [ ] **Step 1: Change `_map_dlg` type**

```gdscript
var _map_dlg: GameDialog = null
```

- [ ] **Step 2: Rewrite `_on_minimap_pressed`**

Replace the AcceptDialog construction and the end `popup_centered` block. Skeleton:

```gdscript
func _on_minimap_pressed() -> void:
	if _map_dlg != null and is_instance_valid(_map_dlg):
		_close_all_dialogs()
		return
	_close_all_dialogs()
	var popup_mgr: Node = get_node_or_null("UILayer/UI/PopupManager")
	if popup_mgr == null or player == null:
		return
	var dlg := GameDialog.create("Map", Vector2i(960, 1400))
	popup_mgr.add_child(dlg)
	_map_dlg = dlg
	dlg.set_on_close(func():
		if _map_dlg == dlg: _map_dlg = null)
	var vb: VBoxContainer = dlg.body()

	vb.add_child(UICards.section_header("Current Floor"))
	var depth_card: PanelContainer = UICards.card(Color(1.0, 0.85, 0.40))
	var depth_col := VBoxContainer.new()
	depth_card.add_child(depth_col)
	depth_col.add_child(UICards.accent_value(
			"%s Depth %d" % [_current_branch_display(), current_depth], 48))
	vb.add_child(depth_card)

	# Keep the existing minimap TextureRect build here (extracted from the
	# previous AcceptDialog body).
	var minimap_tex_rect := TextureRect.new()
	minimap_tex_rect.texture = _build_minimap_texture()
	minimap_tex_rect.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	minimap_tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	minimap_tex_rect.custom_minimum_size = Vector2(0, 900)
	vb.add_child(minimap_tex_rect)

	vb.add_child(UICards.section_header("Legend"))
	var legend := GridContainer.new()
	legend.columns = 2
	legend.add_theme_constant_override("h_separation", 24)
	legend.add_theme_constant_override("v_separation", 6)
	for pair in [
		["▲", "Stairs up"],
		["▼", "Stairs down"],
		["☥", "Altar"],
		["$", "Shop"],
		["^", "Trap"],
	]:
		var glyph := UICards.accent_value(String(pair[0]), 44)
		legend.add_child(glyph)
		var desc := Label.new()
		desc.text = String(pair[1])
		desc.add_theme_font_size_override("font_size", 36)
		legend.add_child(desc)
	vb.add_child(legend)
```

Note: `_current_branch_display()` and `_build_minimap_texture()` are placeholders for the **existing** branch-name helper and minimap-texture composer already in `GameBootstrap.gd`. Use the real function names discovered in the original `_on_minimap_pressed` body.

- [ ] **Step 3: Verify**

Open Map. Verify:
- Gold "Current Floor" header + gold card showing branch + depth.
- Minimap texture below.
- Gold "Legend" header + 2-column grid of glyph + meaning.
- Single bottom Close.

- [ ] **Step 4: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "feat: Map dialog uses GameDialog + current-floor + legend cards"
```

---

## Task 8: Remaining popups — chrome migration only

**Scope:** Shop, Altar pledge, Essence invoke, Identify picker, Quickslot assign, item info, skill info, god guide.

**Files:**
- Modify: `scripts/core/GameBootstrap.gd` — every remaining `AcceptDialog.new()` callsite.

**Per callsite, apply the following substitution pattern (no card / header changes):**

Old:
```gdscript
var dlg := AcceptDialog.new()
dlg.exclusive = false
dlg.title = "Foo"
dlg.ok_button_text = "Close"
# ... add children ...
popup_mgr.add_child(dlg)
dlg.confirmed.connect(dlg.queue_free)
dlg.canceled.connect(dlg.queue_free)
dlg.close_requested.connect(dlg.queue_free)
dlg.popup_centered(Vector2i(W, H))
```

New:
```gdscript
var dlg := GameDialog.create("Foo", Vector2i(W, H))
popup_mgr.add_child(dlg)
var vb: VBoxContainer = dlg.body()
# ... add children to vb instead of dlg ...
```

All subsequent `dlg.queue_free()` calls in handlers → `dlg.close()`. Handler parameter types `AcceptDialog` → `GameDialog`.

- [ ] **Step 1: Migrate Shop (`_open_shop_dialog`, line 1436)**

Apply substitution. Verify: open a shop from the dungeon (or test scene). Purchase still works; dialog refreshes on buy; Close dismisses.

- [ ] **Step 2: Migrate Altar pledge (inside `_on_altar_tapped`, line 1512)**

Apply substitution. Verify: step on altar → pledge dialog; pledge/decline both behave; no crash.

- [ ] **Step 3: Migrate Essence invoke dialogs**

The Essence row "Invoke" button at line 1598 opens an AcceptDialog for ability pick. Apply substitution.

- [ ] **Step 4: Migrate Identify picker (`_on_identify_one_requested` at 2276 and `_on_identify_pick` at 2329)**

Apply substitution. Verify: read identify scroll → picker dialog opens; pick → item identified; close dismisses cleanly.

- [ ] **Step 5: Migrate Quickslot assign (`_assign_quickslot_item` callsite builder at line 507)**

The builder is around line 507-577. Apply substitution.

- [ ] **Step 6: Migrate item info popup (`_on_bag_info` at 4262)**

Apply substitution. Small body — just one GameDialog with labels in body().

- [ ] **Step 7: Migrate skill info popup**

Search for any remaining `AcceptDialog.new()` callsites that show a skill description (the description text is in `_SKILL_DESCS`). Apply substitution.

- [ ] **Step 8: Migrate god guide popup**

Search for `GodRegistry.GUIDES` usage in a dialog. Apply substitution.

- [ ] **Step 9: Final audit — zero AcceptDialog remaining**

Run:

```bash
grep -n 'AcceptDialog' scripts/core/GameBootstrap.gd
```

Expected: no matches (or only in a comment describing the legacy).

- [ ] **Step 10: Verify end-to-end**

Play a short run:
1. Start character → Status works.
2. Pick up item → Bag works, Equipped grid updates.
3. Buy from shop → Shop works.
4. Cast a spell → Magic works, pills render.
5. Use altar → pledge dialog works.
6. Open minimap → Map works.
7. Read identify scroll → picker works.
8. Assign quickslot → assign dialog works.
9. Every dialog has **one** bottom Close, closes on outside-tap and ESC.

- [ ] **Step 11: Commit**

```bash
git add scripts/core/GameBootstrap.gd
git commit -m "refactor: migrate all remaining dialogs to GameDialog"
```

---

## Final verification

- [ ] **Step 1: Pull-through check**

Run the game, open every dialog listed in Task 8 Step 10. Take a screenshot of each. Confirm the full-width bottom Close and gold title in every one.

- [ ] **Step 2: Memory update**

Append a session note to `.claude-memory/dcss_port_progress.md` under a new section describing the UI overhaul and the introduction of `GameDialog` / `UICards`. Cross off any relevant backlog items in `.claude-memory/dcss_port_backlog.md`.

- [ ] **Step 3: Push**

```bash
git push
```
