---
name: Skip brainstorm when detailed spec/guide already exists
description: When the project contains a detailed design/spec doc (e.g. clean_room_reboot_guide.md), skip brainstorming and planning steps — go directly to TodoWrite + implementation
type: feedback
originSessionId: 1cc7ec78-12c9-429a-9ad0-009a1a55bfef
---
Rule: If the project already has a detailed, current design/spec/guide
document, treat that doc as the approved plan. Do NOT run the brainstorming
skill, do NOT write a separate implementation plan, and do NOT re-propose 2-3
approaches. Create TodoWrite tasks from the doc's checklist/order and execute.

**Why**: User said explicitly "항목별 세부 개발계획도 가이드에있으니까 바로
구현해" (per-item detailed plans are in the guide, just implement) during the
2026-04-22 PROJ_D reboot session. They had written a 941-line guide covering
architecture, data model, system specs, build order, UI whitelist, and
pitfalls — re-doing that work as "brainstorming" would have been pure churn.

**How to apply**:
- Still ask one scoped question: *which slice* of the spec to tackle this
  session. The spec is big; the session is small.
- Still verify the spec's specific claims as you go (e.g., this session
  caught `BagTooltips` misclassified as clean in the UI whitelist). Fix the
  spec inline when you find errors.
- Skip: Visual Companion offer, 2-3 approach proposals, separate plan doc.
- Do: TodoWrite per task, mark in_progress/completed as you go, run any
  available verification (grep for undefined refs, headless parse if
  possible), and note deferred items explicitly.

**When NOT to apply**: If the doc is stale, vague, or contradicts observed
code state, fall back to clarifying questions. The rule is "trust the spec
when it's current and detailed", not "never brainstorm".
