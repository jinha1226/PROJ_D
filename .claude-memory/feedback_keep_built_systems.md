---
name: feedback-keep-built-systems
description: "User prefers leaving already-implemented systems dormant rather than deleting them, even when removing the gameplay trigger that activates them. Don't propose mass deletion of working code without specific reason."
metadata: 
  node_type: memory
  type: feedback
  originSessionId: ae9b7462-a38a-4a0b-9765-08fe3229d2e0
---

When the user asks to remove a feature, default to **removing only the trigger/entry point**, not the implementation. Working code stays as dormant code unless the user explicitly says to delete it.

**Why:** User explicitly redirected: "신앙자체를 다 삭제하진말고 그냥 3층에서 신앙 선택 분기만삭제 하자. 생각해보니까 구현해놓은걸 굳이 또 안할이유가없네" (2026-05-21). The reasoning: implemented work has cost; if there's any chance it gets reused, deletion is wasted motion. Code that's not referenced from any gameplay path is effectively gone from the player's perspective anyway.

**How to apply:** When the user says "remove X" or "delete X system":
- First ask: does X have gameplay triggers (UI buttons, event handlers, scripted spawns) AND implementation (data files, system scripts)?
- If yes, default to removing only the triggers, leaving the implementation as dormant code.
- Explicit deletion-of-implementation requires user confirming "yes delete the whole thing", not just "remove X".
- Doesn't apply to: removing trial code never used, removing scaffolding from finished features, security-driven removal of risky code. Apply judgment.

Related: [[reboot-decision]] — the PROJ_D reboot kept `oldproject/` archived rather than deleted for the same reason.
