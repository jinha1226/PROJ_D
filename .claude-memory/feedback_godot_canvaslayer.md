---
name: Godot CanvasLayer → use get_viewport().set_input_as_handled
description: CanvasLayer has no accept_event() — that's Control-only. Use get_viewport().set_input_as_handled() to swallow events from a CanvasLayer script. Silent-parse-error trap.
type: feedback
originSessionId: bda8e519-d968-4fec-8b43-05dd2de5b447
---
`accept_event()` is a `Control` method, NOT a `CanvasLayer` method. Calling
it from a `CanvasLayer`-extending script produces a parse error
("Function accept_event() not found in base self"). Godot still keeps the
class registered in the cache, but instances instantiate broken / invisible.

**Why**: Godot's parse error for a missing method doesn't block the
class_name from appearing in `global_script_class_cache.cfg`, so
`GameDialog.create()` etc. continue to compile at call-sites. But the
dialog scene instantiates into a non-functional state — symptom is "button
signal fires, dialog reference is valid, but nothing renders and no
visible console error" on mobile web. We chased this for a full session
(2026-04-21 session 6) with a wrong diagnosis — "nested CanvasLayers
don't render descendants" — and a wrong fix (switching parent from
PopupManager to GameBootstrap). The real fix shipped the next session
when the parse error finally surfaced in the IDE.

**Bogus lesson from session 6** (now retracted): "CanvasLayer-inside-
CanvasLayer doesn't render." — this is NOT actually true. Nested
CanvasLayers DO render; `popup_mgr.add_child(GameDialog)` would have
worked fine if the script had compiled. Don't prop up this pattern.

**How to apply**:
- In `_unhandled_input` from a `CanvasLayer` script, swallow the event with
  `get_viewport().set_input_as_handled()`, not `accept_event()`.
- Inside a `gui_input` callback on a Control child (e.g.
  `Dim.gui_input.connect(...)`), the same rule holds if the callback lives
  on the CanvasLayer — call `get_viewport().set_input_as_handled()`, not
  `self.accept_event()`.
- When a Godot dialog "silently doesn't render" with no console error,
  OPEN THE SCRIPT IN THE IDE FIRST. Editor shows parse errors that the
  headless export pipeline may swallow.
