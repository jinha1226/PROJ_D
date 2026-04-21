---
name: Godot CanvasLayer nesting gotcha
description: Never attach a CanvasLayer node as a child of another CanvasLayer in this project — descendants don't render. Use Node2D parent (GameBootstrap) instead.
type: feedback
---

CanvasLayer dialogs / overlays MUST be attached to a Node-typed parent
(e.g. GameBootstrap which extends Node2D), NOT to another CanvasLayer.

**Why**: Godot 4's render pipeline does not properly compose nested
CanvasLayers — the inner CanvasLayer's CanvasItem descendants silently
fail to draw. Symptom: input still routes (button highlights work),
but the visuals never appear, and there is no console error to
explain it. We hit this 2026-04-21 when GameDialog (CanvasLayer
layer=100) was added to PopupManager (CanvasLayer layer=10) — the
Status button highlighted but no panel rendered. Fix at 024d0e08.

**How to apply**:
- Working pattern in this codebase: `add_child(canvas_layer_instance)`
  from inside GameBootstrap (Node2D) — proven by ResultScreen and
  SkillLevelUpToast.
- Broken pattern: `popup_mgr.add_child(canvas_layer_instance)` where
  popup_mgr is the PopupManager (CanvasLayer).
- AcceptDialog / Window subwindows are EXEMPT — those use Godot's
  separate Window subsystem and render fine when added to PopupManager.
- For new GameDialog calls (Bag / Skills / Magic / Map migrations),
  attach via `self.add_child(dlg)` not `popup_mgr.add_child(dlg)`.
